#Requires -Version 4.0

# Import helper module
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.AnalyzerRules.Helper.psm1')

# Import Localized Data
Import-LocalizedData -BindingVariable localizedData

$script:diagnosticRecordType = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
$script:diagnosticRecord = @{
    Message  = ''
    Extent   = $null
    RuleName = $null
    Severity = 'Warning'
}

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
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ParameterAst]
        $ParameterAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $ParameterAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName
        [System.Boolean] $inAClass = Test-IsInClass -Ast $ParameterAst

        <#
            If we are in a class the parameter attributes are not valid in Classes
            the ParameterValidation attributes are however
        #>
        if (!$inAClass)
        {
            if ($ParameterAst.Attributes.TypeName.FullName -notcontains 'parameter')
            {
                $script:diagnosticRecord['Message'] = $localizedData.ParameterBlockParameterAttributeMissing

                $script:diagnosticRecord -as $script:diagnosticRecordType
            }
            elseif ($ParameterAst.Attributes[0].TypeName.FullName -ne 'parameter')
            {
                $script:diagnosticRecord['Message'] = $localizedData.ParameterBlockParameterAttributeWrongPlace

                $script:diagnosticRecord -as $script:diagnosticRecordType
            }
            elseif ($ParameterAst.Attributes[0].TypeName.FullName -cne 'Parameter')
            {
                $script:diagnosticRecord['Message'] = $localizedData.ParameterBlockParameterAttributeLowerCase

                $script:diagnosticRecord -as $script:diagnosticRecordType
            }
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
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.NamedAttributeArgumentAst]
        $NamedAttributeArgumentAst
    )

    try
    {
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName
        [System.Boolean] $inAClass = Test-IsInClass -Ast $NamedAttributeArgumentAst

        <#
            Parameter Attributes are not valid in classes, and DscProperty does
            not use the (Mandatory = $true) format just DscProperty(Mandatory)
        #>
        if (!$inAClass)
        {
            if ($NamedAttributeArgumentAst.ArgumentName -eq 'Mandatory')
            {
                $script:diagnosticRecord['Extent'] = $NamedAttributeArgumentAst.Extent

                if ($NamedAttributeArgumentAst)
                {
                    $invalidFormat = $false
                    try
                    {
                        $value = $NamedAttributeArgumentAst.Argument.SafeGetValue()
                        if ($value -eq $false)
                        {
                            $script:diagnosticRecord['Message'] = $localizedData.ParameterBlockNonMandatoryParameterMandatoryAttributeWrongFormat

                            $script:diagnosticRecord -as $script:diagnosticRecordType
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
                        $script:diagnosticRecord['Message'] = $localizedData.ParameterBlockParameterMandatoryAttributeWrongFormat

                        $script:diagnosticRecord -as $script:diagnosticRecordType
                    }
                }
            }
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the function block braces and new lines around braces.

    .DESCRIPTION
        Each function should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.

    .EXAMPLE
        Measure-FunctionBlockBraces -FunctionDefinitionAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.FunctionDefinitionAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-FunctionBlockBraces
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionDefinitionAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $FunctionDefinitionAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $FunctionDefinitionAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.FunctionOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.FunctionOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.FunctionOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the if-statement block braces and new lines around braces.

    .DESCRIPTION
        Each if-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The if statement should also be in all lower case.
        The else and elseif statements are not currently checked.

    .EXAMPLE
        Measure-IfStatement -IfStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.IfStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-IfStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.IfStatementAst]
        $IfStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $IfStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        <#
            This removes the clause from if-statement, so it ends up an empty if().
            This is to resolve issue #238, when the clause spans multiple rows,
            and the first rows ends with a correct open brace. See example in
            regression test for #238.
        #>
        $extentTextWithClauseRemoved = $IfStatementAst.Extent.Text.Replace($IfStatementAst.Clauses[0].Item1.Extent.Text, '')

        $testParameters = @{
            StatementBlock = $extentTextWithClauseRemoved
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.IfStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.IfStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.IfStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'if'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the foreach-statement block braces and new lines around braces.

    .DESCRIPTION
        Each foreach-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The foreach statement should also be in all lower case.

    .EXAMPLE
        Measure-ForEachStatement -ForEachStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.ForEachStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-ForEachStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ForEachStatementAst]
        $ForEachStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $ForEachStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $ForEachStatementAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.ForEachStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.ForEachStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.ForEachStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'foreach'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the DoUntil-statement block braces and new lines around braces.

    .DESCRIPTION
        Each DoUntil-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The do statement should also be in all lower case.

    .EXAMPLE
        Measure-DoUntilStatement -DoUntilStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.DoUntilStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-DoUntilStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.DoUntilStatementAst]
        $DoUntilStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $DoUntilStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $DoUntilStatementAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.DoUntilStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.DoUntilStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.DoUntilStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'do'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the DoWhile-statement block braces and new lines around braces.

    .DESCRIPTION
        Each DoWhile-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The do statement should also be in all lower case.

    .EXAMPLE
        Measure-DoWhileStatement -DoWhileStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.DoWhileStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-DoWhileStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.DoWhileStatementAst]
        $DoWhileStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $DoWhileStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $DoWhileStatementAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.DoWhileStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.DoWhileStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.DoWhileStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'do'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the while-statement block braces and new lines around braces.

    .DESCRIPTION
        Each while-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The while statement should also be in all lower case.

    .EXAMPLE
        Measure-WhileStatement -WhileStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.WhileStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-WhileStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.WhileStatementAst]
        $WhileStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $WhileStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $WhileStatementAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.WhileStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.WhileStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.WhileStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'while'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the for-statement block braces and new lines around braces.

    .DESCRIPTION
        Each for-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The for statement should also be in all lower case.

    .EXAMPLE
        Measure-ForStatement -ForStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.ForStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-ForStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ForStatementAst]
        $ForStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $ForStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $ForStatementAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.ForStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.ForStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.ForStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'for'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the switch-statement block braces and new lines around braces.

    .DESCRIPTION
        Each switch-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The switch statement should also be in all lower case.

    .EXAMPLE
        Measure-SwitchStatement -SwitchStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.SwitchStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-SwitchStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.SwitchStatementAst]
        $SwitchStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $SwitchStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $SwitchStatementAst.Extent
        }

        <#
            Must use an else block here, because otherwise, if there is a
            switch-clause that is formatted wrong it will hit on that
            and return the wrong rule message.
        #>
        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.SwitchStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
        elseif (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.SwitchStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.SwitchStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'switch'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the try-statement block braces and new lines around braces.

    .DESCRIPTION
        Each try-statement should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The try statement should also be in all lower case.

    .EXAMPLE
        Measure-TryStatement -TryStatementAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.TryStatementAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-TryStatement
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.TryStatementAst]
        $TryStatementAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $TryStatementAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $TryStatementAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.TryStatementOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.TryStatementOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.TryStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'try'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the catch-clause block braces and new lines around braces.

    .DESCRIPTION
        Each catch-clause should have the opening brace on a separate line.
        Also, the opening brace should be followed by a new line.
        The catch statement should also be in all lower case.

    .EXAMPLE
        Measure-CatchClause -CatchClauseAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.CatchClauseAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-CatchClause
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.CatchClauseAst]
        $CatchClauseAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $CatchClauseAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $CatchClauseAst.Extent
        }

        if (Test-StatementOpeningBraceOnSameLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.CatchClauseOpeningBraceNotOnSameLine
            $script:diagnosticRecord -as $diagnosticRecordType
        }

        if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.CatchClauseOpeningBraceShouldBeFollowedByNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.CatchClauseOpeningBraceShouldBeFollowedByOnlyOneNewLine
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if

        if (Test-StatementContainsUpperCase @testParameters)
        {
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'catch'
            $script:diagnosticRecord -as $diagnosticRecordType
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates the Class and Enum of PowerShell.

    .DESCRIPTION
        Each Class or Enum must be formatted correctly.
        The class or enum statement should also be in all lower case.

    .EXAMPLE
        Measure-TypeDefinition -TypeDefinitionAst $ScriptBlockAst

    .INPUTS
        [System.Management.Automation.Language.TypeDefinitionAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-TypeDefinition
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.TypeDefinitionAst]
        $TypeDefinitionAst
    )

    try
    {
        $script:diagnosticRecord['Extent'] = $TypeDefinitionAst.Extent
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $testParameters = @{
            StatementBlock = $TypeDefinitionAst.Extent
        }

        if ($TypeDefinitionAst.IsEnum)
        {
            if (Test-StatementOpeningBraceOnSameLine @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.EnumOpeningBraceNotOnSameLine
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if

            if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.EnumOpeningBraceShouldBeFollowedByNewLine
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if

            if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.EnumOpeningBraceShouldBeFollowedByOnlyOneNewLine
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if

            if (Test-StatementContainsUpperCase @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'enum'
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if
        } # if
        elseif ($TypeDefinitionAst.IsClass)
        {
            if (Test-StatementOpeningBraceOnSameLine @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.ClassOpeningBraceNotOnSameLine
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if

            if (Test-StatementOpeningBraceIsNotFollowedByNewLine @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.ClassOpeningBraceShouldBeFollowedByNewLine
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if

            if (Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.ClassOpeningBraceShouldBeFollowedByOnlyOneNewLine
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if

            if (Test-StatementContainsUpperCase @testParameters)
            {
                $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f 'class'
                $script:diagnosticRecord -as $diagnosticRecordType
            } # if
        } # if
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates all keywords.

    .DESCRIPTION
        Each keyword should be in all lower case.

    .EXAMPLE
        Measure-Keyword -Token $Token

    .INPUTS
        [System.Management.Automation.Language.Token[]]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

   .NOTES
        None
#>
function Measure-Keyword
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.Token[]]
        $Token
    )

    try
    {
        $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

        $keywordsToIgnore = @('configuration')
        $keywordFlag = [System.Management.Automation.Language.TokenFlags]::Keyword
        $keywords = $Token.Where{ $_.TokenFlags.HasFlag($keywordFlag) -and
            $_.Kind -ne 'DynamicKeyword' -and
            $keywordsToIgnore -notcontains $_.Text
        }
        $upperCaseTokens = $keywords.Where{ $_.Text -cmatch '[A-Z]+' }

        $tokenWithNoSpace = $keywords.Where{ $_.Extent.StartScriptPosition.Line -match "$($_.Extent.Text)\(.*" }

        foreach ($item in $upperCaseTokens)
        {
            $script:diagnosticRecord['Extent'] = $item.Extent
            $script:diagnosticRecord['Message'] = $localizedData.StatementsContainsUpperCaseLetter -f $item.Text
            $script:diagnosticRecord -as $diagnosticRecordType
        }

        foreach ($item in $tokenWithNoSpace)
        {
            $script:diagnosticRecord['Extent'] = $item.Extent
            $script:diagnosticRecord['Message'] = $localizedData.OneSpaceBetweenKeywordAndParenthesis
            $script:diagnosticRecord -as $diagnosticRecordType
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

<#
    .SYNOPSIS
        Validates all hashtables.

    .DESCRIPTION
        Hashtables should have the correct format

    .EXAMPLE
        PS C:\> Measure-Hashtable -HashtableAst $HashtableAst

    .INPUTS
        [System.Management.Automation.Language.HashtableAst]

    .OUTPUTS
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]

    .NOTES
        None
#>
function Measure-Hashtable
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.HashtableAst[]]
        $HashtableAst
    )

    try
    {
        foreach ($hashtable in $HashtableAst)
        {
            # Empty hashtables should be ignored
            if ($hashtable.extent.Text -eq '@{}' -or $hashtable.extent.Text -eq '@{ }')
            {
                continue
            }

            $script:diagnosticRecord['RuleName'] = $PSCmdlet.MyInvocation.InvocationName

            $hashtableLines = $hashtable.Extent.Text -split '\n'

            # Hashtable should start with '@{' and end with '}'
            if (($hashtableLines[0] -notmatch '\s*@?{\r' -and $hashtableLines[0] -notmatch '\s*@?{$') -or
                $hashtableLines[-1] -notmatch '\s*}')
            {
                $script:diagnosticRecord['Extent'] = $hashtable.Extent
                $script:diagnosticRecord['Message'] = $localizedData.HashtableShouldHaveCorrectFormat
                $script:diagnosticRecord -as $diagnosticRecordType
            }
            else
            {
                # We alredy checked that the first line is correctly formatted. Getting the starting indentation here
                $initialIndent = ([regex]::Match($hashtable.Extent.StartScriptPosition.Line, '(\s*)')).Length
                $expectedLineIndent = $initialIndent + 5

                foreach ($keyValuePair in $hashtable.KeyValuePairs)
                {
                    if ($keyValuePair.Item1.Extent.StartColumnNumber -ne $expectedLineIndent)
                    {
                        $script:diagnosticRecord['Extent'] = $hashtable.Extent
                        $script:diagnosticRecord['Message'] = $localizedData.HashtableShouldHaveCorrectFormat
                        $script:diagnosticRecord -as $diagnosticRecordType
                        break
                    }
                }
            }
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

Export-ModuleMember -Function Measure-*
