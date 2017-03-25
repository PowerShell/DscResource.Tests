<#
.SYNOPSIS

New-DscResourceWikiSite generates wiki pages that can be uploaded to GitHub to use as
public documentation for a module.

.DESCRIPTION

The New-DscResourceWikiSite cmdlet will review all of the MOF based resources
in a specified module directory and will output the Markdown files to the specified directory.
These help files include details on the property types for each resource, as well as a text
description and examples where they exist.

.PARAMETER OutputPath

Where should the files be saved to

.PARAMETER ModulePath

The path to the root of the DSC resource module (where the PSD1 file is found, not the folder for
and individual DSC resource)

.EXAMPLE

This example shows how to generate help for a specific module

    New-DscResourceWikiSite -ModulePath C:\repos\SharePointdsc -OutputPath C:\repos\SharePointDsc\en-US

#>
function New-DscResourceWikiSite
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $OutputPath,

        [parameter(Mandatory = $true)]
        [System.String]
        $ModulePath
    )

    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "MofHelper.psm1")

    $mofSearchPath = (Join-Path -Path $ModulePath -ChildPath "\**\*.schema.mof")
    $mofSchemas = Get-ChildItem -Path $mofSearchPath -Recurse
    $mofSchemas | ForEach-Object {
        $mofFileObject = $_
        $result = (Get-MofSchemaObject $_.FullName) | Where-Object {
            ($_.ClassName -eq $mofFileObject.Name.Replace(".schema.mof", "")) `
                -and ($null -ne $_.FriendlyName)
        }

        $descriptionPath = Join-Path -Path $_.DirectoryName -ChildPath "readme.md"
        if (Test-Path -Path $descriptionPath)
        {
            Write-Verbose -Message "Generating wiki page for $($result.FriendlyName)"

            $output = New-Object System.Text.StringBuilder
            $null = $output.AppendLine('**Parameters**')
            $null = $output.AppendLine('')
            $null = $output.AppendLine('| Parameter | Attribute | DataType | Description | Allowed Values |')
            $null = $output.AppendLine('| --- | --- | --- | --- | --- |')
            foreach ($property in $result.Attributes)
            {
                # If the attribute is an array, add [] to the DataType string
                $dataType = $property.DataType
                if ($property.IsArray)
                {
                    $dataType += '[]'
                }
                $null = $output.Append("| **$($property.Name)** " + `
                    "| $($property.State) " + `
                    "| $dataType " + `
                    "| $($property.Description) |")
                if ([string]::IsNullOrEmpty($property.ValueMap) -ne $true)
                {
                    $null = $output.Append(($property.ValueMap -Join ", "))
                }
                $null = $output.AppendLine("|")
            }

            $descriptionContent = Get-Content -Path $descriptionPath -Raw
            $null = $output.AppendLine()
            $null = $output.AppendLine($descriptionContent)

            $exampleSearchPath = "\Examples\Resources\$($result.FriendlyName)\*.ps1"
            $examplesPath = (Join-Path -Path $ModulePath -ChildPath $exampleSearchPath)
            $exampleFiles = Get-ChildItem -Path $examplesPath -ErrorAction SilentlyContinue

            if ($null -ne $exampleFiles)
            {
                $null = $output.AppendLine('**Examples**')
                $null = $output.AppendLine('')
                $exampleCount = 1
                foreach ($exampleFile in $exampleFiles)
                {
                    $exampleContent = Get-Content -Path $exampleFile.FullName -Raw
                    $helpStart = $exampleContent.IndexOf("<#")
                    $helpEnd = $exampleContent.IndexOf("#>") + 2
                    $help = $exampleContent.Substring($helpStart, $helpEnd - $helpStart)
                    $helpOriginal = $help
                    $help += [Environment]::NewLine + '````powershell'
                    $help = $help.Replace("    ", "")
                    $exampleContent = $exampleContent -replace $helpOriginal, $help
                    $exampleContent = $exampleContent -replace "<#"
                    $exampleContent = $exampleContent -replace "#>"
                    $exampleContent = $exampleContent.Replace(".EXAMPLE", `
                                                            "***Example $exampleCount***`n")
                    $exampleContent += '````'

                    $null = $output.AppendLine($exampleContent)

                    $exampleCount ++
                }
            }
            $output.ToString() | Out-File -FilePath (Join-Path $OutputPath "$($result.FriendlyName).md") `
                               -Encoding utf8 -Force
        }
    }
}

Export-ModuleMember -Function *
