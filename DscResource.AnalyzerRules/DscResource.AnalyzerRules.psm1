#Requires -Version 4.0

# Import Localized Data
Import-LocalizedData -BindingVariable localizedData

<#
.SYNOPSIS
    Validates the [Parameter()] attribute for each parameter.
.DESCRIPTION
    All parameters in a param block must contain a [Parameter()] attribute
    and it must bethe first attribute for each parameter and must start with
    a capital letter P.
.EXAMPLE
    Measure-ParameterBlockParameterAttribute -ScriptBlockAst $ScriptBlockAst
.INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
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
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    Process
    {
        $results = @()

        try
        {
            $diagnosticRecordType = 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'

            $findAllFunctionsFilter = {
                $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }

            $findAllParametersFilter = {
                $args[0] -is [System.Management.Automation.Language.ParamBlockAst]
            }

            [System.Management.Automation.Language.Ast[]] $functionsAst = $ScriptBlockAst.FindAll( $findAllFunctionsFilter, $true )

            foreach ($functionAst in $functionsAst)
            {
                [System.Management.Automation.Language.Ast[]] $parametersAst = $functionAst.FindAll( $findAllParametersFilter, $true ).Parameters

                foreach ($parameterAst in $parametersAst)
                {
                    if ($parameterAst.Attributes.Typename.FullName -notcontains 'parameter')
                    {
                        $results += New-Object `
                                    -Typename $diagnosticRecordType `
                                    -ArgumentList @(
                                        $localizedData.ParameterBlockParameterAttributeMissing, `
                                        $parameterAst.Extent, `
                                        $PSCmdlet.MyInvocation.InvocationName, `
                                        'Warning', `
                                        $null
                                    )
                    }
                    elseif ($parameterAst.Attributes[0].Typename.FullName -ne 'parameter')
                    {
                        $results += New-Object `
                                    -Typename $diagnosticRecordType `
                                    -ArgumentList @(
                                        $localizedData.ParameterBlockParameterAttributeWrongPlace, `
                                        $parameterAst.Extent, `
                                        $PSCmdlet.MyInvocation.InvocationName, `
                                        'Warning',`
                                        $null
                                    )
                    }
                    elseif ($parameterAst.Attributes[0].Typename.FullName -cne 'Parameter')
                    {
                        $results += New-Object `
                                    -Typename $diagnosticRecordType  `
                                    -ArgumentList @(
                                        $localizedData.ParameterBlockParameterAttributeLowerCase, `
                                        $parameterAst.Extent, `
                                        $PSCmdlet.MyInvocation.InvocationName, `
                                        'Warning', `
                                        $null
                                    )
                    } # if
                } # foreach parameter
            } # foreach function

            return $results
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

Export-ModuleMember -Function Measure*
