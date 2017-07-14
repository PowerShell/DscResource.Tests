<#
    .SYNOPSIS
        Helper functions for the common tests (Meta.Tests.ps1).
#>

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
        [String]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [String]
        $Version,

        [Parameter(Mandatory = $true)]
        [String]
        $Author,

        [Parameter(Mandatory=$true)]
        [String]
        $Owners,

        [Parameter(Mandatory=$true)]
        [String]
        $DestinationPath,

        [String]
        $LicenseUrl,

        [String]
        $ProjectUrl,

        [String]
        $IconUrl,

        [String]
        $PackageDescription,

        [String]
        $ReleaseNotes,

        [String]
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

    if (-not [String]::IsNullOrEmpty($LicenseUrl))
    {
        $nuspecFileContent += @"
    <licenseUrl>$LicenseUrl</licenseUrl>
"@
    }

    if (-not [String]::IsNullOrEmpty($ProjectUrl))
    {
        $nuspecFileContent += @"
    <projectUrl>$ProjectUrl</projectUrl>
"@
    }

    if (-not [String]::IsNullOrEmpty($IconUrl))
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
        [String]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [String]
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

            $nugetPath = $tempNugetPath
        }
        else
        {
            Write-Verbose -Message "Using Nuget.exe found at $tempNugetPath"
        }
    }

    $moduleOutputDirectory = "$(Split-Path -Path $DestinationPath -Parent)\"

    $nugetSource = 'https://www.powershellgallery.com/api/v2'
    # Use Nuget.exe to install the module
    $null = & $nugetPath @( `
        'install', $ModuleName, `
        '-source', $nugetSource, `
        '-outputDirectory', $moduleOutputDirectory, `
        '-ExcludeVersion' `
        )

    if ($LASTEXITCODE -ne 0)
    {
        throw "Installation of module $ModuleName using Nuget failed with exit code $LASTEXITCODE."
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
            -DSCModuleName 'xSQLServer' `
            -DSCResourceName 'xSQLServerAlwaysOnAvailabilityGroupDatabaseMembership' `
            -TestType Unit
            -ResourceType Class

        This command will initialize the test environment for Unit testing
        the xSQLServerAlwaysOnAvailabilityGroupDatabaseMembership class-based DSC
        resource in the xSQLServer DSC module.

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
        [String]
        $DscModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscResourceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Unit', 'Integration')]
        [String]
        $TestType,

        [Parameter()]
        [ValidateSet('Mof','Class')]
        [String]
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
        $newPSModulePathSplit = $oldPSModulePathSplit | Where-Object {$_ -ne $moduleParentFilePath}
        $newPSModulePath = $newPSModulePathSplit -join ';'
    }
    else
    {
        $newPSModulePath = $oldPSModulePath
    }

    $newPSModulePath = "$moduleParentFilePath;$newPSModulePath"

    $env:PSModulePath = $newPSModulePath

    if ($TestType -ieq 'Integration')
    {
        <#
            For integration tests we have to set the machine's PSModulePath because otherwise the
            DSC LCM won't be able to find the resource module being tested or may use the wrong one.
        #>
        [System.Environment]::SetEnvironmentVariable('PSModulePath', $newPSModulePath, [System.EnvironmentVariableTarget]::Machine)

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
        DSCModuleName = $DscModuleName
        DSCResourceName = $DscResourceName
        TestType = $TestType
        ImportedModulePath = $moduleToImportFilePath
        OldPSModulePath = $oldPSModulePath
        OldExecutionPolicy = $oldExecutionPolicy
    }
}

<#
    .SYNOPSIS
        Restores the enviroment after running unit or integration tests
        on a DSC resource.

        This restores the following changes made by calling
        Initialize-TestEnvironemt:
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
        $env:PSModulePath = $TestEnvironment.OldPSModulePath

        if ($TestEnvironment.TestType -eq 'Integration')
        {
            # Restore the machine PSModulePath for integration tests.
            [System.Environment]::SetEnvironmentVariable('PSModulePath', $TestEnvironment.OldPSModulePath, [System.EnvironmentVariableTarget]::Machine)
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

    Stop-DscConfiguration -ErrorAction 'SilentlyContinue' -Force
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
        [String]
        $FilePath
    )

    $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)

    foreach ($fileAttributeAst in $fileAst.FindAll({$args[0] -is [System.Management.Automation.Language.AttributeAst]}, $false))
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
        [String]
        $FilePath
    )

    $classResourceNames = [String[]]@()

    if (Test-FileContainsClassResource -FilePath $FilePath)
    {
        $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)

        $typeDefinitionAsts = $fileAst.FindAll({$args[0] -is [System.Management.Automation.Language.TypeDefinitionAst]}, $false)
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
        [String]
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
        [String]
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
        [String]
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
        [String]
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
        [String]
        $Root
    )

    $textFileExtensions = @('.gitignore', '.gitattributes', '.ps1', '.psm1', '.psd1', '.json', '.xml', '.cmd', '.mof','.md','.js','.yml')

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
        [String]
        $ModulePath
    )

    $scriptResourceNames = @()

    $dscResourcesFolderFilePath = Join-Path -Path $ModulePath -ChildPath 'DscResources'
    $mofSchemaFiles = Get-ChildItem -Path $dscResourcesFolderFilePath -Filter '*.schema.mof' -File -Recurse

    foreach ($mofSchemaFile in $mofSchemaFiles)
    {
        $scriptResourceName = $mofSchemaFile.BaseName -replace '.schema',''
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
        [String]
        $FilePath
    )

    $suppressedPSSARuleNames = [String[]]@()

    $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)

    # Overall file attrbutes
    $attributeAsts = $fileAst.FindAll({$args[0] -is [System.Management.Automation.Language.AttributeAst]}, $true)

    foreach ($attributeAst in $attributeAsts)
    {
        if ([System.Diagnostics.CodeAnalysis.SuppressMessageAttribute].FullName.ToLower().Contains($attributeAst.TypeName.FullName.ToLower()))
        {
            $suppressedPSSARuleNames += $attributeAst.PositionalArguments.Extent.Text
        }
    }

    return $suppressedPSSARuleNames
}

<#
    .SYNOPSIS
        Downloads and installs a specific version of Nuget.exe to be used to produce
        DSC Resouce NUPKG files.

        This allows control over the version of Nuget.exe that is used. This helps
        resolve an issue with different versions of Nuget.exe formatting the version
        number in the filename of a produced NUPKG file.

        See https://github.com/PowerShell/xNetworking/issues/177 for more information.

    .PARAMETER OutFile
        The path to the download Nuget.exe to.

    .PARAMETER Uri
        The URI to use to dowload Nuget.exe from.
#>
function Install-NugetExe
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $OutFile,

        [String]
        $Uri = 'https://dist.nuget.org/win-x86-commandline/v3.4.4/NuGet.exe'
    )

    if (Test-Path -Path $OutFile)
    {
        Remove-Item -Path $OutFile -Force
    }
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile
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
        block.  Writes a warning if the test is not opted-in.

    .PARAMETER OptIns
        An array of what is opted-in
#>
function Get-PesterDescribeOptInStatus
{
    param
    (
        [string[]]$OptIns
    )

    $describeName = Get-PesterDescribeName
    $optIn = $OptIns -icontains $describeName
    if(!$optIn)
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
        Gets the value of the Name parameter for the specified command in the stack

    .PARAMETER Command
        The name of the command to find the Name parameter for
#>
function Get-CommandNameParameterValue
{
    Param(
        [Parameter(Mandatory=$true)]
        [string] $Command
    )

    $commandStackItem = (Get-PSCallStack).Where{$_.Command -eq $Command}
    $commandArgumentNameValues = $commandStackItem.Arguments.TrimStart('{',' ').TrimEnd('}',' ') -split '\s*,\s*'
    $nameParameterValue = ($commandArgumentNameValues.Where{ $_ -like 'name=*'} -split '=')[-1]
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
function Get-PSModulePathItem {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Prefix
    )

    $item = $env:PSModulePath.Split(';') | 
        Where-Object -FilterScript { $_ -like "$Prefix*" } |
        Select-Object -First 1

    if (!$item) {
        Write-Error -Message "Cannot find the requested item in the PowerShell module path.`n`$env:PSModulePath = $env:PSModulePath"
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
function Get-UserProfilePSModulePathItem {
    param()

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
function Get-PSHomePSModulePathItem {
    param()

    return Get-PSModulePathItem -Prefix $global:PSHOME
}

Export-ModuleMember -Function @(
    'New-Nuspec', `
    'Install-ModuleFromPowerShellGallery', `
    'Initialize-TestEnvironment', `
    'Restore-TestEnvironment', `
    'Get-ClassResourceNameFromFile', `
    'Test-ModuleContainsScriptResource', `
    'Test-ModuleContainsClassResource', `
    'Get-Psm1FileList', `
    'Get-FileParseErrors', `
    'Get-TextFilesList', `
    'Test-FileInUnicode', `
    'Get-ModuleScriptResourceNames', `
    'Import-PSScriptAnalyzer', `
    'Import-xDscResourceDesigner', `
    'Get-SuppressedPSSARuleNameList',
    'Reset-DSC',
    'Install-NugetExe',
    'Get-PesterDescribeOptInStatus',
    'Get-UserProfilePSModulePathItem',
    'Get-PSHomePSModulePathItem'
)
