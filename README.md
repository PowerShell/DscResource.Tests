# DscResource.Tests

Common meta tests and other shared functions for PowerShell DSC resources repositories.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## DSC Resource Common Meta Tests

> Meta.Tests.ps1

### Goals

1. Consistency in encoding and indentations.

  Consistency is good by itself. But more importantly it allows us to:
2. Avoid big diffs with cosmetic changes in Pull Requests.
  Cosmetic changes (like formatting) make reviews harder.
  If you want to include formatting changes (like replacing `"` by `'`),
  please make it a **separate commit**.
  This will give reviewers an option to review meaningful changes separately
  from formatting changes.

### Git and Unicode

By default git treats [unicode files as binary files](http://stackoverflow.com/questions/6855712/why-does-git-treat-this-text-file-as-a-binary-file).
You may not notice it if your client (like VS or GitHub for Windows) takes care
of such conversion.
History with Unicode files is hardly usable from command line `git`.

```dos
> git diff
 diff --git a/xActiveDirectory.psd1 b/xActiveDirectory.psd1
 index 0fc1914..55fdb85 100644
Binary files a/xActiveDirectory.psd1 and b/xActiveDirectory.psd1 differ
```

With forced `--text` option it would look like this:

```dos
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

### Markdown Testing

> .markdownlint.json
> gulpfile.js
> package.json

The DSC Resource Common Meta Tests contains tests for validating that any
markdown files in a DSC Resource meet the standard markdown guidelines.

These tests use NPM to download Gulp, which then uses a Gulp file to ensure
that the markdown files are correct.

The 'markdown' tests can be excluded when running pester by using:

```PowerShell
Invoke-Pester -ExcludeTag 'Markdown'
```

It is possible to override the default behavior of the markdown validation test.
By default the common tests use the settings in the markdownlint settings file
[.markdownlint.json](/.markdownlint.json). If the file '.markdownlint.json' exists
in the root path of the module repository, then that file will be used as the settings
file.
Please note that there are currently _only two markdown lint rules allowed to be
overridden_, and that is lint rule MD013 (line length) and MD024 (Multiple headers
with the same content). These are disabled by default, and can be enabled by
individual repositories to enforce those linting rules.

### Example Testing

The DSC Resource Common Meta Tests contains tests for validating that any
included Example files work correctly.
These tests are performed by attempting to apply the example DSC Configurations
to the machine running the tests.
This causes them to behave as extra integration tests.

The 'example' tests can be excluded when running pester by using:

```PowerShell
Invoke-Pester -ExcludeTag 'Example'
```

When a repository is opted-in to example testing, each example file in the 'Examples'
folder must have a function named Example which should contain the configuration
which will be tested.

An optional configuration data hash table can be added for any specific data that
needs to be provided to the example configuration. The configuration data hash table
variable name must be `$ConfigurationData` for the test to pick it up. If no
configuration block is provided a default configuration block is used.

## MetaFixers Module

> MetaFixers.psm1

We are trying to provide automatic fixers where it's appropriate. A fixer
corresponds to a particular test.

For example, if `Files encoding` test from [Meta.Tests.ps1](Meta.Tests.ps1) test
fails, you should be able to run `ConvertTo-UTF8` fixer from [MetaFixers.psm1](MetaFixers.psm1).

## TestHelper Module

> TestHelper.psm1

The test helper module (TestHelper.psm1) contains the following functions:

* **New-Nuspec**: Creates a new nuspec file for nuget package.
* **Install-ResourceDesigner**: Will attempt to download the
  xDSCResourceDesignerModule using Nuget package and return the module.
* **Initialize-TestEnvironment**: Initializes an environment for running unit or
  integration tests on a DSC resource.
* **Restore-TestEnvironment**: Restores the environment after running unit or
  integration tests on a DSC resource.

## Templates for Creating Tests

The Template files that are used for creating Unit and Integration tests for a
DSC resource are available in the [DSCResources GitHub Repository](https://github.com/PowerShell/DscResources)
in the [Tests.Template folder](https://github.com/PowerShell/DscResources/tree/master/Tests.Template)

To use these files, see the [test guidelines](https://github.com/PowerShell/DscResources/blob/master/TestsGuidelines.md)
document and the instructions at the top of each template file.

The resource files are:

* **[Unit_Template.ps1](https://github.com/PowerShell/DscResources/blob/master/Tests.Template/unit_template.ps1)**:
  Use to create a set of Unit Pester tests for a single DSC Resource.
* **[Integration_Template.ps1](https://github.com/PowerShell/DscResources/blob/master/Tests.Template/integration_template.ps1)**:
  Use to create a set of Integration Pester tests for a single DSC Resource.
* **[Integration_Config_Template.ps1](https://github.com/PowerShell/DscResources/blob/master/Tests.Template/unit_template.ps1)**:
  Use to create a DSC Configuration file for a single DSC Resource. Used in
  conjunction with Integration_Template.ps1.

## Example Test Usage

To see examples of the Unit/Integration tests in practice, see the xNetworking
MSFT_xFirewall resource:
[Unit Tests](https://github.com/PowerShell/xNetworking/blob/dev/Tests/Unit/MSFT_xFirewall.Tests.ps1)
[Integration Tests](https://github.com/PowerShell/xNetworking/blob/dev/Tests/Integration/MSFT_xFirewall.Integration.Tests.ps1)
[Resource DSC Configuration](https://github.com/PowerShell/xNetworking/blob/dev/Tests/Integration/MSFT_xFirewall.config.ps1)

## Example Usage of DSCResource.Tests in AppVeyor.yml

To automatically download and install the DscResource.Tests in an AppVeyor.yml
file, please see the following sample AppVeyor.yml.
[https://github.com/PowerShell/DscResources/blob/master/DscResource.Template/appveyor.yml](https://github.com/PowerShell/DscResources/blob/master/DscResource.Template/appveyor.yml)

## AppVeyor Module

> AppVeyor.psm1

This module provides functions for building and testing DSC Resources in AppVeyor.

**Note: These functions will only work if called within an AppVeyor CI build task.**

* **Invoke-AppveyorInstallTask**: This task is used to set up the environment in
  preparation for the test and deploy tasks.
  It should be called in the _install_ AppVeyor phase.
* **Invoke-AppveyorTestScriptTask**: This task is used to execute the tests.
  It should be called in the _test_script_ AppVeyor phase.
* **Invoke-AppveyorAfterTestTask**: This task is used to perform the following tasks:
  * Generate, zip and publish the Wiki content to AppVeyor (optional).
  * Set the build number in the DSC Resource Module manifest.
  * Publish the Test Results artefact to AppVeyor.
  * Zip and publish the DSC Resource content to AppVeyor.
  It should be called in the _test_script_ AppVeyor phase.

### Phased Meta test Opt-In

New tests may run but only produce errors.  Once you fix the test, please copy
`.MetaTestOptIn.json` from this repo to the root of your repo.  If there is
any new problem in the area, this will cause the tests to fail, not just warn.

### Using AppVeyor.psm1 with eXperiemental DSC Resources

An example ```AppVeyor.yml``` file used in an 'experimental' DSC Resource where the
AppVeyor.psm1 module is being used:

```yml
version: 4.0.{build}.0
install:
    - git clone https://github.com/PowerShell/DscResource.Tests

    - ps: |
        Import-Module "$env:APPVEYOR_BUILD_FOLDER\DscResource.Tests\AppVeyor.psm1"
        Invoke-AppveyorInstallTask

build: false

test_script:
    - ps: |
        Invoke-AppveyorTestScriptTask -CodeCoverage

deploy_script:
    - ps: |
        Invoke-AppveyorAfterTestTask
```

### Using AppVeyor.psm1 with HQRM DSC Resources

An example ```AppVeyor.yml``` file used in an 'HQRM' DSC Resource where the
AppVeyor.psm1 module is being used:

```yml
version: 3.1.{build}.0
install:
    - git clone https://github.com/PowerShell/DscResource.Tests

    - ps: |
        $moduleName = 'xNetworking'
        $mainModuleFolder = "Modules\$moduleName"
        $harnessModulePath = "Tests\$($moduleName).TestHarness.psm1"
        $harnessFunctionName = "Invoke-$($moduleName)Test"
        Import-Module "$env:APPVEYOR_BUILD_FOLDER\DscResource.Tests\AppVeyor.psm1"
        Invoke-AppveyorInstallTask

build: false

test_script:
    - ps: |
        Invoke-AppveyorTestScriptTask `
            -Type 'Harness' `
            -MainModulePath $mainModuleFolder `
            -HarnessModulePath $harnessModulePath `
            -HarnessFunctionName $harnessFunctionName

deploy_script:
    - ps: |
        Invoke-AppveyorAfterTestTask `
            -Type 'Wiki' `
            -MainModulePath $mainModuleFolder `
            -ResourceModuleName $moduleName
```

## CodeCoverage reporting with CodeCov.io

This is to enable code coverage reporting through
[codecov.io](http://codecov.io) which allows you to report on pull
request and project code coverage.  To use codecov.io, you must have enabled
Pester code coverage, which the first two sections cover.

### Ensure Code Coverage is enabled

#### Repos using `-Type 'Default'` for `Invoke-AppveyorTestScriptTask`

1. On the call to `Invoke-AppveyorTestScriptTask`, make sure you have
    `-CodeCoverage` specified.  This will enable Pester code coverage.

#### Repos using `-Type 'Harness'` for `Invoke-AppveyorTestScriptTask`

1. Make sure you are properly generating pester code coverage in the repo's
    harness code.

### Enable reporting to CodeCove.io

1. On the call to `Invoke-AppveyorTestScriptTask`, specify
    `-CodeCovIo`.  This will enable reporting to [codecov.io](http://codecov.io)

### Configure CodeCov.io

1. Copy `.codecov.io` from the root of this repo to the root of your repo.
2. Adjust the code coverage goals if needed.  See the [CodeCov.io documentation](https://docs.codecov.io/docs/commit-status).

### Add the badge to the Readme

Add the following code below the AppVeyor badge in the main repo `readme.md`,
replacing `<reproName>` with the name of the repo

```markdown
[![codecov](https://codecov.io/gh/PowerShell/<reproName>/branch/master/graph/badge.svg)](https://codecov.io/gh/PowerShell/<reproName>)
```

## Documentation Helper Module

> DscResource.DocumentationHelper\DscResource.DocumentationHelper.psd1
> DscResource.DocumentationHelper\MofHelper.psm1
> DscResource.DocumentationHelper\PowerShellHelp.psm1
> DscResource.DocumentationHelper\WikiPages.psm1

This module is used by some HQRM DSC Resource modules to produce Wiki Content to
be distributed with the DSC Resource module as well as published in the Wiki
section of the DSC Resource repo on GitHub.

It is usually called by the ```Invoke-AppveyorAfterTestTask``` task in AppVeyor.psm1
when the ```-type``` parameter is set to 'Wiki'. For example:

```powershell
Invoke-AppveyorAfterTestTask `
    -Type 'Wiki' `
    -MainModulePath '.\Modules\SharePointDsc\' `
    -ResourceModuleName 'SharePointDsc'
```

## Versions

### Unreleased

* Extra whitespace trimmed from TestHelper.psm1 (feature of VS Code).
* Removed code to Remove-Module from Initialize-TestEnvironment because not
  required: Import-Module -force should do the same thing.
* Initialize-TestEnvironment changed to import module being tested into Global
  scope so that InModuleScope not required in tests.
* Fixed aliases in files
* Initialize-TestEnvironment changed to update the execution policy for the
  current process only
* Restore-TestEnvironment changed to update the execution policy for the
  current process only.
* Cleaned all common tests
  * Added tests for PS Script Analyzer
* Cleaned TestHelper
  * Removed Force parameter from Install-ModuleFromPowerShellGallery
  * Added more test helper functions
* Cleaned MetaFixers and TestRunner
* Updated common test output format
* Added ```Install-NugetExe``` to TestHelper.psm1
* Fixed up Readme.md to remove markdown violations and resolve duplicate information
* Added ```AppVeyor.psm1``` module
* Added ```DscResource.DocumentationHelper``` modules
* Added new tests for testing Examples and Markdown (using Node/NPM/Gulp)
* Clean up layout of Readme.md to be more logically structured and added more information
  about the new tests and modules
* Added documentation for new tests and features
* Added phased Meta Test roll-out
* Added code coverage report with [codecov.io](http://codecove.io)
* Added default parameter values for HarnessFunctionName and HarnessModulePath in AppVeyor\Invoke-AppveyorTestScriptTask cmdlet
* Fixed bug in DscResource.DocumentationHelper\MofHelper.psm1 when 'class' mentioned in MOF file outside of header
* Added ability for DscResource.DocumentationHelper\WikiPages.psm1 to display Array type parameters correctly
* Fixed Wiki Generation to create Markdown that does not violate markdown rules
* Removed violation of markdown rules from Readme.md
* Fixed Wiki Generation when Example header contains parentheses.
* Added so that any error message for each test are also published to the AppVeyor "Tests-view".
* Added a common test to verify so that no markdown files contains Byte Order Mark (BOM) (issue #108).
* Fixed bug where node_modules or .git directories caused errors with long file
  paths for tests
* Added SkipPublisherCheck to Install-Module calls for installing Pester.
  This way it does not conflict with signed Pester module included in Windows.
  * Fixed bug when SkipPublisherCheck does not exist in older versions of the
    Install-Module cmdlet.
* Changed so that markdown lint rules MD013 and MD024 is disabled by default for the markdown common test.
* Added an option to use a markdown lint settings file in the repository which will
  override the default markdown lint settings file in DscResource.Tests repository.
* Added a new parameter ResourceType to the test helper function Initialize-TestEnvironment
  to be able to test class-based resources in the folder DscClassResources.
  The new parameter ResourceType can be set to either 'Mof' or 'Class'.
  Default value for parameter ResourceType is 'Mof'.
* Changed markdown lint rule MD029 to use the 'one' style for ordered lists (issue #115).
* Removed the reference to the function ConvertTo-SpaceIndentation from the warning
  message in the test that checks for tabs in module files. The function
  ConvertTo-SpaceIndentation does not exist anymore ([issue #4](https://github.com/PowerShell/DscResource.Tests/issues/4)).

### 0.2.0.0

* Fixed unicode and path bugs in tests

### 0.1.0.0

* Initial release
