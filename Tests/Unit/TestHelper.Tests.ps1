$script:ModuleName = 'TestHelper'
$script:moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

Describe "$($script:ModuleName) Unit Tests" {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $script:moduleRootPath -ChildPath "$($script:ModuleName).psm1") -Force
    }

    InModuleScope $script:ModuleName {
        Describe 'Get-DscIntegrationTestOrderNumber' {
            BeforeAll {
                # Set up TestDrive
                $filePath_NoAttribute = Join-Path -Path $TestDrive -ChildPath 'NoAttribute.ps1'
                $filePath_WrongAttribute = Join-Path -Path $TestDrive -ChildPath 'WrongAttribute.ps1'
                $filePath_CorrectAttribute = Join-Path -Path $TestDrive -ChildPath 'CorrectAttribute.ps1'

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
            }

            Context 'When configuration file does not contain a attribute' {
                It 'Should not return any value' {
                    $result = Get-DscIntegrationTestOrderNumber -Path $filePath_NoAttribute
                    $result | Should BeNullOrEmpty
                }
            }

            Context 'When configuration file contain a attribute but without the correct named attribute argument' {
                It 'Should not return any value' {
                    $result = Get-DscIntegrationTestOrderNumber -Path $filePath_WrongAttribute
                    $result | Should BeNullOrEmpty
                }
            }

            Context 'When configuration file does contain a attribute and with the correct named attribute argument' {
                It 'Should not return any value' {
                    $result = Get-DscIntegrationTestOrderNumber -Path $filePath_CorrectAttribute
                    $result | Should BeExactly 2
                }
            }
        }
    }
}
