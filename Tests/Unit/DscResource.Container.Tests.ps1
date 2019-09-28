$projectRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$moduleRootPath = Join-Path -Path $projectRootPath -ChildPath 'DscResource.Container'
$modulePath = Join-Path -Path $moduleRootPath -ChildPath 'DscResource.Container.psm1'

Import-Module -Name $modulePath -Force

InModuleScope -ModuleName 'DscResource.Container' {

    <#
        Dynamically built scriptblock which variables inside are sent in
        the BeforeEach-block before the It-block that is using them for
        Mocks.
    #>
    $mockDockerInspectName = {
        return 'ContainerName'
    }

    $mockDockerInspectName_ParameterFilter = {
        $args[0] -eq 'inspect' `
            -and $args[1] -eq $mockDynamicContainerIdentifer `
            -and $args[2] -eq '--format' `
            -and $args[3] -eq '{{.Name}}'
    }

    $mockDockerInspectState_ParameterFilter = {
        $args[0] -eq 'inspect' `
            -and $args[1] -eq $mockDynamicContainerIdentifer `
            -and $args[2] -eq '--format' `
            -and $args[3] -eq '{{.State.Running}}'
    }

    $mockDockerInspectExitCode_ParameterFilter = {
        $args[0] -eq 'inspect' `
            -and $args[1] -eq $mockDynamicContainerIdentifer `
            -and $args[2] -eq '--format' `
            -and $args[3] -eq '{{.State.ExitCode}}'
    }

    $mockDockerCpTo_ParameterFilter = {
        $args[0] -eq 'cp' `
            -and $args[1] -eq $mockDynamicLocalPath `
            -and $args[2] -eq ('{0}:{1}' -f $mockDynamicContainerIdentifer, $mockDynamicContainerPath)
    }

    $mockDockerCpFrom_ParameterFilter = {
        $args[0] -eq 'cp' `
            -and $args[1] -eq ('{0}:{1}' -f $mockDynamicContainerIdentifer, $mockDynamicContainerPath) `
            -and $args[2] -eq $mockDynamicLocalPath
    }

    $mockDockerLogs_ParameterFilter = {
        $args[0] -eq 'logs' `
            -and $args[1] -eq $mockDynamicContainerIdentifer
    }

    $mockDockerStart_ParameterFilter = {
        $args[0] -eq 'start' `
            -and $args[1] -eq $mockDynamicContainerIdentifer
    }

    $mockDockerImages_ParameterFilter = {
        $args[0] -eq 'images' `
            -and $args[1] -eq '--format' `
            -and $args[2] -eq '{{.Repository}}'
    }

    $mockDockerImagesWithTag_ParameterFilter = {
        $args[0] -eq 'images' `
            -and $args[1] -eq '--format' `
            -and $args[2] -eq '{{.Repository}}:{{.Tag}}'
    }

    $mockDockerPull_ParameterFilter = {
        $args[0] -eq 'pull' `
            -and $args[1] -eq $mockDynamicContainerImageName
    }

    $mockDockerCreate_ParameterFilter = {
        $args[0] -eq 'create' `
            -and $args[1] -eq '--name' `
            -and $args[2] -eq $mockDynamicContainerName `
            -and $args[3] -eq $mockDynamicContainerImageName `
            -and $args[4] -eq 'powershell.exe'
    }

    Describe 'DscResource.Container\Write-PesterItBlock' {
        BeforeAll {
            Mock -CommandName 'Write-Host'

            $testCases = @(
                @{
                    Result = 'Passed'
                    Name   = 'TestPassed'
                    Passed = $true
                },
                @{
                    Result = 'Skipped'
                    Name   = 'TestSkipped'
                    Passed = $true
                },
                @{
                    Result = 'Failed'
                    Name   = 'TestFailed'
                    Passed = $false
                }
            )
        }

        Context 'When outputting an It-block' {
            It 'Should call the correct mocks for a <Result> It-block' -TestCases $testCases {
                param
                (
                    $Result,
                    $Name,
                    $Passed
                )

                $mockTest = [PSCustomObject] @{
                    Result = $Result
                    Name   = $Name
                    Passed = $Passed
                }

                Mock -CommandName 'It' -ParameterFilter {
                    $Name -eq $mockTest.Name
                }

                { Write-PesterItBlock -TestResult $mockTest } | Should -Not -Throw

                $isSkipped = $false
                if ($mockTest.Result -eq 'Skipped')
                {
                    $isSkipped = $true
                }

                Assert-MockCalled -CommandName 'It' -ParameterFilter {
                    $Name -eq $mockTest.Name -and $Skip -eq $isSkipped
                } -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'DscResource.Container\Out-TestResult' {
        BeforeAll {
            Mock -CommandName 'Write-Host'
            Mock -CommandName 'Start-Sleep'
        }

        Context 'When outputting an test results' {
            BeforeAll {
                $mockTest = [PSCustomObject] @{
                    Describe = 'MockedDescribeName'
                    Passed   = $true
                    Result   = 'Passed'
                    Name     = 'TestPassed'
                }
            }

            It 'Should call the correct mocks for the Describe-block without throwing' {
                Mock -CommandName 'Describe' -ParameterFilter {
                    $Name -eq $mockTest.Describe
                }

                { Out-TestResult -TestResult $mockTest } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Describe' -ParameterFilter {
                    $Name -eq $mockTest.Describe
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When outputting only failed test results' {
            BeforeAll {
                $mockTest = [PSCustomObject] @{
                    Describe = 'MockedDescribeName'
                    Passed   = $false
                    Result   = 'Passed'
                    Name     = 'TestPassed'
                }
            }

            It 'Should call the correct mocks for the Describe-block without throwing' {
                Mock -CommandName 'Describe' -ParameterFilter {
                    $Name -eq $mockTest.Describe
                }

                { Out-TestResult -TestResult $mockTest -ShowOnlyFailed } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Describe' -ParameterFilter {
                    $Name -eq $mockTest.Describe
                } -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'DscResource.Container\Start-ContainerTest' {
        Context 'When start test for a container' {
            BeforeAll {
                Mock -CommandName 'Write-Info'
                Mock -CommandName 'Start-Transcript'
                Mock -CommandName 'Stop-Transcript'
                Mock -CommandName 'Install-PackageProvider'
                Mock -CommandName 'Install-Module'
                Mock -CommandName 'Out-File'
                Mock -CommandName 'Invoke-Pester' -MockWith {
                    @{
                        Passed = $true
                    }
                }
            }

            Context 'When code coverage is used' {
                It 'Should start container test without throwing' {
                    $startContainerTestParameters = @{
                        ContainerName = 'Dummy'
                        Path          = $TestDrive
                        TestPath      = Join-Path -Path $TestDrive -ChildPath 'Dummy.Tests.ps1'
                        CodeCoverage  = Join-Path -Path $TestDrive -ChildPath 'Dummy.ps1'
                    }

                    { Start-ContainerTest @startContainerTestParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName 'Start-Transcript' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Stop-Transcript' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Install-PackageProvider' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Install-Module' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Invoke-Pester' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Invoke-Pester' -Scope It -Exactly -Times 1
                }
            }

            Context 'When code coverage is not used' {
                It 'Should start container test without throwing' {
                    $startContainerTestParameters = @{
                        ContainerName = 'Dummy'
                        Path          = $TestDrive
                        TestPath      = Join-Path -Path $TestDrive -ChildPath 'Dummy.Tests.ps1'
                    }

                    { Start-ContainerTest @startContainerTestParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName 'Start-Transcript' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Stop-Transcript' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Install-PackageProvider' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Install-Module' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Invoke-Pester' -Scope It -Exactly -Times 1
                    Assert-MockCalled -CommandName 'Invoke-Pester' -Scope It -Exactly -Times 1
                }
            }
        }
    }

    Describe 'DscResource.Container\Out-MissedCommand' {
        BeforeAll {
            $mockMissedCommand = @(
                [PSCustomObject] @{
                    File     = '\TestFile1' # Extra backspace is a test.
                    Function = 'TestFunction1'
                    Line     = '9999'
                    Command  = 'Command1'
                },

                [PSCustomObject] @{
                    File     = '\TestFile2' # Extra backspace is a test.
                    Function = 'TestFunction2'
                    Line     = '8888'
                    Command  = 'Command2'
                }
            )

            $mockTestOutputStringMissedCommand1 = (
                '{0}\s*{1}\s*{2}\s*{3}' -f `
                ($mockMissedCommand[0].File -replace '\\'),
                $mockMissedCommand[0].Function,
                $mockMissedCommand[0].Line,
                $mockMissedCommand[0].Command
            )

            $mockTestOutputStringMissedCommand2 = (
                '{0}\s*{1}\s*{2}\s*{3}' -f `
                ($mockMissedCommand[1].File -replace '\\'),
                $mockMissedCommand[1].Function,
                $mockMissedCommand[1].Line,
                $mockMissedCommand[1].Command
            )

            Mock -CommandName 'Write-Output' -MockWith {
                if ($Inputobject -match $mockTestOutputStringMissedCommand1 `
                        -or $Inputobject -match $mockTestOutputStringMissedCommand2)
                {
                    $script:countNumberOfMissedCommandWritten += 1
                }
            }
        }

        BeforeEach {
            $script:countNumberOfMissedCommandWritten = 0
        }

        Context 'When test results contain missed commands' {
            It 'Should output the correct missed commands without throwing' {
                { Out-MissedCommand -MissedCommand $mockMissedCommand } | Should -Not -Throw

                $script:countNumberOfMissedCommandWritten | Should -Be 2
            }
        }

        Context 'When test results contain missed commands and wait for AppVeyor console' {
            BeforeAll {
                Mock -CommandName 'Start-Sleep'
            }

            It 'Should output the correct missed commands without throwing' {
                { Out-MissedCommand -MissedCommand $mockMissedCommand -WaitForAppVeyorConsole -Timeout 55 } | Should -Not -Throw

                $script:countNumberOfMissedCommandWritten | Should -Be 2

                Assert-MockCalled -CommandName 'Start-Sleep' -ParameterFilter {
                    $Seconds -eq 55
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When test results does not contain missed commands (an empty array or $null value)' {
            It 'Should output the correct missed commands without throwing' {
                { Out-MissedCommand -MissedCommand $null } | Should -Not -Throw

                $script:countNumberOfMissedCommandWritten | Should -Be 0

                Assert-MockCalled -CommandName 'Write-Output' -Exactly -Times 2
            }
        }
    }

    Describe 'DscResource.Container\Copy-ItemToContainer' {
        BeforeAll {
            Mock -CommandName 'Write-Info'

            <#
                A placeholder/wrapper for the docker.exe so the code is tricked
                in to thinking it exists so that we can mock it.
            #>
            function docker
            {
            }

            Mock -CommandName 'docker' -MockWith $mockDockerInspectName `
                -ParameterFilter $mockDockerInspectName_ParameterFilter

            Mock -CommandName 'docker' -ParameterFilter $mockDockerCpTo_ParameterFilter
        }

        AfterAll {
            Remove-Item -Path 'Function:\docker'
        }

        Context 'When copying item to a container' {
            BeforeAll {
                $mockIdentifier = '1A3'
                $mockPath = 'C:\'
                $mockDestination = 'D:\'

                $copyItemToContainerParameters = @{
                    ContainerIdentifier = $mockIdentifier
                    Path                = $mockPath
                    Destination         = $mockDestination
                }
            }

            BeforeEach {
                $mockDynamicContainerIdentifer = $mockIdentifier
                $mockDynamicLocalPath = $mockPath
                $mockDynamicContainerPath = $mockDestination
            }

            It 'Should copy the item without throwing' {
                { Copy-ItemToContainer @copyItemToContainerParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectName_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerCpTo_ParameterFilter -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'DscResource.Container\Copy-ItemFromContainer' {
        BeforeAll {
            Mock -CommandName 'Write-Info'

            <#
                A placeholder/wrapper for the docker.exe so the code is tricked
                in to thinking it exists so that we can mock it.
            #>
            function docker
            {
            }

            Mock -CommandName 'docker' -MockWith $mockDockerInspectName `
                -ParameterFilter $mockDockerInspectName_ParameterFilter

            Mock -CommandName 'docker' -ParameterFilter $mockDockerCpFrom_ParameterFilter
        }

        AfterAll {
            Remove-Item -Path 'Function:\docker'
        }

        Context 'When copying item from a container' {
            BeforeAll {
                $mockIdentifier = '1A3'
                $mockPath = 'D:\'
                $mockDestination = 'C:\'

                $copyItemToContainerParameters = @{
                    ContainerIdentifier = $mockIdentifier
                    Path                = $mockPath
                    Destination         = $mockDestination
                }
            }

            BeforeEach {
                $mockDynamicContainerIdentifer = $mockIdentifier
                $mockDynamicLocalPath = $mockDestination
                $mockDynamicContainerPath = $mockPath
            }

            It 'Should copy the item without throwing' {
                { Copy-ItemFromContainer @copyItemToContainerParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectName_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerCpFrom_ParameterFilter -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'DscResource.Container\Get-ContainerLog' {
        BeforeAll {
            Mock -CommandName 'Write-Info'

            <#
                A placeholder/wrapper for the docker.exe so the code is tricked
                in to thinking it exists so that we can mock it.
            #>
            function docker
            {
            }

            Mock -CommandName 'docker' -MockWith $mockDockerInspectName `
                -ParameterFilter $mockDockerInspectName_ParameterFilter

            Mock -CommandName 'docker' -MockWith {
                function New-ErrorRecord
                {
                    param
                    (
                        # Error message to return.
                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $Message
                    )

                    return Write-Error -Message $Message 2>&1
                }

                return @(
                    New-ErrorRecord -Message 'MockedError1'
                    New-ErrorRecord -Message 'MockedError2'
                )
            } -ParameterFilter $mockDockerLogs_ParameterFilter
        }

        AfterAll {
            Remove-Item -Path 'Function:\docker'
        }

        Context 'When gathering the logs from a container' {
            BeforeAll {
                $mockIdentifier = '1A3'
            }

            BeforeEach {
                $mockDynamicContainerIdentifer = $mockIdentifier
            }

            It 'Should fetch the logs without throwing' {
                { Get-ContainerLog -ContainerIdentifier $mockIdentifier } | Should -Not -Throw

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectName_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerLogs_ParameterFilter -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'DscResource.Container\Wait-Container' {
        BeforeAll {
            $exitCode = 1

            Mock -CommandName 'Write-Info'

            <#
                A placeholder/wrapper for the docker.exe so the code is tricked
                in to thinking it exists so that we can mock it.
            #>
            function docker
            {
            }

            Mock -CommandName 'docker' -MockWith $mockDockerInspectName `
                -ParameterFilter $mockDockerInspectName_ParameterFilter
        }

        AfterAll {
            Remove-Item -Path 'Function:\docker'
        }

        Context 'When wait for a container to stop' {
            BeforeAll {
                $mockIdentifier = '1A3'

                Mock -CommandName 'Start-Sleep'
                Mock -CommandName 'docker' -MockWith {
                    <#
                        On the second hit on the mock this must return 'true'
                        to be able to exit the do-until-loop.
                    #>
                    if ($script:dockerStateQueryHits -eq 0)
                    {
                        $script:dockerStateQueryHits += 1
                        return 'true'
                    }
                    else
                    {
                        return 'false'
                    }
                } -ParameterFilter $mockDockerInspectState_ParameterFilter


                Mock -CommandName 'docker' -MockWith {
                    return $exitCode
                } -ParameterFilter $mockDockerInspectExitCode_ParameterFilter
            }

            BeforeEach {
                $script:dockerStateQueryHits = 0
                $mockDynamicContainerIdentifer = $mockIdentifier
            }

            It 'Should wait for the container until it is stopped without throwing' {
                { Wait-Container -ContainerIdentifier $mockIdentifier } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Start-Sleep' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectName_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectState_ParameterFilter -Exactly -Times 2 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectExitCode_ParameterFilter -Exactly -Times 1 -Scope It
            }
        }

        Context 'When the container fails to stop within the timeout period' {
            BeforeAll {
                $mockIdentifier = '1A3'

                Mock -CommandName 'docker' -MockWith {
                    return 'true'
                } -ParameterFilter $mockDockerInspectState_ParameterFilter
            }

            BeforeEach {
                $mockDynamicContainerIdentifer = $mockIdentifier
            }

            It 'Should throw the correct error message' {
                $mockTimeout = 1
                $errorMessage = $localizedData.ContainerTimeout -f $mockTimeout

                { Wait-Container -ContainerIdentifier $mockIdentifier -Timeout $mockTimeout } | Should -Throw $errorMessage

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectName_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectState_ParameterFilter -Exactly -Times 2 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectExitCode_ParameterFilter -Exactly -Times 0 -Scope It
            }
        }

        Context 'When the container throws an error when waiting for container to stop' {
            BeforeAll {
                $mockIdentifier = '1A3'
                $errorMessage = 'Something went wrong in the mock of docker inspect'

                Mock -CommandName 'docker' -MockWith {
                    throw $errorMessage
                } -ParameterFilter $mockDockerInspectState_ParameterFilter
            }

            BeforeEach {
                $mockDynamicContainerIdentifer = $mockIdentifier
            }

            It 'Should throw the correct error message' {
                { Wait-Container -ContainerIdentifier $mockIdentifier } | Should -Throw $errorMessage

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectName_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectState_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectExitCode_ParameterFilter -Exactly -Times 0 -Scope It
            }
        }
    }

    Describe 'DscResource.Container\Start-Container' {
        BeforeAll {
            Mock -CommandName 'Write-Info'

            <#
                A placeholder/wrapper for the docker.exe so the code is tricked
                in to thinking it exists so that we can mock it.
            #>
            function docker
            {
            }

            Mock -CommandName 'docker' -MockWith $mockDockerInspectName `
                -ParameterFilter $mockDockerInspectName_ParameterFilter

            Mock -CommandName 'docker' -MockWith $mockDockerInspectName `
                -ParameterFilter $mockDockerStart_ParameterFilter
        }

        AfterAll {
            Remove-Item -Path 'Function:\docker'
        }

        Context 'When starting a container' {
            BeforeAll {
                $mockIdentifier = '1A3'
            }

            BeforeEach {
                $mockDynamicContainerIdentifer = $mockIdentifier
            }

            It 'Should start the container without throwing' {
                { Start-Container -ContainerIdentifier $mockIdentifier } | Should -Not -Throw

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerInspectName_ParameterFilter -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'docker' `
                    -ParameterFilter $mockDockerStart_ParameterFilter -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'DscResource.Container\New-Container' {
        BeforeAll {
            $mockIdentifier = '1A3'
            $mockName = 'TestContainer'
            $mockImageName = 'microsoft/windowsservercore'
            $mockImageNameWithTag = 'microsoft/windowsservercore:1709'
            $mockImageNameWithLatestTag = 'microsoft/windowsservercore:latest'
            $mockTestPath = @('C:\Test1.Tests.ps1', 'C:\Test2.Tests.ps1')
            $mockCodeCoverage = @('C:\Test1.psm1', 'C:\Test2.psm1')
        }

        Context 'When creating a new container' {
            BeforeAll {
                # The file name never be 'StartTest.ps1'.
                $mockStartFilePath = Join-Path -Path $TestDrive -ChildPath 'MockFile.ps1'

                Mock -CommandName 'Write-Info'
                Mock -CommandName 'Copy-ItemToContainer'

                Mock -CommandName 'Out-File' -MockWith {
                    $InputObject | Out-File $mockStartFilePath -Encoding ascii
                } -ParameterFilter {
                    $FilePath -match 'StartTest\.ps1'
                }

                <#
                    A placeholder/wrapper for the docker.exe so the code is tricked
                    in to thinking it exists so that we can mock it.
                #>
                function docker
                {
                }

                Mock -CommandName 'docker' -ParameterFilter $mockDockerPull_ParameterFilter

                Mock -CommandName 'docker' -MockWith {
                    return @('wrong images')
                } -ParameterFilter $mockDockerImages_ParameterFilter

                Mock -CommandName 'docker' -MockWith {
                    return @('wrong images')
                } -ParameterFilter $mockDockerImagesWithTag_ParameterFilter

                Mock -CommandName 'docker' -MockWith {
                    return $mockIdentifier
                } -ParameterFilter $mockDockerCreate_ParameterFilter
            }

            AfterAll {
                Remove-Item -Path 'Function:\docker'
            }

            Context 'When image does not contain a tag' {
                BeforeEach {
                    $mockDynamicContainerName = $mockName
                    $mockDynamicContainerImageName = $mockImageName
                }

                It 'Should create the container without throwing' {
                    $newContainerParameters = @{
                        Name         = $mockName
                        ImageName    = $mockImageName
                        TestPath     = $mockTestPath
                        ProjectPath  = $TestDrive
                        CodeCoverage = $mockCodeCoverage
                    }

                    { New-Container @newContainerParameters } | Should -Not -Throw
                    $mockStartFilePath | Should -Exist

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerImages_ParameterFilter -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerImagesWithTag_ParameterFilter -Exactly -Times 0 -Scope It

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerPull_ParameterFilter -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerCreate_ParameterFilter -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName 'Copy-ItemToContainer' -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName 'Out-File' -Exactly -Times 1 -Scope It
                }

                Context 'When the container image already exists' {
                    BeforeAll {
                        Mock -CommandName 'docker' -MockWith {
                            return @($mockImageName)
                        } -ParameterFilter $mockDockerImages_ParameterFilter
                    }

                    It 'Should not pull the container image' {
                        $newContainerParameters = @{
                            Name         = $mockName
                            ImageName    = $mockImageName
                            TestPath     = $mockTestPath
                            ProjectPath  = $TestDrive
                            CodeCoverage = $mockCodeCoverage
                        }

                        { New-Container @newContainerParameters } | Should -Not -Throw

                        Assert-MockCalled -CommandName 'docker' `
                            -ParameterFilter $mockDockerPull_ParameterFilter -Exactly -Times 0 -Scope It
                    }
                }
            }

            Context 'When image does not contain a tag' {
                BeforeEach {
                    $mockDynamicContainerName = $mockName
                    $mockDynamicContainerImageName = $mockImageNameWithTag
                }

                It 'Should create the container without throwing' {
                    $newContainerParameters = @{
                        Name         = $mockName
                        ImageName    = $mockImageNameWithTag
                        TestPath     = $mockTestPath
                        ProjectPath  = $TestDrive
                        CodeCoverage = $mockCodeCoverage
                    }

                    { New-Container @newContainerParameters } | Should -Not -Throw
                    $mockStartFilePath | Should -Exist

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerImages_ParameterFilter -Exactly -Times 0 -Scope It

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerImagesWithTag_ParameterFilter -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerPull_ParameterFilter -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerCreate_ParameterFilter -Exactly -Times 1 -Scope It

                    Assert-MockCalled -CommandName 'Copy-ItemToContainer' -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName 'Out-File' -Exactly -Times 1 -Scope It
                }

                Context 'When the container image already exists' {
                    BeforeAll {
                        Mock -CommandName 'docker' -MockWith {
                            return @($mockImageNameWithTag)
                        } -ParameterFilter $mockDockerImagesWithTag_ParameterFilter
                    }

                    It 'Should not pull the container image' {
                        $newContainerParameters = @{
                            Name         = $mockName
                            ImageName    = $mockImageNameWithTag
                            TestPath     = $mockTestPath
                            ProjectPath  = $TestDrive
                            CodeCoverage = $mockCodeCoverage
                        }

                        { New-Container @newContainerParameters } | Should -Not -Throw

                        Assert-MockCalled -CommandName 'docker' `
                            -ParameterFilter $mockDockerPull_ParameterFilter -Exactly -Times 0 -Scope It
                    }
                }
            }

            Context 'When the container image already exist, but the tag is ''latest''' {
                BeforeAll {
                    Mock -CommandName 'docker' -MockWith {
                        return @($mockImageNameWithLatestTag)
                    } -ParameterFilter $mockDockerImagesWithTag_ParameterFilter
                }

                BeforeEach {
                    $mockDynamicContainerName = $mockName
                    $mockDynamicContainerImageName = $mockImageNameWithLatestTag
                }

                It 'Should always pull the container image' {
                    $newContainerParameters = @{
                        Name         = $mockName
                        ImageName    = $mockImageNameWithLatestTag
                        TestPath     = $mockTestPath
                        ProjectPath  = $TestDrive
                        CodeCoverage = $mockCodeCoverage
                    }

                    { New-Container @newContainerParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName 'docker' `
                        -ParameterFilter $mockDockerPull_ParameterFilter -Exactly -Times 1 -Scope It
                }
            }
        }

        Context 'When Docker command does not exist' {
            BeforeAll {
                Mock -CommandName 'Get-Command' -MockWith {
                    return $false
                }
            }

            It 'Should throw the correct error' {
                $newContainerParameters = @{
                    Name         = $mockName
                    ImageName    = $mockImageName
                    TestPath     = $mockTestPath
                    ProjectPath  = $TestDrive
                    CodeCoverage = $mockCodeCoverage
                }

                $errorMessage = $script:localizedData.DockerIsNotAvailable

                { New-Container @newContainerParameters } | Should -Throw $errorMessage
            }
        }
    }
}
