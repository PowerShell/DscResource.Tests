$script:ModuleName = 'AppVeyor'
$script:moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

Import-Module -Name (Join-Path -Path $script:moduleRootPath -ChildPath "$($script:ModuleName).psm1") -Force

InModuleScope $script:ModuleName {
    Describe 'AppVeyor\Invoke-AppveyorTestScriptTask' {
        BeforeAll {
            <#
                Mocking $env:APPVEYOR_BUILD_FOLDER to point to $TestDrive
                to be able to test relative path.
            #>
            $originalAppVeyorBuildFolder = $env:APPVEYOR_BUILD_FOLDER
            $env:APPVEYOR_BUILD_FOLDER = $TestDrive

            New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'Modules') -ItemType Directory -Force
            New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Integration') -ItemType Directory -Force
            New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Unit') -ItemType Directory -Force

            $mockModuleFolder = 'Modules'


            # Added functions that are specific to AppVeyor environment so mocks would not fail
            function Add-AppveyorTest
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
            Mock -CommandName New-DscSelfSignedCertificate
            Mock -CommandName Initialize-LocalConfigurationManager
            Mock -CommandName Write-Warning
            Mock -CommandName Write-Verbose
            Mock -CommandName Export-CodeCovIoJson -MockWith {
                return Join-Path -Path $TestDrive -ChildPath 'CodecovReport.json'
            }

            $mockMissedCommands = @(
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

            $mockHitCommands = @(
                [PSCustomObject] @{
                    File     = 'TestFile1'
                    Function = 'TestFunction1'
                    Line     = '2222'
                    Command  = 'Command3'
                }
            )

            $mockAnalyzedFiles = @(
                'TestFile1'
                'TestFile2'
            )

            $mockTestResult = @{
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
                    Add-Member -MemberType NoteProperty -Name 'MissedCommands' -Value $mockMissedCommands -PassThru |
                    Add-Member -MemberType NoteProperty -Name 'HitCommands' -Value $mockHitCommands -PassThru |
                    Add-Member -MemberType NoteProperty -Name 'AnalyzedFiles' -Value $mockAnalyzedFiles -PassThru -Force
            }
        }

        AfterAll {
            <#
                This will reset the APPVEYOR_BUILD_FOLDER or remove the environment
                variable if it was not set to begin with.
            #>
            $env:APPVEYOR_BUILD_FOLDER = $originalAppVeyorBuildFolder
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
                    that normally exists in the module TestHarness.psm1.
                #>
                function Invoke-TestHarness
                {
                    return [PSCustomObject] $mockTestResult
                }
            }

            It 'Should call the correct mocks' {
                $testParameters = @{
                    Type           = 'Harness'
                    MainModulePath = $mockModuleFolder
                    CodeCovIo      = $true
                }

                {
                    Invoke-AppveyorTestScriptTask @testParameters
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Add-AppveyorTest -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Push-TestArtifact -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Export-CodeCovIoJson -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Invoke-UploadCoveCoveIoReport -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Initialize-LocalConfigurationManager -Exactly -Times 1 -Scope It
            }
        }

        Context 'When there is no Tests folder' {
            BeforeAll {
                Mock -CommandName Copy-Item
                Mock -CommandName Remove-Item
                Mock -CommandName Import-Module -ParameterFilter {
                    $Name -match 'TestHarness\.psm1'
                }

                Mock -CommandName Test-Path -MockWith {
                    return $false
                }

                <#
                    This is a mock of the default harness function name
                    that normally exists in the module TestHarness.psm1.
                #>
                function Invoke-TestHarness
                {
                    return [PSCustomObject] $mockTestResult
                }
            }

            It 'Should call the correct mock and write a warning' {
                $testParameters = @{
                    Type           = 'Harness'
                    MainModulePath = $mockModuleFolder
                    CodeCovIo      = $true
                }

                {
                    Invoke-AppveyorTestScriptTask @testParameters
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                    $Message -eq 'The ''Tests'' folder is missing, the test framework will only run the common tests.'
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When CodeCoverage requires additional directories' {
            $pesterReturnedValues = @{
                PassedCount = 1
                FailedCount = 0
            }

            BeforeAll {
                Mock -CommandName Test-Path -MockWith {
                    return $true
                } -ParameterFilter {
                    $Path -eq (Join-Path -Path $TestDrive -ChildPath 'Tests')
                }

                Mock -CommandName Test-Path -MockWith {
                    return $false
                }

                Mock -CommandName Get-ChildItem -MockWith {
                    return 'file.Tests.ps1'
                }

                Mock -CommandName Get-ChildItem -MockWith {
                    return $null
                } -ParameterFilter {
                    $Include -eq '*.config.ps1'
                }

                Mock -CommandName Invoke-Pester -MockWith {
                    return $pesterReturnedValues
                }

                # Making sure there is no output when performing tests
                Mock -CommandName Test-IsRepositoryDscResourceTests -MockWith {
                    return $false
                }
            } # End BeforeAll

            AfterEach {
                Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -Scope It -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources"
                }

                Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -Scope It -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources"
                }

                Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -Scope It -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\Modules"
                }

                Assert-MockCalled -CommandName Get-ChildItem -Times 1 -Exactly -Scope It -ParameterFilter {
                    $Include -eq '*.config.ps1'
                }

                Assert-MockCalled -CommandName Get-ChildItem -Times 2 -Exactly -Scope It
            } # End AfterEach

            It 'Should only include DSCClassResources for CodeCoverage' {
                Mock -CommandName Test-Path -MockWith {
                    return $true
                } -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources"
                }

                Mock -CommandName Test-Path -MockWith {
                    return $false
                } -ParameterFilter {
                    $Path -and $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources"
                }

                {
                    Invoke-AppveyorTestScriptTask -CodeCoverage
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1"
                }

                Assert-MockCalled -CommandName Invoke-Pester -Times 0 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1"
                }
            } # End It DSCClassResources only

            It 'Should only include DSCResources for CodeCoverage' {
                Mock -CommandName Test-Path -MockWith {
                    return $false
                } -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources"
                }

                Mock -CommandName Test-Path -MockWith {
                    return $true
                } -ParameterFilter {
                    $Path -and $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources"
                }

                {
                    Invoke-AppveyorTestScriptTask -CodeCoverage
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Pester -Times 0 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1"
                }

                Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1"
                }
            } # End It DSCResources only

            It 'Should include DSCResources and DSCClassResources for CodeCoverage' {
                Mock -CommandName Test-Path -MockWith {
                    return $true
                } -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources"
                }

                Mock -CommandName Test-Path -MockWith {
                    return $true
                } -ParameterFilter {
                    $Path -and $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources"
                }

                {
                    Invoke-AppveyorTestScriptTask -CodeCoverage
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1"
                }

                Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1"
                }
            } # End It Both DSCResources and DSCClassResources

            It 'Should include all default paths for CodeCoverage' {
                Mock -CommandName Test-Path -MockWith {
                    return $true
                }

                {
                    Invoke-AppveyorTestScriptTask -CodeCoverage
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources\**\*.psm1" `
                    -and $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\DSCResources\**\*.psm1" `
                    -and $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\Modules\**\*.psm1"
                }
            } # End It Both DSCResources and DSCClassResources
        } # End Context When CodeCoverage requires additional directories

        Context 'When Invoke-AppveyorTestScriptTask is called with parameter CodeCoverage and CodeCoveragePath ' {
            $pesterReturnedValues = @{
                PassedCount = 1
                FailedCount = 0
            }

            BeforeAll {
                Mock -CommandName Test-Path -MockWith {
                    return $false
                }

                Mock -CommandName Get-ChildItem -MockWith {
                    return 'file.Tests.ps1'
                }

                Mock -CommandName Get-ChildItem -MockWith {
                    return $null
                } -ParameterFilter {
                    $Include -eq '*.config.ps1'
                }

                Mock -CommandName Invoke-Pester -MockWith {
                    return $pesterReturnedValues
                }

                # Making sure there is no output when performing tests
                Mock -CommandName Test-IsRepositoryDscResourceTests -MockWith {
                    return $false
                }
            } # End BeforeAll

            AfterEach {
                Assert-MockCalled -CommandName Test-Path -Times 0 -Exactly -Scope It -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCClassResources"
                }

                Assert-MockCalled -CommandName Test-Path -Times 0 -Exactly -Scope It -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\DSCResources"
                }

                Assert-MockCalled -CommandName Test-Path -Times 0 -Exactly -Scope It -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\Modules"
                }

                Assert-MockCalled -CommandName Test-Path -Times 1 -Exactly -Scope It -ParameterFilter {
                    $Path -eq "$env:APPVEYOR_BUILD_FOLDER\OtherPath"
                }

                Assert-MockCalled -CommandName Get-ChildItem -Times 1 -Exactly -Scope It -ParameterFilter {
                    $Include -eq '*.config.ps1'
                }

                Assert-MockCalled -CommandName Get-ChildItem -Times 2 -Exactly -Scope It
            } # End AfterEach

            It 'Should only include the correct specified path for CodeCoverage' {
                Mock -CommandName Test-Path -MockWith { return $true }

                {
                    Invoke-AppveyorTestScriptTask -CodeCoverage -CodeCoveragePath @('OtherPath')
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Pester -Times 1 -Exactly -Scope It -ParameterFilter {
                    $CodeCoverage -contains "$env:APPVEYOR_BUILD_FOLDER\OtherPath\**\*.psm1"
                }
            }
        } # End Context When CodeCoverage requires additional directories

        Context 'When called with model type as ''Default''' {
            BeforeAll {
                Mock -CommandName Write-Warning
                Mock -CommandName Invoke-Pester -MockWith {
                    return $mockTestResult
                }
            }

            AfterEach {
                Assert-MockCalled -CommandName Invoke-Pester -Exactly -Times 1 -Scope It
            }

            Context 'When called with default values' {
                It 'Should not throw exception and call the correct mocks' {
                    {
                        Invoke-AppveyorTestScriptTask
                    } | Should -Not -Throw

                    Assert-MockCalled -CommandName Add-AppveyorTest -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Push-TestArtifact -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Initialize-LocalConfigurationManager -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Export-CodeCovIoJson -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName Invoke-UploadCoveCoveIoReport -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName Write-Warning -Exactly -Times 0 -Scope It
                }

                Context 'When configuration needs a module to compile' {
                    BeforeAll {
                        New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Integration\MockResource1.config.ps1') -ItemType File -Force

                        Mock -CommandName Get-ResourceModulesInConfiguration -MockWith {
                            return @{
                                Name = 'MyModule'
                            }
                        }

                        Mock -CommandName Install-DependentModule
                    }

                    It 'Should not throw exception and call the correct mocks' {
                        {
                            Invoke-AppveyorTestScriptTask
                        } | Should -Not -Throw

                        Assert-MockCalled -CommandName Get-ResourceModulesInConfiguration -Exactly -Times 1 -Scope It
                        Assert-MockCalled -CommandName Install-DependentModule -Exactly -Times 1 -Scope It
                    }
                }
            }

            Context 'When called with the parameters CodeCoverage and CodeCovIo ' {
                It 'Should not throw exception and call the correct mocks' {
                    $testParameters = @{
                        CodeCoverage = $true
                        CodeCovIo    = $true
                    }

                    {
                        Invoke-AppveyorTestScriptTask @testParameters
                    } | Should -Not -Throw

                    Assert-MockCalled -CommandName Add-AppveyorTest -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Push-TestArtifact -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Export-CodeCovIoJson -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Invoke-UploadCoveCoveIoReport -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Initialize-LocalConfigurationManager -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Write-Warning -Exactly -Times 1 -Scope It
                }
            }

            Context 'When called with the parameters ExcludeTag' {
                It 'Should not throw exception and call the correct mocks' {
                    $testParameters = @{
                        ExcludeTag = @('Markdown')
                    }

                    {
                        Invoke-AppveyorTestScriptTask @testParameters
                    } | Should -Not -Throw

                    Assert-MockCalled -CommandName Add-AppveyorTest -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Push-TestArtifact -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Export-CodeCovIoJson -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName Invoke-UploadCoveCoveIoReport -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Initialize-LocalConfigurationManager -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Write-Warning -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName Invoke-Pester -ParameterFilter {
                        $ExcludeTag[0] -eq 'Markdown'
                    } -Exactly -Times 1
                }
            }

            Context 'When called with parameters RunTestInOrder' {
                BeforeAll {
                    '
                    [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1)]
                    param()
                    ' | Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Integration\MockResource1.Integration.Tests.ps1') -Encoding UTF8 -Force

                    '
                    [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 2)]
                    param()
                    ' | Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Integration\MockResource2.Integration.Tests.ps1') -Encoding UTF8 -Force
                }

                It 'Should not throw exception and call the correct mocks' {
                    $testParameters = @{
                        RunTestInOrder = $true
                    }

                    {
                        Invoke-AppveyorTestScriptTask @testParameters
                    } | Should -Not -Throw

                    Assert-MockCalled -CommandName Add-AppveyorTest -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Push-TestArtifact -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Export-CodeCovIoJson -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName Invoke-UploadCoveCoveIoReport -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Initialize-LocalConfigurationManager -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Write-Warning -Exactly -Times 0 -Scope It
                }
            }

            Context 'When called with parameters RunTestInOrder and CodeCoverage, and using containers' {
                BeforeAll {
                    # Mock the Meta.Tests.ps1 from DscResource.Tests.
                    New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'DSCResource.Tests\Meta.Tests.ps1') -ItemType File -Force

                    <#
                        Mock some empty resource module files. These files are
                        used by the tested code, to mock coverage.
                    #>
                    New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'MockResource1.psm1') -ItemType File -Force
                    New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'MockResource2.psm1') -ItemType File -Force

                    <#
                        Mock some resource integration and unit tests files.
                        Two containers are mocked, each container is running
                        one unit test, and one integration test.
                    #>
                    $containerName1 = 'Container1'
                    $containerIdentifier1 = 1111
                    $containerName2 = 'Container2'
                    $containerIdentifier2 = 2222

                    ('
                    [Microsoft.DscResourceKit.UnitTest(ContainerName = ''{0}'', ContainerImage = ''microsoft/windowsservercore'')]
                    param()
                    ' -f $containerName1) | Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Unit\MockResource1.Tests.ps1') -Encoding UTF8 -Force

                    ('
                    [Microsoft.DscResourceKit.UnitTest(ContainerName = ''{0}'', ContainerImage = ''microsoft/windowsservercore'')]
                    param()
                    ' -f $containerName2)| Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Unit\MockResource2.Tests.ps1') -Encoding UTF8 -Force

                    ('
                    [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1, ContainerName = ''{0}'', ContainerImage = ''microsoft/windowsservercore'')]
                    param()
                    ' -f $containerName1) | Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Integration\MockResource1.Integration.Tests.ps1') -Encoding UTF8 -Force

                    ('
                    [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 2, ContainerName = ''{0}'', ContainerImage = ''microsoft/windowsservercore'')]
                    param()
                    ' -f $containerName2) | Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'Tests\Integration\MockResource2.Integration.Tests.ps1') -Encoding UTF8 -Force

                    Mock -CommandName New-Container -MockWith {
                        return $containerIdentifier1
                    } -ParameterFilter {
                        $Name -eq $containerName1
                    }

                    Mock -CommandName New-Container -MockWith {
                        return $containerIdentifier2
                    } -ParameterFilter {
                        $Name -eq $containerName2
                    }

                    Mock -CommandName Start-Container
                    Mock -CommandName Get-ContainerLog
                    Mock -CommandName Copy-ItemFromContainer
                    Mock -CommandName Out-TestResult
                    Mock -CommandName Out-MissedCommand
                    Mock -CommandName Wait-Container -MockWith {
                        # Mock an error.
                        return 1
                    }

                    Mock -CommandName Get-Content -MockWith {
                        return ($mockTestResult | ConvertTo-Json)
                    }

                    Mock -CommandName ConvertFrom-Json -MockWith {
                        return $mockTestResult
                    }
                }

                It 'Should not throw exception and call the correct mocks' {
                    $testParameters = @{
                        CodeCoverage   = $true
                        CodeCovIo      = $true
                        RunTestInOrder = $true
                    }

                    {
                        Invoke-AppveyorTestScriptTask @testParameters
                    } | Should -Not -Throw

                    Assert-MockCalled -CommandName Add-AppveyorTest -Exactly -Times 3 -Scope It
                    Assert-MockCalled -CommandName Push-TestArtifact -Exactly -Times 9 -Scope It
                    Assert-MockCalled -CommandName Export-CodeCovIoJson -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Invoke-UploadCoveCoveIoReport -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Initialize-LocalConfigurationManager -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Write-Warning -Exactly -Times 5 -Scope It
                    Assert-MockCalled -CommandName Get-Content -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName Out-TestResult -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName Out-MissedCommand -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName New-Container -ParameterFilter {
                        $Name -eq $containerName1
                    } -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName New-Container -ParameterFilter {
                        $Name -eq $containerName2
                    } -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName Start-Container -ParameterFilter {
                        $ContainerIdentifier -eq $containerIdentifier1
                    } -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName Start-Container -ParameterFilter {
                        $ContainerIdentifier -eq $containerIdentifier2
                    } -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName Wait-Container -ParameterFilter {
                        $ContainerIdentifier -eq $containerIdentifier1
                    } -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName Wait-Container -ParameterFilter {
                        $ContainerIdentifier -eq $containerIdentifier2
                    } -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName Copy-ItemFromContainer -ParameterFilter {
                        $ContainerIdentifier -eq $containerIdentifier1
                    } -Exactly -Times 3 -Scope It

                    Assert-MockCalled -CommandName Copy-ItemFromContainer -ParameterFilter {
                        $ContainerIdentifier -eq $containerIdentifier2
                    } -Exactly -Times 3 -Scope It
                }

                Context 'When container reports an error' {
                    BeforeAll {
                        $errorMessage = 'MockError'

                        Mock -CommandName Get-ContainerLog -MockWith {
                            $invalidOperationException = New-Object -TypeName 'InvalidOperationException' -ArgumentList @( $errorMessage )
                            $newObjectParameters = @{
                                TypeName = 'System.Management.Automation.ErrorRecord'
                                ArgumentList = @(
                                    $invalidOperationException.ToString(),
                                    'MachineStateIncorrect',
                                    'InvalidOperation',
                                    $null
                                )
                            }

                            return @(
                                New-Object @newObjectParameters
                            )
                        }
                    }

                    It 'Should throw the correct error' {
                        $testParameters = @{
                            CodeCoverage   = $true
                            CodeCovIo      = $true
                            RunTestInOrder = $true
                        }

                        {
                            Invoke-AppveyorTestScriptTask @testParameters
                        } | Should -Throw $errorMessage

                    }
                }

                Context 'When container does not return any result' {
                    BeforeAll {
                        Mock -CommandName Get-Content
                    }

                    It 'Should throw the correct error' {
                        $testParameters = @{
                            CodeCoverage   = $true
                            CodeCovIo      = $true
                            RunTestInOrder = $true
                        }

                        {
                            Invoke-AppveyorTestScriptTask @testParameters
                        } | Should -Throw 'The container did not report any test result! This indicates that an error occurred in the container.'
                    }
                }
            }
        }
    } # End Describe AppVeyor\Invoke-AppveyorTestScriptTask

    Describe 'AppVeyor\Invoke-AppVeyorDeployTask' {
        BeforeAll {
            # Stub for the function so we don't need to import the module.
            function Start-GalleryDeploy
            {
            }

            function Publish-WikiContent
            {
            }

            Mock -CommandName Write-Info
            Mock -CommandName Start-GalleryDeploy
            Mock -CommandName Publish-WikiContent
            Mock -CommandName Import-Module -ParameterFilter {
                $Name -match 'DscResource\.GalleryDeploy'
            }
            Mock -CommandName Import-Module -ParameterFilter {
                $Name -match 'DscResource\.DocumentationHelper'
            }

            $mockBranchName = 'MockTestBranch'

            # Change build environment variables and remember the previous setting.
            $originalAppVeyorBuildFolder = $env:APPVEYOR_BUILD_FOLDER
            $oldAppVeyorRepoBranch = $env:APPVEYOR_REPO_BRANCH
            $env:APPVEYOR_BUILD_FOLDER = $TestDrive
            $env:APPVEYOR_REPO_BRANCH = $mockBranchName
        }

        AfterAll {
            <#
                This will reset the APPVEYOR_REPO_BRANCH or remove the environment
                variable if it was not set to begin with.
            #>
            $env:APPVEYOR_REPO_BRANCH = $oldAppVeyorRepoBranch

            <#
                This will reset the APPVEYOR_BUILD_FOLDER or remove the environment
                variable if it was not set to begin with.
            #>
            $env:APPVEYOR_BUILD_FOLDER = $originalAppVeyorBuildFolder
        }

        Context 'When not opt-in for publishing examples' {
            It 'Should not call Start-GalleryDeploy' {
                {
                    Invoke-AppVeyorDeployTask -OptIn @() -Branch $mockBranchName
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Import-Module -ParameterFilter {
                    $Name -match 'DscResource\.GalleryDeploy'
                } -Exactly -Times 0 -Scope It

                Assert-MockCalled -CommandName Start-GalleryDeploy -Exactly -Times 0 -Scope It
            }
        }

        Context 'When opt-in for publishing examples, but building on the wrong branch' {
            It 'Should not call Start-GalleryDeploy' {
                {
                    Invoke-AppVeyorDeployTask -OptIn @('PublishExample') -Branch 'WrongBranch'
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Import-Module -ParameterFilter {
                    $Name -match 'DscResource\.GalleryDeploy'
                } -Exactly -Times 0 -Scope It

                Assert-MockCalled -CommandName Start-GalleryDeploy -Exactly -Times 0 -Scope It
            }
        }

        Context 'When opt-in for publishing examples and building on the correct branch' {
            It 'Should call Start-GalleryDeploy' {
                {
                    Invoke-AppVeyorDeployTask -OptIn @('PublishExample') -Branch $mockBranchName
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Import-Module -ParameterFilter {
                    $Name -match 'DscResource\.GalleryDeploy'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName Start-GalleryDeploy -Exactly -Times 1 -Scope It
            }
        }

        Context 'When not opt-in for publishing Wiki Content' {
            It 'Should not call Publish-WikiContent' {
                {
                    Invoke-AppVeyorDeployTask -OptIn @() -Branch $mockBranchName
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Import-Module -ParameterFilter {
                    $Name -match 'DscResource\.DocumentationHelper'
                } -Exactly -Times 0 -Scope It

                Assert-MockCalled -CommandName Publish-WikiContent -Exactly -Times 0 -Scope It
            }
        }

        Context 'When opt-in for publishing Wiki Content, but building on the wrong branch' {
            It 'Should not call Publish-WikiContent' {
                {
                    Invoke-AppVeyorDeployTask -OptIn @('PublishWikiContent') -Branch 'WrongBranch'
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Import-Module -ParameterFilter {
                    $Name -match 'DscResource\.DocumentationHelper'
                } -Exactly -Times 0 -Scope It

                Assert-MockCalled -CommandName Publish-WikiContent -Exactly -Times 0 -Scope It
            }
        }

        Context 'When opt-in for publishing Wiki Content and building on the correct branch' {
            It 'Should call Publish-WikiContent' {
                {
                    Invoke-AppVeyorDeployTask -OptIn @('PublishWikiContent') -Branch $mockBranchName
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Import-Module -ParameterFilter {
                    $Name -match 'DscResource\.DocumentationHelper'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName Publish-WikiContent -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'AppVeyor\Invoke-AppveyorInstallTask' {
        BeforeAll {
            Mock -CommandName Write-Info
            Mock -CommandName Get-PackageProvider
            Mock -CommandName Install-Module
            Mock -CommandName Install-NugetExe
            Mock -CommandName New-DscSelfSignedCertificate
        }

        Context 'When installing tests prerequisites using default parameter values' {
            It 'Should call the correct mocks' {
                {
                    Invoke-AppveyorInstallTask
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Install-NugetExe -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName Install-Module -ParameterFilter {
                    $Name -eq 'PowerShellGet'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName Install-Module -ParameterFilter {
                    $Name -eq 'Pester' `
                    -and $PSBoundParameters.ContainsKey('MaximumVersion') -eq $false
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When installing tests prerequisites using specific Pester version' {
            BeforeEach {
                $mockPesterMaximumVersion = '1.0.0'
            }

            It 'Should call the correct mocks' {
                {
                    Invoke-AppveyorInstallTask -PesterMaximumVersion $mockPesterMaximumVersion
                } | Should -Not -Throw

                Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Install-NugetExe -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName Install-Module -ParameterFilter {
                    $Name -eq 'PowerShellGet'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName Install-Module -ParameterFilter {
                    $Name -eq 'Pester' `
                    -and $MaximumVersion -eq [Version] $mockPesterMaximumVersion
                } -Exactly -Times 1 -Scope It
            }
        }
    }
} # End InModuleScope
