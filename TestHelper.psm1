<#
    Script Constants used by *-ResourceDesigner Functions
#>
<#
    .SYNOPSIS Creates a new nuspec file for nuget package.
        Will create $packageName.nuspec in $destinationPath

    .EXAMPLE
        New-Nuspec -packageName "TestPackage" -version 1.0.1 -licenseUrl "http://license" -packageDescription "description of the package" -tags "tag1 tag2" -destinationPath C:\temp
#>
function New-Nuspec
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$true)]
        [string] $version,
        [Parameter(Mandatory=$true)]
        [string] $author,
        [Parameter(Mandatory=$true)]
        [string] $owners,
        [string] $licenseUrl,
        [string] $projectUrl,
        [string] $iconUrl,
        [string] $packageDescription,
        [string] $releaseNotes,
        [string] $tags,
        [Parameter(Mandatory=$true)]
        [string] $destinationPath
    )

    $year = (Get-Date).Year

    $content +=
"<?xml version=""1.0""?>
<package xmlns=""http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd"">
  <metadata>
    <id>$packageName</id>
    <version>$version</version>
    <authors>$author</authors>
    <owners>$owners</owners>"

    if (-not [string]::IsNullOrEmpty($licenseUrl))
    {
        $content += "
    <licenseUrl>$licenseUrl</licenseUrl>"
    }

    if (-not [string]::IsNullOrEmpty($projectUrl))
    {
        $content += "
    <projectUrl>$projectUrl</projectUrl>"
    }

    if (-not [string]::IsNullOrEmpty($iconUrl))
    {
        $content += "
    <iconUrl>$iconUrl</iconUrl>"
    }

    $content +="
    <requireLicenseAcceptance>true</requireLicenseAcceptance>
    <description>$packageDescription</description>
    <releaseNotes>$releaseNotes</releaseNotes>
    <copyright>Copyright $year</copyright>
    <tags>$tags</tags>
  </metadata>
</package>"

    if (-not (Test-Path -Path $destinationPath))
    {
        New-Item -Path $destinationPath -ItemType Directory > $null
    }

    $nuspecPath = Join-Path $destinationPath "$packageName.nuspec"
    New-Item -Path $nuspecPath -ItemType File -Force > $null
    Set-Content -Path $nuspecPath -Value $content
}

<#
    .SYNOPSIS
        Will attempt to download the module from PowerShellGallery using
        Nuget package and return the module.

        If already installed will return the module without making changes.

        If module could not be downloaded it will return null.

    .PARAMETER Force
        Used to force any installations to occur without confirming with
        the user.

    .PARAMETER moduleName
        Name of the module to install

    .PARAMETER modulePath
        Path where module should be installed

    .EXAMPLE
        Install-ModuleFromPowerShellGallery

    .EXAMPLE
        if ($env:APPVEYOR) {
            # Running in AppVeyor so force silent install of xDSCResourceDesigner
            $PSBoundParameters.Force = $true
        }

        $xDSCResourceDesignerModuleName = "xDscResourceDesigner"
        $xDSCResourceDesignerModulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\$xDSCResourceDesignerModuleName"
        $xDSCResourceDesignerModule = Install-ModuleFromPowerShellGallery -ModuleName $xDSCResourceDesignerModuleName -ModulePath $xDSCResourceDesignerModulePath @PSBoundParameters
