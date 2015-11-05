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
        Will attempt to download the resource designer code via PowerShellGet or Nuget package.
    
    .EXAMPLE
        Get-ResourceDesigner

#>
function Get-ResourceDesigner {
    [CmdletBinding()]
       
    $DesignerModuleName = 'xDscResourceDesigner'
    $DesignerModulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\$DesignerModuleName"
    $OutputDirectory = "$(Split-Path -Path $DesignerModulePath -Parent)\"

    if ($env:APPVEYOR) {
        if (Test-Path -Path $DesignerModulePath)
        {
            # Remove any installed version of the DscResourceDesigner module
            Remove-Item -Path $DesignerModulePath -Recurse -Force
        }
  
        # Is PowerShellGet module installed?
        if (@(Get-Module -Name PowerShellGet -ListAvailable).Count -ne 0)
        {
            Import-Module PackageManagement

            # Make sure the Nuget Package provider is initialized.
            Get-PackageProvider -name nuget -ForceBootStrap -Force

            # PowerShellGet is available - use that
            Import-Module PowerShellGet

            # Install the module - make sure we terminate if it fails.
            Install-Module -Name $DesignerModuleName -Force
        }
        else
        {
            # PowerShellGet module isn't available, so use Nuget directly to download it
            $nugetSource = 'https://www.powershellgallery.com/api/v2'
            $nugetPath = 'nuget.exe'
            & "$nugetPath" @('install',$DesignerModuleName,'-source',$nugetSource,'-outputDirectory',$OutputDirectory,'-ExcludeVersion')
            $ExitCode = $LASTEXITCODE

            if ($ExitCode -ne 0)
            {
                throw (
                    'Module installation using Nuget of {0} failed with exit code {1}.' `
                        -f $DesignerModuleName,$ExitCode
                    )
            }
        }
    }

    # Import the module using the name
    Import-Module -Name $DesignerModuleName -Force
}
