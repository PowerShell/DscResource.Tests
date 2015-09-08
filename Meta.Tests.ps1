<# 
.summary
    Test that describes code.
#>

[CmdletBinding()]
param()

if (!$PSScriptRoot) # $PSScriptRoot is not defined in 2.0
{
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

$RepoRoot = (Resolve-Path $PSScriptRoot\..).Path

Import-Module $PSScriptRoot\MetaFixers.psm1

#region Download and import latest stable DSC Resource Designer module

# We are using nuget to be compatible with WMF v4 machines which
# do not have the PowerShell Package Management module.
$DesignerModuleName = 'xDscResourceDesigner'
$DesignerModulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\$DesignerModuleName"
$nugetSource = 'https://www.powershellgallery.com/api/v2'
$nugetOutputDirectory = "$(Split-Path -Path $DesignerModulePath -Parent)\\"


if (Test-Path -Path $DesignerModulePath)
{
    # Remove any installed version of the DscResourceDesigner module
    Remove-Item -Path $DesignerModulePath -Recurse -Force
}

$nugetArguments = @(
    "install $DesignerModuleName"
    '-source "{0}"' -f $nugetSource
    '-outputDirectory "{0}"' -f $nugetOutputDirectory
    '-ExcludeVersion'
)
$nugetProcess = Start-Process -Wait -PassThru -FilePath 'nuget.exe' -ArgumentList $nugetArguments
if ($nugetProcess.ExitCode -ne 0)
{
    throw (
        'Module installation of {0} failed with exit code {1}' -f $DesignerModuleName,
            $nugetProcess.ExitCode
    )
}

Import-Module -Name $DesignerModulePath -Force
#endregion

# Modify PSModulePath of the current PowerShell session.
# We want to make sure we always test the development version of the resource
# in the current build directory.
if (($env:PSModulePath.Split(';') | Select-Object -First 1) -ne $pwd)
{
    $env:PSModulePath = "$pwd;$env:PSModulePath"
}

Describe 'Text files formatting' {
    
    $allTextFiles = Get-TextFilesList $RepoRoot
    
    Context 'Files encoding' {

        It "Doesn't use Unicode encoding" {
            $unicodeFilesCount = 0
            $allTextFiles | %{
                if (Test-FileUnicode $_) {
                    $unicodeFilesCount += 1
                    Write-Warning "File $($_.FullName) contains 0x00 bytes. It's probably uses Unicode and need to be converted to UTF-8. Use Fixer 'Get-UnicodeFilesList `$pwd | ConvertTo-UTF8'."
                }
            }
            $unicodeFilesCount | Should Be 0
        }
    }

    Context 'Indentations' {

        It 'Uses spaces for indentation, not tabs' {
            $totalTabsCount = 0
            $allTextFiles | %{
                $fileName = $_.FullName
                $tabStrings = (Get-Content $_.FullName -Raw) | Select-String "`t" | % {
                    Write-Warning "There are tab in $fileName. Use Fixer 'Get-TextFilesList `$pwd | ConvertTo-SpaceIndentation'."
                    $totalTabsCount++
                }
            }
            $totalTabsCount | Should Be 0
        }
    }
}

Describe 'PowerShell DSC resource modules' {
    
    # Force convert to array
    $psm1Files = @(
        Get-ChildItem -Path $RepoRoot\DscResources -Recurse -Filter '*.psm1' -File |
            Foreach-Object {
                # Ignore Composite configurations
                # They requires additional resources to be installed on the box
                if (-not ($_.Name -like '*.schema.psm1'))
                {
                    $MofFileName = "$($_.BaseName).schema.mof"
                    $MofFilePath = Join-Path -Path $_.DirectoryName -ChildPath $MofFileName
                    if (Test-Path -Path $MofFilePath -ErrorAction SilentlyContinue)
                    {
                        Write-Output -InputObject $_
                    }
                }
            }
    )

    if (-not $psm1Files) {
        Write-Verbose -Verbose 'There are no resource files to analyze'
    } else {

        Write-Verbose -Verbose "Analyzing $($psm1Files.Count) resources"

        Context 'Correctness' {

            function Get-ParseErrors
            {
                param(
                    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
                    [string]$fileName
                )    

                $tokens = $null 
                $errors = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($fileName, [ref] $tokens, [ref] $errors)
                return $errors
            }


            It 'all .psm1 files don''t have parse errors' {
                $errors = @()
                $psm1Files | ForEach-Object { 
                    $localErrors = Get-ParseErrors $_.FullName
                    if ($localErrors) {
                        Write-Warning "There are parsing errors in $($_.FullName)"
                        Write-Warning ($localErrors | Format-List | Out-String)
                    }
                    $errors += $localErrors
                }
                $errors.Count | Should Be 0
            }
        }

        foreach ($psm1file in $psm1Files) 
        {
            Context "Schema Validation of $($psm1file.BaseName)" {

                It 'should pass Test-xDscResource' {
                    $result = Test-xDscResource -Name $psm1file.DirectoryName
                    $result | Should Be $true
                }

                It 'should pass Test-xDscSchema' {
                    $Splat = @{
                        Path = $psm1file.DirectoryName
                        ChildPath = "$($psm1file.BaseName).schema.mof"
                    }
                    $result = Test-xDscSchema -Path (Join-Path @Splat -Resolve -ErrorAction Stop)
                    $result | Should Be $true
                }
            }
        }
    }
}

