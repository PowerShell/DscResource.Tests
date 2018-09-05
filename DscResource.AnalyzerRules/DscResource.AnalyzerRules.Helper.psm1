<#
    .SYNOPSIS
        Helper function to check if an Ast is part of a class.
        Returns true or false

    .EXAMPLE
        Test-IsInClass -Ast $ParameterBlockAst

    .INPUTS
        [System.Management.Automation.Language.Ast]

    .OUTPUTS
        [System.Boolean]

   .NOTES
        I initially just walked up the AST tree till I hit 
        a TypeDefinitionAst that was a class

        But...

        That means it would throw false positives for things like

        class HasAFunctionInIt
        {
            [Func[int,int]] $MyFunc = {
                param
                (
                    [Parameter(Mandatory=$true)]
                    [int]
                    $Input
                )

                $Input
            }
        }

        Where the param block and all its respective items ARE
        valid being in their own anonymous function definition
        that just happens to be inside a class property's
        assignment value

        So This check has to be a DELIBERATE step by step up the
        AST Tree ONLY far enough to validate if it is directly
        part of a class or not
#>
function Test-IsInClass
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.Ast]
        $Ast
    )

    [System.Boolean] $inAClass = $false
    # Is a Named Attribute part of Class Property?
    if ($Ast -is [System.Management.Automation.Language.NamedAttributeArgumentAst])
    {
        # Parent is an Attribute Ast AND
        $inAClass = $Ast.Parent -is [System.Management.Automation.Language.AttributeAst] -and 
            # Grandparent is a Property Member Ast (This Ast Type ONLY shows up inside a TypeDefinitionAst) AND
            $Ast.Parent.Parent -is [System.Management.Automation.Language.PropertyMemberAst] -and
            # Great Grandparent is a Type Definition Ast AND
            $Ast.Parent.Parent.Parent -is [System.Management.Automation.Language.TypeDefinitionAst] -and
            # Great Grandparent is a Class
            $ast.Parent.Parent.Parent.IsClass
    }
    # Is a Parameter part of a Class Method?
    elseif ($Ast -is [System.Management.Automation.Language.ParameterAst])
    {
        # Parent is a Function Definition Ast AND
        $inAClass = $Ast.Parent -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            # Grandparent is a Function Member Ast (This Ast Type ONLY shows up inside a TypeDefinitionAst) AND 
            $Ast.Parent.Parent -is [System.Management.Automation.Language.FunctionMemberAst] -and
            # Great Grandparent is a Type Definition Ast AND
            $Ast.Parent.Parent.Parent -is [System.Management.Automation.Language.TypeDefinitionAst] -and
            # Great Grandparent is a Class
            $Ast.Parent.Parent.Parent.IsClass
    }

    $inAClass
}

<#
    .SYNOPSIS
        Helper function for the Test-Statement* helper functions.
        Returns the extent text as an array of strings.

    .EXAMPLE
        Get-StatementBlockAsRows -StatementBlock $ScriptBlockAst.Extent

    .INPUTS
        [System.String]

    .OUTPUTS
        [System.String[]]

   .NOTES
        None
#>
function Get-StatementBlockAsRows
{
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $StatementBlock
    )

    <#
        Remove carriage return since the file is different depending if it's run in
        AppVeyor or locally. Locally it contains both '\r\n', but when cloned in
        AppVeyor it only contains '\n'.
    #>
    $statementBlockWithNewLine = $StatementBlock -replace '\r', ''
    return $statementBlockWithNewLine -split '\n'
}

<#
    .SYNOPSIS
        Helper function for the Measure-*Statement PSScriptAnalyzer rules.
        Test a single statement block for opening brace on the same line.

    .EXAMPLE
        Test-StatementOpeningBraceOnSameLine -StatementBlock $ScriptBlockAst.Extent

    .INPUTS
        [System.String]

    .OUTPUTS
        [System.Boolean]

   .NOTES
        None
#>
function Test-StatementOpeningBraceOnSameLine
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $StatementBlock
    )

    $statementBlockRows = Get-StatementBlockAsRows -StatementBlock $StatementBlock
    if ($statementBlockRows.Count)
    {
        # Check so that an opening brace does not exist on the same line as the statement.
        if ($statementBlockRows[0] -match '{[\s]*$')
        {
            return $true
        } # if
    } # if

    return $false
}

<#
    .SYNOPSIS
        Helper function for the Measure-*Statement PSScriptAnalyzer rules.
        Test a single statement block for new line after opening brace.

    .EXAMPLE
        Test-StatementOpeningBraceIsNotFollowedByNewLine -StatementBlock $ScriptBlockAst.Extent

    .INPUTS
        [System.String]

    .OUTPUTS
        [System.Boolean]

   .NOTES
        None
#>
function Test-StatementOpeningBraceIsNotFollowedByNewLine
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $StatementBlock
    )

    $statementBlockRows = Get-StatementBlockAsRows -StatementBlock $StatementBlock
    if ($statementBlockRows.Count -ge 2)
    {
        # Check so that an opening brace is followed by a new line.
        if ($statementBlockRows[1] -match '\{.+')
        {
            return $true
        } # if
    } # if

    return $false
}

<#
    .SYNOPSIS
        Helper function for the Measure-*Statement PSScriptAnalyzer rules.
        Test a single statement block for only one new line after opening brace.

    .EXAMPLE
        Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine -StatementBlock $ScriptBlockAst.Extent

    .INPUTS
        [System.String]

    .OUTPUTS
        [System.Boolean]

   .NOTES
        None
#>
function Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $StatementBlock
    )

    $statementBlockRows = Get-StatementBlockAsRows -StatementBlock $StatementBlock
    if ($statementBlockRows.Count -ge 3)
    {
        # Check so that an opening brace is followed by only one new line.
        if (-not $statementBlockRows[2].Trim())
        {
            return $true
        } # if
    } # if

    return $false
}
