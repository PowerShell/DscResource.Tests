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

