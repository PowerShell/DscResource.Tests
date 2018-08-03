$script:ModuleName = 'TestRunner'
$script:moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

Describe "$($script:ModuleName) Unit Tests" {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $script:moduleRootPath -ChildPath "$($script:ModuleName).psm1") -Force
    }

    InModuleScope $script:ModuleName {
        Describe 'Start-DscResourceTests' {
            BeforeAll {
                # Set up TestDrive
                $mockResourcePath = Join-Path -Path 'TestDrive:' -ChildPath 'DscResources'
                New-Item -Path $mockResourcePath -ItemType Directory

                $mockResource1Path = Join-Path -Path $mockResourcePath -ChildPath 'Resource1'
                New-Item -Path $mockResource1Path -ItemType Directory

                $mockResource2Path = Join-Path -Path $mockResourcePath -ChildPath 'Resource2'
                New-Item -Path $mockResource2Path -ItemType Directory

                Push-Location

                Set-Location -Path $mockResourcePath
            }

            BeforeEach {
                Mock -CommandName Push-Location -Verifiable
                Mock -CommandName Pop-Location -Verifiable
                Mock -CommandName Invoke-Pester -Verifiable
            }

            Context 'When starting tests' {
                It 'Should call Invoke-Pester exactly 2 times' {
                    { Start-DscResourceTests -ResourcesPath $mockResourcePath } | Should -Not -Throw

                    Assert-MockCalled -CommandName Invoke-Pester -Exactly -Times 2
                }
            }

            AfterAll {
                Pop-Location
            }

            Assert-VerifiableMock
        }
    }
}
