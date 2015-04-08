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

        It "Uses spaces for indentation, not tabs" {
            $totalTabsCount = 0
            $allTextFiles | %{
                $fileName = $_.FullName
                $tabStrings = (cat $_.FullName -Raw) | Select-String "`t" | % {
                    Write-Warning "There are tab in $fileName. Use Fixer 'Get-TextFilesList `$pwd | ConvertTo-SpaceIndentation'."
                    $totalTabsCount++
                }
            }
            $totalTabsCount | Should Be 0
        }
    }
}

