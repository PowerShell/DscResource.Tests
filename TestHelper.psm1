<#
    Script Constants used by *-ResourceDesigner Functions
#>
$Script:DesignerModuleName = 'xDscResourceDesigner'
$Script:DesignerModulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\${Script:DesignerModuleName}"
$Script:NugetDownloadURL = 'http://nuget.org/nuget.exe'
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
        Will attempt to download the xDSCResourceDesignerModule using
        Nuget package and return the module.
        
        If already installed will return the module without making changes.

        If module could not be downloaded it will return null.
    
    .PARAMETER Force
        Used to force any installations to occur without confirming with
        the user.

    .EXAMPLE
        Install-ResourceDesigner

#>

function Install-ResourceDesigner
{
    [OutputType([System.Management.Automation.PSModuleInfo])]
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    Param
    (
        [Boolean]$Force = $false
    )
    $DesignerModule = Get-Module -Name $Script:DesignerModuleName -ListAvailable
    if (@($DesignerModule).Count -ne 0)
    {
        # ResourceDesigner is already installed - report it.
        Write-Verbose -Verbose (`
            'Version {0} of the {1} module is already installed.' `
                -f $DesignerModule.Version,$Script:DesignerModuleName            
        )
        # Could check for a newer version available here in future and perform an update.
        return $DesignerModule
    }

    Write-Verbose -Verbose (`
        'The {0} module is not installed.' `
            -f $Script:DesignerModuleName            
    )
   
    $OutputDirectory = "$(Split-Path -Path $Script:DesignerModulePath -Parent)\"

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
                Invoke-WebRequest $Script:NugetDownloadURL -OutFile $nugetPath

                Write-Verbose -Verbose (`
                    "Nuget.exe was installed from '{0}' to Temp folder." `
                        -f $Script:NugetDownloadURL
                )
            }
            else
            {
                # Without Nuget.exe we can't continue
                Write-Warning -Message (`
                    'Nuget.exe was not installed. {0} module can not be installed automatically.' `
                        -f $Script:DesignerModuleName
                )
                return $null    
            }
        }
        else
        {
            Write-Verbose -Verbose 'Using Nuget.exe found in Temp folder.'
        }
    }
        
    $nugetSource = 'https://www.powershellgallery.com/api/v2'
    If ($Force -or $PSCmdlet.ShouldProcess(( `
        "Download and install the {0} module from '{1}' using Nuget" `
            -f $Script:DesignerModuleName,$nugetSource)))
    {
        # Use Nuget.exe to install the module
        $null = & "$nugetPath" @( `
            'install', $Script:DesignerModuleName, `
            '-source', $nugetSource, `
            '-outputDirectory', $OutputDirectory, `
            '-ExcludeVersion' `
            )
        $ExitCode = $LASTEXITCODE

        if ($ExitCode -ne 0)
        {
            throw (
                'Installation of {0} module using Nuget failed with exit code {1}.' `
                    -f $Script:DesignerModuleName,$ExitCode
                )
        }
        Write-Verbose -Verbose (`
            'The {0} module was installed using Nuget.' `
                -f $Script:DesignerModuleName            
        )
    }
    else
    {
        Write-Warning -Message (`
            '{0} module was not installed automatically.' `
                -f $Script:DesignerModuleName
        )
        return $null
    }
    
    return (Get-Module -Name $Script:DesignerModuleName -ListAvailable)
}


<#
    .SYNOPSIS
        Initializes an enviroment for running unit or integration tests
        on a DSC resource.
        
        This includes the following things:
        1. Backing up any modules matching the name of the module being tested.
        2. Copying this module to the PSModules folder.
        3. Backing up any settings that need to be changed to accurately test
           a resource.
        4. Producing a test object containing any parameters that may be used
           for testing as well as storing the backed up settings.
    
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
            -DSCResourceName 'MSFT_xFirewall'
            
        This command will initialize the test enviroment for Unit testing
        the MSFT_xFirewall DSC resource in the xNetworking DSC module.      

    .EXAMPLE
        $TestEnvironment = Inialize-TestEnvironment `
            -DSCModuleName 'xNetworking' `
            -DSCResourceName 'MSFT_xFirewall'
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
    
    Write-Verbose -Verbose (`
        'Initializing Test Environment for {0} testing of {1} in module {2}.' `
            -f $TestType,$DSCResourceName,$DSCModuleName)   
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
    
    # The folder where this module is found
    [String] $moduleRoot = $pwd

    # The folder that all tests will find this module in
    [string] $modulesFolder = Resolve-Path -Path (Join-Path -Path $pwd -Child '..')   
        
    # Import the Module
    $Splat = @{
        Path = $moduleRoot
        ChildPath = $RelativeModulePath
        Resolve = $true
        ErrorAction = 'Stop'
    }
    $DSCModuleFile = Get-Item -Path (Join-Path @Splat)    
    
    # Remove all copies of the module from memory so an old one is not used.
    if (Get-Module -Name $DSCModuleFile.BaseName -All)
    {
        Get-Module -Name $DSCModuleFile.BaseName -All | Remove-Module
    }
    
    # Import the Module to test.
    Import-Module -Name $DSCModuleFile.FullName -Force
    
    # Set the PSModulePath environment variable because the LCM will use this path
    # to try and locate modules when integration tests are called.
    [String] $OldModulePath = $env:PSModulePath
    [String] $NewModulePath = $OldModulePath
    if (($NewModulePath).Split(';') -ccontains $modulesFolder)
    {
        $NewModulePath = ($NewModulePath -split ';' | Where-Object {$_ -ne $modulesFolder}) -join ';'
    }
    $env:PSModulePath = $NewModulePath
    [System.Environment]::SetEnvironmentVariable('PSModulePath',$NewModulePath,[System.EnvironmentVariableTarget]::Machine)
    
    # Preserve and set the execution policy so that the DSC MOF can be created
    $OldExecutionPolicy = Get-ExecutionPolicy
    if ($OldExecutionPolicy -ne 'Unrestricted')
    {
        Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force
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
        
        This restores the following things:
        1. Restores any backed up any modules.
        2. Deletes the Working folder.
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

    Write-Verbose -Verbose (`
        'Cleaning up Test Environment after {0} testing of {1} in module {2}.' `
            -f $TestEnvironment.TestType,$TestEnvironment.DSCResourceName,$TestEnvironment.DSCModuleName)
    
    # Restore PSModulePath
    if ($TestEnvironment.OldModulePath -ne $env:PSModulePath)
    {
        $env:PSModulePath = $TestEnvironment.OldModulePath
        [System.Environment]::SetEnvironmentVariable('PSModulePath',$env:PSModulePath,[System.EnvironmentVariableTarget]::Machine)
    }
    
    # Restore the Execution Policy
    if ($TestEnvironment.OldExecutionPolicy -ne (Get-ExecutionPolicy))
    {
        Set-ExecutionPolicy -ExecutionPolicy $TestEnvironment.OldExecutionPolicy -Force
    }   

    # Cleanup Working Folder
    if (Test-Path -Path $TestEnvironment.WorkingFolder)
    {
        Remove-Item -Path $TestEnvironment.WorkingFolder -Recurse -Force
    }
}
