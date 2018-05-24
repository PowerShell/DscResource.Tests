$script:ModuleName = 'AppVeyor'
$script:moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

try
{
    <#
        This must be set here instead of in a BeforeAll- or AfterAll-block
        because the loading of the CustomAppVeyorTasks.psm1 is done in the
        root of the AppVeyor.psm1 module.
        This is in a try-block so we can remove the environment variable
        once the tests has run (either successfully or failed).
    #>
    if ($null -eq $env:APPVEYOR_BUILD_FOLDER)
    {
        $isAppVeyorBuildFolderSetByTest = $true
        $env:APPVEYOR_BUILD_FOLDER = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    }

    Import-Module -Name (Join-Path -Path $script:moduleRootPath -ChildPath "$($script:ModuleName).psm1") -Force
    InModuleScope $script:ModuleName {
        Describe 'AppVeyor\Invoke-AppveyorTestScriptTask' {
            BeforeAll {
                $mockModuleFolder = (Join-Path -Path $TestDrive -ChildPath 'Modules')
                New-Item -Path $mockModuleFolder -ItemType Directory -Force

                # Added functions that are specific to AppVeyor environment so mocks would not fail
                Function Add-AppveyorTest
                {
                }

                <#
                    Mocking Write-Info so the text output can be changed to
                    differentiate from the real test output.
                #>
                Mock -CommandName Write-Info -MockWith {
                    Write-Host -Object "[Mocked Build Info] [UTC $([System.DateTime]::UtcNow)] $message"
                }

                Mock -CommandName Add-AppveyorTest
                Mock -CommandName Push-TestArtifact
                Mock -CommandName Invoke-UploadCoveCoveIoReport
                Mock -CommandName Export-CodeCovIoJson -MockWith {
                    return Join-Path -Path $TestDrive -ChildPath 'CodecovReport.json'
                }
            }

            # Regression test for issue #229
            Context 'When called with model type as ''Harness''' {
                BeforeAll {
                    Mock -CommandName Copy-Item
                    Mock -CommandName Remove-Item
                    Mock -CommandName Import-Module -ParameterFilter {
                        $Name -match 'TestHarness\.psm1'
                    }

                    <#
                        This is a mock of the default harness function name
                        that normally exist in the module TestHarness.psm1.
                    #>
                    function Invoke-TestHarness
                    {
                        return [PSCustomObject] @{
                            TestResult   = @(
                                @{
                                    ErrorRecord            = $null
                                    ParameterizedSuiteName = $null
                                    Describe               = 'MyModule\TestFunction'
                                    Parameters             = [ordered] @{}
                                    Passed                 = $true
                                    Show                   = 'All'
                                    FailureMessage         = $null
                                    Time                   = New-TimeSpan -Seconds 6
                                    Name                   = 'Should return the correct test properties'
                                    Result                 = 'Passed'
                                    Context                = 'When called with test parameters'
                                    StackTrace             = $null
                                }
                            )
                            FailedCount  = 0
                            CodeCoverage = New-Object -TypeName Object |
                                Add-Member -MemberType NoteProperty -Name 'NumberOfCommandsAnalyzed' -Value 3 -PassThru |
                                Add-Member -MemberType NoteProperty -Name 'NumberOfFilesAnalyzed' -Value 2 -PassThru |
                                Add-Member -MemberType NoteProperty -Name 'NumberOfCommandsExecuted' -Value 1 -PassThru |
                                Add-Member -MemberType NoteProperty -Name 'NumberOfCommandsMissed' -Value 2 -PassThru |
                                Add-Member -MemberType ScriptProperty -Name 'MissedCommands' -Value {
                                return @(
                                    [PSCustomObject] @{
                                        File     = 'TestFile1'
                                        Function = 'TestFunction1'
                                        Line     = '9999'
                                        Command  = 'Command1'
                                    }

                                    [PSCustomObject] @{
                                        File     = 'TestFile2'
                                        Function = 'TestFunction2'
                                        Line     = '8888'
                                        Command  = 'Command2'
                                    }
                                )
                            } -PassThru |
                                Add-Member -MemberType ScriptProperty -Name 'HitCommands' -Value {
                                return @(
                                    [PSCustomObject] @{
                                        File     = 'TestFile1'
                                        Function = 'TestFunction1'
                                        Line     = '2222'
                                        Command  = 'Command3'
                                    }
                                )
                            } -PassThru |
                                Add-Member -MemberType ScriptProperty -Name 'AnalyzedFiles' -Value {
                                return @(
                                    'TestFile1'
                                    'TestFile2'
                                )
                            } -PassThru -Force
                        }
                    }
                }

                It 'Should call the correct mocks' {
                    $testParameters = @{
                        Type           = 'Harness'
                        MainModulePath = $mockModuleFolder
                        CodeCovIo      = $true
                    }

                    { Invoke-AppveyorTestScriptTask @testParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Add-AppveyorTest -Exactly -Times 1
                    Assert-MockCalled -CommandName Push-TestArtifact -Exactly -Times 1
                    Assert-MockCalled -CommandName Export-CodeCovIoJson -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-UploadCoveCoveIoReport -Exactly -Times 1
                }
            }

            Context 'When CodeCoverage requires additional directories' {
                $pesterReturnedValues = @{
                    PassedCount = 1
                    FailedCount = 0
                }

                BeforeAll {
                    Mock -CommandName Test-Path -MockWith { return $false }
                    Mock -CommandName Get-ChildItem -MockWith { return 'file.Tests.ps1' }
                    Mock -CommandName Get-ChildItem -MockWith { return $null } -ParameterFilter { $Include -eq '*.config.ps1' }
                    Mock -CommandName Invoke-Pester -MockWith { return $pesterReturnedValues }
                    Mock -CommandName Invoke-Pester -MockWith { return $pesterReturnedValues } -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1" }
                    Mock -CommandName Invoke-Pester -MockWith { return $pesterReturnedValues } -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1" }
                    # Making sure there is no output when performing tests
                    Mock -CommandName Write-Verbose
                    Mock -CommandName Write-Warning
                    Mock -CommandName Write-Info
                    Mock -CommandName Test-IsRepositoryDscResourceTests -MockWith {
                        return $false
                    }
                } # End BeforeAll

                AfterEach {
                    Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -Scope It -ParameterFilter { $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources" }
                    Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -Scope It -ParameterFilter { $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources" }
                    Assert-MockCalled -CommandName Test-Path -Times 2 -Exactly -Scope It
                    Assert-MockCalled -CommandName Get-ChildItem -Times 1 -Exactly -Scope It -ParameterFilter { $Include -eq '*.config.ps1' }
                    Assert-MockCalled -CommandName Get-ChildItem -Times 2 -Exactly -Scope It
                } # End AfterEach

                It 'Should only include DSCClassResources for CodeCoverage' {
                    Mock -CommandName Test-Path -MockWith { return $true } -ParameterFilter { $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources" }
                    Mock -CommandName Test-Path -MockWith { return $false } -ParameterFilter { $Path -and $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources" }

                    { Invoke-AppveyorTestScriptTask -CodeCoverage } | Should Not Throw

                    Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1" }
                    Assert-MockCalled -CommandName Invoke-Pester -Times 0 -Exactly -Scope It -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1" }
                } # End It DSCClassResources only

                It 'Should only include DSCResources for CodeCoverage' {
                    Mock -CommandName Test-Path -MockWith { return $false } -ParameterFilter { $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources" }
                    Mock -CommandName Test-Path -MockWith { return $true } -ParameterFilter { $Path -and $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources" }

                    { Invoke-AppveyorTestScriptTask -CodeCoverage } | Should Not Throw

                    Assert-MockCalled -CommandName Invoke-Pester -Times 0 -Exactly -Scope It -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1" }
                    Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1" }
                } # End It DSCResources only

                It 'Should include DSCResources and DSCClassResources for CodeCoverage' {
                    Mock -CommandName Test-Path -MockWith { return $true } -ParameterFilter { $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources" }
                    Mock -CommandName Test-Path -MockWith { return $true } -ParameterFilter { $Path -and $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources" }

                    { Invoke-AppveyorTestScriptTask -CodeCoverage } | Should Not Throw

                    Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1" }
                    Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter { $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1" }
                } # End It Both DSCResources and DSCClassResources
            } # End Context When CodeCoverage requires additional directories
        } # End Describe AppVeyor\Invoke-AppveyorTestScriptTask
    } # End InModuleScope
}
finally
{
    if ($isAppVeyorBuildFolderSetByTest)
    {
        Remove-Item -Path 'env:\APPVEYOR_BUILD_FOLDER' -Force -ErrorAction SilentlyContinue
    }
}
