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
}
