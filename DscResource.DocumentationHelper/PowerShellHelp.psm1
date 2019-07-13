<#
    Define enumeration for use by help example generation to determine the type of
    block that a text line is within.
#>
if (-not ([System.Management.Automation.PSTypeName]'HelpExampleBlockType').Type)
{
    $typeDefinition = @'
    public enum HelpExampleBlockType
    {
        None,
        PSScriptInfo,
        Configuration,
        ExampleCommentHeader
    }
'@
    Add-Type -TypeDefinition $typeDefinition
}

$projectRootPath = Split-Path -Path $PSScriptRoot -Parent
$testHelperPath = Join-Path -Path $projectRootPath -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

$moduleName = $ExecutionContext.SessionState.Module
$script:localizedData = Get-LocalizedData -ModuleName $moduleName -ModuleRoot $PSScriptRoot

<#
    .SYNOPSIS
        New-DscResourcePowerShellHelp generates PowerShell compatible help files for a DSC
        resource module

    .DESCRIPTION
        The New-DscResourcePowerShellHelp cmdlet will review all of the MOF based resources
        in a specified module directory and will inject PowerShell help files for each resource.
        These help files include details on the property types for each resource, as well as a text
        description and examples where they exist.

        The help files are output to the OutputPath directory if specified, or if not, they are
        output to the releveant resource's 'en-US' directory.

        A README.md with a text description must exist in the resource's subdirectory for the
        help file to be generated.

        These help files can then be read by passing the name of the resource as a parameter to Get-Help.

    .PARAMETER ModulePath
        The path to the root of the DSC resource module (where the PSD1 file is found, not the folder for
        each individual DSC resource)

    .EXAMPLE
        This example shows how to generate help for a specific module

        New-DscResourcePowerShellHelp -ModulePath C:\repos\SharePointdsc
#>
function New-DscResourcePowerShellHelp
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ModulePath,

        [Parameter()]
        [System.String]
        $OutputPath
    )

    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'MofHelper.psm1') -Verbose:$false

    $mofSearchPath = (Join-Path -Path $ModulePath -ChildPath '\**\*.schema.mof')
    $mofSchemas = Get-ChildItem -Path $mofSearchPath -Recurse

    Write-Verbose -Message ($script:localizedData.FoundMofFilesMessage -f $mofSchemas.Count, $ModulePath)

    $mofSchemas | ForEach-Object {
        $mofFileObject = $_

        $result = (Get-MofSchemaObject -FileName $_.FullName) | Where-Object -FilterScript {
            ($_.ClassName -eq $mofFileObject.Name.Replace('.schema.mof', '')) `
                -and ($null -ne $_.FriendlyName)
        }

        $descriptionPath = Join-Path -Path $mofFileObject.DirectoryName -ChildPath 'readme.md'

        if (Test-Path -Path $descriptionPath)
        {
            Write-Verbose -Message ($script:localizedData.GenerateHelpDocumentMessage -f $result.FriendlyName)

            $output = '.NAME' + [Environment]::NewLine
            $output += "    $($result.FriendlyName)"
            $output += [Environment]::NewLine + [Environment]::NewLine

            $descriptionContent = Get-Content -Path $descriptionPath -Raw

            $descriptionContent = $descriptionContent -replace '\n', "`n    "
            $descriptionContent = $descriptionContent -replace '# Description\r\n    ', '.DESCRIPTION'
            $descriptionContent = $descriptionContent -replace '\r\n\s{4}\r\n', "`n`n"
            $descriptionContent = $descriptionContent -replace '\s{4}$', ''

            $output += $descriptionContent
            $output += [Environment]::NewLine

            foreach ($property in $result.Attributes)
            {
                $output += ".PARAMETER $($property.Name)" + [Environment]::NewLine
                $output += "    $($property.State) - $($property.DataType)"
                $output += [Environment]::NewLine

                if ([string]::IsNullOrEmpty($property.ValueMap) -ne $true)
                {
                    $output += "    Allowed values: "
                    $property.ValueMap | ForEach-Object {
                        $output += $_ + ", "
                    }
                    $output = $output.TrimEnd(" ")
                    $output = $output.TrimEnd(",")
                    $output +=  [Environment]::NewLine
                }
                $output += "    " + $property.Description
                $output += [Environment]::NewLine + [Environment]::NewLine
            }

            $exampleSearchPath = "\Examples\Resources\$($result.FriendlyName)\*.ps1"
            $examplesPath = (Join-Path -Path $ModulePath -ChildPath $exampleSearchPath)
            $exampleFiles = Get-ChildItem -Path $examplesPath -ErrorAction SilentlyContinue

            if ($null -ne $exampleFiles)
            {
                $exampleCount = 1

                Write-Verbose -Message "Found $($exampleFiles.count) Examples for resource $($result.FriendlyName)"

                foreach ($exampleFile in $exampleFiles)
                {
                    $exampleContent = Get-DscResourceHelpExampleContent `
                        -ExamplePath $exampleFile.FullName `
                        -ExampleNumber ($exampleCount++)

                    $output += $exampleContent
                    $output += [Environment]::NewLine
                }
            }
            else
            {
                Write-Warning -Message ($script:localizedData.NoExampleFileFoundWarning -f $result.FriendlyName)
            }

            # Output to $OutputPath if specified or the resource 'en-US' directory if not.
            $outputFileName = "about_$($result.FriendlyName).help.txt"
            if ($OutputPath)
            {
                $savePath = Join-Path -Path $OutputPath -ChildPath $outputFileName
            }
            else
            {
                $savePath = Join-Path -Path $mofFileObject.DirectoryName -ChildPath 'en-US' | Join-Path -ChildPath $outputFileName
            }

            Write-Verbose -Message ($script:localizedData.OutputHelpDocumentMessage -f $savePath)

            $output | Out-File -FilePath $savePath -Encoding ascii -Force
        }
        else
        {
            Write-Warning -Message ($script:localizedData.NoDescriptionFileFoundWarning -f $result.FriendlyName)
        }
    }
}

