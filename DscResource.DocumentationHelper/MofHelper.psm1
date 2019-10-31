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
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FileName
    )

    try
    {
        # Workaround for OMI_BaseResource inheritance not resolving.
        $filePath = (Resolve-Path -Path $FileName).Path
        $tempFilePath = Join-Path -Path $env:TEMP -ChildPath "$((New-Guid).Guid).tmp"
        $rawContent = (Get-Content -Path $filePath -Raw) -replace ': OMI_BaseResource', $null
        Set-Content -LiteralPath $tempFilePath -Value $rawContent

        $exceptionCollection = [System.Collections.ObjectModel.Collection[System.Exception]]::new()
        $moduleInfo = [System.Tuple]::Create('Module', [System.Version]'1.0.0')

        $class = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportClasses(
            $tempFilePath, $moduleInfo, $exceptionCollection
        )
    }
    finally
    {
        Remove-Item -LiteralPath $tempFilePath -Force
    }

    $attributes = foreach ($property in $class.CimClassProperties)
    {
        $state = switch ($property.flags)
        {
            {$_ -band [Microsoft.Management.Infrastructure.CimFlags]::Key}      {'Key'}
            {$_ -band [Microsoft.Management.Infrastructure.CimFlags]::Required} {'Required'}
            {$_ -band [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly} {'Read'}
            default                                                             {'Write'}
        }

        @{
            Name             = $property.Name
            State            = $state
            DateType         = $property.CimType
            ValueMap         = $property.Qualifiers.Where({$_.Name -eq 'ValueMap'}).Value
            IsArray          = $property.CimType -gt 16
            Description      = $property.Qualifiers.Where({$_.Name -eq 'Description'}).Value
            EmbeddedInstance = $property.Qualifiers.Where({$_.Name -eq 'EmbeddedInstance'}).Value
        }
    }

    @{
        ClassName = $class.CimClassName
        Attributes = $attributes
        ClassVersion = $class.CimClassQualifiers.Where({$_.Name -eq 'ClassVersion'}).Value
        FriendlyName = $class.CimClassQualifiers.Where({$_.Name -eq 'FriendlyName'}).Value
    }
}

Export-ModuleMember -Function *
