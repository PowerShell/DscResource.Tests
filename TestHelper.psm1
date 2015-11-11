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

function Install-ResourceDesigner {
    [OutputType([System.Management.Automation.PSModuleInfo])]
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
