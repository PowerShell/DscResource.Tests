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
                DataType         = [Microsoft.Management.Infrastructure.CimType]::String
                ValueMap         = @()
                IsArray          = $false
                Name             = 'Id'
                Description      = 'Id Description'
                EmbeddedInstance = ''
            },
            @{
                State            = 'Write'
                DataType         = [Microsoft.Management.Infrastructure.CimType]::String
                ValueMap         = @( 'Value1', 'Value2', 'Value3' )
                IsArray          = $false
                Name             = 'Enum'
                Description      = 'Enum Description.'
                EmbeddedInstance = ''
            },
            @{
                State            = 'Write'
                DataType         = [Microsoft.Management.Infrastructure.CimType]::String
                ValueMap         = @()
                IsArray          = $true
                Name             = 'Array'
                Description      = 'Array Description.'
                EmbeddedInstance = ''
            },
            @{
                State            = 'Required'
                DataType         = [Microsoft.Management.Infrastructure.CimType]::UInt32
                ValueMap         = @()
                IsArray          = $false
                Name             = 'Int'
                Description      = 'Int Description.'
                EmbeddedInstance = ''
            },
            @{
                State            = 'Read'
                DataType         = [Microsoft.Management.Infrastructure.CimType]::String
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
| **Array** | Write | String[] | Array Description. ||
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
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemExample_parameterFilter `
                    -MockWith { $script:mockExampleFiles }

                Mock `
                    -CommandName Get-MofSchemaObject `
                    -MockWith { $script:mockGetMofSchemaObject }

                Mock `
                    -CommandName Test-Path `
                    -MockWith { $true }

                Mock `
                    -CommandName Get-Content `
                    -MockWith { $script:mockGetContentReadme }

                Mock `
                    -CommandName Get-DscResourceWikiExampleContent `
                    -MockWith { $script:mockExampleContent }

                Mock `
                    -CommandName Out-File
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

    Context 'When a path to an example file from CertificateDsc resource module and example number 8' {
        $script:getDscResourceWikiExampleContent_parameters = @{
            ExamplePath   = $script:mockExampleFilePath
            ExampleNumber = 8
            Verbose       = $true
        }

        $script:mockExampleContent = '### Example 8

Exports a certificate as a CERT using the friendly name to identify it.

```powershell
Configuration CertificateExport_CertByFriendlyName_Config
{
    Import-DscResource -ModuleName CertificateDsc

    Node localhost
    {
        CertificateExport SSLCert
        {
            Type         = ''CERT''
            FriendlyName = ''Web Site SSL Certificate for www.contoso.com''
            Path         = ''c:\sslcert.cer''
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

#Requires -module CertificateDsc

<#
    .DESCRIPTION
        Exports a certificate as a CERT using the friendly name to identify it.
#>
Configuration CertificateExport_CertByFriendlyName_Config
{
    Import-DscResource -ModuleName CertificateDsc

    Node localhost
    {
        CertificateExport SSLCert
        {
            Type         = ''CERT''
            FriendlyName = ''Web Site SSL Certificate for www.contoso.com''
            Path         = ''c:\sslcert.cer''
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

    Describe 'DscResource.DocumentationHelper\WikiPages.psm1\Publish-WikiContent' {
        $mockRepoName = 'PowerShell/DummyServiceDsc'
        $mockResourceModuleName = ($mockRepoName -split '/')[1]
        $mockGitUserEmail = 'mock@contoso.com'
        $mockGitUserName = 'mock'
        $mockGithubAccessToken = '1234567890'
        $mockPath = $env:temp
        $mockJobId = 'imy2wgh1ylo9qcpb'
        $mockBuildVersion = '2.1.456.0'
        $mockapiUrl = 'https://ci.appveyor.com/api'
        $mockJobArtifactsUrl = "$mockapiUrl/buildjobs/$mockJobId/artifacts"
        $mockGitRepoNotFoundMessage = 'git.exe : fatal: remote error'
        $mockInvokeRestMethodJobIdNotFoundMessage = '{"Message":"Job not found."}'
        $mockInvokeRestMethodUnexpectedErrorMessage = '{"Message":"Unexpected Error."}'

        $mockInvokeRestMethodJobArtifactsObject = @(
            @{
                created  = '2019-06-04T15:23:53.8064505+00:00'
                filename = "TestsResults.xml"
                size     = 1049288
                type     = 'File'

            }
            @{
                created  = '2019-06-04T15:24:28.0273896+00:00'
                filename = "$($mockResourceModuleName)_$($mockBuildVersion)_wikicontent.zip"
                size     = 20692
                type     = 'Zip'
            }
        )
        $mockInvokeRestMethodJobArtifactsObjectNoWikiContent = $mockInvokeRestMethodJobArtifactsObject[0]
        $mockWikiContentArtifactUrl = "$mockapiUrl/buildjobs/$mockJobId/artifacts/$($mockInvokeRestMethodJobArtifactsObject[1].fileName)"

        # Parameter filters
        $script:invokeGitClone_parameterFilter = {
            $arguments -eq 'clone'
        }

        $script:invokeGitConfigUserEmail_parameterFilter = {
            $Arguments[0] -eq 'config' -and
            $Arguments[1] -eq '--local' -and
            $Arguments[2] -eq 'user.email' -and
            $Arguments[3] -eq $mockGitUserEmail
        }

        $script:invokeGitConfigUserName_parameterFilter = {
            $Arguments[0] -eq 'config' -and
            $Arguments[1] -eq '--local' -and
            $Arguments[2] -eq 'user.name' -and
            $Arguments[3] -eq $mockGitUserName
        }

        $script:invokeGitRemoteSetUrl_parameterFilter = {
            $Arguments[0] -eq 'remote' -and
            $Arguments[1] -eq 'set-url' -and
            $Arguments[2] -eq 'origin' -and
            $Arguments[3] -eq "https://$($mockGitUserName):$($mockGithubAccessToken)@github.com/$mockRepoName.wiki.git"
        }

        $script:invokeGitAdd_parameterFilter = {
            $Arguments[0] -eq 'add' -and
            $Arguments[1] -eq '*'
        }

        $script:invokeGitCommit_parameterFilter = {
            $Arguments[0] -eq 'commit' -and
            $Arguments[1] -eq '--message' -and
            $Arguments[2] -eq ($localizedData.UpdateWikiCommitMessage -f $mockJobId) -and
            $Arguments[3] -eq '--quiet'
        }

        $script:invokeGitTag_parameterFilter = {
            $Arguments[0] -eq 'tag' -and
            $Arguments[1] -eq '--annotate' -and
            $Arguments[2] -eq $mockBuildVersion -and
            $Arguments[3] -eq '--message' -and
            $Arguments[4] -eq $mockBuildVersion
        }

        $script:invokeGitPush_parameterFilter = {
            $Arguments[0] -eq 'push' -and
            $Arguments[1] -eq 'origin' -and
            $Arguments[2] -eq '--quiet'
        }

        $script:invokeGitPushBuildVersion_parameterFilter = {
            $Arguments[0] -eq 'push' -and
            $Arguments[1] -eq 'origin' -and
            $Arguments[2] -eq $mockBuildVersion -and
            $Arguments[3] -eq '--quiet'
        }

        $script:invokeRestMethodJobArtifacts_parameterFilter = {
            $uri -eq $mockJobArtifactsUrl
        }

        $script:invokeRestMethodWikiContentArtifact_parameterFilter = {
            $uri -eq $mockWikiContentArtifactUrl
        }

        # Function call parameters
        $script:publishWikiContent_parameters = @{
            RepoName           = $mockRepoName
            JobId              = $mockJobId
            MainModulePath     = $mockPath
            ResourceModuleName = $mockResourceModuleName
            BuildVersion       = $mockbuildVersion
            GitUserEmail       = $mockGitUserEmail
            GitUserName        = $mockGitUserName
            GithubAccessToken  = $mockGithubAccessToken
        }

        $script:mockNewItemObject = @{
            FullName = $mockPath
        }

        BeforeAll {
            Mock -CommandName New-Item -MockWith { $script:mockNewItemObject }
            Mock -CommandName Invoke-Git
            Mock -CommandName Invoke-RestMethod
            Mock -CommandName Expand-Archive
            Mock -CommandName Remove-Item
            Mock -CommandName Set-Location
            Mock -CommandName Set-WikiSidebar
            Mock -CommandName Set-WikiFooter
            Mock -CommandName Copy-WikiFile
        }

        Context 'When the Wiki Git repo is not found' {
            BeforeAll {
                Mock -CommandName Invoke-Git -MockWith { Throw $mockGitRepoNotFoundMessage }
            }

            It 'Should throw the correct exception' {
                { Publish-WikiContent @script:publishWikiContent_parameters } |
                    Should -Throw $mockGitRepoNotFoundMessage
            }
        }

        Context 'When the Wiki Git repo is found' {
            BeforeAll {
                Mock -CommandName Invoke-RestMethod `
                    -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                    -MockWith { $mockInvokeRestMethodJobArtifactsObject }
            }

            It 'Should not throw an exception' {
                { Publish-WikiContent @script:publishWikiContent_parameters } |
                    Should -Not -Throw
            }

            It 'Should call the expected mocks' {
                Assert-MockCalled `
                    -CommandName Invoke-Git `
                    -ParameterFilter $script:invokeGitClone_parameterFilter `
                    -Exactly -Times 1
            }

            Context 'When the AppVeyor job ID is not found' {
                BeforeAll {
                    Mock -CommandName Invoke-RestMethod `
                    -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                    -MockWith { throw $mockInvokeRestMethodJobIdNotFoundMessage }
                }

                It 'Should throw the correct exception' {
                    { Publish-WikiContent @script:publishWikiContent_parameters } |
                        Should -Throw ($script:LocalizedData.NoAppVeyorJobFoundError -f $mockJobId)
                }
            }

            Context 'When the AppVeyor artifact details download Invoke-RestMethod produces an unexpected error' {
                BeforeAll {
                    Mock -CommandName Invoke-RestMethod `
                    -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                    -MockWith { Throw $mockInvokeRestMethodUnexpectedErrorMessage }
                }

                It 'Should throw the correct exception' {
                    { Publish-WikiContent @script:publishWikiContent_parameters } |
                        Should -Throw (($mockInvokeRestMethodUnexpectedErrorMessage | ConvertTo-Json).Message)
                }
            }

            Context 'When the AppVeyor job ID is found' {
                BeforeAll {
                    Mock -CommandName Invoke-RestMethod `
                        -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                        -MockWith { $mockInvokeRestMethodJobArtifactsObject }
                }

                It 'Should not throw an exception' {
                    { Publish-WikiContent @script:publishWikiContent_parameters } | Should -Not -Throw
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled `
                        -CommandName Invoke-RestMethod `
                        -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                        -Exactly -Times 1
                }

                Context 'When the AppVeyor job has no artifacts' {
                    BeforeAll {
                        Mock -CommandName Invoke-RestMethod `
                            -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                            -MockWith { @() }
                    }

                    It 'Should throw the correct exception' {
                        { Publish-WikiContent @script:publishWikiContent_parameters } |
                            Should -Throw ($LocalizedData.NoWikiContentArtifactError -f $mockJobId)
                    }
                }

                Context 'When the AppVeyor job does not have a WikiContent artifact' {
                    BeforeAll {
                        Mock -CommandName Invoke-RestMethod `
                            -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                            -MockWith { $mockInvokeRestMethodJobArtifactsObjectNoWikiContent }
                    }

                    It 'Should throw the correct exception' {
                        { Publish-WikiContent @script:publishWikiContent_parameters } |
                            Should -Throw ($LocalizedData.NoWikiContentArtifactError -f $mockJobId)
                    }
                }

                Context 'When the AppVeyor job does have a WikiContent artifact' {
                    BeforeAll {
                        Mock -CommandName Invoke-RestMethod `
                            -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                            -MockWith { $mockInvokeRestMethodJobArtifactsObject }
                    }

                    It 'Should not throw' {
                        { Publish-WikiContent @script:publishWikiContent_parameters } |
                            Should -Not -Throw
                    }

                    It 'Should call the expected mocks' {
                        Assert-MockCalled `
                            -CommandName Invoke-RestMethod `
                            -ParameterFilter $script:invokeRestMethodJobArtifacts_parameterFilter `
                            -Exactly -Times 1
                    }

                    Context 'When the AppVeyor WikiContent artifact cannot be downloaded' {
                        BeforeAll {
                            Mock -CommandName Invoke-RestMethod `
                                -ParameterFilter $script:invokeRestMethodWikiContentArtifact_parameterFilter `
                                -MockWith { Throw ($LocalizedData.NoWikiContentArtifactError -f $mockJobId) }
                        }

                        It 'Should throw the correct exception' {
                            { Publish-WikiContent @script:publishWikiContent_parameters } |
                                Should -Throw ($LocalizedData.NoWikiContentArtifactError -f $mockJobId)
                        }
                    }

                    Context 'When the AppVeyor WikiContent artifact can be downloaded' {
                        BeforeAll {
                            Mock -CommandName Invoke-RestMethod `
                                -ParameterFilter $script:invokeRestMethodWikiContentArtifact_parameterFilter `
                        }

                        It 'Should not throw' {
                            { Publish-WikiContent @script:publishWikiContent_parameters } |
                                Should -Not -Throw
                        }

                        It 'Should call the expected mocks' {
                            Assert-MockCalled `
                                -CommandName Invoke-RestMethod `
                                -ParameterFilter $script:invokeRestMethodWikiContentArtifact_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                                -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitConfigUserEmail_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                               -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitConfigUserName_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                                -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitRemoteSetUrl_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                                -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitAdd_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                                -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitCommit_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                                -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitTag_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                                -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitPush_parameterFilter `
                                -Exactly -Times 1

                            Assert-MockCalled `
                                -CommandName Invoke-Git `
                                -ParameterFilter $script:invokeGitPushBuildVersion_parameterFilter `
                                -Exactly -Times 1
                        }
                    }
                }
            }
        }
    }

    Describe 'DscResource.DocumentationHelper\WikiPages.psm1\New-TempFile' {
        $mockPath = @{
            Name = 'l55xoanl.ojy'

        }
        Context 'When a new temp folder is created' {
            BeforeAll {
            Mock -CommandName New-Item `
                -ParameterFilter { $ItemType -eq 'Directory' } `
                -MockWith { $mockPath }
            }

            It 'Should not throw' {
                { New-TempFolder } | Should -Not -Throw
            }

            It 'Should call the expected mocks' {
                Assert-MockCalled `
                    -CommandName New-Item `
                    -ParameterFilter { $ItemType -eq 'Directory' } `
                    -Exactly -Times 1
            }
        }

        Context 'When a new temp folder cannot be created' {
            BeforeAll {
            Mock -CommandName New-Item `
                -ParameterFilter { $ItemType -eq 'Directory' } `
                -MockWith { $false }
            }

            It 'Should throw the correct error' {
                $tempPath = [System.IO.Path]::GetTempPath()
                { New-TempFolder } | Should -Throw ($localizedData.NewTempFolderCreationError -f $tempPath)
            }

            It 'Should call the expected mocks' {
                Assert-MockCalled `
                    -CommandName New-Item `
                    -ParameterFilter { $ItemType -eq 'Directory' } `
                    -Exactly -Times 10
            }
        }
    }

    Describe 'DscResource.DocumentationHelper\WikiPages.psm1\Set-WikiSideBar' {
        BeforeAll {
            $mockSetWikiSideBarParms = @{
                ResourceModuleName = 'TestResource'
                Path               = $env:temp
            }

            $mockFileInfo = @(
                @{
                    Name     = 'resource1.md'
                    BaseName = 'resource1'
                    FullName = "$($env:temp)\resource1.md"
                }
            )

            $wikiSideBarFileBaseName = '_Sidebar.md'
            $wikiSideBarFileFullName = Join-Path -Path $mockSetWikiSideBarParms.Path -ChildPath $wikiSideBarFileBaseName

            Mock -CommandName Out-File
        }

        Context 'When there are markdown files to add to the side bar' {
            BeforeAll {
                Mock -CommandName Get-ChildItem -MockWith { $mockFileInfo }
            }

            It 'Should not throw an exception' {
                { Set-WikiSideBar @mockSetWikiSideBarParms -Verbose } | Should -Not -Throw
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-ChildItem `
                    -ParameterFilter { $Path -eq $mockSetWikiSideBarParms.Path } `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $wikiSideBarFileFullName } `
                    -Exactly -Times 1
            }
        }
    }

    Describe 'DscResource.DocumentationHelper\WikiPages.psm1\Set-WikiFooter' {
        BeforeAll {
            $mockSetWikiFooterParms = @{
                ResourceModuleName = 'TestResource'
                Path               = $env:temp
            }

            $mockWikiFooterPath = Join-Path -Path $mockSetWikiFooterParms.Path -ChildPath '_Footer.md'

            Mock -CommandName Out-File
        }

        Context 'When there is no pre-existing Wiki footer file' {
            BeforeAll {
                Mock -CommandName Test-Path `
                    -ParameterFilter { $Path -eq $mockWikiFooterPath } `
                    -MockWith { $false }
            }

            It 'Should not throw an exception' {
                { Set-WikiFooter @mockSetWikiFooterParms } | Should -Not -Throw
            }

            It 'Should create the footer file' {
                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $mockWikiFooterPath } `
                    -Exactly -Times 1
            }
        }

        Context 'When there is a pre-existing Wiki footer file' {
            BeforeAll {
                Mock -CommandName Test-Path `
                    -ParameterFilter { $Path -eq $mockWikiFooterPath } `
                    -MockWith { $true }
            }

            It 'Should not throw an exception' {
                { Set-WikiFooter @mockSetWikiFooterParms } | Should -Not -Throw
            }

            It 'Should not create the footer file' {
                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter { $FilePath -eq $mockWikiFooterPath } `
                    -Exactly -Times 0
            }
        }
    }

    Describe 'DscResource.DocumentationHelper\WikiPages.psm1\Copy-WikiFile' {
        BeforeAll {
            $mockCopyWikiFileParms = @{
                MainModulePath   = "$env:temp\TestModule"
                Path             = $env:temp
                WikiSourceFolder = 'WikiSource'
            }

            $mockFileInfo = @(
                @{
                    Name     = 'Home.md'
                    FullName = "$($mockCopyWikiFilParms.MainModulePath)\WikiSource\Home.md"
                }
                @{
                    Name     = 'image.png'
                    FullName = "$($mockCopyWikiFilParms.MainModulePath)\WikiSource\image.png"
                }
            )

            Mock -CommandName Copy-Item
        }

        Context 'When there are no files to copy' {
            BeforeAll {
                Mock -CommandName Get-ChildItem
            }

            It 'Should not throw an exception' {
                { Copy-WikiFile @mockCopyWikiFileParms } | Should -Not -Throw
            }

            It 'Should not copy any files' {
                Assert-MockCalled `
                    -CommandName Copy-Item `
                    -Exactly -Times 0
            }
        }

        Context 'When there are files to copy' {
            BeforeAll {
                Mock -CommandName Get-ChildItem `
                    -MockWith { $mockfileInfo }
            }

            It 'Should not throw an exception' {
                { Copy-WikiFile @mockCopyWikiFileParms } | Should -Not -Throw
            }

            It 'Should copy the correct number of files' {
                Assert-MockCalled `
                    -CommandName Copy-Item `
                    -ParameterFilter { $Destination -eq $env:temp } `
                    -Exactly -Times 2
            }
        }
    }
}

$modulePath = Join-Path -Path $moduleRootPath -ChildPath 'PowerShellHelp.psm1'

Import-Module -Name $modulePath -Force

InModuleScope -ModuleName 'PowerShellHelp' {

    $script:mockOutputPath = Join-Path -Path $ENV:Temp -ChildPath 'docs'
    $script:mockModulePath = Join-Path -Path $ENV:Temp -ChildPath 'module'

    # Schema file info
    $script:mockResourceName = 'MyResource'
    $script:expectedSchemaPath = Join-Path -Path $script:mockModulePath -ChildPath '\**\*.schema.mof'
    $script:mockSchemaBaseName = "MSFT_$($script:mockResourceName).schema"
    $script:mockSchemaFileName = "$($script:mockSchemaBaseName).mof"
    $script:mockSchemaFolder = Join-Path -Path $script:mockModulePath -ChildPath "DSCResources\$($script:mockResourceName)"
    $script:mockSchemaFilePath = Join-Path -Path $script:mockSchemaFolder -ChildPath $script:mockSchemaFileName
    $script:mockSchemaFiles = @(
        @{
            FullName      = $script:mockSchemaFilePath
            Name          = $script:mockSchemaFileName
            DirectoryName = $script:mockSchemaFolder
            BaseName      = $script:mockSchemaBaseName
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
    $script:mockExampleFilePath = Join-Path -Path $script:mockModulePath -ChildPath "\Examples\Resources\$($script:mockResourceName)\$($script:mockResourceName)_Example1_Config.ps1"
    $script:expectedExamplePath = Join-Path -Path $script:mockModulePath -ChildPath "\Examples\Resources\$($script:mockResourceName)\*.ps1"
    $script:mockExampleFiles = @(
        @{
            Name      = "$($script:mockResourceName)_Example1_Config.ps1"
            FullName  = $script:mockExampleFilePath
        }
    )
    $script:mockExampleContent = '.EXAMPLE 1

Example description.

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
}'

    # General mock values
    $script:mockReadmePath = Join-Path -Path $script:mockSchemaFolder -ChildPath 'readme.md'
    $script:mockOutputFile = Join-Path -Path $script:mockOutputPath -ChildPath "$($script:mockResourceName).md"
    $script:mockSavePath = Join-Path -Path $script:mockModulePath -ChildPath "DscResources\$($script:mockResourceName)\en-US\about_$($script:mockResourceName).help.txt"
    $script:mockOutputSavePath = Join-Path -Path $script:mockOutputPath -ChildPath "about_$($script:mockResourceName).help.txt"
    $script:mockGetContentReadme = '# Description

The description of the resource.'
    $script:mockPowerShellHelpOutput = '.NAME
    MyResource

.DESCRIPTION
    The description of the resource.
.PARAMETER Id
    Key - String
    Id Description

.PARAMETER Enum
    Write - String
    Allowed values: Value1, Value2, Value3
    Enum Description.

.PARAMETER Int
    Required - Uint32
    Int Description.

.PARAMETER Read
    Read - String
    Read Description.

.EXAMPLE 1

Example description.

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
'
    Describe 'DscResource.DocumentationHelper\PowerShellHelp.psm1\New-DscResourcePowerShellHelp' {
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
        $script:getDscResourceHelpExampleContent_parameterFilter = {
            $ExamplePath -eq $script:mockExampleFilePath -and $ExampleNumber -eq 1
        }
        $script:outFile_parameterFilter = {
            $FilePath -eq $script:mockSavePath
        }
        $script:outFileInputObject_parameterFilter = {
            $InputObject -eq $script:mockPowerShellHelpOutput -and
            $FilePath -eq $script:mockSavePath
        }
        $script:outFileOutputInputObject_parameterFilter = {
            $InputObject -eq $script:mockPowerShellHelpOutput -and
            $FilePath -eq $script:mockOutputSavePath
        }
        $script:writeWarningDescription_parameterFilter = {
            $Message -eq ($script:localizedData.NoDescriptionFileFoundWarning -f $mockResourceName)
        }
        $script:writeWarningExample_parameterFilter = {
            $Message -eq ($script:localizedData.NoExampleFileFoundWarning -f $mockResourceName)
        }
        # Function call parameters
        $script:newDscResourcePowerShellHelp_parameters = @{
            ModulePath = $script:mockModulePath
        }
        $script:newDscResourcePowerShellHelpOutput_parameters = @{
            ModulePath = $script:mockModulePath
            OutputPath = $script:mockOutputPath
        }

        Context 'When there is no schemas found in the module folder' {
            BeforeAll {
                Mock `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter

                Mock `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFile_parameterFilter
            }

            It 'Should not throw an exception' {
                { New-DscResourcePowerShellHelp @script:newDscResourcePowerShellHelp_parameters } | Should -Not -Throw
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Out-File `
                    -Exactly -Times 0
            }
        }

        Context 'When there is no resource description found' {
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
                    -MockWith { $false }

                Mock `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFile_parameterFilter

                Mock `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningDescription_parameterFilter
            }

            It 'Should not throw an exception' {
                { New-DscResourcePowerShellHelp @script:newDscResourcePowerShellHelp_parameters } | Should -Not -Throw
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningDescription_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFile_parameterFilter `
                    -Exactly -Times 0
            }
        }

        Context 'When there is no resource example file found' {
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

                Mock `
                    -CommandName Get-DscResourceHelpExampleContent

                Mock `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFile_parameterFilter

                Mock `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningExample_parameterFilter
            }

            It 'Should not throw an exception' {
                { New-DscResourcePowerShellHelp @script:newDscResourcePowerShellHelp_parameters } | Should -Not -Throw
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $script:getChildItemSchema_parameterFilter `
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
                    -CommandName Get-DscResourceHelpExampleContent `
                    -ParameterFilter $script:getDscResourceHelpExampleContent_parameterFilter `
                    -Exactly -Times 0

                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFile_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningExample_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningDescription_parameterFilter `
                    -Exactly -Times 0
                }
        }

        Context 'When there is one schema found in the module folder and one example using .EXAMPLE and the OutputPath is specified' {
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
                    -CommandName Get-DscResourceHelpExampleContent `
                    -ParameterFilter $script:getDscResourceHelpExampleContent_parameterFilter `
                    -MockWith { $script:mockExampleContent }

                Mock `
                    -CommandName Out-File

                Mock `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningExample_parameterFilter

                Mock `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningDescription_parameterFilter
            }

            It 'Should not throw an exception' {
                { New-DscResourcePowerShellHelp @script:newDscResourcePowerShellHelpOutput_parameters } | Should -Not -Throw
            }

            It 'Should produce the correct output' {
                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFileOutputInputObject_parameterFilter `
                    -Exactly -Times 1
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
                    -CommandName Get-DscResourceHelpExampleContent `
                    -ParameterFilter $script:getDscResourceHelpExampleContent_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningExample_parameterFilter `
                    -Exactly -Times 0

                Assert-MockCalled `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningDescription_parameterFilter `
                    -Exactly -Times 0
            }
        }

        Context 'When there is one schema found in the module folder and one example using .EXAMPLE and the OutputPath is not specified' {
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
                    -CommandName Get-DscResourceHelpExampleContent `
                    -ParameterFilter $script:getDscResourceHelpExampleContent_parameterFilter `
                    -MockWith { $script:mockExampleContent }

                Mock `
                    -CommandName Out-File

                Mock `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningExample_parameterFilter

                Mock `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningDescription_parameterFilter
            }

            It 'Should not throw an exception' {
                { New-DscResourcePowerShellHelp @script:newDscResourcePowerShellHelp_parameters } | Should -Not -Throw
            }

            It 'Should produce the correct output' {
                Assert-MockCalled `
                    -CommandName Out-File `
                    -ParameterFilter $script:outFileInputObject_parameterFilter `
                    -Exactly -Times 1
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
                    -CommandName Get-DscResourceHelpExampleContent `
                    -ParameterFilter $script:getDscResourceHelpExampleContent_parameterFilter `
                    -Exactly -Times 1

                Assert-MockCalled `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningExample_parameterFilter `
                    -Exactly -Times 0

                Assert-MockCalled `
                    -CommandName Write-Warning `
                    -ParameterFilter $script:writeWarningDescription_parameterFilter `
                    -Exactly -Times 0
            }
        }
    }

    Describe 'DscResource.DocumentationHelper\PowerShellHelp.psm1\Get-DscResourceHelpExampleContent' {
        # Parameter filters
        $script:getContentExample_parameterFilter = {
            $Path -eq $script:mockExampleFilePath
        }

        Context 'When a path to an example file with .EXAMPLE is passed and example number 1' {
            $script:getDscResourceHelpExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 1
                Verbose       = $true
            }

            $script:mockExampleContent = '.EXAMPLE 1

Example Description.

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
'

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
                { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -BeExactly $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .DESCRIPTION is passed and example number 2' {
            $script:getDscResourceHelpExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 2
                Verbose       = $true
            }

            $script:mockExampleContent = '.EXAMPLE 2

Example Description.

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
'

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
                { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -BeExactly $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .SYNOPSIS is passed and example number 3' {
            $script:getDscResourceHelpExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 3
                Verbose       = $true
            }

            $script:mockExampleContent = '.EXAMPLE 3

Example Description.

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
'

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
                { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -BeExactly $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .SYNOPSIS and #Requires is passed and example number 4' {
            $script:getDscResourceHelpExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 4
                Verbose       = $true
            }

            $script:mockExampleContent = '.EXAMPLE 4

Example Description.

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
'

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
                { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -BeExactly $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .DESCRIPTION, #Requires and PSScriptInfo is passed and example number 5' {
            $script:getDscResourceHelpExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 5
                Verbose       = $true
            }

            $script:mockExampleContent = '.EXAMPLE 5

Example Description.

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
'

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
                { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -BeExactly $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file with .SYNOPSIS, .DESCRIPTION and PSScriptInfo is passed and example number 6' {
            $script:getDscResourceHelpExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 6
                Verbose       = $true
            }

            $script:mockExampleContent = '.EXAMPLE 6

Example Synopsis.

Example Description.

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
'

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
                { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -BeExactly $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }

        Context 'When a path to an example file from SharePointDsc resource module and example number 7' {
            $script:getDscResourceHelpExampleContent_parameters = @{
                ExamplePath   = $script:mockExampleFilePath
                ExampleNumber = 7
                Verbose       = $true
            }

            $script:mockExampleContent = '.EXAMPLE 7

This example shows how to deploy Access Services 2013 to the local SharePoint farm.

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
'

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
                { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
            }

            It 'Should return the expected string' {
                $script:result | Should -BeExactly $script:mockExampleContent
            }

            It 'Should call the expected mocks ' {
                Assert-MockCalled `
                    -CommandName Get-Content `
                    -ParameterFilter $script:getContentExample_parameterFilter `
                    -Exactly -Times 1
            }
        }
    }

    Context 'When a path to an example file from CertificateDsc resource module and example number 8' {
        $script:getDscResourceHelpExampleContent_parameters = @{
            ExamplePath   = $script:mockExampleFilePath
            ExampleNumber = 8
            Verbose       = $true
        }

        $script:mockExampleContent = '.EXAMPLE 8

Exports a certificate as a CERT using the friendly name to identify it.

Configuration CertificateExport_CertByFriendlyName_Config
{
    Import-DscResource -ModuleName CertificateDsc

    Node localhost
    {
        CertificateExport SSLCert
        {
            Type         = ''CERT''
            FriendlyName = ''Web Site SSL Certificate for www.contoso.com''
            Path         = ''c:\sslcert.cer''
        }
    }
}
'

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

#Requires -module CertificateDsc

<#
    .DESCRIPTION
        Exports a certificate as a CERT using the friendly name to identify it.
#>
Configuration CertificateExport_CertByFriendlyName_Config
{
    Import-DscResource -ModuleName CertificateDsc

    Node localhost
    {
        CertificateExport SSLCert
        {
            Type         = ''CERT''
            FriendlyName = ''Web Site SSL Certificate for www.contoso.com''
            Path         = ''c:\sslcert.cer''
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
            { $script:result = Get-DscResourceHelpExampleContent @script:getDscResourceHelpExampleContent_parameters } | Should -Not -Throw
        }

        It 'Should return the expected string' {
            $script:result | Should -BeExactly $script:mockExampleContent
        }

        It 'Should call the expected mocks ' {
            Assert-MockCalled `
                -CommandName Get-Content `
                -ParameterFilter $script:getContentExample_parameterFilter `
                -Exactly -Times 1
        }
    }
}
