$script:ProjectRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
$script:ModuleName = (Get-Item -Path $PSCommandPath).BaseName -replace '\.Tests'
$script:ModuleRootPath = Join-Path -Path $script:ProjectRoot -ChildPath $script:ModuleName

Describe "$($script:ModuleName) Unit Tests" {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $script:ProjectRoot -ChildPath 'TestHelper.psm1') -Force
        Import-PSScriptAnalyzer

        $modulePath = Join-Path -Path $script:ModuleRootPath -ChildPath "$($script:ModuleName).psm1"
        Import-LocalizedData -BindingVariable localizedData -BaseDirectory $script:ModuleRootPath -FileName "$($script:ModuleName).psd1"
    }

    Describe 'Measure-ParameterBlockParameterAttribute' {
        Context 'When ParameterAttribute is missing' {
            It 'Should write the correct record, when ParameterAttribute is missing' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            $ParameterName
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockParameterAttributeMissing
            }

            It 'Should not write a record, when ParameterAttribute is present' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter()]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }
        }

        Context 'When ParameterAttribute is not declared first' {
            It 'Should write the correct record, when ParameterAttribute is not declared first' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [ValidateSet("one", "two")]
                            [Parameter()]
                            $ParameterName
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockParameterAttributeWrongPlace
            }

            It 'Should not write a record, when ParameterAttribute is declared first' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter()]
                            [ValidateSet("one", "two")]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }
        }

        Context 'When ParameterAttribute is in lower-case' {
            It 'Should write the correct record, when ParameterAttribute is written in lower case' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [parameter()]
                            $ParameterName
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockParameterAttributeLowerCase
            }

            It 'Should not write a record, when ParameterAttribute is written correctly' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter()]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }
        }

        Context 'When a param block contains more than one parameter' {
            It 'Should write the correct records, when ParameterAttribute is missing from two parameters' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            $ParameterName1,

                            $ParameterName2
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 2
                $record[0].Message | Should Be $localizedData.ParameterBlockParameterAttributeMissing
                $record[1].Message | Should Be $localizedData.ParameterBlockParameterAttributeMissing
            }

            It 'Should write the correct records, when ParameterAttribute is missing and in lower-case' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            $ParameterName1,

                            [parameter()]
                            $ParameterName2
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 2
                $record[0].Message | Should Be $localizedData.ParameterBlockParameterAttributeMissing
                $record[1].Message | Should Be $localizedData.ParameterBlockParameterAttributeLowerCase
            }

            It 'Should write the correct record, when ParameterAttribute is missing from a second parameter' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter()]
                            $ParameterName1,

                            $ParameterName2
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockParameterAttributeMissing
            }
        }
    }

    Describe 'Measure-ParameterBlockMandatoryNamedArgument' {
        Context 'When Mandatory named argument is incorrectly formatted' {
            It 'Should write the correct record, when Mandatory is included and set to $false' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory = $false)]
                            $ParameterName
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockNonMandatoryParameterMandatoryAttributeWrongFormat
            }

            It 'Should write the correct record, when Mandatory is lower-case' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(mandatory = $true)]
                            $ParameterName
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockParameterMandatoryAttributeWrongFormat
            }

            It 'Should write the correct record, when Mandatory does not include an explicit argument' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory)]
                            $ParameterName
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockParameterMandatoryAttributeWrongFormat
            }

            It 'Should write the correct record, when Mandatory is incorrectly written and other parameters are used' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory = $false, ParameterSetName = "SetName")]
                            $ParameterName
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockNonMandatoryParameterMandatoryAttributeWrongFormat
            }

            It 'Should not write a record, when Mandatory is correctly written' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory = $true)]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }

            It 'Should not write a record, when Mandatory is not present and other parameters are' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(HelpMessage = "HelpMessage")]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }

            It 'Should not write a record, when Mandatory is correctly written and other parameters are listed' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory = $true, ParameterSetName = "SetName")]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }

            It 'Should not write a record, when Mandatory is correctly written and not placed first' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(ParameterSetName = "SetName", Mandatory = $true)]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }

            It 'Should not write a record, when Mandatory is correctly written and other attributes are listed' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory = $true)]
                            [ValidateSet("one", "two")]
                            $ParameterName
                        )
                    }
                '

                Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath | Should BeNullOrEmpty
            }
        }

        Context 'When a param block contains more than one parameter' {
            It 'Should write the correct records, when Mandatory is incorrect set on two parameters' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory)]
                            $ParameterName1,

                            [Parameter(Mandatory = $false)]
                            $ParameterName2
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 2
                $record[0].Message | Should Be $localizedData.ParameterBlockParameterMandatoryAttributeWrongFormat
                $record[1].Message | Should Be $localizedData.ParameterBlockNonMandatoryParameterMandatoryAttributeWrongFormat
            }

            It 'Should write the correct records, when ParameterAttribute is missing and in lower-case' {
                $definition = '
                    function Get-TargetResource
                    {
                        Param (
                            [Parameter(Mandatory = $true)]
                            $ParameterName1,

                            [Parameter(mandatory = $false)]
                            $ParameterName2
                        )
                    }
                '

                $record = Invoke-ScriptAnalyzer -ScriptDefinition $definition -CustomRulePath $modulePath
                ($record | Measure-Object).Count | Should Be 1
                $record.Message | Should Be $localizedData.ParameterBlockNonMandatoryParameterMandatoryAttributeWrongFormat
            }
        }
    }

    Describe 'Measure-FunctionBlockBraces' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When a functions opening brace is on the same line as the function keyword' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something {
                        [CmdletBinding()]
                        [OutputType([System.Boolean])]
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [ValidateNotNullOrEmpty()]
                            [System.String]
                            $Variable1
                        )

                        return $true
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.FunctionOpeningBraceNotOnSameLine
            }
        }

        Context 'When two functions has opening brace is on the same line as the function keyword' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something {
                    }

                    function Get-SomethingElse {
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 2
                $record[0].Message | Should Be $localizedData.FunctionOpeningBraceNotOnSameLine
                $record[1].Message | Should Be $localizedData.FunctionOpeningBraceNotOnSameLine
            }
        }

        Context 'When function opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {   [CmdletBinding()]
                        [OutputType([System.Boolean])]
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [ValidateNotNullOrEmpty()]
                            [System.String]
                            $Variable1
                        )

                        return $true
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.FunctionOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When function opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {

                        [CmdletBinding()]
                        [OutputType([System.Boolean])]
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [ValidateNotNullOrEmpty()]
                            [System.String]
                            $Variable1
                        )

                        return $true
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.FunctionOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When function follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        [CmdletBinding()]
                        [OutputType([System.Boolean])]
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [ValidateNotNullOrEmpty()]
                            [System.String]
                            $Variable1
                        )

                        return $true
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-IfStatement' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When if-statement has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        if ($true) {
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.IfStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When two if-statements has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        if ($true) {
                        }

                        if ($true) {
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 2
                $record[0].Message | Should Be $localizedData.IfStatementOpeningBraceNotOnSameLine
                $record[1].Message | Should Be $localizedData.IfStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When if-statement opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        if ($true)
                        { return $true
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.IfStatementOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When if-statement opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        if ($true)
                        {

                            return $true
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.IfStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When if-statement follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        if ($true)
                        {
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }

        # Regression test for issue reported in review comment for PR #180.
        Context 'When if-statement is using braces in the evaluation expression' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        if (Get-Command | Where-Object -FilterScript { $_.Name -eq ''Get-Help'' } )
                        {
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-ForEachStatement' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When foreach-statement has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $myArray = @()
                        foreach ($stringText in $myArray) {
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.ForEachStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When foreach-statement opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $myArray = @()
                        foreach ($stringText in $myArray)
                        {   $stringText
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.ForEachStatementOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When foreach-statement opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $myArray = @()
                        foreach ($stringText in $myArray)
                        {

                            $stringText
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.ForEachStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When foreach-statement follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $myArray = @()
                        foreach ($stringText in $myArray)
                        {
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-DoUntilStatement' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When DoUntil-statement has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 0

                        do {
                            $i++
                        } until ($i -eq 2)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.DoUntilStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When DoUntil-statement opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 0

                        do
                        { $i++
                        } until ($i -eq 2)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.DoUntilStatementOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When DoUntil-statement opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 0

                        do
                        {

                            $i++
                        } until ($i -eq 2)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.DoUntilStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When DoUntil-statement follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 0

                        do
                        {
                            $i++
                        } until ($i -eq 2)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-DoWhileStatement' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When DoWhile-statement has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        do {
                            $i--
                        } while ($i -gt 0)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.DoWhileStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When DoWhile-statement opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        do
                        { $i--
                        } while ($i -gt 0)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.DoWhileStatementOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When DoWhile-statement opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        do
                        {

                            $i--
                        } while ($i -gt 0)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.DoWhileStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When DoWhile-statement follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        do
                        {
                            $i--
                        } while ($i -gt 0)
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-WhileStatement' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When While-statement has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        while ($i -gt 0) {
                            $i--
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.WhileStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When While-statement opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        while ($i -gt 0)
                        { $i--
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.WhileStatementOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When While-statement opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        while ($i -gt 0)
                        {

                            $i--
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.WhileStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When While-statement follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $i = 10

                        while ($i -gt 0)
                        {
                            $i--
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-SwitchStatement' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When Switch-statement has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $value = 1

                        switch ($value) {
                            1
                            {
                                ''one''
                            }
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.SwitchStatementOpeningBraceNotOnSameLine
            }
        }

        # Regression test.
        Context 'When Switch-statement has an opening brace on the same line, and also has a clause with an opening brace on the same line' {
            It 'Should write only one error record, and the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $value = 1

                        switch ($value) {
                            1 { ''one'' }
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.SwitchStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When Switch-statement opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $value = 1

                        switch ($value)
                        {   1
                            {
                                ''one''
                            }
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.SwitchStatementOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When Switch-statement opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $value = 1

                        switch ($value)
                        {

                            1
                            {
                                ''one''
                            }
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.SwitchStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When Switch-statement follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        $value = 1

                        switch ($value)
                        {
                            1
                            {
                                ''one''
                            }
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-TryStatement' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When Try-statement has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try {
                            $value = 1
                        }
                        catch
                        {
                            throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.TryStatementOpeningBraceNotOnSameLine
            }
        }

        Context 'When Try-statement opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try
                        { $value = 1
                        }
                        catch
                        {
                            throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.TryStatementOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When Try-statement opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try
                        {

                            $value = 1
                        }
                        catch
                        {
                            throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.TryStatementOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When Try-statement follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try
                        {
                            $value = 1
                        }
                        catch
                        {
                            throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }

    Describe 'Measure-CatchClause' {
        BeforeEach {
            $invokeScriptAnalyzerParameters = @{
                CustomRulePath = $modulePath
            }
        }

        Context 'When Catch-clause has an opening brace on the same line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try
                        {
                            $value = 1
                        }
                        catch {
                            throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.CatchClauseOpeningBraceNotOnSameLine
            }
        }

        Context 'When Catch-clause opening brace is not followed by a new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try
                        {
                            $value = 1
                        }
                        catch
                        { throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.CatchClauseOpeningBraceShouldBeFollowedByNewLine
            }
        }

        Context 'When Catch-clause opening brace is followed by more than one new line' {
            It 'Should write the correct error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try
                        {
                            $value = 1
                        }
                        catch
                        {

                            throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                ($record | Measure-Object).Count | Should BeExactly 1
                $record.Message | Should Be $localizedData.CatchClauseOpeningBraceShouldBeFollowedByOnlyOneNewLine
            }
        }

        Context 'When Catch-clause follows style guideline' {
            It 'Should not write an error record' {
                $invokeScriptAnalyzerParameters['ScriptDefinition'] = '
                    function Get-Something
                    {
                        try
                        {
                            $value = 1
                        }
                        catch
                        {
                            throw
                        }
                    }
                '

                $record = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
                $record | Should BeNullOrEmpty
            }
        }
    }
}
