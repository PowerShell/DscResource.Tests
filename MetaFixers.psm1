<#
    .SYNOPSIS
        Fixes problems found by Meta.Tests.ps1
#>

$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$testHelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperModulePath

<#
    .SYNOPSIS
        Converts the given file to UTF8 encoding.

    .PARAMETER FileInfo
        The file to convert.
#>
function ConvertTo-UTF8
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.IO.FileInfo]
        $FileInfo
    )

    process
    {
        $fileContent = Get-Content -Path $FileInfo.FullName -Encoding 'Unicode' -Raw
        [System.IO.File]::WriteAllText($FileInfo.FullName, $fileContent, [System.Text.Encoding]::UTF8)
    }
}

<#
    .SYNOPSIS
        Converts the given file to ASCII encoding.

    .PARAMETER FileInfo
        The file to convert.
#>
function ConvertTo-ASCII
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.IO.FileInfo]
        $FileInfo
    )

    process
    {
        $fileContent = Get-Content -Path $FileInfo.FullName -Encoding 'Unicode' -Raw
        [System.IO.File]::WriteAllText($FileInfo.FullName, $fileContent, [System.Text.Encoding]::ASCII)
    }
}

function Convert-TabsToSpaceIndentation
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.IO.FileInfo]
        $FileInfo
    )

    process
    {
        $fileContent = Get-Content -Path $FileInfo.FullName -Encoding 'Unicode' -Raw
        $newFileContent = $fileContent.Replace("`t", '    ')
        [System.IO.File]::WriteAllText($FileInfo.FullName, $newFileContent)
    }
}

function Get-UnicodeFilesList
{
    [OutputType([System.IO.FileInfo[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Root
    )

    return Get-TextFilesList -Root $Root | Where-Object { Test-FileInUnicode $_ }
}

function Add-NewLineAtEndOfFile
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.IO.FileInfo]
        $FileInfo
    )

    process
    {
        $fileContent = Get-Content -Path $FileInfo.FullName -Raw
        $fileContent += "`r`n"
        [System.IO.File]::WriteAllText($FileInfo.FullName, $fileContent)
    }
}
