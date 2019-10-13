<#
    .SYNOPSIS
        Helper functions for the common tests (Meta.Tests.ps1).
#>

<#
    Test if type Microsoft.DscResourceKit.Test is loaded into the session,
    if not load all the helper types.
#>
if (-not ('Microsoft.DscResourceKit.Test' -as [Type]))
{
    <#
        This loads the types:
            Microsoft.DscResourceKit.Test
            Microsoft.DscResourceKit.UnitTest
            Microsoft.DscResourceKit.IntegrationTest

        Change WarningAction so it does not output a warning for the sealed class.
    #>
    Add-Type -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Microsoft.DscResourceKit.cs') -WarningAction SilentlyContinue
}

<#
    .SYNOPSIS
        Creates a nuspec file for a nuget package at the specified path.

    .EXAMPLE
        New-Nuspec `
            -PackageName 'TestPackage' `
            -Version '1.0.0.0' `
            -Author 'Microsoft Corporation' `
            -Owners 'Microsoft Corporation' `
            -DestinationPath C:\temp `
            -LicenseUrl 'http://license' `
            -PackageDescription 'Description of the package' `
            -Tags 'tag1 tag2'
#>
function New-Nuspec
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Version,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Author,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Owners,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DestinationPath,

        [Parameter()]
        [System.String]
        $LicenseUrl,

        [Parameter()]
        [System.String]
        $ProjectUrl,

        [Parameter()]
        [System.String]
        $IconUrl,

        [Parameter()]
        [System.String]
        $PackageDescription,

        [Parameter()]
        [System.String]
        $ReleaseNotes,

        [Parameter()]
        [System.String]
        $Tags
    )

    $currentYear = (Get-Date).Year

    $nuspecFileContent += @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd">
  <metadata>
    <id>$PackageName</id>
    <version>$Version</version>
    <authors>$Author</authors>
    <owners>$Owners</owners>
"@

    if (-not [System.String]::IsNullOrEmpty($LicenseUrl))
    {
        $nuspecFileContent += @"
    <licenseUrl>$LicenseUrl</licenseUrl>
"@
    }

    if (-not [System.String]::IsNullOrEmpty($ProjectUrl))
    {
        $nuspecFileContent += @"
    <projectUrl>$ProjectUrl</projectUrl>
"@
    }

    if (-not [System.String]::IsNullOrEmpty($IconUrl))
    {
        $nuspecFileContent += @"
    <iconUrl>$IconUrl</iconUrl>
"@
    }

    $nuspecFileContent += @"
    <requireLicenseAcceptance>true</requireLicenseAcceptance>
    <description>$PackageDescription</description>
    <releaseNotes>$ReleaseNotes</releaseNotes>
    <copyright>Copyright $currentYear</copyright>
    <tags>$Tags</tags>
  </metadata>
</package>
"@

    if (-not (Test-Path -Path $DestinationPath))
    {
        $null = New-Item -Path $DestinationPath -ItemType 'Directory'
    }

    $nuspecFilePath = Join-Path -Path $DestinationPath -ChildPath "$PackageName.nuspec"
    $null = New-Item -Path $nuspecFilePath -ItemType 'File' -Force

    $null = Set-Content -Path $nuspecFilePath -Value $nuspecFileContent
}

<#
    .SYNOPSIS
        Downloads and installs a module from PowerShellGallery using
        Nuget.

    .PARAMETER ModuleName
        Name of the module to install

    .PARAMETER DestinationPath
        Path where module should be installed
#>
function Install-ModuleFromPowerShellGallery
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DestinationPath
    )

    $nugetPath = 'nuget.exe'

    # Can't assume nuget.exe is available - look for it in Path
    if ($null -eq (Get-Command -Name $nugetPath -ErrorAction 'SilentlyContinue'))
    {
        # Is it in temp folder?
        $tempNugetPath = Join-Path -Path $env:temp -ChildPath $nugetPath

        if (-not (Test-Path -Path $tempNugetPath))
        {
            # Nuget.exe can't be found - download it to temp folder
            $nugetDownloadURL = 'http://nuget.org/nuget.exe'

            Invoke-WebRequest -Uri $nugetDownloadURL -OutFile $tempNugetPath
            Write-Verbose -Message "nuget.exe downloaded at $tempNugetPath"
        }
        else
        {
            Write-Verbose -Message "Using Nuget.exe found at $tempNugetPath"
        }

        $nugetPath = $tempNugetPath
    }

    $moduleOutputDirectory = "$(Split-Path -Path $DestinationPath -Parent)\"

    $nugetSource = 'https://www.powershellgallery.com/api/v2'

    # Use Nuget.exe to install the module
    $arguments = @(
        "install $ModuleName",
        "-source $nugetSource",
        "-outputDirectory $moduleOutputDirectory",
        '-ExcludeVersion'
    )

    $result = Start-Process -FilePath $nugetPath -ArgumentList $arguments -PassThru -Wait

    if ($result.ExitCode -ne 0)
    {
        throw "Installation of module $ModuleName using Nuget failed with exit code $($result.ExitCode)."
    }

    Write-Verbose -Message "The module $ModuleName was installed using Nuget."
}

