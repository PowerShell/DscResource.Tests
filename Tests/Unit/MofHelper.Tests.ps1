$projectRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$moduleRootPath = Join-Path -Path $projectRootPath -ChildPath 'DscResource.DocumentationHelper'
$modulePath = Join-Path -Path $moduleRootPath -ChildPath 'MofHelper.psm1'

Import-Module -Name $modulePath -Force

InModuleScope -ModuleName 'MofHelper' {
    $script:className = 'MSFT_MofHelperTest'
    $script:fileName = '{0}.schema.mof' -f $script:ClassName
    $script:tempFileName = '{0}.tmp' -f $script:fileName
    $script:filePath = 'TestDrive:\{0}' -f $script:fileName
    $script:tempFilePath = 'TestDrive:\{0}' -f $script:tempFileName

    Describe Get-MofSchemaObject {
        Mock -CommandName Resolve-Path -MockWith {
            [pscustomobject]@{
                Path = $script:filePath
            }
        } -ParameterFilter {$Path -eq $script:fileName}

        Mock -CommandName Join-Path -MockWith {
            $script:tempFilePath
        }

$fileContent = @"
[ClassVersion("1.0.0"), FriendlyName("MofHelperTest")]
class MSFT_MofHelperTest : OMI_BaseResource
{
    [Key,      Description("Test key string property")] String Name;
    [Required, Description("Test required property"), ValueMap{"Present","Absent"}, Values{"Present","Absent"}] String Needed;
    [Write,    Description("Test writeable string array")] String MultipleValues[];
    [Write,    Description("Test writeable boolean")] Boolean Switch;
    [Write,    Description("Test writeable datetime")] DateTime ExecuteOn;
    [Write,    Description("Test credential"), EmbeddedInstance("MSFT_Credential")] String Credential;
    [Read,     Description("Test readonly integer")] Uint32 NoWrite;
};
"@
        Set-Content -Path $script:filePath -Value $fileContent

        It 'Should import the class from the schema file without throwing' {
            { Get-MofSchemaObject -FileName $script:filePath } | Should -Not -Throw
        }

        $schema = Get-MofSchemaObject -FileName $script:filePath

        It "Should import class with ClassName $script:className" {
            $schema.ClassName | Should -Be $script:className
        }

        It 'Should get class version' {
            $schema.ClassVersion | Should -Be '1.0.0'
        }

        It 'Should get class FriendlyName' {
            $schema.FriendlyName | Should -Be 'MofHelperTest'
        }

        It 'Should get property <PropertyName> with all correct properties' {
            [CmdletBinding()]
            param (
                [Parameter()]
                [System.String]
                $PropertyName,

                [Parameter()]
                [System.String]
                $State,

                [Parameter()]
                [System.String]
                $DataType,

                [Parameter()]
                [System.Boolean]
                $IsArray,

                [Parameter()]
                [System.String]
                $Description
            )

            $property = $schema.Attributes.Where({$_.Name -eq $PropertyName})

            $property.State | Should -Be $State
            $property.DataType | Should -Be $DataType
            $property.Description | Should -Be $Description
            $property.IsArray | Should -Be $IsArray
        } -TestCases @(
            @{
                PropertyName = 'Name'
                State = 'Key'
                DataType = 'String'
                Description = 'Test key string property'
                IsArray = $false
            }
            @{
                PropertyName = 'Needed'
                State = 'Required'
                DataType = 'String'
                Description = 'Test required property'
                IsArray = $false
            }
            @{
                PropertyName = 'MultipleValues'
                State = 'Write'
                DataType = 'StringArray'
                Description = 'Test writeable string array'
                IsArray = $true
            }
            @{
                PropertyName = 'Switch'
                State = 'Write'
                DataType = 'Boolean'
                Description = 'Test writeable boolean'
                IsArray = $false
            }
            @{
                PropertyName = 'ExecuteOn'
                State = 'Write'
                DataType = 'DateTime'
                Description = 'Test writeable datetime'
                IsArray = $false
            }
            @{
                PropertyName = 'Credential'
                State = 'Write'
                DataType = 'Instance'
                Description = 'Test credential'
                IsArray = $false
            }
            @{
                PropertyName = 'NoWrite'
                State = 'Read'
                DataType = 'Uint32'
                Description = 'Test readonly integer'
                IsArray = $false
            }
        )

        It 'Should return the proper ValueMap' {
            $property = $schema.Attributes.Where({$_.Name -eq 'Needed'})
            $property.ValueMap | Should -HaveCount 2
            $property.ValueMap | Should -Contain 'Absent'
            $property.ValueMap | Should -Contain 'Present'
        }

        It 'Should return the proper EmbeddedInstance for Credential' {
            $property = $schema.Attributes.Where({$_.Name -eq 'Credential'})
            $property.EmbeddedInstance | Should -Be 'MSFT_Credential'
        }
    }
}
