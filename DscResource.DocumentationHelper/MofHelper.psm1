<#
.SYNOPSIS

Get-MofSchemaObject is used to read a .schema.mof file for a DSC resource

.DESCRIPTION

The Get-MofSchemaObject method is used to read the text content of the .schema.mof file
that all MOF based DSC resources have. The object that is returned contains all of the
data in the schema so it can be processed in other scripts.

.PARAMETER FileName

The full path to the .schema.mof file to process

.EXAMPLE

This example parses a MOF schema file

    $mof = Get-MofSchemaObject -FileName C:\repos\SharePointDsc\DSCRescoures\MSFT_SPSite\MSFT_SPSite.schema.mof

#>
function Get-MofSchemaObject
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $FileName
    )
    $contents = Get-Content $FileName

    $results = @()

    $currentResult = @{
        ClassVersion = $null
        FriendlyName = $null
        ClassName = $null
        Attributes = @()
    }

    $currentComment = ""
    $currentlyInCommentBlock = $false
    $partialLine = $null
    foreach($textLine in $contents)
    {
        if ($textLine.StartsWith("/*"))
        {
            $currentlyInCommentBlock = $true
        }
        elseif($textLine.StartsWith("*/"))
        {
            $currentlyInCommentBlock = $false
        }
        elseif($currentlyInCommentBlock -eq $true)
        {
            # Ignore lines in comment blocks
        }
        elseif ($textLine -match "ClassVersion" -or $textLine -match "FriendlyName")
        {
            if ($textLine -match "ClassVersion(`"*.`")")
            {
                $start = $textLine.IndexOf("ClassVersion(`"") + 14
                $end = $textLine.IndexOf("`")", $start)
                $currentResult.ClassVersion = $textLine.Substring($start, $end - $start)
            }

            if ($textLine -match "FriendlyName(`"*.`")")
            {
                $start = $textLine.IndexOf("FriendlyName(`"") + 14
                $end = $textLine.IndexOf("`")", $start)
                $currentResult.FriendlyName = $textLine.Substring($start, $end - $start)
            }
        }
        elseif ($textLine -match "class ")
        {
            $start = $textLine.ToLower().IndexOf("class ") + 6
            $end = $textLine.IndexOf(" ", $start)
            if ($end -eq -1)
            {
                $end = $textLine.Length
            }
            $currentResult.ClassName = $textLine.Substring($start, $end - $start)
        }
        elseif ($textLine.Trim() -eq "{" -or [string]::IsNullOrEmpty($textLine.Trim()))
        {
            # Ignore lines that are only brackets
        }
        elseif ($textLine.Trim() -eq "};")
        {
            $results += $currentResult
            $currentResult = @{
                ClassVersion = $null
                FriendlyName = $null
                ClassName = $null
                Attributes = @()
                Documentation = $null
            }
        }
        elseif (!$textLine.TrimEnd().EndsWith(';'))
        {
            $partialLine += $textLine
        }
        else
        {
            if($partialLine)
            {
                [string] $currentLine = $partialLine + $textLine
                $partialLine = $null
            }
            else 
            {
                $currentLine = $textLine                
            }

            $attributeValue = @{
                State = $null
                EmbeddedInstance = $null
                ValueMap = $null
                DataType = $null
                Name = $null
                Description = $null
                IsArray = $false
            }

            $start = $currentLine.IndexOf("[") + 1
            $end = $currentLine.IndexOf("]", $start)
            $metadataEnd = $end
            $length = $end - $start
            $metadataObjects = @()

            # Does this assume that the metadata is on the same line?
            if($length -gt 0)
            {
                $metadata = $currentLine.Substring($start, $end - $start)
                $metadataObjects = $metadata.Split(",")
                $attributeValue.State = $metadataObjects[0]
            }

            $metadataObjects | ForEach-Object {
                if ($_.Trim().StartsWith("EmbeddedInstance"))
                {
                    $start = $currentLine.IndexOf("EmbeddedInstance(`"") + 18
                    $end = $currentLine.IndexOf("`")", $start)
                    $attributeValue.EmbeddedInstance = $currentLine.Substring($start, $end - $start)
                }
                if ($_.Trim().StartsWith("ValueMap"))
                {
                    $start = $currentLine.IndexOf("ValueMap{") + 9
                    $end = $currentLine.IndexOf("}", $start)
                    $valueMap = $currentLine.Substring($start, $end - $start)
                    $attributeValue.ValueMap = $valueMap.Replace("`"", "").Split(",")
                }
                if ($_.Trim().StartsWith("Description"))
                {
                    $start = $currentLine.IndexOf("Description(`"") + 13
                    $end = $currentLine.IndexOf("`")", $start)
                    $attributeValue.Description = $currentLine.Substring($start, $end - $start)
                }
            }

            $nonMetadata = $currentLine.Replace(";","").Substring($metadataEnd + 1)

            $nonMetadataObjects =  $nonMetadata -split '\s+'
            $attributeValue.DataType = $nonMetadataObjects[1]
            $attributeValue.Name = $nonMetadataObjects[2]

            if ($attributeValue.Name -and $attributeValue.Name.EndsWith("[]") -eq $true)
            {
                $attributeValue.Name = $attributeValue.Name.Replace("[]", "")
                $attributeValue.IsArray = $true
            }

            $currentResult.Attributes += $attributeValue
        }
    }
    return $results
}

Export-ModuleMember -Function *
