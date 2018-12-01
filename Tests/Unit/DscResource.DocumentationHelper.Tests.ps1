$projectRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$moduleRootPath = Join-Path -Path $projectRootPath -ChildPath 'DscResource.DocumentationHelper'
$modulePath = Join-Path -Path $moduleRootPath -ChildPath 'WikiPages.psm1'

Import-Module -Name $modulePath -Force

Import-Module -Name (Join-Path -Path (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'TestHelpers') -ChildPath 'CommonTestHelper.psm1') -Global

InModuleScope -ModuleName 'WikiPages' {

    $script:mockOutputPath = Join-Path -Path $ENV:Temp -ChildPath 'docs'
    $script:mockModulePath = Join-Path -Path $ENV:Temp -ChildPath 'module'

    # Schema file info
    $script:expectedSchemaPath = Join-Path -Path $script:mockModulePath -ChildPath '\**\*.schema.mof'
    $script:mockSchemaFileName = 'MSFT_MyResource.schema.mof'
    $script:mockSchemaFolder = Join-Path -Path $script:mockModulePath -ChildPath 'DSCResources\MSFT_MyResource'
    $script:mockSchemaFilePath = Join-Path -Path $script:mockSchemaFolder -ChildPath $script:mockSchemaFileName
    $script:mockSchemaFiles = @(
        @{
            FullName      = $script:mockSchemaFilePath
            Name          = $script:mockSchemaFileName
            DirectoryName = $script:mockSchemaFolder
        }
    )
    $script:mockGetMofSchemaObject = @{
        ClassName    = 'MSFT_MyResource'
        Attributes   = @(
            @{
                State            = 'Key'
                DataType         = 'String'
                ValueMap         = @()
                IsArray          = $false
                Name             = 'Id'
                Description      = 'Id Description'
                EmbeddedInstance = ''
            },
            @{
                State            = 'Write'
                DataType         = 'String'
                ValueMap         = @( 'Value1', 'Value2', 'Value3' )
                IsArray          = $false
                Name             = 'Enum'
                Description      = 'Enum Description.'
                EmbeddedInstance = ''
            },
            @{
                State            = 'Required'
                DataType         = 'Uint32'
                ValueMap         = @()
                IsArray          = $false
                Name             = 'Int'
                Description      = 'Int Description.'
                EmbeddedInstance = ''
            },
            @{
                State            = 'Read'
                DataType         = 'String'
                ValueMap         = @()
                IsArray          = $false
                Name             = 'Read'
                Description      = 'Read Description.'
                EmbeddedInstance = ''
            }
        )
        ClassVersion = '1.0.0'
        FriendlyName = 'MyResource'
    }

    # Example file info
    $script:mockExampleFilePath = Join-Path -Path $script:mockModulePath -ChildPath '\Examples\Resources\MyResource\MyResource_Example1_Config.ps1'
    $script:expectedExamplePath = Join-Path -Path $script:mockModulePath -ChildPath '\Examples\Resources\MyResource\*.ps1'
    $script:mockExampleFiles = @(
        @{
            Name      = 'MyResource_Example1_Config.ps1'
            FullName  = $script:mockExampleFilePath
        }
    )
    $script:mockExampleContent = '### Example 1

Example description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```'

    # General mock values
    $script:mockReadmePath = Join-Path -Path $script:mockSchemaFolder -ChildPath 'readme.md'
    $script:mockOutputFile = Join-Path -Path $script:mockOutputPath -ChildPath 'MyResource.md'
    $script:mockGetContentReadme = '
# Description

The description of the resource.
'
    $script:mockWikiPageOutput = '# MyResource

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **Id** | Key | String | Id Description ||
| **Enum** | Write | String | Enum Description. |Value1, Value2, Value3|
| **Int** | Required | Uint32 | Int Description. ||
| **Read** | Read | String | Read Description. ||


## Description

The description of the resource.

## Examples

### Example 1

Example description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```
'

    Describe 'DscResource.DocumentationHelper\WikiPages.psm1\New-DscResourceWikiSite' {
        # Parameter filters
        $script:getChildItemSchema_parameterFilter = {
            $Path -eq $script:expectedSchemaPath
        }
        $script:getChildItemExample_parameterFilter = {
            $Path -eq $script:expectedExamplePath
        }
        $script:getMofSchemaObjectSchema_parameterfilter = {
            $Filename -eq $script:mockSchemaFilePath
        }
        $script:getTestPathReadme_parameterFilter = {
            $Path -eq $script:mockReadmePath
        }
        $script:getContentReadme_parameterFilter = {
            $Path -eq $script:mockReadmePath
        }
        $script:getDscResourceWikiExampleContent_parameterFilter = {
            $ExamplePath -eq $script:mockExampleFilePath -and $ExampleNumber -eq 1
        }
        $script:outFile_parameterFilter = {
            $FilePath -eq $script:mockOutputFile `
                -and $InputObject -eq $script:mockWikiPageOutput
        }

        # Function call parameters
        $script:newDscResourceWikiSite_parameters = @{
            OutputPath = $script:mockOutputPath
            ModulePath = $script:mockModulePath
            Verbose    = $true
        }

        Context 'When there is no schemas found in the module folder' {
            BeforeAll {
                Mock `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter
            }

            It 'Should not throw an exception' {
                { New-DscResourceWikiSite @script:newDscResourceWikiSite_parameters } | Should -Not -Throw
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When there is one schema found in the module folder and one example using .EXAMPLE' {
            BeforeAll {
                Mock `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter `
                    -MockWith { $script:mockSchemaFiles }

                Mock `
                    -CommandName Get-MofSchemaObject `
                    -ParameterFilter $script:getMofSchemaObjectSchema_parameterfilter `
                    -MockWith { $script:mockGetMofSchemaObject }

                Mock `
                    -CommandName Test-Path `
                    -ParameterFilter $script:getTestPathReadme_parameterFilter `
                    -MockWith { $true }

                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentReadme_parameterFilter `
                    -MockWith { $script:mockGetContentReadme }

                Mock `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemExample_parameterFilter `
                    -MockWith { $script:mockExampleFiles }

                Mock `
                    -CommandName Get-DscResourceWikiExampleContent `
                    -ParameterFilter $script:getDscResourceWikiExampleContent_parameterFilter `
                    -MockWith { $script:mockExampleContent }

                Mock `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFile_parameterFilter
            }

            It 'Should not throw an exception' {
                { New-DscResourceWikiSite @script:newDscResourceWikiSite_parameters } | Should -Not -Throw
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Get-MofSchemaObject `
                    -ParameterFilter $script:getMofSchemaObjectSchema_parameterfilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Test-Path `
                    -ParameterFilter $script:getTestPathReadme_parameterFilter `
                    -Exactly -Times 1

                 Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentReadme_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemExample_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Get-DscResourceWikiExampleContent `
                    -ParameterFilter $script:getDscResourceWikiExampleContent_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFile_parameterFilter `
                    -Exactly -Times 1
            }
        }
    }

    Describe 'DscResource.DocumentationHelper\WikiPages.psm1\Get-DscResourceWikiExampleContent' {
        # Parameter filters
        $script:getContentExample_parameterFilter = {
            $Path -eq $script:mockExampleFilePath
        }

        Context 'When a path to an example file with .EXAMPLE is passed and example number 1' {
            $script:getDscResourceWikiExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 1
                Verbose       = $true
            }

            $script:mockExampleContent = '### Example 1

Example Description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```'

            $script:mockGetContentExample = '<#
.EXAMPLE
Example Description.
#>
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}' -split "`r`n"

            BeforeAll {
                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -MockWith { $script:mockGetContentExample }
            }

            It 'Should not throw an exception' {
                { $script:result = Get-DscResourceWikiExampleContent @script:getDscResourceWikiExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -Be $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .DESCRIPTION is passed and example number 2' {
            $script:getDscResourceWikiExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 2
                Verbose       = $true
            }

            $script:mockExampleContent = '### Example 2

Example Description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```'

                $script:mockGetContentExample = '<#
    .DESCRIPTION
    Example Description.
#>
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}' -split "`r`n"

            BeforeAll {
                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -MockWith { $script:mockGetContentExample }
            }

            It 'Should not throw an exception' {
                { $script:result = Get-DscResourceWikiExampleContent @script:getDscResourceWikiExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -Be $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .SYNOPSIS is passed and example number 3' {
            $script:getDscResourceWikiExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 3
                Verbose       = $true
            }

            $script:mockExampleContent = '### Example 3

Example Description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```'

                $script:mockGetContentExample = '<#
    .SYNOPSIS
    Example Description.
#>
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}' -split "`r`n"

            BeforeAll {
                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -MockWith { $script:mockGetContentExample }
            }

            It 'Should not throw an exception' {
                { $script:result = Get-DscResourceWikiExampleContent @script:getDscResourceWikiExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -Be $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .SYNOPSIS and #Requires is passed and example number 4' {
            $script:getDscResourceWikiExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 4
                Verbose       = $true
            }

            $script:mockExampleContent = '### Example 4

Example Description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```'

                $script:mockGetContentExample = '#Requires -module MyModule
#Requires -module OtherModule

<#
    .SYNOPSIS
    Example Description.
#>
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}' -split "`r`n"

            BeforeAll {
                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -MockWith { $script:mockGetContentExample }
            }

            It 'Should not throw an exception' {
                { $script:result = Get-DscResourceWikiExampleContent @script:getDscResourceWikiExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -Be $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .DESCRIPTION, #Requires and PSScriptInfo is passed and example number 5' {
            $script:getDscResourceWikiExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 5
                Verbose       = $true
            }

            $script:mockExampleContent = '### Example 5

Example Description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```'

            $script:mockGetContentExample = '<#PSScriptInfo
.VERSION 1.0.0
.GUID 14b1346a-436a-4f64-af5c-b85119b819b3
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/CertificateDsc/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/CertificateDsc
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module MyModule
#Requires -module OtherModule

<#
    .DESCRIPTION
        Example Description.
#>
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}' -split "`r`n"

            BeforeAll {
                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -MockWith { $script:mockGetContentExample }
            }

            It 'Should not throw an exception' {
                { $script:result = Get-DscResourceWikiExampleContent @script:getDscResourceWikiExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -Be $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .SYNOPSIS, .DESCRIPTION and PSScriptInfo is passed and example number 6' {
            $script:getDscResourceWikiExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 6
                Verbose       = $true
            }

            $script:mockExampleContent = '### Example 6

Example Synopsis.

Example Description.

```powershell
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}
```'

            $script:mockGetContentExample = '<#PSScriptInfo
.VERSION 1.0.0
.GUID 14b1346a-436a-4f64-af5c-b85119b819b3
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/CertificateDsc/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/CertificateDsc
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

<#
    .SYNOPSIS
        Example Synopsis.

    .DESCRIPTION
        Example Description.
#>
Configuration Example
{
    Import-DSCResource -ModuleName MyModule

    Node localhost
    {
        MyResource Something
        {
            Id    = ''MyId''
            Enum  = ''Value1''
            Int   = 1
        }
    }
}' -split "`r`n"

            BeforeAll {
                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -MockWith { $script:mockGetContentExample }
            }

            It 'Should not throw an exception' {
                { $script:result = Get-DscResourceWikiExampleContent @script:getDscResourceWikiExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -Be $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file from SharePointDsc resource module and example number 7' {
            $script:getDscResourceWikiExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 7
                Verbose       = $true
            }

            $script:mockExampleContent = '### Example 7

This example shows how to deploy Access Services 2013 to the local SharePoint farm.

```powershell
    Configuration Example
    {
        param(
            [Parameter(Mandatory = $true)]
            [PSCredential]
            $SetupAccount
        )
        Import-DscResource -ModuleName SharePointDsc

        node localhost {
            SPAccessServiceApp AccessServices
            {
                Name                 = "Access Services Service Application"
                ApplicationPool      = "SharePoint Service Applications"
                DatabaseServer       = "SQL.contoso.local\SQLINSTANCE"
                PsDscRunAsCredential = $SetupAccount
            }
        }
    }
```'

            $script:mockGetContentExample = '<#
.EXAMPLE
    This example shows how to deploy Access Services 2013 to the local SharePoint farm.
#>

    Configuration Example
    {
        param(
            [Parameter(Mandatory = $true)]
            [PSCredential]
            $SetupAccount
        )
        Import-DscResource -ModuleName SharePointDsc

        node localhost {
            SPAccessServiceApp AccessServices
            {
                Name                 = "Access Services Service Application"
                ApplicationPool      = "SharePoint Service Applications"
                DatabaseServer       = "SQL.contoso.local\SQLINSTANCE"
                PsDscRunAsCredential = $SetupAccount
            }
        }
    }' -split "`r`n"

            BeforeAll {
                Mock `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -MockWith { $script:mockGetContentExample }
            }

            It 'Should not throw an exception' {
                { $script:result = Get-DscResourceWikiExampleContent @script:getDscResourceWikiExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -Be $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }
    }
}