<#
    .SYNOPSIS
        Initializes an environment for running unit or integration tests
        on a DSC resource.

        This includes:
        1. Updates the $env:PSModulePath to ensure the correct module is tested.
        2. Imports the module to test.
        3. Sets the PowerShell ExecutionMode to Unrestricted.
        4. Produces a test object to store the backed up settings.

        The above changes are reverted by calling the Restore-TestEnvironment
        function.

        Returns a test environment object which must be passed to the
        Restore-TestEnvironment function to allow it to restore the system
        back to the original state.

    .PARAMETER DscModuleName
        The name of the DSC Module containing the resource that the tests will be
        run on.

    .PARAMETER DscResourceName
        The full name of the DSC resource that the tests will be run on. This is
        usually the name of the folder containing the actual resource MOF file.

    .PARAMETER TestType
        Specifies the type of tests that are being initialized. It can be:
        Unit: Initialize for running Unit tests on a DSC resource. Default.
        Integration: Initialize for running Integration tests on a DSC resource.

    .PARAMETER ResourceType
        Specifies if the DscResource under test is mof-based or class-based.
        The default value is 'mof'.

        It can be:
        Mof: The test initialization assumes a Mof-based DscResource folder structure.
        Class: The test initialization assumes a Class-based DscResource folder structure.

    .EXAMPLE
        $TestEnvironment = Initialize-TestEnvironment `
            -DSCModuleName 'xNetworking' `
            -DSCResourceName 'MSFT_xFirewall' `
            -TestType Unit

        This command will initialize the test environment for Unit testing
        the MSFT_xFirewall mof-based DSC resource in the xNetworking DSC module.

    .EXAMPLE
        $TestEnvironment = Initialize-TestEnvironment `
            -DSCModuleName 'SqlServerDsc' `
            -DSCResourceName 'SqlAGDatabase' `
            -TestType Unit
            -ResourceType Class

        This command will initialize the test environment for Unit testing
        the SqlAGDatabase class-based DSC resource in the SqlServer DSC module.

    .EXAMPLE
        $TestEnvironment = Initialize-TestEnvironment `
            -DSCModuleName 'xNetworking' `
            -DSCResourceName 'MSFT_xFirewall' `
            -TestType Integration

        This command will initialize the test environment for Integration testing
        the MSFT_xFirewall DSC resource in the xNetworking DSC module.
#>
function Initialize-TestEnvironment
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DscModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DscResourceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Unit', 'Integration')]
        [System.String]
        $TestType,

        [Parameter()]
        [ValidateSet('Mof', 'Class')]
        [System.String]
        $ResourceType = 'Mof'
    )

    Write-Verbose -Message "Initializing test environment for $TestType testing of $DscResourceName in module $DscModuleName"

    $moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent
    $moduleManifestFilePath = Join-Path -Path $moduleRootFilePath -ChildPath "$DscModuleName.psd1"

    if (Test-Path -Path $moduleManifestFilePath)
    {
        Write-Verbose -Message "Module manifest $DscModuleName.psd1 detected at $moduleManifestFilePath"
    }
    else
    {
        throw "Module manifest could not be found for the module $DscModuleName in the root folder $moduleRootFilePath"
    }

    # Import the module to test
    if ($TestType -ieq 'Unit')
    {
        switch ($ResourceType)
        {
            'Mof'
            {
                $resourceTypeFolderName = 'DSCResources'
            }

            'Class'
            {
                $resourceTypeFolderName = 'DSCClassResources'
            }
        }

        $dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath $resourceTypeFolderName
        $dscResourceToTestFolderFilePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $DscResourceName

        $moduleToImportFilePath = Join-Path -Path $dscResourceToTestFolderFilePath -ChildPath "$DscResourceName.psm1"
    }
    else
    {
        $moduleToImportFilePath = $moduleManifestFilePath
    }

    Import-Module -Name $moduleToImportFilePath -Scope 'Global' -Force

    <#
        Set the PSModulePath environment variable so that the module path that includes the module
        we want to test appears first. LCM will then use this path to locate modules when
        integration tests are called. Placing the path we want first ensures the correct module
        will be tested.
    #>
    $moduleParentFilePath = Split-Path -Path $moduleRootFilePath -Parent

    $oldPSModulePath = $env:PSModulePath

    if ($null -ne $oldPSModulePath)
    {
        $oldPSModulePathSplit = $oldPSModulePath.Split(';')
    }
    else
    {
        $oldPSModulePathSplit = $null
    }

    if ($oldPSModulePathSplit -ccontains $moduleParentFilePath)
    {
        # Remove the existing module path from the new PSModulePath
        $newPSModulePathSplit = $oldPSModulePathSplit | Where-Object { $_ -ne $moduleParentFilePath }
        $newPSModulePath = $newPSModulePathSplit -join ';'
    }
    else
    {
        $newPSModulePath = $oldPSModulePath
    }

    $newPSModulePath = "$moduleParentFilePath;$newPSModulePath"

    Set-PSModulePath -Path $newPSModulePath

    if ($TestType -ieq 'Integration')
    {
        <#
            For integration tests we have to set the machine's PSModulePath because otherwise the
            DSC LCM won't be able to find the resource module being tested or may use the wrong one.
        #>
        Set-PSModulePath -Path $newPSModulePath -Machine

        # Reset the DSC LCM
        Reset-DSC
    }

    # Preserve and set the execution policy so that the DSC MOF can be created
    $oldExecutionPolicy = Get-ExecutionPolicy
    if ($oldExecutionPolicy -ine 'Unrestricted')
    {
        Set-ExecutionPolicy -ExecutionPolicy 'Unrestricted' -Scope 'Process' -Force
    }

    # Return the test environment
    return @{
        DSCModuleName      = $DscModuleName
        DSCResourceName    = $DscResourceName
        TestType           = $TestType
        ImportedModulePath = $moduleToImportFilePath
        OldPSModulePath    = $oldPSModulePath
        OldExecutionPolicy = $oldExecutionPolicy
    }
}

<#
    .SYNOPSIS
        Restores the environment after running unit or integration tests
        on a DSC resource.

        This restores the following changes made by calling
        Initialize-TestEnvironment:
        1. Restores the $env:PSModulePath if it was changed.
        2. Restores the PowerShell execution policy.
        3. Resets the DSC LCM if running Integration tests.

    .PARAMETER TestEnvironment
        The hashtable created by the Initialize-TestEnvironment.

    .EXAMPLE
        Restore-TestEnvironment -TestEnvironment $TestEnvironment
#>
function Restore-TestEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $TestEnvironment
    )

    Write-Verbose -Message "Cleaning up Test Environment after $($TestEnvironment.TestType) testing of $($TestEnvironment.DSCResourceName) in module $($TestEnvironment.DSCModuleName)."

    if ($TestEnvironment.TestType -ieq 'Integration')
    {
        # Reset the DSC LCM
        Reset-DSC
    }

    # Restore PSModulePath
    if ($TestEnvironment.OldPSModulePath -ne $env:PSModulePath)
    {
        Set-PSModulePath -Path $TestEnvironment.OldPSModulePath

        if ($TestEnvironment.TestType -eq 'Integration')
        {
            # Restore the machine PSModulePath for integration tests.
            Set-PSModulePath -Path $TestEnvironment.OldPSModulePath -Machine
        }
    }

    # Restore the Execution Policy
    if ($TestEnvironment.OldExecutionPolicy -ne (Get-ExecutionPolicy))
    {
        Set-ExecutionPolicy -ExecutionPolicy $TestEnvironment.OldExecutionPolicy -Scope 'Process' -Force
    }
}

<#
    .SYNOPSIS
        Resets the DSC LCM by performing the following functions:
        1. Cancel any currently executing DSC LCM operations
        2. Remove any DSC configurations that:
            - are currently applied
            - are pending application
            - have been previously applied

        The purpose of this function is to ensure the DSC LCM is in a known
        and idle state before an integration test is performed that will
        apply a configuration.

        This is to prevent an integration test from being performed but failing
        because the DSC LCM is applying a previous configuration.

        This function should be called after each Describe block in an integration
        test to ensure the DSC LCM is reset before another test DSC configuration
        is applied.
    .EXAMPLE
        Reset-DSC

        This command will reset the DSC LCM and clear out any DSC configurations.
#>
function Reset-DSC
{
    [CmdletBinding()]
    param ()

    Write-Verbose -Message 'Resetting the DSC LCM'

    Stop-DscConfiguration -ErrorAction 'SilentlyContinue' -WarningAction 'SilentlyContinue' -Force
    Remove-DscConfigurationDocument -Stage 'Current' -Force
    Remove-DscConfigurationDocument -Stage 'Pending' -Force
    Remove-DscConfigurationDocument -Stage 'Previous' -Force
}

<#
    .SYNOPSIS
        Tests if a PowerShell file contains a DSC class resource.

    .PARAMETER FilePath
        The full path to the file to test.

    .EXAMPLE
        Test-ContainsClassResource -ModulePath 'c:\mymodule\myclassmodule.psm1'

        This command will test myclassmodule for the presence of any class-based
        DSC resources.
#>
function Test-FileContainsClassResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.String]
        $FilePath
    )

    $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)
    $attributeAst = $fileAst.FindAll( { $args[0] -is [System.Management.Automation.Language.AttributeAst] }, $false)

    foreach ($fileAttributeAst in $attributeAst)
    {
        if ($fileAttributeAst.Extent.Text -ieq '[DscResource()]')
        {
            return $true
        }
    }

    return $false
}

<#
    .SYNOPSIS
        Retrieves the name(s) of any DSC class resources from a PowerShell file.

    .PARAMETER FilePath
        The full path to the file to test.

    .EXAMPLE
        Get-ClassResourceNameFromFile -FilePath 'c:\mymodule\myclassmodule.psm1'

        This command will get any DSC class resource names from the myclassmodule module.
#>
function Get-ClassResourceNameFromFile
{
    [OutputType([String[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.String]
        $FilePath
    )

    $classResourceNames = [String[]]@()

    if (Test-FileContainsClassResource -FilePath $FilePath)
    {
        $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)

        $typeDefinitionAsts = $fileAst.FindAll( { $args[0] -is [System.Management.Automation.Language.TypeDefinitionAst] }, $false)
        foreach ($typeDefinitionAst in $typeDefinitionAsts)
        {
            if ($typeDefinitionAst.Attributes.TypeName.Name -ieq 'DscResource')
            {
                $classResourceNames += $typeDefinitionAst.Name
            }
        }
    }

    return $classResourceNames
}

<#
    .SYNOPSIS
        Tests if a module contains a script resource.

    .PARAMETER ModulePath
        The path to the module to test.
#>
function Test-ModuleContainsScriptResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.String]
        $ModulePath
    )

    $dscResourcesFolderFilePath = Join-Path -Path $ModulePath -ChildPath 'DscResources'
    $mofSchemaFiles = Get-ChildItem -Path $dscResourcesFolderFilePath -Filter '*.schema.mof' -File -Recurse

    return ($null -ne $mofSchemaFiles)
}

<#
    .SYNOPSIS
        Tests if a module contains a class resource.

    .PARAMETER ModulePath
        The path to the module to test.
#>
function Test-ModuleContainsClassResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.String]
        $ModulePath
    )

    $psm1Files = Get-Psm1FileList -FilePath $ModulePath

    foreach ($psm1File in $psm1Files)
    {
        if (Test-FileContainsClassResource -FilePath $psm1File.FullName)
        {
            return $true
        }
    }

    return $false
}

<#
    .SYNOPSIS
        Retrieves all .psm1 files under the given file path.

    .PARAMETER FilePath
        The root file path to gather the .psm1 files from.
#>
function Get-Psm1FileList
{
    [OutputType([Object[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.String]
        $FilePath
    )

    return Get-ChildItem -Path $FilePath -Filter '*.psm1' -File -Recurse
}

<#
    .SYNOPSIS
        Retrieves the parse errors for the given file.

    .PARAMETER FilePath
        The path to the file to get parse errors for.
#>
function Get-FileParseErrors
{
    [OutputType([System.Management.Automation.Language.ParseError[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.String]
        $FilePath
    )

    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref] $null, [ref] $parseErrors)

    return $parseErrors
}

<#
    .SYNOPSIS
        Retrieves all text files under the given root file path.

    .PARAMETER Root
        The root file path under which to retrieve all text files.

    .NOTES
        Retrieves all files with the '.gitignore', '.gitattributes', '.ps1', '.psm1', '.psd1',
        '.json', '.xml', '.cmd', or '.mof' file extensions.
#>
function Get-TextFilesList
{
    [OutputType([System.IO.FileInfo[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Root
    )

    $textFileExtensions = @('.gitignore', '.gitattributes', '.ps1', '.psm1', '.psd1', '.json', '.xml', '.cmd', '.mof', '.md', '.js', '.yml')

    return Get-ChildItem -Path $Root -File -Recurse | Where-Object { $textFileExtensions -contains $_.Extension }
}

<#
    .SYNOPSIS
        Tests if a file is encoded in Unicode.

    .PARAMETER FileInfo
        The file to test.
#>
function Test-FileInUnicode
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.IO.FileInfo]
        $FileInfo
    )

    $filePath = $FileInfo.FullName
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $zeroBytes = @( $fileBytes -eq 0 )

    return ($zeroBytes.Length -ne 0)
}

<#
    .SYNOPSIS
        Retrieves the names of all script resources for the given module.

    .PARAMETER ModulePath
        The path to the module to retrieve the script resource names of.
#>
function Get-ModuleScriptResourceNames
{
    [OutputType([String[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.String]
        $ModulePath
    )

    $scriptResourceNames = @()

    $dscResourcesFolderFilePath = Join-Path -Path $ModulePath -ChildPath 'DscResources'
    $mofSchemaFiles = Get-ChildItem -Path $dscResourcesFolderFilePath -Filter '*.schema.mof' -File -Recurse

    foreach ($mofSchemaFile in $mofSchemaFiles)
    {
        $scriptResourceName = $mofSchemaFile.BaseName -replace '.schema', ''
        $scriptResourceNames += $scriptResourceName
    }

    return $scriptResourceNames
}

<#
    .SYNOPSIS
        Imports the PS Script Analyzer module.
        Installs the module from the PowerShell Gallery if it is not already installed.
#>
function Import-PSScriptAnalyzer
{
    [CmdletBinding()]
    param ()

    $psScriptAnalyzerModule = Get-Module -Name 'PSScriptAnalyzer' -ListAvailable

    if ($null -eq $psScriptAnalyzerModule)
    {
        Write-Verbose -Message 'Installing PSScriptAnalyzer from the PowerShell Gallery'
        $userProfilePSModulePathItem = Get-UserProfilePSModulePathItem
        $psScriptAnalyzerModulePath = Join-Path -Path $userProfilePSModulePathItem -ChildPath PSScriptAnalyzer
        Install-ModuleFromPowerShellGallery -ModuleName 'PSScriptAnalyzer' -DestinationPath $psScriptAnalyzerModulePath
    }

    $psScriptAnalyzerModule = Get-Module -Name 'PSScriptAnalyzer' -ListAvailable

    <#
        When using custom rules in PSSA the Get-Help cmdlet gets
        called by PSSA. This causes a warning to be thrown in AppVeyor.
        This warning does not cause a failure or error, but causes
        additional bloat to the analyzer output. To suppress this
        the registry key
        HKLM:\Software\Microsoft\PowerShell\DisablePromptToUpdateHelp
        should be set to 1 when running in AppVeyor.

        See this line from PSSA in GetExternalRule() method for more
        information:
        https://github.com/PowerShell/PSScriptAnalyzer/blob/development/Engine/ScriptAnalyzer.cs#L1120
    #>
    if ($env:APPVEYOR -eq $true)
    {
        Set-ItemProperty -Path HKLM:\Software\Microsoft\PowerShell -Name DisablePromptToUpdateHelp -Value 1
    }

    Import-Module -Name $psScriptAnalyzerModule
}

<#
    .SYNOPSIS
        Imports the xDscResourceDesigner module.
        Installs the module from the PowerShell Gallery if it is not already installed.
#>
function Import-xDscResourceDesigner
{
    [CmdletBinding()]
    param ()

    $xDscResourceDesignerModule = Get-Module -Name 'xDscResourceDesigner' -ListAvailable

    if ($null -eq $xDscResourceDesignerModule)
    {
        Write-Verbose -Message 'Installing xDscResourceDesigner from the PowerShell Gallery'
        $userProfilePSModulePathItem = Get-UserProfilePSModulePathItem
        $xDscResourceDesignerModulePath = Join-Path -Path $userProfilePSModulePathItem -ChildPath xDscResourceDesigner
        Install-ModuleFromPowerShellGallery -ModuleName 'xDscResourceDesigner' -DestinationPath $xDscResourceDesignerModulePath
    }

    $xDscResourceDesignerModule = Get-Module -Name 'xDscResourceDesigner' -ListAvailable

    Import-Module -Name $xDscResourceDesignerModule
}

<#
    .SYNOPSIS
        Retrieves the list of suppressed PSSA rules in the file at the given path.

    .PARAMETER FilePath
        The path to the file to retrieve the suppressed rules of.
#>
function Get-SuppressedPSSARuleNameList
{
    [OutputType([String[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FilePath
    )

    $suppressedPSSARuleNames = [String[]]@()

    $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)

    # Overall file attributes
    $attributeAsts = $fileAst.FindAll( { $args[0] -is [System.Management.Automation.Language.AttributeAst] }, $true)

    foreach ($attributeAst in $attributeAsts)
    {
        $messageAttributeName = [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute].FullName.ToLower()

        if ($messageAttributeName.Contains($attributeAst.TypeName.FullName.ToLower()))
        {
            $suppressedPSSARuleNames += $attributeAst.PositionalArguments.Extent.Text
        }
    }

    return $suppressedPSSARuleNames
}

<#
    .SYNOPSIS
        Downloads and saves a specific version of NuGet.exe to a local path, to
        be used to produce DSC Resource NUPKG files.

        This allows control over the version of NuGet.exe that is used. This helps
        resolve an issue with different versions of NuGet.exe formatting the version
        number in the filename of a produced NUPKG file.

        See https://github.com/PowerShell/xNetworking/issues/177 for more information.

    .PARAMETER OutFile
        The local path to save the downloaded NuGet.exe to.

    .PARAMETER Uri
        The URI to use as the location from where to download NuGet.exe
        i.e. 'https://dist.nuget.org/win-x86-commandline'.

    .PARAMETER RequiredVersion
        The specific version of the NuGet.exe to download.
#>
function Install-NugetExe
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $OutFile,

        [Parameter()]
        [System.String]
        $Uri = 'https://dist.nuget.org/win-x86-commandline',

        [Parameter()]
        [System.Version]
        $RequiredVersion = '3.4.4'
    )

    $downloadUri = '{0}/v{1}/NuGet.exe' -f $Uri, $RequiredVersion.ToString()
    Write-Info -Message ('Downloading NuGet.exe (v{2}) from URL ''{0}'', and installing it to local path ''{1}''.' -f $downloadUri, $OutFile, $RequiredVersion.ToString())

    if (Test-Path -Path $OutFile)
    {
        Remove-Item -Path $OutFile -Force
    }

    Invoke-WebRequest -Uri $downloadUri -OutFile $OutFile
} # Install-NugetExe

<#
    .SYNOPSIS
        Gets the current Pester Describe block name
#>
function Get-PesterDescribeName
{
    return Get-CommandNameParameterValue -Command 'Describe'
}

<#
    .SYNOPSIS
        Gets the opt-in status of the current pester Describe
        block. Writes a warning if the test is not opted-in.

    .PARAMETER OptIns
        An array of what is opted-in
#>
function Get-PesterDescribeOptInStatus
{
    param
    (
        [Parameter()]
        [System.String[]]
        $OptIns
    )

    $describeName = Get-PesterDescribeName
    $optIn = $OptIns -icontains $describeName
    if (-not $optIn)
    {
        $message = @"
Describe $describeName will not fail unless you opt-in.
To opt-in, create a '.MetaTestOptIn.json' at the root
of the repo in the following format:
[
     "$describeName"
]
"@
        Write-Warning -Message $message
    }

    return $optIn
}

<#
    .SYNOPSIS
        Gets the opt-in status of an option with the specified name. Writes
        a warning if the test is not opted-in.

    .PARAMETER OptIns
        An array of what is opted-in.

    .PARAMETER Name
        The name of the opt-in option to check the status of.
#>
function Get-OptInStatus
{
    param
    (
        [Parameter()]
        [System.String[]]
        $OptIns,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $optIn = $OptIns -icontains $Name
    if (-not $optIn)
    {
        $message = @"
$Name will not fail unless you opt-in.
To opt-in, create a '.MetaTestOptIn.json' at the root
of the repo in the following format:
[
     "$Name"
]
"@
        Write-Warning -Message $message
    }

    return $optIn
}

<#
    .SYNOPSIS
        Gets the value of the Name parameter for the specified command in the stack.

    .PARAMETER Command
        The name of the command to find the Name parameter for.
#>
function Get-CommandNameParameterValue
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Command
    )

    $commandStackItem = (Get-PSCallStack).Where{ $_.Command -eq $Command }
    $commandArgumentNameValues = $commandStackItem.Arguments.TrimStart('{', ' ').TrimEnd('}', ' ') -split '\s*,\s*'
    $nameParameterValue = ($commandArgumentNameValues.Where{ $_ -like 'name=*' } -split '=')[-1]
    return $nameParameterValue
}

<#
    .SYNOPSIS
        Returns first the item in $env:PSModulePath that matches the given Prefix ($env:PSModulePath is list of semicolon-separated items).
        If no items are found, it reports an error.
    .PARAMETER Prefix
        Path prefix to look for.
    .NOTES
        If there are multiple matching items, the function returns the first item that occurs in the module path; this matches the lookup
        behavior of PowerSHell, which looks at the items in the module path in order of occurrence.
    .EXAMPLE
        If $env:PSModulePath is
            C:\Program Files\WindowsPowerShell\Modules;C:\Users\foo\Documents\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules
        then
            Get-PSModulePathItem C:\Users
        will return
            C:\Users\foo\Documents\WindowsPowerShell\Modules
#>
function Get-PSModulePathItem
{
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Prefix
    )

    $item = $env:PSModulePath.Split(';') |
    Where-Object -FilterScript { $_ -like "$Prefix*" } |
    Select-Object -First 1

    if (-not $item)
    {
        Write-Error -Message "Cannot find the requested item in the PowerShell module path.`n`$env:PSModulePath = $env:PSModulePath"
    }
    else
    {
        $item = $item.TrimEnd('\')
    }

    return $item
}

<#
    .SYNOPSIS
        Returns the first item in $env:PSModulePath that is a path under $env:USERPROFILE.
        If no items are found, it reports an error.
    .EXAMPLE
        If $env:PSModulePath is
            C:\Program Files\WindowsPowerShell\Modules;C:\Users\foo\Documents\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules
        and the current user is 'foo', then
            Get-UserProfilePSModulePathItem
        will return
            C:\Users\foo\Documents\WindowsPowerShell\Modules
#>
function Get-UserProfilePSModulePathItem
{
    param ()

    return Get-PSModulePathItem -Prefix $env:USERPROFILE
}

<#
    .SYNOPSIS
        Returns the first item in $env:PSModulePath that is a path under $env:USERPROFILE.
        If no items are found, it reports an error.
    .EXAMPLE
        If $env:PSModulePath is
            C:\Program Files\WindowsPowerShell\Modules;C:\Users\foo\Documents\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules
        then
            Get-PSHomePSModulePathItem
        will return
            C:\Windows\system32\WindowsPowerShell\v1.0\Modules
#>
function Get-PSHomePSModulePathItem
{
    param ()

    return Get-PSModulePathItem -Prefix $PSHOME
}

<#
    .SYNOPSIS
        Tests if a file contains Byte Order Mark (BOM).

    .PARAMETER FilePath
        The file path to evaluate.
#>
function Test-FileHasByteOrderMark
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FilePath
    )

    $getContentParameters = @{
        Path       = $FilePath
        ReadCount  = 3
        TotalCount = 3
    }

    # Need to treat Windows Powershell and PowerShell Core different.
    if ($PSVersionTable.PSEdition -eq 'Core')
    {
        $getContentParameters['AsByteStream'] = $true
    }
    else
    {
        $getContentParameters['Encoding'] = 'Byte'
    }

    # This reads the first three bytes of the first row.
    $firstThreeBytes = Get-Content @getContentParameters

    # Check for the correct byte order (239,187,191) which equal the Byte Order Mark (BOM).
    return ($firstThreeBytes[0] -eq 239 `
            -and $firstThreeBytes[1] -eq 187 `
            -and $firstThreeBytes[2] -eq 191)
}

<#
    .SYNOPSIS
        This returns a string containing the relative path from the module root.

    .PARAMETER FilePath
        The file path to remove the module root path from.

    .PARAMETER ModuleRootFilePath
        The root path to remove from the file path.
#>
function Get-RelativePathFromModuleRoot
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FilePath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleRootFilePath
    )

    <#
        Removing the module root path from the file path so that the path
        doesn't get so long in the Pester output.
    #>
    return ($FilePath -replace [Regex]::Escape($ModuleRootFilePath), '').Trim('\')
}

<#
    .SYNOPSIS
        Gets an array of DSC Resource modules imported in a DSC Configuration
        file.

    .PARAMETER ConfigurationPath
        The path to the configuration file to get the list from.
#>
function Get-ResourceModulesInConfiguration
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ConfigurationPath
    )

    # Resource modules
    $listedModules = @()

    # Get the AST object for the configuration
    $dscConfigurationAST = [System.Management.Automation.Language.Parser]::ParseFile($ConfigurationPath , [ref]$null, [ref]$Null)

    # Get all the Import-DscResource module commands
    $findAllImportDscResources = {
        $args[0] -is [System.Management.Automation.Language.DynamicKeywordStatementAst] `
            -and $args[0].CommandElements[0].Value -eq 'Import-DscResource'
    }

    $importDscResourceCmds = $dscConfigurationAST.EndBlock.FindAll( $findAllImportDscResources, $true )

    foreach ($importDscResourceCmd in $importDscResourceCmds)
    {
        $parameterName = 'ModuleName'
        $moduleName = ''
        $moduleVersion = ''

        foreach ($element in $importDscResourceCmd.CommandElements)
        {
            # For each element in the Import-DscResource command determine what it means
            if ($element -is [System.Management.Automation.Language.CommandParameterAst])
            {
                $parameterName = $element.ParameterName
            }
            elseif ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] `
                    -and $element.Value -ne 'Import-DscResource')
            {
                switch ($parameterName)
                {
                    'ModuleName'
                    {
                        $moduleName = $element.Value
                    } # ModuleName

                    'ModuleVersion'
                    {
                        $moduleVersion = $element.Value
                    } # ModuleVersion
                } # switch
            }
            elseif ($element -is [System.Management.Automation.Language.ArrayLiteralAst])
            {
                <#
                    This is an array of strings (usually something like xNetworking,xWebAdministration)
                    So we need to add each module to the list
                #>
                foreach ($item in $element.Elements)
                {
                    $listedModules += @{
                        Name = $item.Value
                    }
                } # foreach
            } # if
        } # foreach

        # Did a module get identified when stepping through the elements?
        if (-not [System.String]::IsNullOrEmpty($moduleName))
        {
            if ([System.String]::IsNullOrEmpty($moduleVersion))
            {
                $listedModules += @{
                    Name = $moduleName
                }
            }
            else
            {
                $listedModules += @{
                    Name    = $moduleName
                    Version = $moduleVersion
                }
            }
        } # if
    } # foreach

    return $listedModules
}

<#
    .SYNOPSIS
        Installs dependent modules in the user scope, if not already available
        and only if run on an AppVeyor build worker. If not run on a AppVeyor
        build worker, it will output a warning saying that the users must
        install the correct module to be able to run the test.

    .PARAMETER Module
        An array of hash tables containing one or more dependent modules that
        should be installed. The correct array is returned by the helper
        function Get-ResourceModulesInConfiguration.

        Hash table should be in this format. Where property Name is mandatory
        and property Version is optional.

        @{
            Name    = 'xStorage'
            [Version = '3.2.0.0']
        }
#>
function Install-DependentModule
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable[]]
        $Module
    )

    # Check any additional modules required are installed
    foreach ($requiredModule in $Module)
    {
        $getModuleParameters = @{
            Name          = $requiredModule.Name
            ListAvailable = $true
            ErrorAction   = 'SilentlyContinue'
        }

        if ($requiredModule.ContainsKey('Version'))
        {
            $requiredModuleExist = `
                Get-Module @getModuleParameters |
            Where-Object -FilterScript {
                $_.Version -eq $requiredModule.Version
            }
        }
        else
        {
            $requiredModuleExist = Get-Module @getModuleParameters
        }

        if (-not ($requiredModuleExist))
        {
            # The required module is missing from this machine
            if ($requiredModule.ContainsKey('Version'))
            {
                $requiredModuleName = ('{0} version {1}' -f $requiredModule.Name, $requiredModule.Version)
            }
            else
            {
                $requiredModuleName = ('{0}' -f $requiredModule.Name)
            }

            if ($env:APPVEYOR -eq $true)
            {
                <#
                    Tests are running in AppVeyor so just install the module.
                    If not installed by using Force then the error message
                    "User declined to install untrusted module (<module name>)."
                    is thrown
                #>
                $installModuleParameters = @{
                    Name  = $requiredModule.Name
                    Force = $true
                }

                if ($requiredModule.ContainsKey('Version'))
                {
                    $installModuleParameters['RequiredVersion'] = $requiredModule.Version
                }

                Write-Info -Message "Installing module $requiredModuleName required to compile a configuration."

                try
                {
                    Install-Module @installModuleParameters -Scope CurrentUser
                }
                catch
                {
                    throw "An error occurred installing the required module $($requiredModuleName) : $_"
                }
            }
            else
            {
                # Warn the user that the test fill fail
                Write-Warning -Message ("To be able to compile a configuration the resource module $requiredModuleName " + `
                        'is required but it is not installed on this computer. ' + `
                        'The test that is dependent on this module will fail until the required module is installed. ' + `
                        'Please install it from the PowerShell Gallery to enable these tests to pass.')
            } # if
        } # if
    } # foreach
}

<#
    .SYNOPSIS
        Returns the integration test order number if it exists in the
        attribute 'Microsoft.DscResourceKit.IntegrationTest' with the
        named attribute argument 'OrderNumber'. If it is not found, a
        $null value will be returned.

    .PARAMETER Path
        A path to the test file (.Tests.ps1) file to search for the attribute
        'Microsoft.DscResourceKit.IntegrationTest' with the named
        attribute argument 'OrderNumber'.
#>
function Get-DscIntegrationTestOrderNumber
{
    [CmdletBinding()]
    [OutputType([System.UInt32])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    <#
        Will always return $null if the attribute 'Microsoft.DscResourceKit.IntegrationTest'
        is not found with the named attribute argument 'OrderNumber'.
    #>
    $returnValue = $null

    $scriptBlockAst = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $null, [ref] $null)

    $findIntegrationTestAttributeFilter = {
        $args[0] -is [System.Management.Automation.Language.AttributeAst] `
            -and (
            $args[0].TypeName.FullName -eq 'IntegrationTest' `
                -or $args[0].TypeName.FullName -eq 'Microsoft.DscResourceKit.IntegrationTest'
        )
    }

    # Get IntegrationTest attribute in the file if it exist.
    [System.Management.Automation.Language.Ast[]] $integrationTestAttributeAst = `
        $scriptBlockAst.Find($findIntegrationTestAttributeFilter, $true)

    if ($integrationTestAttributeAst)
    {
        $findOrderNumberNamedAttributeArgumentFilter = {
            $args[0] -is [System.Management.Automation.Language.NamedAttributeArgumentAst] `
                -and $args[0].ArgumentName -eq 'OrderNumber'
        }

        [System.Management.Automation.Language.Ast[]] $orderNumberNamedAttributeArgumentAst = `
            $integrationTestAttributeAst.Find($findOrderNumberNamedAttributeArgumentFilter, $true)

        if ($orderNumberNamedAttributeArgumentAst)
        {
            $returnValue = $orderNumberNamedAttributeArgumentAst.Argument.Value
        }
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Returns the container name and the container image to use for the test
        if found.
        If the attribute 'Microsoft.DscResourceKit.IntegrationTest' or
        'Microsoft.DscResourceKit.UnitTest' exists with at least one of the named
        attribute arguments 'ContainerName' or 'ContainerImage' they will be
        returned.
        If neither attribute is not found, a $null value will be returned.

    .PARAMETER Path
        A path to the test file (.Tests.ps1) to search for the attribute
        'Microsoft.DscResourceKit.IntegrationTest' or
        'Microsoft.DscResourceKit.UnitTest'.

    .OUTPUTS
        Returns a hash table containing container name and the container image
        name, or $null if neither attribute could be found.

        @{
            ContainerName = [System.String or $null]
            ContainerImage = [System.String or $null]
        }
#>
function Get-DscTestContainerInformation
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    $returnValue = $null

    $scriptBlockAst = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $null, [ref] $null)

    $findIntegrationTestAttributeFilter = {
        $args[0] -is [System.Management.Automation.Language.AttributeAst] `
            -and (
            $args[0].TypeName.FullName -eq 'IntegrationTest' `
                -or $args[0].TypeName.FullName -eq 'Microsoft.DscResourceKit.IntegrationTest' `
                -or $args[0].TypeName.FullName -eq 'UnitTest' `
                -or $args[0].TypeName.FullName -eq 'Microsoft.DscResourceKit.UnitTest'
        )
    }

    # Get IntegrationTest attribute in the file if it exist.
    [System.Management.Automation.Language.Ast[]] $integrationTestAttributeAst = `
        $scriptBlockAst.Find($findIntegrationTestAttributeFilter, $true)

    if ($integrationTestAttributeAst)
    {
        $findAttributeArgumentFilter = {
            $args[0] -is [System.Management.Automation.Language.NamedAttributeArgumentAst] `
        }

        [System.Management.Automation.Language.Ast[]] $attributeArgumentAst = `
            $integrationTestAttributeAst.FindAll($findAttributeArgumentFilter, $true)

        foreach ($currentAttributeArgumentAst in $attributeArgumentAst)
        {
            if ($currentAttributeArgumentAst.ArgumentName -in ('ContainerName', 'ContainerImage'))
            {
                # Only initiate the hash table if $returnValue is $null.
                if (-not $returnValue)
                {
                    # Build the has table to return.
                    $returnValue = @{
                        ContainerName  = $null
                        ContainerImage = $null
                    }
                }

                switch ($currentAttributeArgumentAst.ArgumentName)
                {
                    'ContainerName'
                    {
                        $returnValue['ContainerName'] = $currentAttributeArgumentAst.Argument.Value
                    }

                    'ContainerImage'
                    {
                        $returnValue['ContainerImage'] = $currentAttributeArgumentAst.Argument.Value
                    }
                }
            }
        }
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Returns $true if the current repository being tested is
        DscResource.Tests, otherwise the value returned will be
        $false.

    .NOTES
        There are two scenarios.

        1. Testing DscResource.Tests; path C:\Projects\DscResource.Tests,
           or V:\Source\GitHub\DscResource.Tests (or any other path used
           by users).
        2. Testing a DSC resource module (ie. xStorage); path
           C:\Projects\xStorage\DscResource.Tests,
           or V:\Source\GitHub\xStorage\DscResource.Tests (or any other path
           used by users).

        In both these scenarios, when the tests are run, the $PSScriptRoot
        (current folder) is set to one of the above paths, that is
        $PSScriptRoot (current folder) will always be set to the DscResource.Tests
        folder.

        The following logic will determine if we are running the code on the
        repository DscResource.Tests or some other resource module.

        If the parent folder of $PSScriptRoot does NOT contain a module manifest
        we will assume that DscResource.Test is the module being tested.
        Example:
            Current folder:  c:\source\DscResource.Tests
            Parent folder:   c:\source
            Module manifest: $null

        If the parent folder of $PSScriptRoot do contain a module manifest we
        will assume that DscResource.Test has been cloned into another resource
        module and it is that resource module that is being tested.
        Example:
            Current folder:  c:\source\SqlServerDsc\DscResource.Tests
            Parent folder:   c:\source\SqlServerDsc
            Module manifest: c:\source\SqlServerDsc\SqlServerDsc.psd1
#>
function Test-IsRepositoryDscResourceTests
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
    )

    $moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent

    $moduleManifestExistInModuleRootFilePath = Get-ChildItem -Path $moduleRootFilePath -Filter '*.psd1'
    if (-not $moduleManifestExistInModuleRootFilePath)
    {
        return $true
    }
    else
    {
        return $false
    }
}

<#
    .SYNOPSIS
        The is a wrapper to set $env:PSModulePath both in current session and
        machine wide.
        This is needed to be able to mock the function in the unit tests.

    .PARAMETER Path
        A string with all the paths separated by semi-colons.

    .PARAMETER Machine
        If set the PSModulePath will be changed machine wide. If not set, only
        the current session will be changed.

    .EXAMPLE
        Set-PSModulePath -Path '<Path 1>;<Path 2>'

    .EXAMPLE
        Set-PSModulePath -Path '<Path 1>;<Path 2>' -Machine
#>
function Set-PSModulePath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [Switch]
        $Machine
    )

    if ($Machine.IsPresent)
    {
        [System.Environment]::SetEnvironmentVariable('PSModulePath', $Path, [System.EnvironmentVariableTarget]::Machine)
    }
    else
    {
        $env:PSModulePath = $Path
    }
}

<#
    .SYNOPSIS
        Writes a message to the console in a standard format.

    .PARAMETER Message
        The message to write to the console.

    .PARAMETER ForegroundColor
        The text color to use when writing the message to the console. Defaults
        to 'Yellow'.
#>
function Write-Info
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message,

        [Parameter()]
        [System.String]
        $ForegroundColor = 'Yellow'
    )

    $curentColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Information -MessageData "[Build Info] [UTC $([System.DateTime]::UtcNow)] $message"
    $host.UI.RawUI.ForegroundColor = $curentColor
}

<#
    .SYNOPSIS
        Retrieves the localized string data based on the machine's culture.
        Falls back to en-US strings if the machine's culture is not supported.

    .PARAMETER ModuleName
        The name of the module as it appears before '.strings.psd1' of the localized string file.
        For example:
            For module: DscResource.Container

    .PARAMETER ModuleRoot
        The module root path where to expect to find the culture folder.
#>
function Get-LocalizedData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleRoot
    )

    $localizedStringFileLocation = Join-Path -Path $ModuleRoot -ChildPath $PSUICulture

    if (-not (Test-Path -Path $localizedStringFileLocation))
    {
        # Fallback to en-US
        $localizedStringFileLocation = Join-Path -Path $ModuleRoot -ChildPath 'en-US'
    }

    Import-LocalizedData `
        -BindingVariable 'localizedData' `
        -FileName "$ModuleName.strings.psd1" `
        -BaseDirectory $localizedStringFileLocation

    return $localizedData
}

<#
    .SYNOPSIS
        This command will return a filename without extension and without any
        starting numeric value followed by a dash (-).

    .PARAMETER Path
        The path to the example for which the filename should be returned.

    .OUTPUTS
        Returns a filename without extension and without any starting numeric
        value followed by a dash (-).
#>
function Get-PublishFileName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    # Get the filename without extension.
    $filenameWithoutExtension = (Get-Item -Path $Path).BaseName

    <#
        Resource modules using auto-documentation uses a numeric value followed
        by a dash ('-') to be able to control the order of the example in
        the documentation. That will not be used when publishing, so remove
        it here from the name that is compared to the configuration name.
    #>
    return $filenameWithoutExtension -replace '^[0-9]+-'
}

<#
    .SYNOPSIS
        Copies the resource module to the PowerShell module path.

    .PARAMETER ResourceModuleName
        Name of the resource module being deployed.

    .PARAMETER ModuleRootPath
        The root path to the repository.

    .OUTPUTS
        Returns the path to where the module was copied (the root of the module).
#>
function Copy-ResourceModuleToPSModulePath
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceModuleName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleRootPath
    )

    $psHomePSModulePathItem = Get-PSHomePSModulePathItem
    $powershellModulePath = Join-Path -Path $psHomePSModulePathItem -ChildPath $ResourceModuleName

    Write-Verbose -Message ('Copying module from ''{0}'' to ''{1}''' -f $ModuleRootPath, $powershellModulePath)

    # Creates the destination module folder.
    New-Item -Path $powershellModulePath -ItemType Directory -Force | Out-Null

    # Copies all module files into the destination module folder.
    Copy-Item -Path (Join-Path -Path $ModuleRootPath -ChildPath '*') `
        -Destination $powershellModulePath `
        -Exclude @('node_modules', '.*') `
        -Recurse `
        -Force

    return $powershellModulePath
}