#>
function Install-ModuleFromPowerShellGallery {
    [OutputType([System.Management.Automation.PSModuleInfo])]
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String] $moduleName,

        [Parameter(Mandatory=$true)]
        [String] $modulePath,

        [Boolean]$Force = $false
    )

    $module = Get-Module -Name $moduleName -ListAvailable
    if (@($module).Count -ne 0)
    {
        # Module is already installed - report it.
        Write-Host -Object (`
            'Version {0} of the {1} module is already installed.' `
                -f $($module.Version -join ', '),$moduleName
        ) -ForegroundColor:Yellow
        # Could check for a newer version available here in future and perform an update.
        # Return only the latest version of the module
        return $module `
            | Sort-Object -Property Version -Descending `
            | Select-Object -First 1
    }

    Write-Verbose -Message (`
        'The {0} module is not installed.' `
            -f $moduleName
    )

    $OutputDirectory = "$(Split-Path -Path $modulePath -Parent)\"

    # Use Nuget directly to download the module
    $nugetPath = 'nuget.exe'

    # Can't assume nuget.exe is available - look for it in Path
    if ((Get-Command $nugetPath -ErrorAction SilentlyContinue) -eq $null)
    {
        # Is it in temp folder?
        $nugetPath = Join-Path -Path $ENV:Temp -ChildPath $nugetPath
        if (-not (Test-Path -Path $nugetPath))
        {
            # Nuget.exe can't be found - download it to temp folder
            $NugetDownloadURL = 'http://nuget.org/nuget.exe'
            If ($Force -or $PSCmdlet.ShouldProcess( `
                "Download Nuget.exe from '{0}' to Temp folder" `
                    -f $NugetDownloadURL))
            {
                Invoke-WebRequest $NugetDownloadURL -OutFile $nugetPath

                Write-Verbose -Message (`
                    "Nuget.exe was installed from '{0}' to Temp folder." `
                        -f $NugetDownloadURL
                )
            }
            else
            {
                # Without Nuget.exe we can't continue
                Write-Warning -Message (`
                    'Nuget.exe was not installed. {0} module can not be installed automatically.' `
                        -f $moduleName
                )
                return $null
            }
        }
        else
        {
            Write-Verbose -Message 'Using Nuget.exe found in Temp folder.'
        }
    }

    $nugetSource = 'https://www.powershellgallery.com/api/v2'
    If ($Force -or $PSCmdlet.ShouldProcess(( `
        "Download and install the {0} module from '{1}' using Nuget" `
            -f $moduleName,$nugetSource)))
    {
        # Use Nuget.exe to install the module
        $null = & "$nugetPath" @( `
            'install', $moduleName, `
            '-source', $nugetSource, `
            '-outputDirectory', $OutputDirectory, `
            '-ExcludeVersion' `
            )
        $ExitCode = $LASTEXITCODE

        if ($ExitCode -ne 0)
        {
            throw (
                'Installation of {0} module using Nuget failed with exit code {1}.' `
                    -f $moduleName,$ExitCode
                )
        }
        Write-Host -Object (`
            'The {0} module was installed using Nuget.' `
                -f $moduleName
        ) -ForegroundColor:Yellow
    }
    else
    {
        Write-Warning -Message (`
            '{0} module was not installed automatically.' `
                -f $moduleName
        )
        return $null
    }

    return (Get-Module -Name $moduleName -ListAvailable)
}

<#
    .SYNOPSIS
        Initializes an enviroment for running unit or integration tests
        on a DSC resource.

        This includes the following things:
        1. Creates a temporary working folder.
        2. Updates the $env:PSModulePath to ensure the correct module is tested.
        3. Backs up any settings that need to be changed to accurately test
           the resource.
        4. Produces a test object containing any parameters that may be used
           for testing as well as storing the backed up settings.

        The above changes are reverted by calling the Restore-TestEnvironment
        function. This includes deleteing the temporary working folder.

    .PARAMETER DSCModuleName
        The name of the DSC Module containing the resource that the tests will be
        run on.

    .PARAMETER DSCResourceName
        The full name of the DSC resource that the tests will be run on. This is
        usually the name of the folder containing the actual resource MOF file.

    .PARAMETER TestType
        Specifies the type of tests that are being intialized. It can be:
        Unit: Initialize for running Unit tests on a DSC resource. Default.
        Integration: Initialize for running Integration tests on a DSC resource.

    .OUTPUT
        Returns a test environment object which must be passed to the
        Restore-TestEnvironment function to allow it to restore the system
        back to the original state as well as clean up and working/temp files.

    .EXAMPLE
        $TestEnvironment = Inialize-TestEnvironment `
            -DSCModuleName 'xNetworking' `
            -DSCResourceName 'MSFT_xFirewall' `
            -TestType Unit

        This command will initialize the test enviroment for Unit testing
        the MSFT_xFirewall DSC resource in the xNetworking DSC module.

    .EXAMPLE
        $TestEnvironment = Inialize-TestEnvironment `
            -DSCModuleName 'xNetworking' `
            -DSCResourceName 'MSFT_xFirewall' `
            -TestType Integration

        This command will initialize the test enviroment for Integration testing
        the MSFT_xFirewall DSC resource in the xNetworking DSC module.
