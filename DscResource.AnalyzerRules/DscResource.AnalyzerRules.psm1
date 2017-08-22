#Requires -Version 4.0

# Import Localized Data
Import-LocalizedData -BindingVariable localizedData

<#
.SYNOPSIS
    Validates the [Parameter()] attribute for each parameter.

.DESCRIPTION
    All parameters in a param block must contain a [Parameter()] attribute
    and it must be the first attribute for each parameter and must start with
    a capital letter P.

.EXAMPLE
    Measure-ParameterBlockParameterAttribute -ParameterAst $parameterAst

.INPUTS
    [System.Management.Automation.Language.ParameterAst]

.OUTPUTS
    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

.NOTES
    None
#>
function Measure-ParameterBlockParameterAttribute
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ParameterAst]
        $ParameterAst
    )

    try
    {
        $recordType = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
        $record = @{
            Message  = ''
            Extent   = $ParameterAst.Extent
            Rulename = $PSCmdlet.MyInvocation.InvocationName
            Severity = 'Warning'
        }

        if ($ParameterAst.Attributes.TypeName.FullName -notcontains 'parameter')
        {
            $record['Message'] = $localizedData.ParameterBlockParameterAttributeMissing

            $record -as $recordType
        }
        elseif ($ParameterAst.Attributes[0].TypeName.FullName -ne 'parameter')
        {
            $record['Message'] = $localizedData.ParameterBlockParameterAttributeWrongPlace

            $record -as $recordType
        }
        elseif ($ParameterAst.Attributes[0].TypeName.FullName -cne 'Parameter')
        {
            $record['Message'] = $localizedData.ParameterBlockParameterAttributeLowerCase

            $record -as $recordType
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
.SYNOPSIS
    Validates use of the Mandatory named argument within a Parameter attribute.

.DESCRIPTION
    If a parameter attribute contains the mandatory attribute the
    mandatory attribute must be formatted correctly.

.EXAMPLE
    Measure-ParameterBlockMandatoryNamedArgument -NamedAttributeArgumentAst $namedAttributeArgumentAst

.INPUTS
    [System.Management.Automation.Language.NamedAttributeArgumentAst]

.OUTPUTS
    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

.NOTES
    None
#>
function Measure-ParameterBlockMandatoryNamedArgument
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.NamedAttributeArgumentAst]
        $NamedAttributeArgumentAst
    )

    try
    {
        if ($NamedAttributeArgumentAst.ArgumentName -eq 'Mandatory')
        {
            $recordType = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
            $record = @{
                Message  = ''
                Extent   = $NamedAttributeArgumentAst.Extent
                Rulename = $PSCmdlet.MyInvocation.InvocationName
                Severity = 'Warning'
            }

            if ($NamedAttributeArgumentAst)
            {
                $invalidFormat = $false
                try
                {
                    $value = $NamedAttributeArgumentAst.Argument.SafeGetValue()
                    if ($value -eq $false)
                    {
                        $record['Message'] = $localizedData.ParameterBlockNonMandatoryParameterMandatoryAttributeWrongFormat

                        $record -as $recordType
                    }
                    elseif ($NamedAttributeArgumentAst.Argument.VariablePath.UserPath -cne 'true')
                    {
                        $invalidFormat = $true
                    }
                    elseif ($NamedAttributeArgumentAst.ArgumentName -cne 'Mandatory')
                    {
                        $invalidFormat = $true
                    }
                }
                catch
                {
                    $invalidFormat = $true
                }

                if ($invalidFormat)
                {
                    $record['Message'] = $localizedData.ParameterBlockParameterMandatoryAttributeWrongFormat

                    $record -as $recordType
                }
            }
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

Export-ModuleMember -Function Measure*
