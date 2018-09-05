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
        New-DscResourceWikiSite -ModulePath C:\repos\SharePointdsc -OutputPath C:\repos\SharePointDsc\en-US

        This example shows how to generate help for a specific module
#>
function New-DscResourceWikiSite
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $OutputPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModulePath
    )

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'MofHelper.psm1')

    $mofSearchPath = Join-Path -Path $ModulePath -ChildPath '\**\*.schema.mof'
    $mofSchemaFiles = Get-ChildItem -Path $mofSearchPath -Recurse

    # Loop through all the Schema files found in the modules folder
    foreach ($mofSchemaFile in $mofSchemaFiles)
    {
        $mofSchema = Get-MofSchemaObject -FileName $mofSchemaFile.FullName |
            Where-Object -FilterScript {
                ($_.ClassName -eq $mofSchemaFile.Name.Replace('.schema.mof', '')) `
                    -and ($null -ne $_.FriendlyName)
            }

        $descriptionPath = Join-Path -Path $mofSchemaFile.DirectoryName -ChildPath 'readme.md'

        if (Test-Path -Path $descriptionPath)
        {
            Write-Verbose -Message "Generating wiki page for $($mofSchema.FriendlyName)"

            $output = New-Object -TypeName System.Text.StringBuilder
            $null = $output.AppendLine("# $($mofSchema.FriendlyName)")
            $null = $output.AppendLine('')
            $null = $output.AppendLine('## Parameters')
            $null = $output.AppendLine('')
            $null = $output.AppendLine('| Parameter | Attribute | DataType | Description | Allowed Values |')
            $null = $output.AppendLine('| --- | --- | --- | --- | --- |')

            foreach ($property in $mofSchema.Attributes)
            {
                # If the attribute is an array, add [] to the DataType string
                $dataType = $property.DataType

                if ($property.IsArray)
                {
                    $dataType += '[]'
                }

                if ($property.EmbeddedInstance -eq 'MSFT_Credential')
                {
                    $dataType = 'PSCredential'
                }

                $null = $output.Append("| **$($property.Name)** " + `
                    "| $($property.State) " + `
                    "| $dataType " + `
                    "| $($property.Description) |")

                if ([string]::IsNullOrEmpty($property.ValueMap) -ne $true)
                {
                    $null = $output.Append(($property.ValueMap -Join ', '))
                }

                $null = $output.AppendLine('|')
            }

            $descriptionContent = Get-Content -Path $descriptionPath -Raw

            # Change the description H1 header to an H2
            $descriptionContent = $descriptionContent -replace '# Description','## Description'
            $null = $output.AppendLine()
            $null = $output.AppendLine($descriptionContent)

            $exampleSearchPath = "\Examples\Resources\$($mofSchema.FriendlyName)\*.ps1"
            $examplesPath = (Join-Path -Path $ModulePath -ChildPath $exampleSearchPath)
            $exampleFiles = Get-ChildItem -Path $examplesPath -ErrorAction SilentlyContinue

            if ($null -ne $exampleFiles)
            {
                $null = $output.AppendLine('## Examples')
                $exampleCount = 1

                foreach ($exampleFile in $exampleFiles)
                {
                    Write-Verbose -Message "Adding Example file '$($exampleFile.Name)' to wiki page for $($mofSchema.FriendlyName)"

                    $exampleContent = Get-DscResourceWikiExampleContent `
                        -ExamplePath $exampleFile.FullName `
                        -ExampleNumber ($exampleCount++)

                    $null = $output.AppendLine($exampleContent)
                }
            }

            $null = Out-File `
                -InputObject $output.ToString() `
                -FilePath (Join-Path -Path $OutputPath -ChildPath "$($mofSchema.FriendlyName).md") `
                -Encoding utf8 `
                -Force
        }
    }
}

<#
    .SYNOPSIS
        This function reads an example file from a resource and converts
        it to markdown for inclusion in a resource wiki file.

    .DESCRIPTION
        The function will read the example PS1 file and convert the
        help header into the description text for the example. It will
        also surround the example configuration with code marks to
        indication it is powershell code.

    .PARAMETER ExamplePath
        The path to the example file.

    .PARAMETER ModulePath
        The number of the example.

    .EXAMPLE
        Get-DscResourceWikiExampleContent -ExamplePath 'C:\repos\NetworkingDsc\Examples\Resources\DhcpClient\1-DhcpClient_EnableDHCP.ps1' -ExampleNumber 1

        Reads the content of 'C:\repos\NetworkingDsc\Examples\Resources\DhcpClient\1-DhcpClient_EnableDHCP.ps1'
        and converts it to markdown in preparation for being added to a resource wiki page.
#>

function Get-DscResourceWikiExampleContent
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ExamplePath,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $ExampleNumber
    )

    $exampleContent = Get-Content -Path $ExamplePath -Raw
    $helpStart = $exampleContent.IndexOf('<#')
    $helpEnd = $exampleContent.IndexOf('#>') + 2
    $help = $exampleContent.Substring($helpStart, $helpEnd - $helpStart)
    $helpOriginal = $help
    $help += [Environment]::NewLine + '```powershell'
    $help = $help.Replace('    ', '')
    $exampleContent = $exampleContent.Replace($helpOriginal, $help)

    # Remove all the lines starting with '#Requires'
    $exampleContent = [Regex]::Replace(
        $exampleContent,
        '^#Requires.*[\r\n]*',
        [System.String]::Empty,
        [System.Text.RegularExpressions.RegexOptions]::Multiline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    # Remove the comment block delimiters
    $exampleContent = $exampleContent -replace '<#'
    $exampleContent = $exampleContent -replace '#>'

    # Remove comment block headers
    $exampleContent = $exampleContent.Replace('.SYNOPSIS', '')
    $exampleContent = $exampleContent.Replace('.DESCRIPTION', '')
    $exampleContent = $exampleContent.Replace('.EXAMPLE', '')
    $exampleContent += '```'
    $exampleContent = "`r`n### Example $ExampleNumber" + $exampleContent

    return $exampleContent
}

Export-ModuleMember -Function New-DscResourceWikiSite