#>
function Initialize-TestEnvironment
{
    [OutputType([PSObject])]
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $DSCModuleName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $DSCResourceName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Unit','Integration')]
        [String] $TestType
    )

    Write-Host -Object (`
        'Initializing Test Environment for {0} testing of {1} in module {2}.' `
            -f $TestType,$DSCResourceName,$DSCModuleName) -ForegroundColor:Yellow
    if ($TestType -eq 'Unit')
    {
        [String] $RelativeModulePath = "DSCResources\$DSCResourceName\$DSCResourceName.psm1"
    }
    else
    {
        [String] $RelativeModulePath = "$DSCModuleName.psd1"
    }

    # Unique Temp Working Folder - always gets removed on completion
    # The tests can put anything in here and it will get cleaned up.
    [String] $RandomFileName = [System.IO.Path]::GetRandomFileName()
    [String] $WorkingFolder = Join-Path -Path $env:Temp -ChildPath "$DSCResourceName_$RandomFileName"
    # Create the working folder if it doesn't exist (it really shouldn't anyway)
    if (-not (Test-Path -Path $WorkingFolder))
    {
        New-Item -Path $WorkingFolder -ItemType Directory
    }

    # Determine the root folder of this module by stepping up the path until the disk root is found
    # or the DSC Module Manifest is found.
    [String] $Path = $Script:MyInvocation.MyCommand.Path
    [String] $DiskRoot = [System.IO.Path]::GetPathRoot($Path)
    while (($Path -ne $DiskRoot) -and (-not [String]::IsNullOrEmpty($Path)))
    {
        # Does the Path contain the Resource Module?
        if (Test-Path -Path (Join-Path -Path $Path -ChildPath "$DSCModuleName.psd1"))
        {
            # The Module Root folder has been found
            [String] $moduleRoot = $Path
            break
        }
        $Path = Split-Path -Path $Path -Parent
    } # while

    # Check that the Module Root was found
    if (-not $ModuleRoot)
    {
        Throw "The DSC Module Manifest '$DSCModuleName.psd1' could not be found or it was found in the root folder on the disk."
    } # if
    Write-Host -Object (`
        "DSC Module Manifest '{0}.psd1' detected in folder '{1}'." `
            -f $DSCModuleName,$ModuleRoot) -ForegroundColor:Yellow

    # The folder that all tests will find this module in
    [string] $modulesFolder = Split-Path -Parent $moduleRoot

    # Import the Module
    $Splat = @{
        Path = $moduleRoot
        ChildPath = $RelativeModulePath
        Resolve = $true
        ErrorAction = 'Stop'
    }
    $DSCModuleFile = Get-Item -Path (Join-Path @Splat)

    # Import the Module to test.
    Import-Module -Name $DSCModuleFile.FullName -Force -Scope Global

    # Set the PSModulePath environment variable so that the module path this module is in
    # appears first because the LCM will use this path to try and locate modules when integration
    # tests are called. This is to ensure the correct module is tested.
    [String] $OldModulePath = $env:PSModulePath
    [String] $NewModulePath = $OldModulePath
    if (($NewModulePath).Split(';') -ccontains $modulesFolder)
    {
        # Remove the existing module from the module path if it exists
        $NewModulePath = ($NewModulePath -split ';' | Where-Object {$_ -ne $modulesFolder}) -join ';'
    }
    $NewModulePath = "$modulesFolder;$NewModulePath"
    $env:PSModulePath = $NewModulePath
    if ($TestType -eq 'integration')
    {
        # For integration tests we have to set the Machine PSModulePath because otherwise the DSC
        # LCM won't be able to find the Resource module being tested and may use the wrong one.
        [System.Environment]::SetEnvironmentVariable('PSModulePath',$NewModulePath,[System.EnvironmentVariableTarget]::Machine)

        # Reset the DSC LCM
        Reset-DSC
    }

    # Preserve and set the execution policy so that the DSC MOF can be created
    $OldExecutionPolicy = Get-ExecutionPolicy
    if ($OldExecutionPolicy -ne 'Unrestricted')
    {
        Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
    }

    # Generate the test environment object that will be returned
    $TestEnvironment = @{
        DSCModuleName = $DSCModuleName
        DSCResourceName = $DSCResourceName
        TestType = $TestType
        RelativeModulePath = $RelativeModulePath
        WorkingFolder = $WorkingFolder
        OldModulePath = $OldModulePath
        OldExecutionPolicy = $OldExecutionPolicy
    }

    return $TestEnvironment
}

