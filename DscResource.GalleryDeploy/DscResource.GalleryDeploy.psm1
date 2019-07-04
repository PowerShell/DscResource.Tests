$projectRootPath = Split-Path -Path $PSScriptRoot -Parent
$testHelperPath = Join-Path -Path $projectRootPath -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

$script:localizedData = Get-LocalizedData -ModuleName 'DscResource.GalleryDeploy' -ModuleRoot $PSScriptRoot

<#
    .SYNOPSIS
        This command will loop through all scripts and publish any script that
        meet the publishing criteria.

    .PARAMETER ResourceModuleName
        Name of the resource module being deployed.

    .PARAMETER Path
        The path to the examples. This path will be recursively search for
        examples to publish.

    .PARAMETER Branch
        The name of the branch being deployed.

    .PARAMETER ModuleRootPath
        The root path to the repository.
#>
function Start-GalleryDeploy
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceModuleName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Branch,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleRootPath
    )

    if ($Branch -ne 'master')
    {
        <#
            if not on 'master' we enter debug mode, which means that
            Publish-Script will be called with `-WhatIf`.
        #>
        Write-Info -Message $script:localizedData.NotOnMasterBranch -ForegroundColor White

        $isDebugMode = $true
    }
    else
    {
        $isDebugMode = $false

        <#
            Checking if there is a environment variable in which we expect to
            get the PowerShell Gallery API key.
        #>
        if ($env:gallery_api)
        {
            Write-Info -Message $script:localizedData.FoundApiKey -ForegroundColor White
        }
        else
        {
            Write-Warning -Message ('{0} {1}' -f $script:localizedData.CannotPublish, $script:localizedData.MissingApiKey)

            return
        }
    }

    $testOptInFilePath = Join-Path -Path $ModuleRootPath -ChildPath '.MetaTestOptIn.json'

    $optIns = @()
    if (Test-Path $testOptInFilePath)
    {
        $optIns = Get-Content -LiteralPath $testOptInFilePath | ConvertFrom-Json
    }

    <#
        Checking if the repository has opt-in for the example validation
        common tests.
    #>
    $optInValue = 'Common Tests - Validate Example Files'
    if ($optIns -notcontains $optInValue)
    {
        Write-Warning -Message ('{0} {1}' -f `
                $script:localizedData.CannotPublish,
            ($script:localizedData.MissingExampleValidationOptIn -f $optInValue)
        )

        return
    }

    Copy-ResourceModuleToPSModulePath -ResourceModuleName $ResourceModuleName -ModuleRootPath $ModuleRootPath | Out-Null

    <#
        All the preliminary checks are finished and should now try to publish.
    #>
    Write-Info -Message $script:localizedData.EvaluatingExamples -ForegroundColor White

    $examplesToPublish = @()

    <#
        Only examples that has a filename that ends with 'Config' will be
        evaluated.
    #>
    $exampleFile = Get-ChildItem -Path $Path -Filter '*Config.ps1' -Recurse
    foreach ($exampleToValidate in $exampleFile)
    {
        $requiredModules = Get-ResourceModulesInConfiguration -ConfigurationPath $exampleToValidate.FullName |
            Where-Object -Property Name -ne $ResourceModuleName

        if ($requiredModules)
        {
            Install-DependentModule -Module $requiredModules
        }

        $testScriptFileInfoResult = Test-PublishMetadata -Path $exampleToValidate.FullName
        if ($testScriptFileInfoResult)
        {
            $passedTest = Test-ConfigurationName -Path $exampleToValidate.FullName
            if ($passedTest)
            {
                $filenameWithoutExtension = Get-PublishFileName -Path $exampleToValidate.FullName

                # Look if the script don't exist or is a new version.
                $latestScriptVersionInGallery = Find-Script -Name $filenameWithoutExtension -ErrorAction 'SilentlyContinue'
                if ($latestScriptVersionInGallery)
                {
                    # Already exist in Gallery, verify if newer version.
                    if ($testScriptFileInfoResult.Version -gt $latestScriptVersionInGallery.Version)
                    {
                        # The example is newer than the one already published.
                        $publishExample = $true
                    }
                    else
                    {
                        # The example is the same version as the one already published.
                        $publishExample = $false
                        Write-Info -Message ($script:localizedData.ExampleIsAlreadyPublished -f $exampleToValidate.FullName) -ForegroundColor White
                    }
                }
                else
                {
                    # The example does not exist (never been published)
                    $publishExample = $true
                }
            }
            else
            {
                $publishExample = $false

                $skipWarningMessage = $script:localizedData.SkipPublish -f $exampleToValidate.FullName
                Write-Warning -Message ('{0} {1}' -f `
                        $skipWarningMessage, $script:localizedData.ConfigurationNameMismatch)
            }
        }
        else
        {
            <#
                Missing script metadata. A warning message has already been
                written by the helper function Test-PublishMetadata.
            #>
            $publishExample = $false
        }

        if ($publishExample)
        {
            Write-Verbose -Message ($script:localizedData.AddingExampleToBePublished -f $exampleToValidate.FullName)
            $examplesToPublish += $testScriptFileInfoResult
        }
    }

    # Test GUID's
    $duplicateGuid = $examplesToPublish |
        Group-Object -Property 'Guid' |
        Where-Object -FilterScript { $_.Count -gt 1 }

    if ($duplicateGuid)
    {
        $duplicateExamples = $examplesToPublish | Where-Object -FilterScript { $_.Guid -in $duplicateGuid.Name }

        Write-Warning -Message ($script:localizedData.DuplicateGuid -f ($duplicateExamples.Path -join "', '"))
    }

    # Removing examples that contained duplicate GUID's.
    $examplesToPublish = $examplesToPublish | Where-Object -FilterScript { $_.Guid -notin $duplicateGuid.Name }
    foreach ($exampleToPublish in $examplesToPublish)
    {
        $publishFilenameWithoutExtension = Get-PublishFileName -Path $exampleToPublish.Path

        $publishFilename = '{0}{1}' -f `
            $publishFilenameWithoutExtension,
            (Get-Item $exampleToPublish.Path).Extension

        $destinationPath = Join-Path -Path $env:TEMP -ChildPath $publishFilename

        try
        {
            Copy-Item -Path $exampleToPublish.Path -Destination $destinationPath -Force

            Write-Info -Message ($script:localizedData.PublishExample -f $exampleToPublish.Name, $exampleToPublish.Version, $publishFilenameWithoutExtension)

            $publishScriptParameters = @{
                Path        = $destinationPath
                NuGetApiKey = $env:gallery_api
            }

            if ($isDebugMode)
            {
                $publishScriptParameters['WhatIf'] = $true
            }

            Publish-Script @publishScriptParameters
        }
        catch
        {
            throw $_
        }
        finally
        {
            Remove-Item -Path $destinationPath -Force -ErrorAction 'Continue'
        }
    }
}

<#
    .SYNOPSIS
        This command will test if an script file has the required metadata to
        be published.
        If an error occurs a warning will be written, containing the error
        message.

    .PARAMETER Path
        The path to the example to be tested.

    .OUTPUTS
        Returns a Microsoft.PowerShell.Commands.PSScriptInfo object for the
        tested script file, or $null if a known error occurred.
#>
function Test-PublishMetadata
{
    [CmdletBinding()]
    [OutputType([Object])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    $testScriptFileInfoResult = $null

    try
    {
        $testScriptFileInfoResult = Test-ScriptFileInfo -Path $Path
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        $skipWarningMessage = $script:localizedData.SkipPublish -f $Path

        <#
            This is known to throw three errors (FullyQualifiedErrorId).
        #>
        switch ($_.FullyQualifiedErrorId)
        {
            'ScriptParseError,Test-ScriptFileInfo'
            {
                Write-Warning -Message ('{0} {1}' -f `
                        $skipWarningMessage, ($script:localizedData.ScriptParseError -f $errorMessage))
            }

            'MissingPSScriptInfo,Test-ScriptFileInfo'
            {
                Write-Warning -Message ('{0} {1}' -f `
                        $skipWarningMessage, ($script:localizedData.MissingMetadata -f $errorMessage))
            }

            'MissingRequiredPSScriptInfoProperties,Test-ScriptFileInfo'
            {
                Write-Warning -Message ('{0} {1}' -f `
                        $skipWarningMessage, ($script:localizedData.MissingRequiredMetadataProperties -f $errorMessage))
            }

            'InvalidGuid,Test-ScriptFileInfo'
            {
                Write-Warning -Message ('{0} {1}' -f `
                        $skipWarningMessage, ($script:localizedData.InvalidGuid -f $errorMessage))
            }

            default
            {
                # If the error is not recognized then throw.
                throw ($script:localizedData.TestScriptFileInfoError -f $Path, $_)
            }
        }
    }

    return $testScriptFileInfoResult
}

<#
    .SYNOPSIS
        This command will test so the filename and the configuration name
        are equal.

    .PARAMETER Path
        The path to the example to be tested.

    .OUTPUTS
        Returns a $true if they are equal, or $false if they are not.
#>
function Test-ConfigurationName
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    $publishFilename = Get-PublishFileName -Path $Path

    $parseErrors = $null
    $definitionAst = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $null, [ref] $parseErrors)

    if ($parseErrors)
    {
        throw $parseErrors
    }

    $astFilter = {
        $args[0] -is [System.Management.Automation.Language.ConfigurationDefinitionAst]
    }

    $configurationDefinition = $definitionAst.Find($astFilter, $true)

    $isOfCorrectType = $configurationDefinition.ConfigurationType -eq [System.Management.Automation.Language.ConfigurationType]::Resource

    $configurationName = $configurationDefinition.InstanceName.Value
    $hasEqualName = $configurationName -eq $publishFilename

    <#
        The name can contain only letters, numbers, and underscores.
        The name must start with a letter, and it must end with a letter or a number.
    #>
    $hasCorrectNamingConvention = $configurationName -match '^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9]$'

    if ($isOfCorrectType -and $hasEqualName -and $hasCorrectNamingConvention)
    {
        $result = $true
    }
    else
    {
        $result = $false
    }

    return $result
}
