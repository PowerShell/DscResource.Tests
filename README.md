# DscResource.Tests
Common meta tests for PowerShell DSC resources repositories.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## DscResourceCommonTests
### Unreleased
* Extra whitespace trimmed from TestHelper.psm1 (feature of VS Code).
* Removed code to Remove-Module from Initialize-TestEnvironment because not required: Import-Module -force should do the same thing.
* Initialize-TestEnvironment changed to import module being tested into Global scope so that InModuleScope not required in tests.

### 0.2.0.0
* Fixed unicode and path bugs in tests

### 0.1.0.0
* Initial release

## DscResourceTestHelper
### Unreleased

### 0.2.0.0
* Fixed unicode and path bugs in tests

### 0.1.0.0
* Initial release

## Goals

1. Consistency in encoding and indentations.
Consistency is good by itself. But more important it allows us to:
2. Avoid big diffs with cosmetic changes in Pull Requests.
Cosmetic changes (like formatting) make reviews harder.
If you want to include formatting changes (like replacing `"` by `'`),
please make it a **separate commit**.
This will give reviewers an option to review meaningful changes separately from formatting changes.


## Git and Unicode

By default git treats [unicode files as binary files](http://stackoverflow.com/questions/6855712/why-does-git-treat-this-text-file-as-a-binary-file).
You may not notice it if your client (like VS or GitHub for Windows) takes care of such conversion.
History with Unicode files is hardly usable from command line `git`.

```
> git diff
 diff --git a/xActiveDirectory.psd1 b/xActiveDirectory.psd1
 index 0fc1914..55fdb85 100644
Binary files a/xActiveDirectory.psd1 and b/xActiveDirectory.psd1 differ
```

With forced `--text` option it would look like this:

```
> git diff --text
 diff --git a/xActiveDirectory.psd1 b/xActiveDirectory.psd1
 index 0fc1914..55fdb85 100644
 --- a/xActiveDirectory.psd1
 +++ b/xActiveDirectory.psd1
@@ -30,4 +30,4 @@
   C m d l e t s T o E x p o r t   =   ' * '

   }



 -
 \ No newline at end of file
 + #   h e l l o
 \ No newline at end of file
```

Command line `git` version is a core component and should be used as a common denominator.


## MetaFixers Module

We are trying to provide automatic fixers where it's appropriate. A fixer corresponds to a particular test.

For example, if `Files encoding` test from [Meta.Tests.ps1](Meta.Tests.ps1) test fails, you should be able to run `ConvertTo-UTF8` fixer from [MetaFixers.psm1](MetaFixers.psm1).


## TestHelper Module

The test helper module (TestHelper.psm1) contains the following functions:
**New-Nuspec**: Creates a new nuspec file for nuget package.
**Install-ResourceDesigner**: Will attempt to download the xDSCResourceDesignerModule using Nuget package and return the module.
**Initialize-TestEnvironment**: Initializes an environment for running unit or integration tests on a DSC resource.
**Restore-TestEnvironment**: Restores the environment after running unit or integration tests on a DSC resource.


## Templates for Creating Tests

The Template files that are used for creating Unit and Integration tests for a DSC resource are available in the [DSCResources GitHub Repository](https://github.com/PowerShell/DscResources) in the [Tests.Template folder](https://github.com/PowerShell/DscResources/tree/master/Tests.Template)

To use these files, see the [test guidelines](https://github.com/PowerShell/DscResources/blob/master/TestsGuidelines.md) document and the instructions at the top of each template file.

The resource files are:
*[Unit_Template.ps1](https://github.com/PowerShell/DscResources/blob/master/Tests.Template/unit_template.ps1)**: Use to create a set of Unit Pester tests for a single DSC Resource.
**[Integration_Template.ps1](https://github.com/PowerShell/DscResources/blob/master/Tests.Template/integration_template.ps1)**: Use to create a set of Integration Pester tests for a single DSC Resource.
**[Integration_Config_Template.ps1](https://github.com/PowerShell/DscResources/blob/master/Tests.Template/unit_template.ps1)**: Use to create a DSC Configuration file for a single DSC Resource. Used in conjunction with Integration_Template.ps1.


## Example Test Usage

To see examples of the Unit/Integration tests in practice, see the xNetworking MSFT_xFirewall resource:
[Unit Tests](https://github.com/PowerShell/xNetworking/blob/dev/Tests/Unit/MSFT_xFirewall.Tests.ps1)
[Integration Tests](https://github.com/PowerShell/xNetworking/blob/dev/Tests/Integration/MSFT_xFirewall.Integration.Tests.ps1)
[Resource DSC Configuration](https://github.com/PowerShell/xNetworking/blob/dev/Tests/Integration/MSFT_xFirewall.config.ps1)


## Example Usage of DSCResource.Tests in AppVeyor.yml

To automatically download and install the DscResource.Tests in an AppVeyor.yml file, please see the following sample AppVeyor.yml.
[https://github.com/PowerShell/DscResources/blob/master/DscResource.Template/appveyor.yml](https://github.com/PowerShell/DscResources/blob/master/DscResource.Template/appveyor.yml)
