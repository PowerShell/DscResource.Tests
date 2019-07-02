$projectRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$moduleRootPath = Join-Path -Path $projectRootPath -ChildPath 'DscResource.GalleryDeploy'
$modulePath = Join-Path -Path $moduleRootPath -ChildPath 'DscResource.GalleryDeploy.psm1'

Import-Module -Name $modulePath -Force

Import-Module -Name (Join-Path -Path (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'TestHelpers') -ChildPath 'CommonTestHelper.psm1') -Global

InModuleScope -ModuleName 'DscResource.GalleryDeploy' {
    Describe 'DscResource.GalleryDeploy\Start-GalleryDeploy' {
        BeforeAll {
            $mockGuid = 'bdec4a30-2ef5-4040-92b6-534da42ca447'
            $mockResourceModuleName = 'MyResourceModule'
            $mockModuleRootPath = Join-Path -Path $TestDrive -ChildPath 'MyRepository'
            $mockModulesExamplesPath = Join-Path -Path $mockModuleRootPath -ChildPath 'Examples'

            # This will create the full path in the test drive.
            New-Item -Path $mockModulesExamplesPath -ItemType Directory -Force

            $mockExampleValidationOptInValue = 'Common Tests - Validate Example Files'

            Mock -CommandName Install-DependentModule
            Mock -CommandName Copy-ResourceModuleToPSModulePath
            Mock -CommandName Copy-Item
            Mock -CommandName Remove-Item
            Mock -CommandName Write-Verbose -ParameterFilter {
                $Message -match 'Copying module from'
            }
        }

        Context 'When a repository has not opt-in for example validation' {
            BeforeAll {
                $env:gallery_api = 'dummyapi'

                Mock -CommandName Publish-Script
            }

            AfterAll {
                $env:gallery_api = $null
            }

            BeforeEach {
                Mock -CommandName Write-Warning
            }

            It 'Should call the correct mocks ' {
                $startGalleryDeployParameters = @{
                    ResourceModuleName = $mockResourceModuleName
                    Path               = $mockModulesExamplesPath
                    ModuleRootPath     = $mockModuleRootPath
                    Branch             = 'master'
                }

                { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                    $Message -eq ('{0} {1}' -f `
                            $script:localizedData.CannotPublish,
                        ($script:localizedData.MissingExampleValidationOptIn -f `
                                $mockExampleValidationOptInValue)
                    )
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When API key is missing' {
            BeforeEach {
                Mock -CommandName Write-Warning
            }

            It 'Should call the correct mocks ' {
                $startGalleryDeployParameters = @{
                    ResourceModuleName = $mockResourceModuleName
                    Path               = $mockModulesExamplesPath
                    ModuleRootPath     = $mockModuleRootPath
                    Branch             = 'master'
                }

                { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                    $Message -eq ('{0} {1}' -f $script:localizedData.CannotPublish, $script:localizedData.MissingApiKey)
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When the repository has opt-in for publishing and an example configuration should be published' {
            BeforeAll {
                $env:gallery_api = 'dummyapi'

                Mock -CommandName Publish-Script

                $metaTestOptInFileName = Join-Path -Path $mockModuleRootPath -ChildPath '.MetaTestOptIn.json'
                ('["{0}"]' -f $mockExampleValidationOptInValue) |
                    Out-File -FilePath $metaTestOptInFileName -Encoding utf8 -Force
            }

            AfterAll {
                $env:gallery_api = $null
            }

            Context 'When the example configuration name has a mismatch against filename' {
                BeforeAll {
                    Mock -CommandName Write-Warning

                    $mockExampleScriptPath = Join-Path -Path $mockModulesExamplesPath -ChildPath '99-WrongConfig.ps1'

                    $newScriptFileInfoParameters = @{
                        Path = $mockExampleScriptPath
                        Version = '1.0.0.0'
                        Guid = $mockGuid
                        Description = 'Test metadata'
                    }

                    New-ScriptFileInfo @newScriptFileInfoParameters

                    $definition = '
                        Configuration TestConfig
                        {
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath -Encoding utf8 -Force
                }

                It 'Should call the correct mocks' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                        $Message -eq ('{0} {1}' -f `
                            ($script:localizedData.SkipPublish -f $mockExampleScriptPath),
                            $script:localizedData.ConfigurationNameMismatch)
                    } -Exactly -Times 1 -Scope It
                }
            }

            Context 'When the example configuration has a problem with the script metadata' {
                BeforeAll {
                    Mock -CommandName Write-Warning

                    $mockExampleScriptPath = Join-Path -Path $mockModulesExamplesPath -ChildPath 'TestConfig.ps1'

                    $definition = '
                        Configuration TestConfig
                        {
                            # This tests that Install-DependentModule is called.
                            Import-DscResource -ModuleName MyMockModule
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath -Encoding utf8 -Force
                }

                It 'Should not call Publish-Script' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Publish-Script -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-DependentModule -Exactly -Times 1
                    Assert-MockCalled -CommandName Write-Warning -Exactly -Times 1
                }
            }

            Context 'When the example configuration is the same version as the one in the Gallery' {
                BeforeAll {
                    Mock -CommandName Find-Script -MockWith {
                        return @{
                            Version = '1.0.0.0'
                        }
                    }

                    $mockExampleScriptPath = Join-Path -Path $mockModulesExamplesPath -ChildPath 'TestConfig.ps1'

                    $newScriptFileInfoParameters = @{
                        Path = $mockExampleScriptPath
                        Version = '1.0.0.0'
                        Guid = $mockGuid
                        Description = 'Test metadata'
                    }

                    New-ScriptFileInfo @newScriptFileInfoParameters

                    $definition = '
                        Configuration TestConfig
                        {
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath -Encoding utf8 -Force
                }

                It 'Should not call Publish-Script' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Publish-Script -Exactly -Times 0
                }
            }

            Context 'When the example configuration is an older version than the one in the Gallery' {
                BeforeAll {
                    Mock -CommandName Find-Script -MockWith {
                        return @{
                            Version = '1.1.0.0'
                        }
                    }

                    $mockExampleScriptPath = Join-Path -Path $mockModulesExamplesPath -ChildPath 'TestConfig.ps1'

                    $newScriptFileInfoParameters = @{
                        Path = $mockExampleScriptPath
                        Version = '1.0.0.0'
                        Guid = $mockGuid
                        Description = 'Test metadata'
                    }

                    New-ScriptFileInfo @newScriptFileInfoParameters

                    $definition = '
                        Configuration TestConfig
                        {
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath -Encoding utf8 -Force
                }

                It 'Should not call Publish-Script' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Publish-Script -Exactly -Times 0
                }
            }

            Context 'When the example configuration is a newer version than the one in the Gallery' {
                BeforeAll {
                    Mock -CommandName Find-Script -MockWith {
                        return @{
                            Version = '0.9.0.0'
                        }
                    }

                    $mockExampleScriptPath = Join-Path -Path $mockModulesExamplesPath -ChildPath 'TestConfig.ps1'

                    $newScriptFileInfoParameters = @{
                        Path = $mockExampleScriptPath
                        Version = '1.0.0.0'
                        Guid = $mockGuid
                        Description = 'Test metadata'
                    }

                    New-ScriptFileInfo @newScriptFileInfoParameters

                    $definition = '
                        Configuration TestConfig
                        {
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath -Encoding utf8 -Force
                }

                It 'Should call Publish-Script' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Publish-Script -Exactly -Times 1
                }
            }

            Context 'When the example configuration does not have a configuration block' {
                BeforeAll {
                    Mock -CommandName Write-Warning
                    Mock -CommandName Find-Script -MockWith {
                        return @{
                            Version = '1.1.0.0'
                        }
                    }

                    $mockExampleScriptPath = Join-Path -Path $mockModulesExamplesPath -ChildPath 'TestConfig.ps1'

                    $newScriptFileInfoParameters = @{
                        Path = $mockExampleScriptPath
                        Version = '1.0.0.0'
                        Guid = $mockGuid
                        Description = 'Test metadata'
                    }

                    New-ScriptFileInfo @newScriptFileInfoParameters
                }

                It 'Should not call Publish-Script' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Publish-Script -Exactly -Times 0
                    Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                        $Message -eq ('{0} {1}' -f `
                            ($script:localizedData.SkipPublish -f $mockExampleScriptPath),
                            $script:localizedData.ConfigurationNameMismatch)
                    } -Exactly -Times 1 -Scope It
                }
            }

            Context 'When the two example configurations have the same GUID' {
                BeforeEach {
                    Mock -CommandName Write-Warning
                    Mock -CommandName Find-Script

                    # Duplicate script 1
                    $mockExampleScriptPath1 = Join-Path -Path $mockModulesExamplesPath -ChildPath 'Test1Config.ps1'

                    $newScriptFileInfoParameters = @{
                        Path = $mockExampleScriptPath1
                        Version = '1.0.0.0'
                        Guid = $mockGuid
                        Description = 'Test metadata'
                    }

                    New-ScriptFileInfo @newScriptFileInfoParameters

                    $definition = '
                        Configuration Test1Config
                        {
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath1 -Encoding utf8 -Force

                    # Duplicate script 2
                    $mockExampleScriptPath2 = Join-Path -Path $mockModulesExamplesPath -ChildPath 'Test2Config.ps1'

                    $newScriptFileInfoParameters['Path'] = $mockExampleScriptPath2
                    New-ScriptFileInfo @newScriptFileInfoParameters


                    $definition = '
                        Configuration Test2Config
                        {
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath2 -Encoding utf8 -Force
                }

                AfterEach {
                    Remove-Item -Path $mockExampleScriptPath1 -Force
                    Remove-Item -Path $mockExampleScriptPath2 -Force
                }

                It 'Should call the correct mocks' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Publish-Script -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                        $Message -eq ('{0}' -f `
                            ($script:localizedData.DuplicateGuid -f (@($mockExampleScriptPath1, $mockExampleScriptPath2) -join "', '")))
                    } -Exactly -Times 1 -Scope It
                }
            }

            Context 'When there is an example that has correctly opt-in to be published' {
                BeforeAll {
                    Mock -CommandName Write-Warning
                    Mock -CommandName Find-Script

                    $mockExampleScriptPath = Join-Path -Path $mockModulesExamplesPath -ChildPath '99-TestConfig.ps1'

                    $newScriptFileInfoParameters = @{
                        Path = $mockExampleScriptPath
                        Version = '1.0.0.0'
                        Guid = $mockGuid
                        Description = 'Test metadata'
                    }

                    New-ScriptFileInfo @newScriptFileInfoParameters

                    $definition = '
                        Configuration TestConfig
                        {
                        }
                    '

                    $definition | Out-File -Append -FilePath $mockExampleScriptPath -Encoding utf8 -Force
                }

                It 'Should call the correct mocks' {
                    $startGalleryDeployParameters = @{
                        ResourceModuleName = $mockResourceModuleName
                        Path               = $mockModulesExamplesPath
                        ModuleRootPath     = $mockModuleRootPath
                        Branch             = 'master'
                    }

                    { Start-GalleryDeploy @startGalleryDeployParameters -Verbose } | Should -Not -Throw

                    Assert-MockCalled -CommandName Write-Warning -Exactly -Times 0 -Scope It
                    Assert-MockCalled -CommandName Copy-Item -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1 -Scope It

                    <#
                        Should always publish script from temp folder, and not
                        having the number prefix in the filename
                    #>
                    Assert-MockCalled -CommandName Publish-Script -ParameterFilter {
                        $Path -eq (Join-Path -Path $env:TEMP -ChildPath 'TestConfig.ps1')
                    } -Exactly -Times 1 -Scope It
                }

                Context 'When the running against a branch other than the master branch' {
                    It 'Should call Publish-Script using WhatIf' {
                        $startGalleryDeployParameters = @{
                            ResourceModuleName = $mockResourceModuleName
                            Path               = $mockModulesExamplesPath
                            ModuleRootPath     = $mockModuleRootPath
                            Branch             = 'dev'
                        }

                        { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Not -Throw

                        Assert-MockCalled -CommandName Publish-Script -ParameterFilter {
                            # Using $WhatIf did not work, but $WhatIfPreference worked.
                            $WhatIfPreference -eq $true
                        } -Exactly -Times 1 -Scope It
                    }
                }

                Context 'When the Publish-Script throws an error' {
                    BeforeEach {
                        Mock -CommandName Publish-Script -MockWith {
                            throw 'Mocked error'
                        }
                    }

                    It 'Should catch the error and re-throw the error' {
                        $startGalleryDeployParameters = @{
                            ResourceModuleName = $mockResourceModuleName
                            Path               = $mockModulesExamplesPath
                            ModuleRootPath     = $mockModuleRootPath
                            Branch             = 'dev'
                        }

                        { Start-GalleryDeploy @startGalleryDeployParameters } | Should -Throw 'Mocked error'
                    }
                }
            }
        }
    }

    Describe 'DscResource.GalleryDeploy\Test-PublishMetadata' {
        Context 'When a script file contains the correct metadata' {
            BeforeAll {
                Mock -CommandName Test-ScriptFileInfo
            }

            It 'Should call the correct mocks' {
                { Test-PublishMetadata -Path $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Test-ScriptFileInfo' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a script file has parse errors' {
            BeforeAll {
                Mock -CommandName Write-Warning

                $errorMessage = 'The specified script file has parse errors.'

                Mock -CommandName Test-ScriptFileInfo -MockWith {
                    $getInvalidArgumentRecordParameters = @{
                        # Not the actual error message
                        Message      = $errorMessage
                        # This is the FullyQualifiedErrorId
                        ArgumentName = 'ScriptParseError,Test-ScriptFileInfo'
                    }

                    throw Get-InvalidArgumentRecord @getInvalidArgumentRecordParameters
                }
            }

            It 'Should call the correct mocks and return the correct warning message' {
                { Test-PublishMetadata -Path $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName Test-ScriptFileInfo -Exactly -Times 1 -Scope It

                $warningMessage = $script:localizedData.ScriptParseError -f $errorMessage

                Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                    $Message -match ($script:localizedData.SkipPublish -f ($TestDrive -replace '\\','\\')) `
                    -and $Message -match [Regex]::Escape($warningMessage)
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a script file is missing metadata' {
            BeforeAll {
                Mock -CommandName Write-Warning

                $errorMessage = 'PSScriptInfo is not specified in the script file.'

                Mock -CommandName Test-ScriptFileInfo -MockWith {
                    $getInvalidArgumentRecordParameters = @{
                        # Not the actual error message
                        Message      = $errorMessage
                        # This is the FullyQualifiedErrorId
                        ArgumentName = 'MissingPSScriptInfo,Test-ScriptFileInfo'
                    }

                    throw Get-InvalidArgumentRecord @getInvalidArgumentRecordParameters
                }
            }

            It 'Should call the correct mocks and return the correct warning message' {
                { Test-PublishMetadata -Path $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName Test-ScriptFileInfo -Exactly -Times 1 -Scope It

                $warningMessage = $script:localizedData.MissingMetadata -f $errorMessage

                Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                    $Message -match ($script:localizedData.SkipPublish -f ($TestDrive -replace '\\','\\')) `
                    -and $Message -match [Regex]::Escape($warningMessage)
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a script file has missing required metadata properties' {
            BeforeAll {
                Mock -CommandName Write-Warning

                $errorMessage = 'Script file is missing required metadata properties.'

                Mock -CommandName Test-ScriptFileInfo -MockWith {
                    $getInvalidArgumentRecordParameters = @{
                        # Not the actual error message
                        Message      = $errorMessage
                        # This is the FullyQualifiedErrorId
                        ArgumentName = 'MissingRequiredPSScriptInfoProperties,Test-ScriptFileInfo'
                    }

                    throw Get-InvalidArgumentRecord @getInvalidArgumentRecordParameters
                }
            }

            It 'Should call the correct mocks and return the correct warning message' {
                { Test-PublishMetadata -Path $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName Test-ScriptFileInfo -Exactly -Times 1 -Scope It

                $warningMessage = $script:localizedData.MissingRequiredMetadataProperties -f $errorMessage

                Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                    $Message -match ($script:localizedData.SkipPublish -f ($TestDrive -replace '\\','\\')) `
                    -and $Message -match [Regex]::Escape($warningMessage)
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a script file has an invalid GUID in its metadata' {
            BeforeAll {
                Mock -CommandName Write-Warning

                $errorMessage = 'Cannot convert value ''a18e0a9-2a4b-4406-939e-ac2bb7b6e917'' to type ''System.Guid'''

                Mock -CommandName Test-ScriptFileInfo -MockWith {
                    $getInvalidArgumentRecordParameters = @{
                        Message      = $errorMessage
                        # This is the FullyQualifiedErrorId
                        ArgumentName = 'InvalidGuid,Test-ScriptFileInfo'
                    }

                    throw Get-InvalidArgumentRecord @getInvalidArgumentRecordParameters
                }
            }

            It 'Should call the correct mocks and return the correct warning message' {
                { Test-PublishMetadata -Path $TestDrive } | Should -Not -Throw

                Assert-MockCalled -CommandName Test-ScriptFileInfo -Exactly -Times 1 -Scope It

                $warningMessage = $script:localizedData.InvalidGuid -f $errorMessage

                Assert-MockCalled -CommandName Write-Warning -ParameterFilter {
                    $Message -match ($script:localizedData.SkipPublish -f ($TestDrive -replace '\\','\\')) `
                    -and $Message -match [Regex]::Escape($warningMessage)
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When cmdlet Test-ScriptFileInfo throws an unknown error' {
            BeforeAll {
                $throwMessage = 'Unknown error'
                Mock -CommandName Test-ScriptFileInfo -MockWith {
                    throw $throwMessage
                }

                Mock -CommandName Write-Warning
            }

            It 'Should throw the correct error message' {
                $errorMessage = $script:localizedData.TestScriptFileInfoError -f $TestDrive, $throwMessage
                { Test-PublishMetadata -Path $TestDrive } | Should -Throw $errorMessage

                Assert-MockCalled -CommandName Test-ScriptFileInfo -Exactly -Times 1 -Scope It
            }
        }
    }

    Describe 'DscResource.GalleryDeploy\Test-ConfigurationName' {
        BeforeAll {
            $mockScriptPath = Join-Path -Path $TestDrive -ChildPath '99-TestConfig'
        }

        Context 'When a script file has the correct name' {
            BeforeAll {
                $definition = '
                    Configuration TestConfig
                    {
                    }
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return true' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $true
            }
        }

        Context 'When a script file has the different name than the configuration name' {
            BeforeAll {
                $definition = '
                    Configuration WrongConfig
                    {
                    }
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return false' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $false
            }
        }

        Context 'When the configuration name starts with a number' {
            BeforeAll {
                $definition = '
                    Configuration 1WrongConfig
                    {
                    }
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should throw the correct error' {
                $errorMessage = 'The configuration name ''1WrongConfig'' is not valid.'
                { Test-ConfigurationName -Path $mockScriptPath } | Should -Throw $errorMessage
            }
        }

        Context 'When the configuration name does not end with a letter or a number' {
            BeforeAll {
                $definition = '
                    Configuration WrongConfig_
                    {
                    }
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return false' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $false
            }
        }

        Context 'When the configuration name contain other characters than only letters, numbers, and underscores' {
            BeforeAll {
                $definition = '
                    Configuration Wrong-Config
                    {
                    }
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return false' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $false
            }
        }
    }
}
