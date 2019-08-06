# DscResource.Tests

Common meta tests and other shared functions for PowerShell DSC resources repositories.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Branches

### master

[![Build status](https://ci.appveyor.com/api/projects/status/github/PowerShell/DscResource.Tests?branch=master&svg=true)](https://ci.appveyor.com/project/PowerShell/dscresource-tests/branch/master)
[![codecov](https://codecov.io/gh/PowerShell/DscResource.Tests/branch/master/graph/badge.svg)](https://codecov.io/gh/PowerShell/DscResource.Tests/branch/master)

This is the branch containing the latest release - no contributions should be made
directly to this branch.

### dev

[![Build status](https://ci.appveyor.com/api/projects/status/github/PowerShell/DscResource.Tests?branch=dev&svg=true)](https://ci.appveyor.com/project/PowerShell/dscresource-tests/branch/dev)
[![codecov](https://codecov.io/gh/PowerShell/DscResource.Tests/branch/dev/graph/badge.svg)](https://codecov.io/gh/PowerShell/DscResource.Tests/branch/dev)

This is the development branch to which contributions should be proposed by contributors
as pull requests.
This branch is used by DSC Resource Kit modules for running common tests.

## Change Log

A full list of changes in each version can be found in the [change log](CHANGELOG.md).

## Table of Contents

<!-- TOC -->

- [DSC Resource Common Meta Tests](#dsc-resource-common-meta-tests)
  - [Common Meta Test Opt-In](#common-meta-test-opt-in)
    - [Common Tests - Validate Markdown Links](#common-tests---validate-markdown-links)
    - [Common Tests - Spellcheck Markdown Files](#common-tests---spellcheck-markdown-files)
    - [Common Tests - Validating Localization](#common-tests---validating-localization)
  - [Markdown Testing](#markdown-testing)
  - [Example Testing](#example-testing)
  - [PSScriptAnalyzer Rules](#psscriptanalyzer-rules)
  - [Skip meta tests (for debug purpose)](#skip-meta-tests-for-debug-purpose)
- [MetaFixers Module](#metafixers-module)
- [TestHelper Module](#testhelper-module)
- [Templates for Creating Tests](#templates-for-creating-tests)
- [Example Test Usage](#example-test-usage)
- [Example Usage of DSCResource.Tests in AppVeyor.yml](#example-usage-of-dscresourcetests-in-appveyoryml)
- [AppVeyor Module](#appveyor-module)
  - [Using AppVeyor.psm1 with the default shared model](#using-appveyorpsm1-with-the-default-shared-model)
  - [Using AppVeyor.psm1 with harness model](#using-appveyorpsm1-with-harness-model)
- [Encrypt Credentials in Integration Tests](#encrypt-credentials-in-integration-tests)
- [CodeCoverage reporting with CodeCov.io](#codecoverage-reporting-with-codecovio)
  - [Ensure Code Coverage is enabled](#ensure-code-coverage-is-enabled)
  - [Enable reporting to CodeCov.io](#enable-reporting-to-codecovio)
  - [Configure CodeCov.io](#configure-codecovio)
  - [Add the badge to the Readme](#add-the-badge-to-the-readme)
- [Documentation Helper Module](#documentation-helper-module)
- [Run integration tests in order](#run-integration-tests-in-order)
  - [Run tests in a Docker Windows container](#run-tests-in-a-docker-windows-container)
- [Deploy](#deploy)
  - [Publish examples to PowerShell Gallery](#publish-examples-to-powershell-gallery)
  - [Publish Wiki Content](#publish-wiki-content)

<!-- /TOC -->

## DSC Resource Common Meta Tests

> Meta.Tests.ps1

### Common Meta Test Opt-In

New tests may run but only produce errors.  Once you fix the test, please copy
`.MetaTestOptIn.json` from this repo to the root of your repo.  If there is
any new problem in the area, this will cause the tests to fail, not just warn.

The following opt-in flags are available:

- **Common Tests - Validate Module Files**: run tests to validate module files
  have correct BOM.
- **Common Tests - Validate Markdown Files**: run tests to validate markdown
  files do not violate markdown rules. Markdown rules can be suppressed in
  .markdownlint.json file.
- **Common Tests - Validate Example Files**: run tests to validate that examples
  can be compiled without error.
- **Common Tests - Validate Example Files To Be Published**: run tests to
  validate that examples can be published successfully to PowerShell Gallery.
  See requirements under
  [Publish examples to PowerShell Gallery](#publish-examples-to-powershell-gallery).
- **Common Tests - Validate Script Files**: run tests to validate script files
  have correct BOM.
- **Common Tests - Required Script Analyzer Rules**: fail tests if any required
  script analyzer rules are violated.
- **Common Tests - Flagged Script Analyzer Rules**: fail tests if any flagged
  script analyzer rules are violated.
- **Common Tests - New Error-Level Script Analyzer Rules**: fail tests if any
  new error-level script analyzer rules are violated.
- **Common Tests - Custom Script Analyzer Rules**: fail tests if any
  custom script analyzer rules are violated.
- **Common Tests - Relative Path Length**: fail tests if the length of the
  relative full path, from the root of the module, exceeds the max hard limit of
  129 characters. 129 characters is the current (known) maximum for a relative
  path to be able to compile a configuration in Azure Automation using a
  DSC resource module.
- **Common Tests - Validate Markdown Links**: fails tests if a link in
  a markdown file is broken.
- **Common Tests - Spellcheck Markdown Files**: fail test if there are any
  spelling errors in the markdown files. There is the possibility to add
  or override words in the `\.vscode\cSpell.json` file.

#### Common Tests - Validate Markdown Links

The test validates the links in markdown files. Any valid GitHub markdown link
will pass the linter.

>**NOTE!** There is currently a bug in the markdown link linter that makes it
>unable to recognize absolute paths where the absolute link starts in a parent
>folder.
>For example, if a markdown file `/Examples/README.md`,
>contains an absolute link pointing to `/Examples/Resources/SqlAG`,
>that link will fail the test. Changing the link to a relative link from the
>README.md file's folder, e.g `Resources/SqlAG` will pass the test.
>See issue [vors/MarkdownLinkCheck#5](https://github.com/vors/MarkdownLinkCheck/issues/5).

#### Common Tests - Spellcheck Markdown Files

When opt-in to this test, if there are any spelling errors in markdown files,
the tests will fail.

>**Note:** The spell checker is case-insensitive, so the words 'AppVeyor' and
>'appveyor' are equal and both are allowed.

If the spell checker ([cSpell](https://www.npmjs.com/package/cspell)) does not
recognize the word, but the word is correct or a specific phrase is not recognized
but should be allowed, then it is possible to add these to a dictionary or tell it to
ignore the word or phrases. This is done by adding a `\.vscode\cSpell.json` in
the repository.

The following JSON is the simplest form of the file `\.vscode\cSpell.json` (see
[cSpell](https://www.npmjs.com/package/cspell) for more settings).

>This settings file will also work together with the Visual Studio Code extension
>[Code Spell Checker](https://marketplace.visualstudio.com/items?itemName=streetsidesoftware.code-spell-checker).
>By using this extension the spelling errors can be caught in real-time.
>When a cSpell.json exists in the .vscode folder, the individual setting in the
>cSpell.json file will override the corresponding setting in the
>Visual Studio Code *User settings* or *Workspace settings* file. This differs
>from adding a *Code Spell Checker* setting to the Visual Studio Code
>*Workspace settings* file, as the *Workspace settings* file will override all
>the settings in the *User settings*.

```json
{
    "ignorePaths": [
        ".git/*",
        ".vscode/*"
    ],
    "language": "en",
    "dictionaries": [
        "powershell"
    ],
    "words": [
        "markdownlint",
        "Codecov"
    ],
    "ignoreRegExpList": [
        "AppVeyor",
        "opencode@microsoft.com",
        "\\.gitattributes"
    ]
}
```

The key `words` should have the words that are normally used when writing text.

The key `ignoreRegExpList` is used to ignore phrases or combinations of words,
such as `AppVeyor`, which will be detected as two different words since it consists
of two words starting with upper-case letters.
To configure [cSpell](https://www.npmjs.com/package/cspell)
to ignore the word combination `AppVeyor`, then we can add a regular expression,
in this case `AppVeyor`. This will cause [cSpell](https://www.npmjs.com/package/cspell)
to ignore part of the text that matches the regular expression.

#### Common Tests - Validating Localization

These tests validate the localization folders and files, and also that
each localization string key is used and there are no missing or extra
localization string keys. These tests will only work if the localization
variable is `$script:localizedData`, and it is a string constant, e.g.
`$script:localizedData.MyStringKey`.

- Should have an en-US localization folder.
- The en-US localization folder should have the correct casing.
- A resource file with the correct name should exist in the localization
  folder.
- The resource or module should use all the localization string keys from
  the localization resource file.
- The localization resource file should not be missing any localization
  string key that is used in the resource or module.
- If there are other localization folders (other than en-US)
  - They should contain a resource file with the correct name.
  - The folders should use the correct casing.
  - All en-US resource file localized string keys must also exist in the
    resource file.
  - There should be no additional localized string keys in the resource
    file that does not exist in the en-US resource file.

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
Invoke-Pester -ExcludeTag @('Markdown')
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
Invoke-Pester -ExcludeTag @('Example')
```

When a repository is opted-in to example testing, each example file in the 'Examples'
folder must have a function named Example which should contain the configuration
which will be tested.

An optional configuration data hash table can be added for any specific data that
needs to be provided to the example configuration. The configuration data hash table
variable name must be `$ConfigurationData` for the test to pick it up. If no
configuration block is provided a default configuration block is used.

### PSScriptAnalyzer Rules

The DSC Resource Common Meta Tests also contains tests for [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) (PSSA) rules.
Along with the built-in PSSA rules, custom rules are tested. Those rules are defined and maintained in this repository in
[DscResource.AnalyzerRules](https://github.com/PowerShell/DscResource.Tests/tree/dev/DscResource.AnalyzerRules). These custom rules are built
to follow the style guideline, and overriding them should be a temporary measure until the code can follow the style guideline

There will be cases where built-in and/or custom PSSA rules may need to be suppressed in scripts or functions.
You can suppress a rule by decorating a script/function or script/function parameter with .NET's
[SuppressMessageAttribute](https://msdn.microsoft.com/en-us/library/system.diagnostics.codeanalysis.suppressmessageattribute.aspx).

When the *Common Tests - PS Script Analyzer on Resource Files* test fails on a PSSA rule, Meta.Tests will use `Write-Warning` to output
Rule Name, Script Name, Line Number, and Rule Message.  When necessary, the rule name can be used to suppress the rule as needed.
For example, the following code would cause the **PSAvoidGlobalVars** built-in PSSA rule to fail:

```powerShell
function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $FeatureName
    )

    $windowsOptionalFeature = Dism\Enable-WindowsOptionalFeature -FeatureName $FeatureName -NoRestart $true

    if ($windowsOptionalFeature.RestartNeeded -eq $true)
    {
        Write-Verbose -Message $script:localizedData.RestartNeeded
        $global:DSCMachineStatus = 1
    }
}
```

In this example, suppression is allowed here because $global:DSCMachineStatus must be set in order to reboot the machine.
To suppress the **PSAvoidGlobalVars** rule for this function, this can be done by using the SuppressMessageAttribute like this:

```powershell
function Set-TargetResource
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $FeatureName
    )

    $windowsOptionalFeature = Dism\Enable-WindowsOptionalFeature -FeatureName $FeatureName -NoRestart $true

    if ($windowsOptionalFeature.RestartNeeded -eq $true)
    {
        Write-Verbose -Message $script:localizedData.RestartNeeded
        $global:DSCMachineStatus = 1
    }
}
```

For further details and examples for suppressing PSSA rules, please see the [Suppressing Rules documentation](https://github.com/PowerShell/PSScriptAnalyzer#suppressing-rules).

### Skip meta tests (for debug purpose)

For debug purpose it is possible to skip the common tests, the tests in the
Meta.Tests.ps1 script file.
When debugging a certain unit test or integration test in AppVeyor, it takes
quite some time for the common test to run before the actual unit or integration
test runs.

To temporarily skip the common tests, the environment variable `SkipAllCommonTests`
can be used.

#### Add environment variable to the appveyor.yml

>**Note:** This environment variable should not be merged, or
>a commit pushed into the branches `dev` or `master`. This environment
>variable is purely for debug purposes _before_ sending in a pull request
>(PR).

Using AppVeyor environment variable.

```yml
environment:
  SkipAllCommonTests: True
```

Or as the first PowerShell line to run when AppVeyor is starting testing.

```yml
test_script:
    - ps: Set-Item -Path env:\SkipAllCommonTests -Value $true
```

## MetaFixers Module

> MetaFixers.psm1

We are trying to provide automatic fixers where it's appropriate. A fixer
corresponds to a particular test.

For example, if `Files encoding` test from [Meta.Tests.ps1](Meta.Tests.ps1) test
fails, you should be able to run `ConvertTo-UTF8` fixer from [MetaFixers.psm1](MetaFixers.psm1).

## TestHelper Module

> TestHelper.psm1

The test helper module (TestHelper.psm1) contains the following functions:

- **New-Nuspec**: Creates a new nuspec file for NuGet package.
- **Install-ResourceDesigner**: Will attempt to download the
  xDSCResourceDesignerModule using NuGet package and return the module.
- **Initialize-TestEnvironment**: Initializes an environment for running unit or
  integration tests on a DSC resource.
- **Restore-TestEnvironment**: Restores the environment after running unit or
  integration tests on a DSC resource.

## Templates for Creating Tests

The Template files that are used for creating Unit and Integration tests for a
DSC resource are available in the [DSCResource.Template GitHub Repository](https://github.com/PowerShell/DscResource.Template)
in the [Tests folder](https://github.com/PowerShell/DscResource.Template/tree/master/Tests)

To use these files, see the [test guidelines](https://github.com/PowerShell/DscResources/blob/master/TestsGuidelines.md)
document and the instructions at the top of each template file.

The resource files are:

- **[Unit_Template.ps1](https://github.com/PowerShell/DscResource.Template/blob/master/Tests/Unit/unit_test_template.ps1)**:
  Use to create a set of Unit Pester tests for a single DSC Resource.
- **[Integration_Template.ps1](https://github.com/PowerShell/DscResource.Template/blob/master/Tests/Integration/integration_test_template.ps1)**:
  Use to create a set of Integration Pester tests for a single DSC Resource.
- **[Integration_Config_Template.ps1](https://github.com/PowerShell/DscResource.Template/blob/master/Tests/Integration/integration_test_template.config.ps1)**:
  Use to create a DSC Configuration file for a single DSC Resource. Used in
  conjunction with Integration_Template.ps1.

## Example Test Usage

To see examples of the Unit/Integration tests in practice, see the NetworkingDsc
MSFT_Firewall resource:

- [Unit Tests](https://github.com/PowerShell/NetworkingDsc/blob/dev/Tests/Unit/MSFT_Firewall.Tests.ps1)
- [Integration Tests](https://github.com/PowerShell/NetworkingDsc/blob/dev/Tests/Integration/MSFT_Firewall.Integration.Tests.ps1)
- [Resource DSC Configuration](https://github.com/PowerShell/NetworkingDsc/blob/dev/Tests/Integration/MSFT_Firewall_add.config.ps1)

## Example Usage of DSCResource.Tests in AppVeyor.yml

To automatically download and install the DscResource.Tests in an AppVeyor.yml
file, please see the following sample AppVeyor.yml.
[https://github.com/PowerShell/DscResource.Template/blob/master/appveyor.yml](https://github.com/PowerShell/DscResource.Template/blob/master/appveyor.yml)

## AppVeyor Module

> AppVeyor.psm1

This module provides functions for building and testing DSC Resources in AppVeyor.

>Note: These functions will only work if called within an AppVeyor CI build task.

- **Invoke-AppveyorInstallTask**: This task is used to set up the environment in
  preparation for the test and deploy tasks.
  It should be called under the install AppVeyor phase (the `install:` keyword in
  the *appveyor.yml*).
- **Invoke-AppveyorTestScriptTask**: This task is used to execute the tests.
  It should be called under test AppVeyor phase (the `test_script:` keyword in
  the *appveyor.yml*).
- **Invoke-AppveyorAfterTestTask**: This task is used to perform the following tasks.
  It should be called either under the test AppVeyor phase (the `test_script:`
  keyword in the *appveyor.yml*), or the after tests AppVeyor phase (the `after_test:`
  keyword in the *appveyor.yml*).
  - Generate, zip and publish the Wiki content to AppVeyor (optional).
  - Set the build number in the DSC Resource Module manifest.
  - Publish the Test Results artefact to AppVeyor.
  - Zip and publish the DSC Resource content to AppVeyor.
- **Invoke-AppVeyorDeployTask**: This task is used to perform the following tasks.
  It should be called under the deploy AppVeyor phase (the `deploy_script:`
  keyword in the *appveyor.yml*).
  - [Publish examples to PowerShell Gallery](#publish-examples-to-powershell-gallery)
  - [Publish Wiki Content](#publish-wiki-content)

### Using AppVeyor.psm1 with the default shared model

For an example of a AppVeyor.yml file for using the default shared model with a
resource module, see the
[DscResource.Template appveyor.yml](https://github.com/PowerShell/DscResource.Template/blob/master/appveyor.yml).

### Using AppVeyor.psm1 with harness model

An example AppVeyor.yml file of using the harness model with a resource module.

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

## Encrypt Credentials in Integration Tests

Any configuration used for an integration test that uses a configuration
that contains credential parameters must be configured to use MOF encryption
by providing a certificate file.

The path to the certificate file must be provided in the `CertificateFile`
property in the `ConfigurationData`.

```powershell
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName        = 'localhost'
            CertificateFile = $env:DscPublicCertificatePath
        }
    )
}
```

When these tests are run in AppVeyor and the *AppVeyor* module is being used
then the `Invoke-AppveyorInstallTask` and/or `Invoke-AppveyorTestScriptTask`
will automatically generate an appropriate certificate file and assign the
path to the environment variable `$env:DscPublicCertificatePath`.

To run the same tests outside of AppVeyor, the certificate can be created and
the path assigned to the `$env:DscPublicCertificatePath` variable by running
the function `New-DscSelfSignedCertificate` from the *TestHelper* module.

```powershell
$certificate = New-DscSelfSignedCertificate
```

## CodeCoverage reporting with CodeCov.io

This is to enable code coverage reporting through
[codecov.io](http://codecov.io) which allows you to report on pull
request and project code coverage.  To use codecov.io, you must have enabled
Pester code coverage, which the first two sections cover.

### Ensure Code Coverage is enabled

#### Repository using `-Type 'Default'` for `Invoke-AppveyorTestScriptTask`

1. On the call to `Invoke-AppveyorTestScriptTask`, make sure you have
   `-CodeCoverage` specified.  This will enable Pester code coverage.

It is possible to control which relative paths, from the root module folder, are
evaluated for code coverage.
By specifying one or more relative paths in the parameter `-CodeCoveragePath`
each path is searched for PowerShell modules files (.psm1). For each relative
folder it will look in the root of the relative path, and also recursively
search the first level subfolders, for PowerShell module files (.psm1).
Defaults to the relative paths 'DSCResources', 'DSCClassResources', and 'Modules'.

#### Repository using `-Type 'Harness'` for `Invoke-AppveyorTestScriptTask`

1. Make sure you are properly generating pester code coverage in the repository
   harness code.

### Enable reporting to CodeCov.io

1. On the call to `Invoke-AppveyorTestScriptTask`, specify
   `-CodeCovIo`.  This will enable reporting to [codecov.io](http://codecov.io)

### Configure CodeCov.io

1. Copy `.codecov.yml` from the root of this repo to the root of your repo.
1. Adjust the code coverage goals if needed. See the
   [CodeCov.io documentation](https://docs.codecov.io/docs/commit-status).

### Add the badge to the Readme

Add the following code below the AppVeyor badge in the main repo `readme.md`,
replacing `<repoName>` with the name of the repository.

```markdown
[![codecov](https://codecov.io/gh/PowerShell/<repoName>/branch/master/graph/badge.svg)](https://codecov.io/gh/PowerShell/<reproName>/branch/master)
[![codecov](https://codecov.io/gh/PowerShell/<repoName>/branch/dev/graph/badge.svg)](https://codecov.io/gh/PowerShell/<reproName>/branch/dev)
```

## Documentation Helper Module

This module consists of the following three nested modules:

### MofHelper

A helper module containing the `Get-MofSchemaObject` function used to return the
contents of the schema.mof files as a PowerShell object to be used in other scripts.

### PowerShellHelp

A module containing the function `New-DscResourcePowerShellHelp` that when run will
process all of the MOF based resources in a specified module directory and create
PowerShell help files for each resource into the resource's en-US subdirectory. These
help files include details on the property types for each resource, as well as a text
description and examples where they exist.

A README.md with a text description must exist in the resource's subdirectory for the
help file to be generated.

When the DSC resource module is imported, these help files can then be read by passing
the name of the resource as a parameter to `Get-Help`.

### WikiPages

A module containing the function `New-DscResourceWikiSite` that is used by some HQRM
DSC Resource modules to produce Wiki Content to be distributed with the DSC Resource
module as well as published in the Wiki section of the DSC Resource repo on GitHub.

It is usually called by the ```Invoke-AppveyorAfterTestTask``` task in AppVeyor.psm1
when the ```-type``` parameter is set to 'Wiki'. For example:

```powershell
Invoke-AppveyorAfterTestTask `
    -Type 'Wiki' `
    -MainModulePath '.\Modules\SharePointDsc\' `
    -ResourceModuleName 'SharePointDsc'
```

## Run integration tests in order

This is only available for resource modules that are using the shared AppVeyor
module model, meaning those resource modules that are calling the helper function
`Invoke-AppveyorTestScriptTask` either without the parameter `-Type`, or has
assigned the value `'Default'` to parameter `-Type`.

>**Note:** Resource modules using the "Harness"-model (e.g SharePointDsc and
> xStorage) must add this functionality per individual resource module.

To run integration tests in order, the resource module must opt-in by calling
helper function `Invoke-AppveyorTestScriptTask` using the switch parameter
`-RunTestInOrder`.

Also, each integration test file ('*.Integration.Tests.ps1') must be decorated
with an attribute `Microsoft.DscResourceKit.IntegrationTest` containing a named
attribute argument 'OrderNumber' and be assigned a numeric value
(`1`, `2`, `3`,..).
The value `0` should not be used since it is reserved for DscResource.Tests,
for making sure the common tests are always run first.

Integration tests will be run in ascending order, so integration tests with
value 1 will be run before integration tests with value 2. If an integration test
does not have a assigned order, it will be run unordered after all ordered tests
have been run.

Example showing how the integration test file could look like to make sure an
integration test is always run as one of the first integration tests.
This should be put a the top of the integration test script file.

```powershell
[Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1)]
param()
```

### Run tests in a Docker Windows container

The same parameter `RunTestInOrder` can also be use to run unit tests or integration
tests in a container. This make it possible to run integration tests and unit tests
in parallel on the same build worker.
The common tests will by default always be run on the AppVeyor build worker.

To run a test in a container, the test must be decorated with the attribute
`Microsoft.DscResourceKit.IntegrationTest` or `Microsoft.DscResourceKit.UnitTest`.

The Pester output from the container, including errors will be sent to
the console in a Pester like format, and they will also be added to the
list of tests in AppVeyor portal. There is transcript from the
test run that is uploaded as artifact in AppVeyor which can contain more
detailed errors why the one test failed.

> **Note:** The transcript catches more output than Pester normally writes
> to the console since it sees all errors that Pester catches with
> `| Should -Throw`.

If the container returns an exit code other than 0, the Docker log for the
container is gathered and uploaded as an artifact. This is intended to enable
a more detailed error of what happened to be displayed.
The Docker log will be searched for any error records. If any are found then
an exception will be thrown which will stop the the tests in the build worker.

#### Named attribute argument

- **ContainerName**: The name of the container. If the same container name is used
  in multiple tests they will be run sequentially in the same container.
- **ContainerImage**: The name of the container image to use for the container.
  This should use the normal Docker format for specifying a Docker image, i.e.
  'microsoft/windowsservercore:latest'. If the tag 'latest' is used, then
  `docker pull` will always run to make sure the latest revision of the image is
  in the local image repository. To use the 'latest' local revision, don't suffix
  the tag 'latest' to the image name.
  ***Note:** If the same container name is used in multiple test and they have different
  container images, the first container image that is loaded from at test will be
  used for all tests.*

#### Example

This example shows how the integration test file would look if the tests should
be run in a container and also run before other integration tests.
This should be put a the top of the integration test script file.

```powershell
[Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1, ContainerName = 'ContainerName', ContainerImage = 'Organization/ImageName:Tag')]
param()
```

This example shows how the integration test file would look if the tests should
be run in a container and not using any specific order.
This should be put a the top of the integration test script file.

```powershell
[Microsoft.DscResourceKit.IntegrationTest(ContainerName = 'ContainerName', ContainerImage = 'Organization/ImageName:Tag')]
param()
```

This example shows how the unit test file would look if the tests should
be run in a container. This should be put a the top of the unit test script file.
***Note:** Unit test does not support ordered testing at this time.*

```powershell
[Microsoft.DscResourceKit.UnitTest(ContainerName = 'ContainerName', ContainerImage = 'Organization/ImageName:Tag')]
param()
```

#### Artifacts when running tests in a container

These are the artifacts that differ when running tests using a container.

- unittest_Transcript.txt - Contains the transcript from the test run that
  was done in the container.
- unittest_TestResults.xml - Contains the Pester output in the NUnitXML
  format from the tests that was tested in the container.
- unittest_TestResults.json - Contains the serialized object that Pester
  returned after it finished the test run in the container.
- unittest_DockerLog.txt - If the container exits with any other exit code
  than 0 a Docker log is gathered and uploaded as an artifact. This is
  intended to enable a more detailed view of the error.
  If the container exits with exit code 0 then the Docker log will *not* be
  uploaded.
- worker_TestsResults - Contains the Pester output in the NUnitXML format
  from the tests that was tested in the build worker.

## Deploy

To run the deploy steps the following must be added to the appveyor.yml. The
default is that opt-in is required for all the deploy tasks. See comment-based help for
the optional parameters.

Example opt-in to both Example Publishing and Wiki Content Publishing:

```yml
deploy_script:
  - ps: |
        Invoke-AppVeyorDeployTask -OptIn PublishExample, PublishWikiContent
```

### Publish examples to PowerShell Gallery

To opt-in to this task, change the appveyor.yml to include the opt-in task
*PublishExample*, e.g. `Invoke-AppVeyorDeployTask -OptIn PublishExample`.

By opting-in to the *PublishExample* task, the test framework will publish the
examples in the AppVeyor deploy step, but only if it is a 'master' branch build
(`$env:APPVEYOR_REPO_BRANCH -eq 'master'`).

> **Note:** It is possible to override the deploy branch in appveyor.yml,
> e.g. `Invoke-AppVeyorDeployTask -Branch @('dev','my-working-branch')`.
> But if building on any other branch than 'master' the task will do a dry run
> (using `-WhatIf`).

By adding script metadata to an example (see `New-ScriptFileInfo`) the resource
module automatically opt-in to publish that example (if already opt-in for the
deploy tasks in the appveyor.yml).

#### Requirements/dependencies for publishing to PowerShell Gallery

- Publish only on 'master' build.
- Must have opt-in for the example validation common test.
- Publish only an example that passes `Test-ScriptFileInfo`.
- Publish only an example that does not already exist (for example has a newer
  version).
- Publish only an example which is located under '\Examples' folder.
- Publish only an example where file name ends with 'Config'.
- Publish only an example that where filename and configuration name are the same.
  *Published examples must have the same configuration name as the file name to
  be able to deploy in Azure Automation.*
  - Example files are allowed to begin, be prefixed, with numeric value followed
    by a dash (e.g. '1-', '2-') to support auto-documentation. The prefix will
    be removed from the name when publishing, so the filename will appear without
    the prefix in PowerShell Gallery.
- Publish only examples that have a unique GUID within the resource module.
  *Note: This is only validated within the resource module, the validation
  does not validate this against PowerShell Gallery. This is to prevent
  simple copy/paste mistakes within the same resource module.*
- Publish only an example where the configuration name contains only letters,
  numbers, and underscores. Where the name starts with a letter, and ends with a
  letter or a number.

#### PowerShell Gallery API key

For the Publish-Script to work each repo that opt-in must have the PowerShell
Gallery account API key as a secure environment variable in appveyor.yml.
For DSC Resource Kit resource modules, this should be the same API key, since
it must be encrypted by an account that has permission to the AppVeyor PowerShell
organization account.

> **Note:** This key can only be used for resource modules under DSC Resource Kit.

```yml
environment:
  gallery_api:
    secure: 9ekJzfsPCDBkyLrfmov83XbbhZ6E2N3z+B/Io8NbDetbHc6hWS19zsDmy7t0Vvxv
```

> **Note:** There was a problem running `Test-ScriptFileInfo` on the AppVeyor
> build worker, because the build worker has the setting `core.autocrlf=input`
> which result in the files checked out only have LF as as the end-of-line (eol)
> character.
> `Test-ScriptFileInfo` is unable to parse the files with just LF. To solve this,
> the best option is to add a `.gitattributes` file to the root of the repository,
> with the following content. This will always make git checkout files with CRLF
> as the end-of-line (eol) characters.

```plaintext
* text eol=crlf
```

#### Contributor responsibilities

Contributors that add or change an example to be published must make sure that

- The example filename is short but descriptive and ends with 'Config'.
  - If the example is for a single resource, then the resource name could be
    prefixed in the filename (and configuration name) followed by an underscore
    (e.g. xScript_WatchFileContentConfig.ps1). *The thought is to easier find
    related examples.*
- The `Node` block is targeting 'localhost' (or equivalent).
- The filename and configuration name match (see requirements/dependencies above).
- The example contains script metadata with all required properties present.
- The example has an unique GUID in the script metadata.
- The example have comment-based help with at least `.DESCRIPTION`.
- The example script metadata version and release notes is updated accordingly.
- (Optional) The example has a `#Requires` statement.

##### Example of script metadata, #Requires statement and comment-based help

> **Note:** The `.PRIVATEDATA` in the script metadata is optional and it is
> for a future implementation to be able to run integration test on the examples.

```powershell
<#PSScriptInfo
.VERSION 1.0.4
.GUID 124cf79c-d637-4e50-8199-5cf4efb3572d
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module @{ModuleName = 'xPSDesiredStateConfiguration';ModuleVersion = '8.2.0.0'}

<#
    .SYNOPSIS
        Creates a file at the given file path with the specified content through
        the xScript resource.

    .DESCRIPTION
        Creates a file at the given file path with the specified content through
        the xScript resource.

    .PARAMETER FilePath
        The path at which to create the file. Defaults to $env:TEMP.

    .PARAMETER FileContent
        The content to set for the new file.
        Defaults to 'Just some sample text to write to the file'.
#>
```

### Publish Wiki Content

To opt-in to this task, change the appveyor.yml to include the opt-in task
*PublishWikiContent*, e.g. `Invoke-AppVeyorDeployTask -OptIn PublishWikiContent`.

By opting-in to the *PublishWikiContent* task, the test framework will publish the
contents of a DSC Resource Module Wiki Content artifact to the relevant GitHub Wiki
repository, but only if it is a 'master' branch build (`$env:APPVEYOR_REPO_BRANCH -eq 'master'`).
A Wiki Sidebar file will be generated, containing links to all of the markdown
files in the Wiki, as well as as a Wiki Footer file. Any files contained within the
`WikiSource` directory of the repository will also be published to the Wiki
overriding any auto generated files.

> **Note:** It is possible to override the deploy branch in appveyor.yml,
> e.g. `Invoke-AppVeyorDeployTask -Branch @('dev','my-working-branch')`.

#### Requirements/dependencies for publishing Wiki Content

- Publish only on 'master' build.
- The `Invoke-AppveyorAfterTestTask` function must be present in the Appveyor
  configuration with a Type of 'Wiki' to generate the Wiki artifact.
- A GitHub Personal Access Token with `repo/public_repo` permissions for a user
  that has at least `Collaborator` access to the relevant DSC Module GitHub repository
  must be generated and then added as a
  [secure variable](https://www.appveyor.com/docs/build-configuration/#secure-variables)
  called `github_access_token` to the `environment` section of the repository's
  `appveyor.yml` file.
- The GitHub Wiki needs to be initialized on a repository before this function is run.

> **Note:** Currently Wiki content files are only added or updated by the function,
> not deleted. Any deletions must be done manually by cloning the Wiki repository and
> deleting the required content.
