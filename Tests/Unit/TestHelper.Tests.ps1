$script:ModuleName = 'TestHelper'
$script:moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

Import-Module -Name (Join-Path -Path $script:moduleRootPath -ChildPath "$($script:ModuleName).psm1") -Force

InModuleScope $script:ModuleName {
    Describe 'TestHelper\Get-DscIntegrationTestOrderNumber' {
        BeforeAll {
            # Set up TestDrive
            $filePath_NoAttribute = Join-Path -Path $TestDrive -ChildPath 'NoAttribute.ps1'
            $filePath_WrongAttribute = Join-Path -Path $TestDrive -ChildPath 'WrongAttribute.ps1'
            $filePath_CorrectAttribute = Join-Path -Path $TestDrive -ChildPath 'CorrectAttribute.ps1'
            $filePath_CorrectAttributeWithExtraNamedArgument = Join-Path -Path $TestDrive -ChildPath 'CorrectAttributeWithExtraNamedArgument.ps1'

            '
            param()
            ' | Out-File -FilePath $filePath_NoAttribute

            '
            [Microsoft.DscResourceKit.IntegrationTest(UnknownParameter = 2)]
            param()
            ' | Out-File -FilePath $filePath_WrongAttribute

            '
            [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 2)]
            param()
            ' | Out-File -FilePath $filePath_CorrectAttribute

            '
            [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 2, UnknownParameter = ''Test'')]
            param()
            ' | Out-File -FilePath $filePath_CorrectAttributeWithExtraNamedArgument

        }

        Context 'When configuration file does not contain a attribute' {
            It 'Should not return any value' {
                $result = Get-DscIntegrationTestOrderNumber -Path $filePath_NoAttribute
                $result | Should -BeNullOrEmpty
            }
        }

        Context 'When configuration file contain a attribute but without the correct named attribute argument' {
            It 'Should not return any value' {
                $result = Get-DscIntegrationTestOrderNumber -Path $filePath_WrongAttribute
                $result | Should -BeNullOrEmpty
            }
        }

        Context 'When configuration file does contain an attribute and with the correct named attribute argument' {
            It 'Should not return any value' {
                $result = Get-DscIntegrationTestOrderNumber -Path $filePath_CorrectAttribute
                $result | Should -BeExactly 2
            }
        }

        Context 'When configuration file does contain an attribute and with the correct named attribute argument, and there is also another named argument' {
            It 'Should not return any value' {
                $result = Get-DscIntegrationTestOrderNumber -Path $filePath_CorrectAttributeWithExtraNamedArgument
                $result | Should -BeExactly 2
            }
        }
    }

    Describe 'TestHelper\Get-DscTestContainerInformation' {
        BeforeAll {
            $mockContainerImageName = 'Organization/ImageName:Tag'
            $mockContainerName = 'ContainerName'
        }

        Context 'When the test is an integration test' {
            BeforeAll {
                # Set up TestDrive
                $filePath_NoAttribute = Join-Path -Path $TestDrive -ChildPath 'NoAttribute.ps1'
                $filePath_WrongAttribute = Join-Path -Path $TestDrive -ChildPath 'WrongAttribute.ps1'
                $filePath_CorrectAttribute = Join-Path -Path $TestDrive -ChildPath 'CorrectAttribute.ps1'
                $filePath_CorrectAttributeOnlyContainerName = Join-Path -Path $TestDrive -ChildPath 'CorrectAttributeOnlyContainerName.ps1'
                $filePath_CorrectAttributeWithOrderNumber = Join-Path -Path $TestDrive -ChildPath 'CorrectAttributeWithOrderNumber.ps1'

                '
                param()
                ' | Out-File -FilePath $filePath_NoAttribute

                '
                [Microsoft.DscResourceKit.IntegrationTest(UnknownParameter = 2)]
                param()
                ' | Out-File -FilePath $filePath_WrongAttribute

                ('
                [Microsoft.DscResourceKit.IntegrationTest(ContainerName = ''{0}'')]
                param()
                ' -f $mockContainerName) | Out-File -FilePath $filePath_CorrectAttributeOnlyContainerName

                ('
                [Microsoft.DscResourceKit.IntegrationTest(ContainerName = ''{0}'', ContainerImage = ''{1}'')]
                param()
                ' -f $mockContainerName, $mockContainerImageName) | Out-File -FilePath $filePath_CorrectAttribute

                ('
                [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1, ContainerName = ''{0}'', ContainerImage = ''{1}'')]
                param()
                ' -f $mockContainerName, $mockContainerImageName) | Out-File -FilePath $filePath_CorrectAttributeWithOrderNumber
            }

            Context 'When configuration file does not contain the correct attribute' {
                It 'Should not return any value' {
                    $result = Get-DscTestContainerInformation -Path $filePath_NoAttribute
                    $result | Should -BeNullOrEmpty
                }
            }

            Context 'When configuration file contain a attribute but without the correct named attribute arguments' {
                It 'Should not return any value' {
                    $result = Get-DscTestContainerInformation -Path $filePath_WrongAttribute
                    $result | Should -BeNullOrEmpty
                }
            }

            Context 'When configuration file does contain a attribute and with only the correct named attribute argument ''ContainerName''' {
                It 'Should return the correct container name, and not return a container image name' {
                    $result = Get-DscTestContainerInformation -Path $filePath_CorrectAttributeOnlyContainerName
                    $result | Should -BeOfType [System.Collections.Hashtable]
                    $result.ContainerName | Should -Be $mockContainerName
                    $result.ContainerImage | Should -BeNullOrEmpty
                }
            }

            Context 'When configuration file does contain a attribute and with the correct named attribute arguments' {
                It 'Should return the correct container name and container image name' {
                    $result = Get-DscTestContainerInformation -Path $filePath_CorrectAttribute
                    $result | Should -BeOfType [System.Collections.Hashtable]
                    $result.ContainerName | Should -Be $mockContainerName
                    $result.ContainerImage | Should -Be $mockContainerImageName
                }
            }

            Context 'When configuration file contain more attributes than just the correct named attribute arguments' {
                It 'Should return the correct container name and container image name' {
                    $result = Get-DscTestContainerInformation -Path $filePath_CorrectAttributeWithOrderNumber
                    $result | Should -BeOfType [System.Collections.Hashtable]
                    $result.ContainerName | Should -Be $mockContainerName
                    $result.ContainerImage | Should -Be $mockContainerImageName
                }
            }
        }

        Context 'When the test is a unit tests' {
            BeforeAll {
                # Set up TestDrive
                $filePath_NoAttribute = Join-Path -Path $TestDrive -ChildPath 'NoAttribute.ps1'
                $filePath_WrongAttribute = Join-Path -Path $TestDrive -ChildPath 'WrongAttribute.ps1'
                $filePath_CorrectAttribute = Join-Path -Path $TestDrive -ChildPath 'CorrectAttribute.ps1'
                $filePath_CorrectAttributeOnlyContainerName = Join-Path -Path $TestDrive -ChildPath 'CorrectAttributeOnlyContainerName.ps1'

                '
                param()
                ' | Out-File -FilePath $filePath_NoAttribute

                '
                [Microsoft.DscResourceKit.UnitTest(UnknownParameter = 2)]
                param()
                ' | Out-File -FilePath $filePath_WrongAttribute

                ('
                [Microsoft.DscResourceKit.UnitTest(ContainerName = ''{0}'')]
                param()
                ' -f $mockContainerName) | Out-File -FilePath $filePath_CorrectAttributeOnlyContainerName

                ('
                [Microsoft.DscResourceKit.UnitTest(ContainerName = ''{0}'', ContainerImage = ''{1}'')]
                param()
                ' -f $mockContainerName, $mockContainerImageName) | Out-File -FilePath $filePath_CorrectAttribute
            }

            Context 'When configuration file does not contain the correct attribute' {
                It 'Should not return any value' {
                    $result = Get-DscTestContainerInformation -Path $filePath_NoAttribute
                    $result | Should -BeNullOrEmpty
                }
            }

            Context 'When configuration file contain a attribute but without the correct named attribute arguments' {
                It 'Should not return any value' {
                    $result = Get-DscTestContainerInformation -Path $filePath_WrongAttribute
                    $result | Should -BeNullOrEmpty
                }
            }

            Context 'When configuration file does contain a attribute and with only the correct named attribute argument ''ContainerName''' {
                It 'Should return the correct container name, and not return a container image name' {
                    $result = Get-DscTestContainerInformation -Path $filePath_CorrectAttributeOnlyContainerName
                    $result | Should -BeOfType [System.Collections.Hashtable]
                    $result.ContainerName | Should -Be $mockContainerName
                    $result.ContainerImage | Should -BeNullOrEmpty
                }
            }

            Context 'When configuration file does contain a attribute and with the correct named attribute arguments' {
                It 'Should return the correct container name and container image name' {
                    $result = Get-DscTestContainerInformation -Path $filePath_CorrectAttribute
                    $result | Should -BeOfType [System.Collections.Hashtable]
                    $result.ContainerName | Should -Be $mockContainerName
                    $result.ContainerImage | Should -Be $mockContainerImageName
                }
            }
        }
    }


    Describe 'TestHelper\Test-IsRepositoryDscResourceTests' {
        Context 'When the repository is DscResource.Tests' {
            BeforeAll {
                Mock -CommandName 'Split-Path'
                Mock -CommandName 'Get-ChildItem' -MockWith {
                    return $null
                }
            }

            It 'Should return $true' {
                Test-IsRepositoryDscResourceTests | Should -Be $true

                Assert-MockCalled -CommandName 'Split-Path' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Get-ChildItem' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When the repository is not DscResource.Tests' {
            BeforeAll {
                Mock -CommandName 'Split-Path'
                Mock -CommandName 'Get-ChildItem' -MockWith {
                    return 'manifest.psd1'
                }
            }

            It 'Should return $false' {
                Test-IsRepositoryDscResourceTests | Should -Be $false

                Assert-MockCalled -CommandName 'Split-Path' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Get-ChildItem' -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\Install-DependentModule' {
        Context 'When a dependent module need to be installed' {
            BeforeAll {
                # Only save the original value if the test is running in AppVeyor.
                if ($env:APPVEYOR -eq $true)
                {
                    $originalAppVeyorEnvironmentVariable = $env:APPVEYOR
                }

                Mock -CommandName 'Install-Module'
                Mock -CommandName 'Write-Warning'
                Mock -CommandName 'Get-Module' -MockWith {
                    return $false
                }
            }

            AfterAll {
                <#
                    if $originalAppVeyorEnvironmentVariable is null then we ran
                    this outside of AppVeyor
                #>
                if ($null -ne $originalAppVeyorEnvironmentVariable)
                {
                    <#
                        Restore the environment variable if the test are running
                        in AppVeyor.
                    #>
                    $env:APPVEYOR = $originalAppVeyorEnvironmentVariable
                }
                else
                {
                    <#
                        Remove the environment variable if we are running tests
                        outside of AppVeyor.
                    #>
                    Remove-Item env:APPVEYOR
                }
            }

            $moduleName1 = 'ModuleWithoutVersion'
            $moduleName2 = 'ModuleWithSpecificVersion'
            $moduleName3 = 'ModuleWhenTestIsNotRunInAppVeyor'

            $testCases = @(
                @{
                    MockModuleName = $moduleName1
                    MockModule     = @{
                        Name = $moduleName1
                    }
                    MockAppVeyor   = $true
                },
                @{
                    MockModuleName = $moduleName2
                    MockModule     = @{
                        Name    = $moduleName2
                        Version = '2.0.0.0'
                    }
                    MockAppVeyor   = $true
                },
                @{
                    MockModuleName = $moduleName3
                    MockModule     = @{
                        Name = $moduleName3
                    }
                    MockAppVeyor   = $false
                }
            )

            It 'Should install the dependent module ''<MockModuleName>'' without throwing' -TestCases $testCases {
                param
                (
                    # Name of the module being tests, for use in the It-block
                    [Parameter()]
                    [System.String]
                    $MockModuleName,

                    # Hash table containing the mock module
                    [Parameter()]
                    [System.Collections.HashTable]
                    $MockModule,

                    # Boolean value to mock environment variable $env:APPVEYOR
                    [Parameter()]
                    [System.Boolean]
                    $MockAppVeyor
                )

                if ($MockAppVeyor)
                {
                    $env:APPVEYOR = $true
                }
                else
                {
                    $env:APPVEYOR = $false
                }

                { Install-DependentModule -Module $MockModule } | Should -Not -Throw

                if ($MockAppVeyor)
                {
                    Assert-MockCalled -CommandName 'Get-Module' -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName 'Install-Module' -Exactly -Times 1 -Scope It
                }
                else
                {
                    Assert-MockCalled -CommandName 'Get-Module' -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName 'Write-Warning' -Exactly -Times 1 -Scope It
                }
            }
        }
    }

    Describe 'TestHelper\Get-ResourceModulesInConfiguration' {
        BeforeAll {
            $moduleName1 = 'ModuleWithoutVersion'
            $moduleName2 = 'ModuleWithSpecificVersion'
            $moduleVersion = '2.0.0.0'

            $arrayModuleName1 = 'ModuleNameArray1'
            $arrayModuleName2 = 'ModuleNameArray2'

            $scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestConfiguration.ps1'
        }

        Context 'When a script file requires a module' {
            It 'Should return the correct module name' {
                "
                    Configuration Test
                    {
                        Import-DscResource -ModuleName $moduleName1
                    }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Get-ResourceModulesInConfiguration -ConfigurationPath $scriptPath
                $result.Name | Should -Be $moduleName1
                $result.Version | Should -BeNullOrEmpty
            }
        }

        Context 'When a script file requires a module with specific version' {
            It 'Should return the correct module name and version' {
                "
                    Configuration Test
                    {
                        Import-DscResource -ModuleName $moduleName2 -ModuleVersion $moduleVersion
                    }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Get-ResourceModulesInConfiguration -ConfigurationPath $scriptPath
                $result.Name | Should -Be $moduleName2
                $result.Version | Should -Be $moduleVersion
            }
        }

        Context 'When a script file requires two modules' {
            It 'Should return the correct module names' {
                "
                    Configuration Test
                    {
                        Import-DscResource -ModuleName $moduleName1
                        Import-DscResource -ModuleName $moduleName2
                    }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Get-ResourceModulesInConfiguration -ConfigurationPath $scriptPath
                $result.Count | Should -Be 2
                $result[0].Name | Should -Be $moduleName1
                $result[0].Version | Should -BeNullOrEmpty
                $result[1].Name | Should -Be $moduleName2
                $result[1].Version | Should -BeNullOrEmpty
            }
        }

        Context 'When a script file requires two modules which are written in an string array' {
            It 'Should return the correct module name when using an array' {
                "
                    Configuration Test
                    {
                        Import-DscResource -ModuleName $arrayModuleName1,$arrayModuleName2
                    }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Get-ResourceModulesInConfiguration -ConfigurationPath $scriptPath
                $result.Count | Should -Be 2
                $result[0].Name | Should -Be $arrayModuleName1
                $result[0].Version | Should -BeNullOrEmpty
                $result[1].Name | Should -Be $arrayModuleName2
                $result[1].Version | Should -BeNullOrEmpty
            }
        }
    }

    Describe 'TestHelper\Get-RelativePathFromModuleRoot' {
        Context 'When to get the relative path from module root' {
            BeforeAll {
                $relativePath = 'Modules'
                $filePath = Join-Path $TestDrive -ChildPath $relativePath
                $moduleRootPath = $TestDrive

                # Adds a backslash to make sure it gets trimmed.
                $filePath += '\'
            }

            It 'Should return the correct relative path' {
                $result = Get-RelativePathFromModuleRoot `
                    -FilePath $filePath `
                    -ModuleRootFilePath $moduleRootPath

                $result | Should -Be $relativePath
            }
        }
    }

    Describe 'TestHelper\Test-FileHasByteOrderMark' {
        Context 'When a file has Byte Order Mark (BOM)' {
            BeforeAll {
                $fileName = 'TestByteOrderMark.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $fileName | Out-File -FilePath $filePath -Encoding utf8
            }

            It 'Should return $true' {
                $result = Test-FileHasByteOrderMark -FilePath $filePath
                $result | Should -Be $true
            }
        }

        Context 'When a file has no Byte Order Mark (BOM)' {
            BeforeAll {
                $fileName = 'TestNoByteOrderMark.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $fileName | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return $false' {
                $result = Test-FileHasByteOrderMark -FilePath $filePath
                $result | Should -Be $false
            }
        }
    }

    Describe 'TestHelper\Get-PSModulePathItem' {
        Context 'When querying for folder path' {
            It 'Should return the correct folder' {
                $systemModulePath = Join-Path `
                    -Path $env:SystemRoot `
                    -ChildPath 'system32\WindowsPowerShell\v1.0\Modules'

                Get-PSModulePathItem -Prefix $env:SystemRoot | Should -Be $systemModulePath
            }
        }

        Context 'When querying for a wrong path' {
            BeforeAll {
                Mock -CommandName 'Write-Error'
            }

            It 'Should write an error message the correct folder' {
                Get-PSModulePathItem -Prefix 'DummyPath' | Should -BeNullOrEmpty

                Assert-MockCalled -CommandName 'Write-Error' -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\Get-PSHomePSModulePathItem' {
        Context 'When querying for the modules folder path' {
            BeforeAll {
                $path = $TestDrive

                Mock -CommandName Get-PSModulePathItem -MockWith {
                    return $path
                }
            }

            It 'Should return the correct folder' {
                Get-PSHomePSModulePathItem | Should -Be $path
            }
        }
    }

    Describe 'TestHelper\Get-UserProfilePSModulePathItem' {
        Context 'When querying for the user profile modules folder path' {
            BeforeAll {
                $path = $TestDrive

                Mock -CommandName Get-PSModulePathItem -MockWith {
                    return $path
                }
            }

            It 'Should return the correct folder' {
                Get-UserProfilePSModulePathItem | Should -Be $path
            }
        }
    }

    <#
        The following helper functions are tested with these tests:

        Get-PesterDescribeOptInStatus
        Get-PesterDescribeName
        Get-CommandNameParameterValue
    #>
    $describeName = 'TestHelper\Get-PesterDescribeOptInStatus'
    Describe $describeName {
        Context 'When querying for the status of an opted-in test' {
            It 'Should return $true' {
                $result = Get-PesterDescribeOptInStatus -OptIns @($describeName)
                $result | Should -Be $true
            }
        }

        Context 'When querying for the status of an opted-out test' {
            It 'Should return $false' {
                $result = Get-PesterDescribeOptInStatus -OptIns @('Opt-Out')
                $result | Should -Be $false
            }
        }

        # Regression test for empty array (or null value).
        Context 'When querying for the status of an opted-in test, but there were no opt-ins read from .MetaTestOptIn.json' {
            It 'Should not throw an error' {
                Mock -Command Write-Warning

                { Get-PesterDescribeOptInStatus -OptIns @() } | Should -Not -Throw

                Assert-MockCalled -CommandName Write-Warning
            }
        }
    }

    Describe 'TestHelper\Get-OptInStatus' {
        Context 'When querying for the status of an opted-in test' {
            It 'Should return $true when querying for the it status of an opted-in test' {
                $result = Get-OptInStatus -OptIns @('Opt-In') -Name 'Opt-In'
                $result | Should -Be $true
            }
        }

        Context 'When querying for the status of an opted-out test' {
            It 'Should return $false when querying for the it of an opted-out test' {
                $result = Get-OptInStatus -OptIns @('Opt-Out') -Name 'Opt-In'
                $result | Should -Be $false
            }
        }

        # Regression test for empty array (or null value).
        Context 'When querying for the status of an opted-in test, but there were no opt-ins read from .MetaTestOptIn.json' {
            It 'Should not throw an error' {
                Mock -Command Write-Warning

                { Get-OptInStatus -OptIns @() -Name 'Opt-In' } | Should -Not -Throw

                Assert-MockCalled -CommandName Write-Warning
            }
        }
    }

    Describe 'TestHelper\Install-NuGetExe' {
        Context 'When downloading NuGet' {
            BeforeAll {
                Mock -CommandName 'Invoke-WebRequest'

                $mockDownloadUri = 'https://dist.nuget.org/win-x86-commandline'
            }

            It 'Should download NuGet, using default values, without throwing' {
                { Install-NuGetExe -OutFile $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Invoke-WebRequest' -ParameterFilter {
                    $Uri -eq ('{0}/{1}/{2}' -f $mockDownloadUri, 'v3.4.4', 'NuGet.exe')
                } -Exactly -Times 1 -Scope It
            }

            It 'Should download NuGet, using specific version, without throwing' {
                { Install-NuGetExe -OutFile $TestDrive -RequiredVersion '4.0.0' } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Invoke-WebRequest' -ParameterFilter {
                    $Uri -eq ('{0}/{1}/{2}' -f $mockDownloadUri, 'v4.0.0', 'NuGet.exe')
                } -Exactly -Times 1 -Scope It
            }

            It 'Should download NuGet, using specific uri, without throwing' {
                $mockDummyUri = 'https://dummyurl'
                { Install-NuGetExe -OutFile $TestDrive -Uri $mockDummyUri } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Invoke-WebRequest' -ParameterFilter {
                    $Uri -eq ('{0}/{1}/{2}' -f $mockDummyUri, 'v3.4.4', 'NuGet.exe')
                } -Exactly -Times 1 -Scope It
            }

            It 'Should download NuGet, using specific uri and specific version, without throwing' {
                $mockDummyUri = 'https://dummyurl'
                { Install-NuGetExe -OutFile $TestDrive -Uri $mockDummyUri -RequiredVersion '4.1.0' } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Invoke-WebRequest' -ParameterFilter {
                    $Uri -eq ('{0}/{1}/{2}' -f $mockDummyUri, 'v4.1.0', 'NuGet.exe')
                } -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\Get-SuppressedPSSARuleNameList' {
        BeforeAll {
            $rule1 = "'PSAvoidUsingConvertToSecureStringWithPlainText'"
            $rule2 = "'PSAvoidGlobalVars'"

            $scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }

        Context 'When a module files contains suppressed rules' {
            It 'Should return the all the suppressed rules' {
                "
                # Testing suppressing this rule
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute($rule1, '')]
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute($rule2, '')]
                param()
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Get-SuppressedPSSARuleNameList -FilePath $scriptPath
                $result.Count | Should -Be 4
                $result[0] | Should -Be $rule1
                $result[1] | Should -Be "''"
                $result[2] | Should -Be $rule2
                $result[3] | Should -Be "''"
            }
        }
    }

    Describe 'TestHelper\Get-ModuleScriptResourceNames' {
        BeforeAll {
            $resourceName1 = 'TestResource1'
            $resourceName2 = 'TestResource2'
            $resourcesPath = Join-Path -Path $TestDrive -ChildPath 'DscResources'
            $testResourcePath1 = (Join-Path -Path $resourcesPath -ChildPath $resourceName1)
            $testResourcePath2 = (Join-Path -Path $resourcesPath -ChildPath $resourceName2)

            New-Item -Path $resourcesPath -ItemType Directory
            New-Item -Path $testResourcePath1 -ItemType Directory
            New-Item -Path $testResourcePath2 -ItemType Directory

            'resource_schema1' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath1) -Encoding ascii
            'resource_schema2' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath2) -Encoding ascii
        }

        Context 'When a module contains resources' {
            It 'Should return all the resource names' {
                $result = Get-ModuleScriptResourceNames -ModulePath $TestDrive
                $result.Count | Should -Be 2
                $result[0] | Should -Be $resourceName1
                $result[1] | Should -Be $resourceName2
            }
        }
    }

    Describe 'TestHelper\Test-ModuleContainsScriptResource' {
        Context 'When a module contains script resources' {
            BeforeAll {
                $resourceName1 = 'TestResource1'
                $resourceName2 = 'TestResource2'
                $resourcesPath = Join-Path -Path $TestDrive -ChildPath 'DscResources'
                $testResourcePath1 = (Join-Path -Path $resourcesPath -ChildPath $resourceName1)
                $testResourcePath2 = (Join-Path -Path $resourcesPath -ChildPath $resourceName2)

                New-Item -Path $resourcesPath -ItemType Directory
                New-Item -Path $testResourcePath1 -ItemType Directory
                New-Item -Path $testResourcePath2 -ItemType Directory

                'resource_schema1' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath1) -Encoding ascii
                'resource_schema2' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath2) -Encoding ascii
            }

            It 'Should return $true' {
                $result = Test-ModuleContainsScriptResource -ModulePath $TestDrive
                $result | Should -Be $true
            }
        }

        Context 'When a module does not contain a script resource' {
            It 'Should return $false' {
                $result = Test-ModuleContainsScriptResource -ModulePath $TestDrive
                $result | Should -Be $false
            }
        }
    }

    Describe 'TestHelper\Test-FileInUnicode' {
        Context 'When a file is unicode' {
            BeforeAll {
                $fileName = 'TestUnicode.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $fileName | Out-File -FilePath $filePath -Encoding unicode
            }

            It 'Should return $true' {
                $result = Test-FileInUnicode -FileInfo $filePath
                $result | Should -Be $true
            }
        }

        Context 'When a file is not unicode' {
            BeforeAll {
                $fileName = 'TestNotUnicode.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $fileName | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return $false' {
                $result = Test-FileInUnicode -FileInfo $filePath
                $result | Should -Be $false
            }
        }
    }

    Describe 'TestHelper\Get-TextFilesList' {
        BeforeAll {
            $mofFileType = 'test.schema.mof'
            $psm1FileType = 'test.psm1'

            'resource_schema1' | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $mofFileType) -Encoding ascii
            'resource_schema2' | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $psm1FileType) -Encoding ascii
        }

        Context 'When a module contains text files' {
            It 'Should return all the file names of all the text files' {
                $result = Get-TextFilesList -Root $TestDrive
                $result.Count | Should -Be 2

                # Uncertain of returned order, so verify so each value is in the array.
                $result[0] | Should -BeIn @($mofFileType, $psm1FileType)
                $result[1] | Should -BeIn @($mofFileType, $psm1FileType)
            }
        }
    }

    Describe 'TestHelper\Get-Psm1FileList' {
        BeforeAll {
            $psm1FileType = 'test.psm1'
            $filePath = Join-Path -Path $TestDrive -ChildPath $psm1FileType
            'testfile' | Out-File -FilePath $filePath -Encoding ascii
        }

        Context 'When a module contains module files' {
            It 'Should return all the file names of all the module files' {
                $result = Get-Psm1FileList -FilePath $TestDrive
                $result.Name | Should -Be $psm1FileType
            }
        }
    }

    Describe 'TestHelper\Get-FileParseErrors' {
        BeforeAll {
            $filePath = (Join-Path -Path $TestDrive -ChildPath 'test.psm1')
        }

        Context 'When a module does not contain parse errors' {
            BeforeEach {
                'function MockTestFunction {}' | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return $null' {
                Get-FileParseErrors -FilePath $filePath | Should -BeNullOrEmpty
            }
        }

        Context 'When a module do contain parse errors' {
            BeforeEach {
                # The param() is deliberately spelled wrong to get a parse error.
                'function MockTestFunction { parm() }' | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return the correct error string' {
                Get-FileParseErrors -FilePath $filePath | Should -Match 'An expression was expected after ''\('''
            }
        }
    }

    Describe 'TestHelper\Test-ModuleContainsClassResource' {
        BeforeAll {
            $filePath = (Join-Path -Path $TestDrive -ChildPath 'test.psm1')
            'testfile' | Out-File -FilePath $filePath -Encoding ascii
        }

        Context 'When a module contains class resources' {
            BeforeEach {
                Mock -CommandName 'Test-FileContainsClassResource' -MockWith {
                    return $true
                }
            }

            It 'Should return $true' {
                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -Be $true

                Assert-MockCalled -CommandName 'Test-FileContainsClassResource' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a module does not contain a class resource' {
            BeforeEach {
                Mock -CommandName 'Test-FileContainsClassResource' -MockWith {
                    return $false
                }
            }

            It 'Should return $false' {
                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -Be $false

                Assert-MockCalled -CommandName 'Test-FileContainsClassResource' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a module does not contain any resources' {
            BeforeEach {
                Mock -CommandName 'Get-Psm1FileList'
                Mock -CommandName 'Test-FileContainsClassResource'
            }

            It 'Should return $false' {
                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -Be $false

                Assert-MockCalled -CommandName 'Get-Psm1FileList' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Test-FileContainsClassResource' -Exactly -Times 0 -Scope It
            }
        }
    }

    Describe 'TestHelper\Get-ClassResourceNameFromFile' {
        BeforeAll {
            $mockResourceName1 = 'TestResourceName1'
            $mockResourceName2 = 'TestResourceName2'

            $scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }

        Context 'When querying for the name of a class-based resource' {
            It 'Should return the correct name of the resource' {
                "
                [DscResource()]
                class $mockResourceName1
                {
                }

                [DscResource()]
                class $mockResourceName2
                {
                }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Get-ClassResourceNameFromFile -FilePath $scriptPath
                $result.Count | Should -Be 2
                $result[0] | Should -Be $mockResourceName1
                $result[1] | Should -Be $mockResourceName2
            }
        }
    }

    Describe 'TestHelper\Test-FileContainsClassResource' {
        BeforeAll {
            $mockResourceName1 = 'TestResourceName1'
            $mockResourceName2 = 'TestResourceName2'

            $scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }

        Context 'When module file contain class-based resources' {
            It 'Should return $true' {
                "
                [DscResource()]
                class $mockResourceName1
                {
                }

                [DscResource()]
                class $mockResourceName2
                {
                }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $scriptPath
                $result | Should -Be $true
            }
        }

        Context 'When module file does not contain class-based resources' {
            It 'Should return $false' {
                "
                function $mockResourceName1
                {
                }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $scriptPath
                $result | Should -Be $false
            }
        }
    }

    Describe 'TestHelper\Reset-Dsc' {
        BeforeAll {
            Mock -CommandName 'Stop-DscConfiguration'
            Mock -CommandName 'Remove-DscConfigurationDocument'
        }

        Context 'When resetting the DSC LCM' {
            It 'Should reset the LCM without throwing' {
                { Reset-Dsc } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Stop-DscConfiguration' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Remove-DscConfigurationDocument' -ParameterFilter {
                    $Stage -eq 'Current'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Remove-DscConfigurationDocument' -ParameterFilter {
                    $Stage -eq 'Pending'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Remove-DscConfigurationDocument' -ParameterFilter {
                    $Stage -eq 'Previous'
                } -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\Restore-TestEnvironment' {
        BeforeAll {
            Mock -CommandName 'Reset-DSC'
            Mock -CommandName 'Set-PSModulePath'
            Mock -CommandName 'Set-ExecutionPolicy'

            $testCases = @(
                @{
                    TestDescription = 'when restoring from a unit test'
                    TestEnvironment = @{
                        DSCModuleName      = 'TestModule'
                        DSCResourceName    = 'TestResource'
                        TestType           = 'Unit'
                        ImportedModulePath = $moduleToImportFilePath
                        OldPSModulePath    = $env:PSModulePath
                        OldExecutionPolicy = Get-ExecutionPolicy
                    }
                },

                @{
                    TestDescription = 'when restoring from an integration test'
                    TestEnvironment = @{
                        DSCModuleName      = 'TestModule'
                        DSCResourceName    = 'TestResource'
                        TestType           = 'Integration'
                        ImportedModulePath = $moduleToImportFilePath
                        OldPSModulePath    = $env:PSModulePath
                        OldExecutionPolicy = Get-ExecutionPolicy
                    }
                }
            )
        }

        Context 'When restoring the test environment' {
            It 'Should restore without throwing <TestDescription>' -TestCases $testCases {
                param
                (
                    # String containing a description to add to the It-block name
                    [Parameter()]
                    [System.String]
                    $TestDescription,

                    # Hash table containing the test environment
                    [Parameter()]
                    [System.Collections.HashTable]
                    $TestEnvironment
                )

                { Restore-TestEnvironment -TestEnvironment $TestEnvironment } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Set-PSModulePath' -Exactly -Times 0
            }
        }

        # Regression test for issue #70.
        Context 'When restoring the test environment from an integration test that changed the PSModulePath' {
            It 'Should restore without throwing and call the correct mocks' {
                $testEnvironmentParameter = @{
                    DSCModuleName      = 'TestModule'
                    DSCResourceName    = 'TestResource'
                    TestType           = 'Integration'
                    ImportedModulePath = $moduleToImportFilePath
                    OldPSModulePath    = 'Wrong paths'
                    OldExecutionPolicy = Get-ExecutionPolicy
                }

                { Restore-TestEnvironment -TestEnvironment $testEnvironmentParameter } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Reset-DSC' -Exactly -Times 1 -Scope It
                #Assert-MockCalled -CommandName 'Set-ExecutionPolicy' -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                    $Path -eq $testEnvironmentParameter.OldPSModulePath `
                        -and $PSBoundParameters.ContainsKey('Machine') -eq $false
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                    $Path -eq $testEnvironmentParameter.OldPSModulePath `
                        -and $PSBoundParameters.ContainsKey('Machine') -eq $true
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When restoring the test environment from an integration test that has the wrong execution policy' {
            BeforeAll {
                <#
                    Find out which execution policy should be used when mocking
                    the test parameters.
                #>
                if ((Get-ExecutionPolicy) -ne [Microsoft.PowerShell.ExecutionPolicy]::AllSigned )
                {
                    $mockExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::AllSigned
                }
                else
                {
                    $mockExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Unrestricted
                }
            }

            It 'Should restore without throwing' {
                $testEnvironmentParameter = @{
                    DSCModuleName      = 'TestModule'
                    DSCResourceName    = 'TestResource'
                    TestType           = 'Integration'
                    ImportedModulePath = $moduleToImportFilePath
                    OldPSModulePath    = $env:PSModulePath
                    OldExecutionPolicy = $mockExecutionPolicy
                }

                { Restore-TestEnvironment -TestEnvironment $testEnvironmentParameter } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Set-ExecutionPolicy' -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\Initialize-TestEnvironment' {
        Context 'When initializing the test environment' {
            BeforeAll {
                $mockDscModuleName = 'TestModule'
                $mockDscResourceName = 'TestResource'

                Mock -CommandName 'Set-PSModulePath'
                Mock -CommandName 'Reset-DSC'
                Mock -CommandName 'Set-ExecutionPolicy'
                Mock -CommandName 'Import-Module'

                Mock -CommandName 'Split-Path' -MockWith {
                    return $TestDrive
                }

                Mock -CommandName 'Get-ExecutionPolicy' -MockWith {
                    'Restricted'
                }

                <#
                    Build the mocked resource folder and file structure for both
                    mof- and class-based resources.
                #>
                $filePath = Join-Path -Path $TestDrive -ChildPath ('{0}.psd1' -f $mockDscModuleName)
                'test manifest' | Out-File -FilePath $filePath -Encoding ascii

                $mockDscResourcesPath = Join-Path -Path $TestDrive -ChildPath 'DSCResources'
                $mockDscClassResourcesPath = Join-Path -Path $TestDrive -ChildPath 'DSCClassResources'
                New-Item -Path $mockDscResourcesPath -ItemType Directory
                New-Item -Path $mockDscClassResourcesPath -ItemType Directory

                $mockMofResourcePath = Join-Path -Path $mockDscResourcesPath -ChildPath $mockDscResourceName
                $mockClassResourcePath = Join-Path -Path $mockDscClassResourcesPath -ChildPath $mockDscResourceName
                New-Item -Path $mockMofResourcePath -ItemType Directory
                New-Item -Path $mockClassResourcePath -ItemType Directory

                $filePath = Join-Path -Path $mockMofResourcePath -ChildPath ('{0}.psm1' -f $mockDscResourceName)
                'test mof resource module file' | Out-File -FilePath $filePath -Encoding ascii
                $filePath = Join-Path -Path $mockClassResourcePath -ChildPath ('{0}.psm1' -f $mockDscResourceName)
                'test class resource module file' | Out-File -FilePath $filePath -Encoding ascii

                $testCases = @(
                    @{
                        TestType     = 'Unit'
                        ResourceType = 'Mof'
                    },

                    @{
                        TestType     = 'Unit'
                        ResourceType = 'Class'
                    },

                    @{
                        TestType     = 'Integration'
                        ResourceType = 'Mof'
                    }
                )
            }

            It 'Should initializing without throwing when test type is <TestType> and resource type is <ResourceType>' -TestCases $testCases {
                param
                (
                    # String containing the test type; Unit or Integration.
                    [Parameter()]
                    [System.String]
                    $TestType,

                    # String containing a resource type; Mof or Class.
                    [Parameter()]
                    [System.String]
                    $ResourceType
                )

                $initializeTestEnvironmentParameters = @{
                    DSCModuleName   = $mockDscModuleName
                    DSCResourceName = $mockDscResourceName
                    TestType        = $TestType
                    ResourceType    = $ResourceType
                }

                { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Split-Path' -Exactly -Times 2 -Scope It
                Assert-MockCalled -CommandName 'Import-Module' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                    $PSBoundParameters.ContainsKey('Machine') -eq $false
                } -Exactly -Times 1 -Scope It

                if ($TestEnvironment.TestType -eq 'Integration')
                {
                    Assert-MockCalled -CommandName 'Reset-DSC' -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                        $PSBoundParameters.ContainsKey('Machine') -eq $true
                    } -Exactly -Times 1 -Scope It
                }

                Assert-MockCalled -CommandName 'Get-ExecutionPolicy' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Set-ExecutionPolicy' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When there is no module manifest file' {
            BeforeAll {
                Mock -CommandName 'Split-Path' -MockWith {
                    return $TestDrive
                }
            }

            It 'Should throw the correct error' {
                $initializeTestEnvironmentParameters = @{
                    DSCModuleName   = $mockDscModuleName
                    DSCResourceName = $mockDscResourceName
                    TestType        = 'Unit'
                }

                $errorMessage = 'Module manifest could not be found for the module {0} in the root folder {1}' -f $mockDscModuleName, $TestDrive
                { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Throw $errorMessage

                Assert-MockCalled -CommandName 'Split-Path' -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\Install-ModuleFromPowerShellGallery' {
        BeforeAll {
            <#
                A placeholder/wrapper for the nuget.exe so the code is tricked
                in thinking it exist, and so that we can mock it.
            #>
            function nuget.exe
            {
            }

            $mockModuleName = 'DummyTestModule'

            $installModuleFromPowerShellGalleryParameters = @{
                ModuleName      = $mockModuleName
                DestinationPath = $TestDrive
            }
        }

        Context 'When installing a module using NuGet' {
            It 'Should install using the Nuget.exe command'{
                $mockGetCommand = @{
                    Name = 'Nuget.exe'
                }

                Mock -CommandName 'Get-Command' -MockWith {
                    $mockGetCommand
                }
                Mock -CommandName 'Start-Process' -ParameterFilter {$FilePath -eq 'Nuget.exe'} -MockWith {@{ExitCode = 0}}

                { Install-ModuleFromPowerShellGallery @installModuleFromPowerShellGalleryParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Start-Process' -ParameterFilter {$FilePath -eq 'Nuget.exe'} -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Get-Command' -Exactly -Times 1 -Scope It
            }

            It 'Should use the temp Nuget path if Nuget.exe is in the temp directory' {
                $tempPath = Join-Path -Path $env:temp -ChildPath 'Nuget.exe'
                Mock -CommandName 'Get-Command'
                Mock -CommandName 'Start-Process' -ParameterFilter {
                    $FilePath -eq $tempNugetPath
                }  -MockWith {
                        @{ExitCode = 0}
                    }
                Mock -CommandName 'Test-Path' -MockWith {$true}

                { Install-ModuleFromPowerShellGallery @installModuleFromPowerShellGalleryParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Start-Process' -ParameterFilter {$FilePath -eq $tempPath} -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Get-Command' -Exactly -Times 1 -Scope It
            }

            It 'Should install Nuget.exe if it is not available' {
                $tempPath = Join-Path -Path $env:temp -ChildPath 'Nuget.exe'
                Mock -CommandName 'Get-Command'
                Mock -CommandName 'Start-Process' -ParameterFilter {$FilePath -eq $tempPath} -MockWith {@{ExitCode = 0}}
                Mock -CommandName 'Test-Path' -MockWith {$false}

                { Install-ModuleFromPowerShellGallery @installModuleFromPowerShellGalleryParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Start-Process' -ParameterFilter {$FilePath -eq $tempPath} -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Get-Command' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When failing to install a module using NuGet' {
            BeforeAll {
                <#
                    Mocking the nuget.exe but we are actually mocking the function
                    above. Using powershell.exe to set $LASTEXITCODE to 1.
                #>
                Mock -CommandName Start-Process -MockWith {@{ExitCode = 1}}
            }

            It 'Should throw the correct error' {
                $errorMessage = 'Installation of module {0} using Nuget failed with exit code {1}.' -f $mockModuleName, '1'
                { Install-ModuleFromPowerShellGallery @installModuleFromPowerShellGalleryParameters } | Should -Throw $errorMessage
            }
        }
    }

    Describe 'TestHelper\New-Nuspec' {
        Context 'When resetting the DSC LCM' {
            $mockDestinationPath = Join-Path -Path $TestDrive -ChildPath 'Package'

            BeforeAll {
                $mockPackageName = 'TestPackage'
                $mockVersion = '2.0.0.0'
                $mockAuthor = 'AutomaticUnitTest'
                $mockOwners = 'Microsoft'
                $mockDestinationPath = $mockDestinationPath
                $mockLicenseUrl = 'https://testlicense'
                $mockProjectUrl = 'https://testproject'
                $mockIconUrl = 'https://testicon'
                $mockPackageDescription = 'Test description'
                $mockReleaseNotes = 'Test release notes'
                $mockTags = 'DSCResource Tag'
            }

            It 'Should reset the LCM without throwing' {
                $newNuspecParameters = @{
                    PackageName        = $mockPackageName
                    Version            = $mockVersion
                    Author             = $mockAuthor
                    Owners             = $mockOwners
                    DestinationPath    = $mockDestinationPath
                    LicenseUrl         = $mockLicenseUrl
                    ProjectUrl         = $mockProjectUrl
                    IconUrl            = $mockIconUrl
                    PackageDescription = $mockPackageDescription
                    ReleaseNotes       = $mockReleaseNotes
                    Tags               = $mockTags
                }

                { New-Nuspec @newNuspecParameters } | Should -Not -Throw

                $testFilePath = (Join-Path -Path $mockDestinationPath -ChildPath ('{0}.nuspec' -f $mockPackageName))
                $testFilePath | Should -FileContentMatchExactly ('<id>{0}</id>' -f $mockPackageName)
                $testFilePath | Should -FileContentMatchExactly ('<version>{0}</version>' -f $mockVersion)
                $testFilePath | Should -FileContentMatchExactly ('<authors>{0}</authors>' -f $mockAuthor)
                $testFilePath | Should -FileContentMatchExactly ('<owners>{0}</owners>' -f $mockOwners)
                $testFilePath | Should -FileContentMatchExactly ('<licenseUrl>{0}</licenseUrl>' -f $mockLicenseUrl)
                $testFilePath | Should -FileContentMatchExactly ('<projectUrl>{0}</projectUrl>' -f $mockProjectUrl)
                $testFilePath | Should -FileContentMatchExactly ('<iconUrl>{0}</iconUrl>' -f $mockIconUrl)
                $testFilePath | Should -FileContentMatchExactly ('<description>{0}</description>' -f $mockPackageDescription)
                $testFilePath | Should -FileContentMatchExactly ('<releaseNotes>{0}</releaseNotes>' -f $mockReleaseNotes)
                $testFilePath | Should -FileContentMatchExactly ('<tags>{0}</tags>' -f $mockTags)
                $testFilePath | Should -FileContentMatchExactly '<requireLicenseAcceptance>true</requireLicenseAcceptance>'
                $testFilePath | Should -FileContentMatchExactly ('<copyright>Copyright {0}</copyright>' -f (Get-Date).Year)
            }
        }
    }

    Describe 'TestHelper\Get-LocalizedData' {
        $mockTestPath = {
            return $mockTestPathReturnValue
        }

        $mockImportLocalizedData = {
            $BaseDirectory | Should -Be $mockExpectedLanguagePath
        }

        BeforeEach {
            Mock -CommandName 'Test-Path' -MockWith $mockTestPath -Verifiable
            Mock -CommandName 'Import-LocalizedData' -MockWith $mockImportLocalizedData -Verifiable
        }

        Context 'When loading localized data for Swedish' {
            $mockExpectedLanguagePath = 'sv-SE'
            $mockTestPathReturnValue = $true

            It 'Should call Import-LocalizedData with sv-SE language' {
                Mock -CommandName 'Join-Path' -MockWith {
                    return 'sv-SE'
                } -Verifiable

                { Get-LocalizedData -ModuleName 'DummyResource' -ModuleRoot $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Join-Path' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Test-Path' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Import-LocalizedData' -Exactly -Times 1 -Scope It
            }

            $mockExpectedLanguagePath = 'en-US'
            $mockTestPathReturnValue = $false

            It 'Should call Import-LocalizedData and fallback to en-US if sv-SE language does not exist' {
                Mock -CommandName 'Join-Path' -MockWith {
                    return $ChildPath
                } -Verifiable

                { Get-LocalizedData -ModuleName 'DummyResource' -ModuleRoot $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Join-Path' -Exactly -Times 2 -Scope It
                Assert-MockCalled -CommandName 'Test-Path' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Import-LocalizedData' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When loading localized data for English' {
            Mock -CommandName 'Join-Path' -MockWith {
                return 'en-US'
            } -Verifiable

            $mockExpectedLanguagePath = 'en-US'
            $mockTestPathReturnValue = $true

            It 'Should call Import-LocalizedData with en-US language' {
                { Get-LocalizedData -ModuleName 'DummyResource' -ModuleRoot $TestDrive } | Should -Not -Throw
            }
        }

        Assert-VerifiableMock
    }

    Describe 'TestHelper\Write-Info' {
        Context 'When writing a message to console' {
            BeforeAll {
                $testMessageText = 'UnitTestTestMessage'

                Mock -CommandName 'Write-Information' -ParameterFilter {
                    $Messagedata -match $testMessageText
                }
            }

            It 'Should call the correct Cmdlets and not throw' {
                { Write-Info -Message $testMessageText -ForegroundColor 'Red' } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Write-Information' -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\Get-PublishFileName' {
        Context 'When filename starts with a numeric value followed by a slash (-)' {
            BeforeAll {
                $mockName = 'MyFile'
                $mockPath = Join-Path -Path $TestDrive -ChildPath "99-$mockName.ps1"
                New-Item -Path $mockPath -ItemType File -Force
            }

            It 'Should return the correct name' {
                $getPublishFileNameResult = Get-PublishFileName -Path $mockPath
                $getPublishFileNameResult | Should -Be $mockName
            }
        }

        Context 'When filename does not start with a numeric value followed by a slash (-)' {
            BeforeAll {
                $mockName = 'MyFile'
                $mockPath = Join-Path -Path $TestDrive -ChildPath "$mockName.ps1"
                New-Item -Path $mockPath -ItemType File -Force
            }

            It 'Should return the correct name' {
                $getPublishFileNameResult = Get-PublishFileName -Path $mockPath
                $getPublishFileNameResult | Should -Be $mockName
            }
        }
    }

    Describe 'TestHelper\Copy-ResourceModuleToPSModulePath' {
        Context 'When a module is copied' {
            BeforeAll {
                Mock -CommandName New-Item
                Mock -CommandName Copy-Item
            }

            It 'Should call the correct mocks' {
                { Copy-ResourceModuleToPSModulePath -ResourceModuleName 'a' -ModuleRootPath $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName New-Item -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Copy-Item -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'TestHelper\New-DscSelfSignedCertificate' {
        BeforeAll {
            $mockCertificateDNSNames = @('TestDscEncryptionCert')
            $mockCertificateKeyUsage = @('KeyEncipherment', 'DataEncipherment')
            $mockCertificateEKU = @('Document Encryption')
            $mockCertificateSubject = 'TestDscEncryptionCert'
            $mockCertificateFriendlyName = 'TestDscEncryptionCert'
            $mockCertificateThumbprint = '1111111111111111111111111111111111111111'

            $validCertificate = New-Object -TypeName PSObject -Property @{
                Thumbprint        = $mockCertificateThumbprint
                Subject           = "CN=$mockCertificateSubject"
                Issuer            = "CN=$mockCertificateSubject"
                FriendlyName      = $mockCertificateFriendlyName
                DnsNameList       = @(
                    @{ Unicode = $mockCertificateDNSNames[0] }
                )
                Extensions        = @(
                    @{ EnhancedKeyUsages = ($mockCertificateKeyUsage -join ', ') }
                )
                EnhancedKeyUsages = @(
                    @{ FriendlyName = $mockCertificateEKU[0] }
                    @{ FriendlyName = $mockCertificateEKU[1] }
                )
                NotBefore         = (Get-Date).AddDays(-30) # Issued on
                NotAfter          = (Get-Date).AddDays(31) # Expires after
            }

            <#
                This stub is needed because the real Export-Certificate's $cert
                parameter requires an actual [X509Certificate2] object.
            #>
            function Export-Certificate
            {
            }
        }

        Context 'When creating a self-signed certificate for Windows Server 2012 R2' {
            BeforeAll {
                <#
                    Stub to have something to mock on since we can't wait for
                    the Expand-Archive to create the stub that is dot-sourced
                    on runtime.
                #>
                function New-SelfSignedCertificateEx
                {
                }

                Mock -CommandName Get-ChildItem
                Mock -CommandName Get-Command
                Mock -CommandName Install-Module
                Mock -CommandName Import-Module
                Mock -CommandName Export-Certificate
                Mock -CommandName Set-EnvironmentVariable
                Mock -CommandName New-SelfSignedCertificateEx -MockWith {
                    return $validCertificate
                }
            }

            It 'Should return a certificate and call the correct mocks' {
                $result = New-DscSelfSignedCertificate
                $result.Thumbprint | Should -Be $mockCertificateThumbprint
                $result.Subject | Should -Be "CN=$mockCertificateSubject"

                Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1
                Assert-MockCalled -CommandName Get-Command -Exactly -Times 1
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Import-Module -Exactly -Times 1
                Assert-MockCalled -CommandName New-SelfSignedCertificateEx -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscPublicCertificatePath' `
                        -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
                } -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscCertificateThumbprint' `
                        -and $Value -eq $mockCertificateThumbprint
                } -Exactly -Times 1
            }
        }

        Context 'When creating a self-signed certificate for Windows Server 2016' {
            BeforeAll {
                <#
                    Stub is needed if tests is run on operating system older
                    than Windows 10 and Windows Server 2016.
                #>
                function New-SelfSignedCertificate
                {
                }

                Mock -CommandName Get-ChildItem
                Mock -CommandName Get-Command -MockWith {
                    return @{
                        Parameters = @{
                            Keys = @('Type')
                        }
                    }
                }

                Mock -CommandName Export-Certificate
                Mock -CommandName Set-EnvironmentVariable
                Mock -CommandName New-SelfSignedCertificate -MockWith {
                    return $validCertificate
                }
            }

            It 'Should return a certificate and call the correct cmdlets' {
                $result = New-DscSelfSignedCertificate
                $result.Thumbprint | Should -Be $mockCertificateThumbprint
                $result.Subject | Should -Be "CN=$mockCertificateSubject"

                Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1
                Assert-MockCalled -CommandName Get-Command -Exactly -Times 1
                Assert-MockCalled -CommandName New-SelfSignedCertificate -Exactly -Times 1
                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscPublicCertificatePath' `
                        -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
                } -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscCertificateThumbprint' `
                        -and $Value -eq $mockCertificateThumbprint
                } -Exactly -Times 1
            }
        }

        Context 'When a self-signed certificate already exists' {
            BeforeAll {
                Mock -CommandName Get-ChildItem -MockWith {
                    return $validCertificate
                }

                <#
                    Stub to have something to mock on since we can't wait for
                    the Expand-Archive to create the stub that is dot-sourced
                    on runtime.
                #>
                function New-SelfSignedCertificateEx
                {
                }

                Mock -CommandName New-SelfSignedCertificateEx
                Mock -CommandName New-SelfSignedCertificate
                Mock -CommandName Set-EnvironmentVariable
                Mock -CommandName Install-Module
                Mock -CommandName Import-Module
                Mock -CommandName Export-Certificate
            }

            It 'Should return a certificate and call the correct cmdlets' {
                $result = New-DscSelfSignedCertificate
                $result.Thumbprint | Should -Be $mockCertificateThumbprint
                $result.Subject | Should -Be "CN=$mockCertificateSubject"

                Assert-MockCalled -CommandName New-SelfSignedCertificate -Exactly -Times 0
                Assert-MockCalled -CommandName New-SelfSignedCertificateEx -Exactly -Times 0
                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscPublicCertificatePath' `
                        -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
                } -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscCertificateThumbprint' `
                        -and $Value -eq $mockCertificateThumbprint
                } -Exactly -Times 1
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                Assert-MockCalled -CommandName Import-Module -Exactly -Times 0
                Assert-MockCalled -CommandName Export-Certificate -Exactly -Times 1
            }
        }
    }

    Describe 'TestHelper\Initialize-LocalConfigurationManager' {
        BeforeAll {
            Mock -CommandName New-Item
            Mock -CommandName Remove-Item
            Mock -CommandName Invoke-Command
            Mock -CommandName Set-DscLocalConfigurationManager

            # Stub of the generated configuration so it can be mocked.
            function LocalConfigurationManagerConfiguration
            {
            }

            Mock -CommandName LocalConfigurationManagerConfiguration
        }

        Context 'When Local Configuration Manager should have consistency disabled' {
            BeforeAll {
                $expectedConfigurationMetadata = '
                    Configuration LocalConfigurationManagerConfiguration
                    {
                        LocalConfigurationManager
                        {
                            ConfigurationMode = ''ApplyOnly''
                        }
                    }
                '

                # Truncating everything to one line so easier to compare.
                $expectedConfigurationMetadataOneLine = $expectedConfigurationMetadata -replace '[ \r\n]'
            }

            It 'Should call Invoke-Command with the correct configuration' {
                { Initialize-LocalConfigurationManager -DisableConsistency } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
                } -Exactly -Times 1
                Assert-MockCalled -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1
            }
        }

        Context 'When Local Configuration Manager should have consistency disabled' {
            BeforeAll {
                $env:DscCertificateThumbprint = '1111111111111111111111111111111111111111'

                $expectedConfigurationMetadata = "
                    Configuration LocalConfigurationManagerConfiguration
                    {
                        LocalConfigurationManager
                        {
                            CertificateId = '$($env:DscCertificateThumbprint)'
                        }
                    }
                "

                # Truncating everything to one line so easier to compare.
                $expectedConfigurationMetadataOneLine = $expectedConfigurationMetadata -replace '[ \r\n]'
            }

            AfterAll {
                Remove-Item -Path 'env:DscCertificateThumbprint' -Force
            }

            It 'Should call Invoke-Command with the correct configuration' {
                { Initialize-LocalConfigurationManager -Encrypt } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
                } -Exactly -Times 1
                Assert-MockCalled -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1
            }
        }
    }

    Describe 'TestHelper\Write-PsScriptAnalyzerWarning' {
        Context 'When writing a PsScriptAnalyzer warning' {
            BeforeAll {
                $testPssaRuleOutput = [PSCustomObject]@{
                    Line   = '51'
                    Message  = 'Test Message'
                    RuleName = 'TestRule'
                    ScriptName = 'Pester.ps1'
                }
                $testRuleType = 'Test'

                Mock -CommandName 'Write-Warning'
            }

            It 'Should call the correct Cmdlets and not throw' {
                { Write-PsScriptAnalyzerWarning -PssaRuleOutput $testPssaRuleOutput -RuleType $testRuleType } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Write-Warning' -ParameterFilter {
                    $message -eq "The following PSScriptAnalyzer rule '$($testPssaRuleOutput.RuleName)' errors need to be fixed:"
                } -Exactly -Times 1
                Assert-MockCalled -CommandName 'Write-Warning' -ParameterFilter {
                    $message -eq "$($testPssaRuleOutput.ScriptName) (Line $($testPssaRuleOutput.Line)): $($testPssaRuleOutput.Message)"
                } -Exactly -Times 1
                Assert-MockCalled -CommandName 'Write-Warning' -ParameterFilter {
                    $message -eq "$testRuleType PSSA rule(s) did not pass."
                } -Exactly -Times 1
            }
        }
    }
}