<#
    .SYNOPSIS
        This command will create a new self-signed certificate to be used to
        compile configurations.

    .OUTPUTS
        Returns the created certificate. Writes the path to the public
        certificate in the machine environment variable $env:DscPublicCertificatePath,
        and the certificate thumbprint in the machine environment variable
        $env:DscCertificateThumbprint.

    .NOTES
        If a certificate with subject 'DscEncryptionCert' already exists, that
        certificate will be returned instead of creating a new, and will assume
        that the existing certificate was created with this command.
#>
function New-DscSelfSignedCertificate
{
    $dscPublicCertificatePath = Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer'

    $certificateSubject = 'TestDscEncryptionCert'

    # Look if there already is an existing certificate.
    $certificate = Get-ChildItem -Path 'cert:\LocalMachine\My' |
    Where-Object -FilterScript {
        $_.Subject -eq "CN=$certificateSubject"
    } | Select-Object -First 1

    if (-not $certificate)
    {
        $getCommandParameters = @{
            Name        = 'New-SelfSignedCertificate'
            ErrorAction = 'SilentlyContinue'
        }

        $newSelfSignedCertificateCommand = Get-Command @getCommandParameters

        $hasNewSelfSignedCertificateCommand = $newSelfSignedCertificateCommand `
            -and $newSelfSignedCertificateCommand.Parameters.Keys -contains 'Type'

        if ($hasNewSelfSignedCertificateCommand)
        {
            $newSelfSignedCertificateParameters = @{
                Type          = 'DocumentEncryptionCertLegacyCsp'
                DnsName       = $certificateSubject
                HashAlgorithm = 'SHA256'
            }

            $certificate = New-SelfSignedCertificate @newSelfSignedCertificateParameters
        }
        else
        {
            <#
                There are build workers still on Windows Server 2012 R2 so let's
                use the alternate method of New-SelfSignedCertificate.
            #>
            Install-Module -Name PSPKI -Scope CurrentUser -RequiredVersion 3.3.0.0
            Import-Module -Name PSPKI

            $newSelfSignedCertificateExParameters = @{
                Subject            = "CN=$certificateSubject"
                EKU                = 'Document Encryption'
                KeyUsage           = 'KeyEncipherment, DataEncipherment'
                SAN                = "dns:$certificateSubject"
                FriendlyName       = 'DSC Credential Encryption certificate'
                Exportable         = $true
                StoreLocation      = 'LocalMachine'
                KeyLength          = 2048
                ProviderName       = 'Microsoft Enhanced Cryptographic Provider v1.0'
                AlgorithmName      = 'RSA'
                SignatureAlgorithm = 'SHA256'
            }

            $certificate = New-SelfSignedCertificateEx @newSelfSignedCertificateExParameters
        }

        Write-Info -Message ('Created self-signed certificate ''{0}'' with thumbprint ''{1}''.' -f $certificate.Subject, $certificate.Thumbprint)
    }
    else
    {
        Write-Info -Message ('Using self-signed certificate ''{0}'' with thumbprint ''{1}''.' -f $certificate.Subject, $certificate.Thumbprint)
    }

    # Export the public key certificate
    Export-Certificate -Cert $certificate -FilePath $dscPublicCertificatePath -Force

    # Update a machine and session environment variable with the path to the public certificate.
    Set-EnvironmentVariable -Name 'DscPublicCertificatePath' -Value $dscPublicCertificatePath -Machine
    Write-Info -Message ('Environment variable $env:DscPublicCertificatePath set to ''{0}''' -f $env:DscPublicCertificatePath)

    # Update a machine and session environment variable with the thumbprint of the certificate.
    Set-EnvironmentVariable -Name 'DscCertificateThumbprint' -Value $certificate.Thumbprint -Machine
    Write-Info -Message ('Environment variable $env:DscCertificateThumbprint set to ''{0}''' -f $env:DscCertificateThumbprint)

    return $certificate
}

<#
    .SYNOPSIS
        This command will set the machine and session environment variable to
        a value.

    .PARAMETER Name
        The name of the variable to set.

    .PARAMETER Value
        The value of the variable to set. If this is set to $null or
        empty string ('') the environment variable will be removed.

    .PARAMETER Machine
        If present, the environment variable will be set machine wide.
        If not present, the environment variable will be set for the user.
#>
function Set-EnvironmentVariable
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Value,

        [Parameter()]
        [Switch]
        $Machine
    )

    if ($Machine.IsPresent)
    {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
        Set-Item -Path "env:\$Name" -Value $Value
    }
    else
    {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        Set-Item -Path "env:\$Name" -Value $Value
    }
}

<#
    .SYNOPSIS
        This command will initialize the Local Configuration Manager. It's
        meant to be used before running tests.

    .PARAMETER DisableConsistency
        This will switch off monitoring (consistency) for the Local Configuration
        Manager (LCM), setting ConfigurationMode to 'ApplyOnly', on the node
        running tests.

    .PARAMETER Encrypt
        This will switch on encryption for the Local Configuration
        Manager (LCM), setting CertificateId to the thumbprint stored in
        $env:DscCertificateThumbprint, on the node running tests.

        When using this parameter any configuration used for an integration
        test must have CertificateFile pointing to path stored in
        $env:DscPublicCertificatePath.
#>
function Initialize-LocalConfigurationManager
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [Switch]
        $DisableConsistency,

        [Parameter()]
        [Switch]
        $Encrypt
    )

    $disableConsistencyMofPath = Join-Path -Path $env:temp -ChildPath 'LCMConfiguration'
    if (-not (Test-Path -Path $disableConsistencyMofPath))
    {
        $null = New-Item -Path $disableConsistencyMofPath -ItemType Directory -Force
    }

    # Start of the metadata configuration
    $configurationMetadata = '
        Configuration LocalConfigurationManagerConfiguration
        {
            LocalConfigurationManager
            {
    '

    if ($DisableConsistency.IsPresent)
    {
        Write-Info -Message 'Setting Local Configuration Manager property ConfigurationMode to ''ApplyOnly'', disabling consistency check.'
        # Have LCM Apply only once.
        $configurationMetadata += '
            ConfigurationMode = ''ApplyOnly''
        '
    }

    if ($Encrypt.IsPresent)
    {
        Write-Info -Message ('Setting Local Configuration Manager property CertificateId to ''{0}'', enabling decryption of credentials.' -f $env:DscCertificateThumbprint)
        # Should use encryption.
        $configurationMetadata += ('
            CertificateId = ''{0}''
        ' -f $env:DscCertificateThumbprint)
    }

    # End of the metadata configuration
    $configurationMetadata += '
            }
        }
    '

    Invoke-Command -ScriptBlock ([scriptblock]::Create($configurationMetadata)) -NoNewScope

    LocalConfigurationManagerConfiguration -OutputPath $disableConsistencyMofPath

    Set-DscLocalConfigurationManager -Path $disableConsistencyMofPath -Force -Verbose
    $null = Remove-Item -LiteralPath $disableConsistencyMofPath -Recurse -Force -Confirm:$false
}

<#
    .SYNOPSIS
        Write a warning message for PsScriptAnalyzer rules that fail

    .PARAMETER PssaRuleOutput
        Output object from Invoke-ScriptAnalyzer

    .PARAMETER RuleType
        Name of the rule type that is being processed
#>
function Write-PsScriptAnalyzerWarning
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object[]]
        $PssaRuleOutput,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RuleType
    )

    Write-Warning -Message "$RuleType PSSA rule(s) did not pass."
    $ruleCollection = $PssaRuleOutput | Group-Object -Property RuleName

    foreach ($ruleNameGroup in $ruleCollection)
    {
        Write-Warning -Message "The following PSScriptAnalyzer rule '$($ruleNameGroup.Name)' errors need to be fixed:"

        foreach ($rule in $ruleNameGroup.Group)
        {
            Write-Warning -Message "$($rule.ScriptName) (Line $($rule.Line)): $($rule.Message)"
        }
    }

    Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/PSScriptAnalyzer'
}

Export-ModuleMember -Function @(
    'New-Nuspec',
    'Install-ModuleFromPowerShellGallery',
    'Initialize-TestEnvironment',
    'Restore-TestEnvironment',
    'Get-ClassResourceNameFromFile',
    'Test-ModuleContainsScriptResource',
    'Test-ModuleContainsClassResource',
    'Get-Psm1FileList',
    'Get-FileParseErrors',
    'Get-TextFilesList',
    'Test-FileInUnicode',
    'Get-ModuleScriptResourceNames',
    'Import-PSScriptAnalyzer',
    'Import-xDscResourceDesigner',
    'Get-SuppressedPSSARuleNameList',
    'Reset-DSC',
    'Install-NugetExe',
    'Get-PesterDescribeOptInStatus',
    'Get-OptInStatus',
    'Get-UserProfilePSModulePathItem',
    'Get-PSHomePSModulePathItem',
    'Test-FileHasByteOrderMark',
    'Get-RelativePathFromModuleRoot',
    'Get-ResourceModulesInConfiguration',
    'Install-DependentModule',
    'Get-DscIntegrationTestOrderNumber',
    'Test-IsRepositoryDscResourceTests',
    'Set-PSModulePath',
    'Write-Info',
    'Get-LocalizedData',
    'Get-DscTestContainerInformation',
    'Get-PublishFileName',
    'Copy-ResourceModuleToPSModulePath',
    'New-DscSelfSignedCertificate',
    'Set-EnvironmentVariable',
    'Initialize-LocalConfigurationManager'
    'Write-PsScriptAnalyzerWarning'
)
