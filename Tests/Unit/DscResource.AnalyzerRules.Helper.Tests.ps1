Describe 'DscResource.AnalyzerRules.Helper Unit Tests' {
    BeforeAll {
        $projectRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $moduleRootPath = Join-Path -Path $projectRootPath -ChildPath 'DscResource.AnalyzerRules'
        $modulePath = Join-Path -Path $moduleRootPath -ChildPath 'DscResource.AnalyzerRules.Helper.psm1'

        Import-Module -Name $modulePath -Force
    }
    InModuleScope 'DscResource.AnalyzerRules.Helper' {
        Describe 'Get-StatementBlockAsRows' {
            Context 'When string contains CRLF as new line' {
                BeforeAll {
                    $expectedReturnValue1 = 'First line'
                    $expectedReturnValue2 = 'Second line'
                }

                It 'Should return the correct array of strings' {
                    $getStatementBlockAsRowsParameters = @{
                        StatementBlock = "First line`r`nSecond line"
                    }

                    $getStatementBlockAsRowsResult = `
                        Get-StatementBlockAsRows @getStatementBlockAsRowsParameters

                    $getStatementBlockAsRowsResult[0] | Should -Be $expectedReturnValue1
                    $getStatementBlockAsRowsResult[1] | Should -Be $expectedReturnValue2
                }
            }

            Context 'When string contains LF as new line' {
                It 'Should return the correct array of strings' {
                    $getStatementBlockAsRowsParameters = @{
                        StatementBlock = "First line`nSecond line"
                    }

                    $getStatementBlockAsRowsResult = `
                        Get-StatementBlockAsRows @getStatementBlockAsRowsParameters

                    $getStatementBlockAsRowsResult[0] | Should -Be $expectedReturnValue1
                    $getStatementBlockAsRowsResult[1] | Should -Be $expectedReturnValue2
                }
            }
        }

        Describe 'Test-StatementOpeningBraceOnSameLine' {
            Context 'When statement has an opening brace on the same line' {
                It 'Should return $true' {
                    $testStatementOpeningBraceOnSameLineParameters = @{
                        StatementBlock = `
                            'if ($true) {
                             }
                            '
                    }

                    $testStatementOpeningBraceOnSameLineResult = `
                        Test-StatementOpeningBraceOnSameLine @testStatementOpeningBraceOnSameLineParameters

                    $testStatementOpeningBraceOnSameLineResult | Should -Be $true
                }
            }

            # Regression test for issue reported in review comment for PR #180.
            Context 'When statement is using braces in the evaluation expression' {
                It 'Should return $false' {
                    $testStatementOpeningBraceOnSameLineParameters = @{
                        StatementBlock = `
                            'if (Get-Command | Where-Object -FilterScript { $_.Name -eq ''Get-Help'' } )
                             {
                             }
                            '
                    }

                    $testStatementOpeningBraceOnSameLineResult = `
                        Test-StatementOpeningBraceOnSameLine @testStatementOpeningBraceOnSameLineParameters

                    $testStatementOpeningBraceOnSameLineResult | Should -Be $false
                }
            }

            Context 'When statement follows style guideline' {
                It 'Should return $false' {
                    $testStatementOpeningBraceOnSameLineParameters = @{
                        StatementBlock = `
                            'if ($true)
                             {
                             }
                            '
                    }

                    $testStatementOpeningBraceOnSameLineResult = `
                        Test-StatementOpeningBraceOnSameLine @testStatementOpeningBraceOnSameLineParameters

                    $testStatementOpeningBraceOnSameLineResult | Should -Be $false
                }
            }
        }

        Describe 'Test-StatementOpeningBraceIsNotFollowedByNewLine' {
            Context 'When statement opening brace is not followed by a new line' {
                It 'Should return $true' {
                    $testStatementOpeningBraceIsNotFollowedByNewLineParameters = @{
                        StatementBlock = `
                            'if ($true)
                             {  if ($false)
                                {
                                }
                             }
                            '
                    }

                    $testStatementOpeningBraceIsNotFollowedByNewLineResult = `
                        Test-StatementOpeningBraceIsNotFollowedByNewLine @testStatementOpeningBraceIsNotFollowedByNewLineParameters

                    $testStatementOpeningBraceIsNotFollowedByNewLineResult | Should -Be $true
                }
            }

            Context 'When statement follows style guideline' {
                It 'Should return $false' {
                    $testStatementOpeningBraceIsNotFollowedByNewLineParameters = @{
                        StatementBlock = `
                            'if ($true)
                             {
                                if ($false)
                                {
                                }
                             }
                            '
                    }

                    $testStatementOpeningBraceIsNotFollowedByNewLineResult = `
                        Test-StatementOpeningBraceIsNotFollowedByNewLine @testStatementOpeningBraceIsNotFollowedByNewLineParameters

                    $testStatementOpeningBraceIsNotFollowedByNewLineResult | Should -Be $false
                }
            }
        }

        Describe 'Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine' {
            Context 'When statement opening brace is not followed by a new line' {
                It 'Should return $true' {
                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineParameters = @{
                        StatementBlock = `
                            'if ($true)
                             {

                                if ($false)
                                {
                                }
                             }
                            '
                    }

                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineResult = `
                        Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testStatementOpeningBraceIsFollowedByMoreThanOneNewLineParameters

                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineResult | Should -Be $true
                }
            }

            Context 'When statement follows style guideline' {
                It 'Should return $false' {
                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineParameters = @{
                        StatementBlock = `
                            'if ($true)
                             {
                                if ($false)
                                {
                                }
                             }
                            '
                    }

                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineResult = `
                        Test-StatementOpeningBraceIsFollowedByMoreThanOneNewLine @testStatementOpeningBraceIsFollowedByMoreThanOneNewLineParameters

                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineResult | Should -Be $false
                }
            }
        }

        Describe 'Test-isInClass work' {
            Context 'Non Class AST' {
                It 'Should return false for an AST not in a Class AST' {
                    $definition = '
                    function Get-Something
                    {
                        Param
                        (
                            [Parameter(Mandatory=$true)]
                            [string]
                            $Path
                        )

                        $Path
                    }
                '
                    $Ast = [System.Management.Automation.Language.Parser]::ParseInput($definition, [ref] $null, [ref] $null)
                    $ParameterAst = $Ast.Find( {
                        param
                        (
                            [System.Management.Automation.Language.Ast]
                            $AST
                        )
                        $Ast -is [System.Management.Automation.Language.ParameterAst]
                    }, $true)
                    ($ParameterAst -is [System.Management.Automation.Language.ParameterAst]) | Should -Be $true
                    $isInClass = Test-isInClass -Ast $ParameterAst
                    $isInClass | Should -Be $false
                }
            }

            Context 'Class AST' {
                It 'Should Return True for an AST contained in a class AST' {
                    $definition = '
                    class Something
                    {
                        [void] Write([int] $Num)
                        {
                            Write-Host "Writing $Num"
                        }
                    }
                '
                    $Ast = [System.Management.Automation.Language.Parser]::ParseInput($definition, [ref] $null, [ref] $null)
                    $ParameterAst = $Ast.Find( {
                        param
                        (
                            [System.Management.Automation.Language.Ast]
                            $AST
                        )
                        $Ast -is [System.Management.Automation.Language.ParameterAst]
                    }, $true)
                    ($ParameterAst -is [System.Management.Automation.Language.ParameterAst]) | Should -Be $true
                    $isInClass = Test-isInClass -Ast $ParameterAst
                    $isInClass | Should -Be $true
                }

                It "Should return false for an AST contained in a ScriptBlock`r`n`tthat is a value assignment for a property or method in a class AST" {
                    $definition = '
                    class Something
                    {
                        [Func[Int,Int]] $MakeInt = {
                            [Parameter(Mandatory=$true)]
                            Param
                            (
                                [Parameter(Mandatory)]
                                [int] $Input
                            )
                            $Input * 2
                        }
                    }
                '
                    $Ast = [System.Management.Automation.Language.Parser]::ParseInput($definition, [ref] $null, [ref] $null)
                    $ParameterAst = $Ast.Find( {
                        param
                        (
                            [System.Management.Automation.Language.Ast]
                            $AST
                        )
                        $Ast -is [System.Management.Automation.Language.ParameterAst]
                    }, $true)
                    ($ParameterAst -is [System.Management.Automation.Language.ParameterAst]) | Should -Be $true
                    $isInClass = Test-isInClass -Ast $ParameterAst
                    $isInClass | Should -Be $false

                }
            }
        }

        Describe 'Test-StatementContainsUpperCase' {
            Context 'When statement is all lower case' {
                It 'Should return false' {
                    $statementBlock = 'foreach ($a in $b)'

                    Test-StatementContainsUpperCase -StatementBlock $statementBlock | Should -Be $false
                }
            }

            Context 'When statement is all upper case' {
                It 'Should return true' {
                    $statementBlock = 'FOREACH ($a in $b)'

                    Test-StatementContainsUpperCase -StatementBlock $statementBlock | Should -Be $true
                }
            }

            Context 'When statement is starts with lower case but contains upper case letters' {
                It 'Should return true' {
                    $statementBlock = 'forEach ($a in $b)'

                    Test-StatementContainsUpperCase -StatementBlock $statementBlock | Should -Be $true
                }
            }
        }
    }
}
