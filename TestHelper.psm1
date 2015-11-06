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
    param (
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
        Will attempt to install the xDSCResourceDesignerModule and import it.
    
    .EXAMPLE
        Get-ResourceDesigner

#>
function Get-ResourceDesigner {
    [CmdletBinding(
        SupportsShouldProcess = $true
    )]
    Param (
        [Boolean]$Force = $false
    )

    if ($env:APPVEYOR) {
        # Running in AppVeyor so force the install
        $PSBoundParameters.Force = $true
    }
    
    Install-ResourceDesigner @PSBoundParameters

    if (@(Get-Module -Name $Script:DesignerModuleName -ListAvailable).Count -ne 0)
    {
        # Import the module using the name if it is available
        Import-Module -Name $Script:DesignerModuleName -Force
    }
    else
    {
        Write-Warning -Message ( @(
            "The '$Script:DesignerModuleName' module is not installed. "
            "The 'PowerShell DSC resource modules' Pester Tests in Meta.Tests.ps1 "
            'will fail until this module is installed.'
            ) -Join '' )
    }
}

<#
    .SYNOPSIS
        Will attempt to download the xDSCResourceDesignerModule code via
        PowerShellGet or Nuget package.
    
    .EXAMPLE
        Install-ResourceDesigner

#>

function Install-ResourceDesigner {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    Param (
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
        return
    }
   
    $OutputDirectory = "$(Split-Path -Path $Script:DesignerModulePath -Parent)\"

    # Are PowerShellGet and PackageManagement modules installed?
    if (@(Get-Module -Name PowerShellGet,PackageManagement -ListAvailable).Count -eq 2)
    {
        If ($Force -or $PSCmdlet.ShouldProcess( `
            'Initialize the PowerShell Gallery provider then download and install the {0} module' `
                -f $Script:DesignerModuleName))
        {
            Import-Module PackageManagement

            # Make sure the Nuget Package provider is initialized.
            $null = Get-PackageProvider -name nuget -ForceBootStrap -Force

            # PowerShellGet is available - use that
            Import-Module PowerShellGet

            # Install the module
            Install-Module -Name $Script:DesignerModuleName -Force

            Write-Verbose -Verbose (`
                'The {0} module was installed using PowerShellGet.' `
                    -f $Script:DesignerModuleName            
            )
        }
        else
        {
            Write-Warning -Message (`
                '{0} module was not installed automatically.' `
                    -f $Script:DesignerModuleName
            )
            return
        }
    }
    else
    {
        # PowerShellGet module isn't available, so use Nuget directly to download it
        $nugetPath = 'nuget.exe'

        # Can't assume nuget.exe is available
        if ((Get-Command $nugetPath -ErrorAction SilentlyContinue) -eq $null) 
        {
            # Nuget.exe can't be found - download it to current folder
            $nugetURL = 'http://nuget.org/nuget.exe'
            If ($Force -or $PSCmdlet.ShouldProcess( `
                "Download and Install Nuget.exe from '{0}'" `
                    -f $nugetSource))
            {
                $nugetPath = Join-Path -Path (Get-Location) -ChildPath $nugetPath
                Invoke-WebRequest $Script:NugetDownloadURL -OutFile $nugetPath

                Write-Verbose -Verbose (`
                    "Nuget.exe was installed from '{0}'." `
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
                return        
            }
        }
        
        $nugetSource = 'https://www.powershellgallery.com/api/v2'
        If ($Force -or $PSCmdlet.ShouldProcess( `
            "Download and install the {0} module from '{1}' using Nuget" `
                -f $Script:DesignerModuleName,$nugetSource))
        {
            # Use Nuget.exe to install the module
            & "$nugetPath" @( `
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
            return
        }
    }
}
