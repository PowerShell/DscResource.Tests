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

                    $getStatementBlockAsRowsResult[0] | Should Be $expectedReturnValue1
                    $getStatementBlockAsRowsResult[1] | Should Be $expectedReturnValue2
                }
            }

            Context 'When string contains LF as new line' {
                It 'Should return the correct array of strings' {
                    $getStatementBlockAsRowsParameters = @{
                        StatementBlock = "First line`nSecond line"
                    }

                    $getStatementBlockAsRowsResult = `
                        Get-StatementBlockAsRows @getStatementBlockAsRowsParameters

                    $getStatementBlockAsRowsResult[0] | Should Be $expectedReturnValue1
                    $getStatementBlockAsRowsResult[1] | Should Be $expectedReturnValue2
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

                    $testStatementOpeningBraceOnSameLineResult | Should Be $true
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

                    $testStatementOpeningBraceOnSameLineResult | Should Be $false
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

                    $testStatementOpeningBraceOnSameLineResult | Should Be $false
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

                    $testStatementOpeningBraceIsNotFollowedByNewLineResult | Should Be $true
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

                    $testStatementOpeningBraceIsNotFollowedByNewLineResult | Should Be $false
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

                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineResult | Should Be $true
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

                    $testStatementOpeningBraceIsFollowedByMoreThanOneNewLineResult | Should Be $false
                }
            }
        }
    }
}