<#
    .SYNOPSIS
        This function reads an example file from a resource and converts
        it to help text for inclusion in a PowerShell help file.

    .DESCRIPTION
        The function will read the example PS1 file and convert the
        help header into the description text for the example.

    .PARAMETER ExamplePath
        The path to the example file.

    .PARAMETER ModulePath
        The number of the example.

    .EXAMPLE
        Get-DscResourceHelpExampleContent -ExamplePath 'C:\repos\NetworkingDsc\Examples\Resources\DhcpClient\1-DhcpClient_EnableDHCP.ps1' -ExampleNumber 1

        Reads the content of 'C:\repos\NetworkingDsc\Examples\Resources\DhcpClient\1-DhcpClient_EnableDHCP.ps1'
        and converts it to help text in preparation for being added to a PowerShell help file.
#>
function Get-DscResourceHelpExampleContent
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

    $exampleContent = Get-Content -Path $ExamplePath

    # Use a string builder to assemble the example description and code
    $exampleDescriptionStringBuilder = New-Object -TypeName System.Text.StringBuilder
    $exampleCodeStringBuilder = New-Object -TypeName System.Text.StringBuilder

    <#
        Step through each line in the source example and determine
        the content and act accordingly:
        \<#PSScriptInfo...#\> - Drop block
        \#Requires - Drop Line
        \<#...#\> - Drop .EXAMPLE, .SYNOPSIS and .DESCRIPTION but include all other lines
        Configuration ... - Include entire block until EOF
    #>
    $blockType = [HelpExampleBlockType]::None

    foreach ($exampleLine in $exampleContent)
    {
        Write-Debug -Message ('Processing Line: {0}' -f $exampleLine)

        # Determine the behavior based on the current block type
        switch ($blockType.ToString())
        {
            'PSScriptInfo'
            {
                Write-Debug -Message 'PSScriptInfo Block Processing'

                # Exclude PSScriptInfo block from any output
                if ($exampleLine -eq '#>')
                {
                    Write-Debug -Message 'PSScriptInfo Block Ended'

                    # End of the PSScriptInfo block
                    $blockType = [HelpExampleBlockType]::None
                }
            }

            'Configuration'
            {
                Write-Debug -Message 'Configuration Block Processing'

                # Include all lines in the configuration block in the code output
                $null = $exampleCodeStringBuilder.AppendLine($exampleLine)
            }

            'ExampleCommentHeader'
            {
                Write-Debug -Message 'ExampleCommentHeader Block Processing'

                # Include all lines in Example Comment Header block except for headers
                $exampleLine = $exampleLine.TrimStart()

                if ($exampleLine -notin ('.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE', '#>'))
                {
                    # Not a header so add this to the output
                    $null = $exampleDescriptionStringBuilder.AppendLine($exampleLine)
                }

                if ($exampleLine -eq '#>')
                {
                    Write-Debug -Message 'ExampleCommentHeader Block Ended'

                    # End of the Example Comment Header block
                    $blockType = [HelpExampleBlockType]::None
                }
            }

            default
            {
                Write-Debug -Message 'Not Currently Processing Block'

                # Check the current line
                if ($exampleLine.TrimStart() -eq  '<#PSScriptInfo')
                {
                    Write-Debug -Message 'PSScriptInfo Block Started'

                    $blockType = [HelpExampleBlockType]::PSScriptInfo
                }
                elseif ($exampleLine -match 'Configuration')
                {
                    Write-Debug -Message 'Configuration Block Started'

                    $null = $exampleCodeStringBuilder.AppendLine($exampleLine)
                    $blockType = [HelpExampleBlockType]::Configuration
                }
                elseif ($exampleLine.TrimStart() -eq '<#')
                {
                    Write-Debug -Message 'ExampleCommentHeader Block Started'

                    $blockType = [HelpExampleBlockType]::ExampleCommentHeader
                }
            }
        }
    }

    # Assemble the final output
    $null = $exampleStringBuilder = New-Object -TypeName System.Text.StringBuilder
    $null = $exampleStringBuilder.AppendLine(".EXAMPLE $ExampleNumber")
    $null = $exampleStringBuilder.AppendLine()
    $null = $exampleStringBuilder.AppendLine($exampleDescriptionStringBuilder)
    $null = $exampleStringBuilder.Append($exampleCodeStringBuilder)

    return $exampleStringBuilder.ToString()
}

Export-ModuleMember -Function New-DscResourcePowerShellHelp
