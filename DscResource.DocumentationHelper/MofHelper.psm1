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
        #region Workaround for OMI_BaseResource inheritance not resolving.

        $filePath = (Resolve-Path -Path $FileName).Path
        $tempFilePath = Join-Path -Path $env:TEMP -ChildPath "DscMofHelper_$((New-Guid).Guid).tmp"
        $moduleName = (Split-Path -Path $filePath -Leaf).Replace('.schema.mof',$null)
        $rawContent = (Get-Content -Path $filePath -Raw) -replace "$moduleName : OMI_BaseResource", $moduleName
        Set-Content -LiteralPath $tempFilePath -Value $rawContent -ErrorAction Stop

        # .NET methods don't like PowerShell drives
        $tempFilePath = Convert-Path -Path $tempFilePath

        #endregion

        $exceptionCollection = [System.Collections.ObjectModel.Collection[System.Exception]]::new()
        $moduleInfo = [System.Tuple]::Create('Module', [System.Version]'1.0.0')

        $class = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportClasses(
            $tempFilePath, $moduleInfo, $exceptionCollection
        )
    }
    catch
    {
        throw "Failed to import classes from file $FileName. Error $_"
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
            DataType         = $property.CimType
            ValueMap         = $property.Qualifiers.Where({$_.Name -eq 'ValueMap'}).Value
            IsArray          = $property.CimType -gt 16
            Description      = $property.Qualifiers.Where({$_.Name -eq 'Description'}).Value
            EmbeddedInstance = $property.Qualifiers.Where({$_.Name -eq 'EmbeddedInstance'}).Value
        }
    }

    @{
        ClassName    = $class.CimClassName
        Attributes   = $attributes
        ClassVersion = $class.CimClassQualifiers.Where({$_.Name -eq 'ClassVersion'}).Value
        FriendlyName = $class.CimClassQualifiers.Where({$_.Name -eq 'FriendlyName'}).Value
    }
}

Export-ModuleMember -Function *