<#
    .SYNOPSIS
        Restores the enviroment after running unit or integration tests
        on a DSC resource.

        This restores the following changes made by calling
        Initialize-TestEnvironemt:
        1. Deletes the Working folder.
        2. Restores the $env:PSModulePath if it was changed.
        3. Restores any settings that were changed to test the resource.

    .PARAMETER TestEnvironment
        This is the object created by the Initialize-TestEnvironment
        cmdlet.

    .EXAMPLE
        Restore-TestEnvironment -TestEnvironment $TestEnvironment

        This command will initialize the test enviroment for Unit testing
        the MSFT_xFirewall DSC resource in the xNetworking DSC module.
#>
function Restore-TestEnvironment
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $TestEnvironment
    )

    Write-Verbose -Message (`
        'Cleaning up Test Environment after {0} testing of {1} in module {2}.' `
            -f $TestEnvironment.TestType,$TestEnvironment.DSCResourceName,$TestEnvironment.DSCModuleName)

    if ($TestEnvironment.TestType -eq 'integration')
    {
        # Reset the DSC LCM
        Reset-DSC
    }

    # Restore PSModulePath
    if ($TestEnvironment.OldModulePath -ne $env:PSModulePath)
    {
        $env:PSModulePath = $TestEnvironment.OldModulePath
        if ($TestEnvironment.TestType -eq 'integration')
        {
            # Restore the machine PSModulePath for integration tests.
            [System.Environment]::SetEnvironmentVariable('PSModulePath',$env:PSModulePath,[System.EnvironmentVariableTarget]::Machine)
        }
    }

    # Restore the Execution Policy
    if ($TestEnvironment.OldExecutionPolicy -ne (Get-ExecutionPolicy))
    {
        Set-ExecutionPolicy -ExecutionPolicy $TestEnvironment.OldExecutionPolicy -Scope Process -Force
    }

    # Cleanup Working Folder
    if (Test-Path -Path $TestEnvironment.WorkingFolder)
    {
        Remove-Item -Path $TestEnvironment.WorkingFolder -Recurse -Force
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
    Param
    (
    )

    Write-Verbose -Message 'Resetting DSC LCM.'

    Stop-DscConfiguration -Force -ErrorAction SilentlyContinue
    Remove-DscConfigurationDocument -Stage Current -Force
    Remove-DscConfigurationDocument -Stage Pending -Force
    Remove-DscConfigurationDocument -Stage Previous -Force
}

<#
    .SYNOPSIS
        Test if a PowerShell module (psm1) file contains DSC Class
        Resources.

    .PARAMETER Path
        This is the full path of the psm1 file.

    .EXAMPLE
        Test-ClassResource -Path 'c:\mymodule\myclassmodule.psm1'

        This command will test myclassmodule for the presence of Class
        based DSC resources
#>
function Test-ClassResource
{
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String] $Path
    )
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    $result = $false
    foreach ($item in $ast.FindAll({$args[0] -is [System.Management.Automation.Language.AttributeAst]}, $false))
    {
        if ($item.Extent.Text -eq '[DscResource()]')
        {
            $result = $true
        }
    }
    return $result
}

<#
    .SYNOPSIS
        Get DSC Class resource names from a PowerShell module (psm1) file.

    .PARAMETER Path
        This is the full path of the psm1 file.

    .EXAMPLE
        Get-ClassResource -Path 'c:\mymodule\myclassmodule.psm1'

        This command will get DSC Class resource names from the myclassmodule module.
#>
function Get-ClassResource
{
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String] $Path
    )
    if (Test-ClassResource -Path $Path)
    {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $Result = $ast.FindAll({$args[0] -is [System.Management.Automation.Language.TypeDefinitionAst]}, $false)
        foreach ($Item in $Result)
        {
            if ($Item.Attributes.TypeName.Name -eq 'DscResource')
            {
                $Item.Name
            }
        }
    }
}
