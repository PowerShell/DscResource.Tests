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

## DSC Resource Common Meta Tests

> Meta.Tests.ps1

### Goals

1. Consistency in encoding and indentations.

  Consistency is good by itself. But more importantly it allows us to:
1. Avoid big diffs with cosmetic changes in Pull Requests.
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

>Note: These functions will only work if called within an AppVeyor CI build task.

* **Invoke-AppveyorInstallTask**: This task is used to set up the environment in
  preparation for the test and deploy tasks.
  It should be called under the install AppVeyor phase (the `install:` keyword in
  the *appveyor.yml*).
* **Invoke-AppveyorTestScriptTask**: This task is used to execute the tests.
  It should be called under test AppVeyor phase (the `test_script:` keyword in
  the *appveyor.yml*).
* **Invoke-AppveyorAfterTestTask**: This task is used to perform the following tasks.
  It should be called either under the test AppVeyor phase (the `test_script:`
  keyword in the *appveyor.yml*), or the after tests AppVeyor phase (the `after_test:`
  keyword in the *appveyor.yml*).
  * Generate, zip and publish the Wiki content to AppVeyor (optional).
  * Set the build number in the DSC Resource Module manifest.
  * Publish the Test Results artefact to AppVeyor.
  * Zip and publish the DSC Resource content to AppVeyor.
* **Invoke-AppVeyorDeployTask**: This task is used to perform the following tasks.
  It should be called under the deploy AppVeyor phase (the `deploy_script:`
  keyword in the *appveyor.yml*).
  * [Publish examples to PowerShell Gallery](#publish-examples-to-powershell-gallery)).

### Phased Meta test Opt-In

New tests may run but only produce errors.  Once you fix the test, please copy
`.MetaTestOptIn.json` from this repo to the root of your repo.  If there is
any new problem in the area, this will cause the tests to fail, not just warn.

The following opt-in flags are available:

* **Common Tests - Validate Module Files**: run tests to validate module files
  have correct BOM.
* **Common Tests - Validate Markdown Files**: run tests to validate markdown
  files do not violate markdown rules. Markdown rules can be suppressed in
  .markdownlint.json file.
* **Common Tests - Validate Example Files**: run tests to validate that examples
  can be compiled without error.
* **Common Tests - Validate Example Files To Be Published**: run tests to
  validate that examples can be published successfully to PowerShell Gallery.
  See requirements under
  [Publish examples to PowerShell Gallery](#publish-examples-to-powershell-gallery).
* **Common Tests - Validate Script Files**: run tests to validate script files
  have correct BOM.
* **Common Tests - Required Script Analyzer Rules**: fail tests if any required
  script analyzer rules are violated.
* **Common Tests - Flagged Script Analyzer Rules**: fail tests if any flagged
  script analyzer rules are violated.
* **Common Tests - New Error-Level Script Analyzer Rules**: fail tests if any
  new error-level script analyzer rules are violated.
* **Common Tests - Custom Script Analyzer Rules**: fail tests if any
  custom script analyzer rules are violated.

### Using AppVeyor.psm1 with the default shared model

For an example of a AppVeyor.yml file for using the default shared model with a
resource module, see the
[DscResource.Template appveyor.yml](https://github.com/PowerShell/DscResources/blob/master/DscResource.Template/appveyor.yml).

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

#### Repository using `-Type 'Harness'` for `Invoke-AppveyorTestScriptTask`

1. Make sure you are properly generating pester code coverage in the repository
   harness code.

### Enable reporting to CodeCove.io

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

* **ContainerName**: The name of the container. If the same container name is used
  in multiple tests they will be run sequentially in the same container.
* **ContainerImage**: The name of the container image to use for the container.
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

* unittest_Transcript.txt - Contains the transcript from the test run that
  was done in the container.
* unittest_TestResults.xml - Contains the Pester output in the NUnitXML
  format from the tests that was tested in the container.
* unittest_TestResults.json - Contains the serialized object that Pester
  returned after it finished the test run in the container.
* unittest_DockerLog.txt - If the container exits with any other exit code
  than 0 a Docker log is gathered and uploaded as an artifact. This is
  intended to enable a more detailed view of the error.
  If the container exits with exit code 0 then the Docker log will *not* be
  uploaded.
* worker_TestsResults - Contains the Pester output in the NUnitXML format
  from the tests that was tested in the build worker.

## Deploy

To run the deploy steps the following must be added to the appveyor.yml. The
default is to opt-in for all the deploy tasks. See comment-based help for
the optional parameters.

```yml
deploy_script:
  - ps: |
        Invoke-AppVeyorDeployTask
```

### Publish examples to PowerShell Gallery

This deploy task is a default opt-in. To opt-out, change the appveyor.yml
to not include the opt-in task *PublishExample*,
e.g. `Invoke-AppVeyorDeployTask -OptIn @()`.

By opt-in for the task *PublishExample* allows the test framework to publish the
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

* Publish only on 'master' build.
* Must have opt-in for the example validation common test.
* Publish only an example that passes `Test-ScriptFileInfo`.
* Publish only an example that does not already exist (for example has a newer
  version).
* Publish only an example which is located under '\Examples' folder.
* Publish only an example where file name ends with 'Config'.
* Publish only an example that where filename and configuration name are the same.
  *Published examples must have the same configuration name as the file name to
  be able to deploy in Azure Automation.*
  * Example files are allowed to begin, be prefixed, with numeric value followed
    by a dash (e.g. '1-', '2-') to support auto-documentation. The prefix will
    be removed from the name when publishing, so the filename will appear without
    the prefix in PowerShell Gallery.
* Publish only examples that have a unique GUID within the resource module.
  *Note: This is only validated within the resource module, the validation
  does not validate this against PowerShell Gallery. This is to prevent
  simple copy/paste mistakes within the same resource module.*
* Publish only an example where the configuration name contains only letters,
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
> which result in the files checked out only have LF as line-ending character.
> `Test-ScriptFileInfo` is unable to parse the files with just LF, to solve this
> the following need to be added to the appveyor.yml.
>
> ```yml
> init:
>   # Needed for publishing of examples, build worker defaults to core.autocrlf=input.
>   - git config --global core.autocrlf true
> ```

#### Contributor responsibilities

Contributors that add or change an example to be published must make sure that

* The example filename is short but descriptive and ends with 'Config'.
  * If the example is for a single resource, then the resource name could be
    prefixed in the filename (and configuration name) followed by an underscore
    (e.g. xScript_WatchFileContentConfig.ps1). *The thought is to easier find
    related examples.*
* The `Node` block is targeting 'localhost' (or equivalent).
* The filename and configuration name match (see requirements/dependencies above).
* The example contains script metadata with all required properties present.
* The example has an unique GUID in the script metadata.
* The example have comment-based help with at least `.DESCRIPTION`.
* The example script metadata version and release notes is updated accordingly.
* (Optional) The example has a `#Requires` statement.

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
* Removed Byte Order Mark (BOM) from the module file TestRunner.psm1.
* Updated so that checking for Byte Order Mark (BOM) in markdown file lists the
  full path so it easier to distinguish when filenames are equal in different
  locations.
* Updated so that module files (.psm1) are checked for Byte Order Mark (BOM)
  (issue #143).
* Updated It-blocks for File Parsing tests so that they are more descriptive for
  the AppVeyor "Tests-view".
* Changed debug message which outputs the type of the $results variable (in
  AppVeyor.psm1) to use Write-Verbose instead of Write-Info ([issue #99](https://github.com/PowerShell/DscResource.Tests/issues/99)).
* Added `Get-ResourceModulesInConfiguration` to `TestHelper.psm1` to get support installing
  DSC Resource modules when testing examples.
* Enable 'Common Tests - Validate Example Files' to install missing required modules if
  running in AppVeyor or show warning if run by user.
* Added new common test so that script files (.ps1) are checked for Byte Order
  Mark (BOM) ([issue #160](https://github.com/PowerShell/DscResource.Tests/issues/160)).
  This test is opt-in using .MetaTestOptIn.json.
* Added minimum viable product for applying custom PSSA rules to check adherence to
  DSC Resource Kit style guidelines ([issue #86](https://github.com/PowerShell/DscResource.Tests/issues/86)).
  The current rules checks the [Parameter()] attribute format is correct in all parameter blocks.
  * Fixed Byte Order Mark (BOM) in files; DscResource.AnalyzerRules.psd1,
  DscResource.AnalyzerRules.psm1 and en-US/DscResource.AnalyzerRules.psd1
  ([issue #169](https://github.com/PowerShell/DscResource.Tests/issues/169)).
  * Extended the parameter custom rule to also validate the Mandatory attribute.
* Fixed so that code coverage can be scan for code even if there is no DSCResource
  folder.
* Added workaround for AppVeyor replaces punctuation in folder structure for
  DscResource.Tests.
* Remove the $repoName variable and replace it with $moduleName as it was a
  duplicate.
* Added so that DscResource.Tests is testing it self with it's own common tests
  ([issue #170](https://github.com/PowerShell/DscResource.Tests/issues/170)).
* Change README.md to resolve lint error MD029 and MD036.
* Added module manifest for manifest common tests to pass.
* Added status badges to README.md.
* Fixed the markdown test so that node_modules can be deleted when path contains
  an apostrophe ([issue #166](https://github.com/PowerShell/DscResource.Tests/issues/166)).
  * Fixed typo in It-blocks when uninstalling dependencies.
* Code was moved from the example tests into a new helper function Install-DependentModule
  ([issue #168](https://github.com/PowerShell/DscResource.Tests/issues/168)).
  Also fixed bug with Version, where Install-Module would not use the correct
  variable for splatting.
* Enable so that missing required modules for integration tests is installed if
  running in AppVeyor or show warning if run by user ([issue #168](https://github.com/PowerShell/DscResource.Tests/issues/168)).
* Set registry key HKLM:\Software\Microsoft\PowerShell\DisablePromptToUpdateHelp
  to 1 when running in AppVeyor to suppress warning caused by running custom rules
  in PSScriptAnalyzer in the GetExternalRule() method of `Engine/ScriptAnalyzer.cs`
  ([issue #176](https://github.com/PowerShell/DscResource.Tests/issues/176)).
* Added unit tests for helper function Start-DscResourceTests.
* Updated AppVeyor code so that common tests and unit tests is run on the working
  branch's tests. This is to be able to test changes to tests in pull requests
  without having to merge the pull request before seeing the result.
* Add opt-in parameter RunTestInOrder for the helper function Invoke-AppveyorTestScriptTask
  which enables running integration tests in order ([issue #184](https://github.com/PowerShell/DscResource.Tests/issues/184)).
  * Refactored the class IntegrationTest to be a public sealed class and using
    a named property for OrderNumber
    ([issue #191](https://github.com/PowerShell/DscResource.Tests/issues/191)).
* Add Script Analyzer custom rule to test functions and statements so that
  opening braces are set according to the style guideline ([issue #27](https://github.com/PowerShell/DscResource.Tests/issues/27)).
* When common tests are running on another repository than DscResource.Tests the
  DscResource.Tests unit and integration tests are removed from the list of tests
  to run ([issue #189](https://github.com/PowerShell/DscResource.Tests/issues/189)).
* Fix ModuleVersion number value inserted into manifest in Nuget package produced
  in Invoke-AppveyorAfterTestTask ([issue #193](https://github.com/PowerShell/DscResource.Tests/issues/193)).
* Fix TestRunner.Tests.ps1 to make compatible with Pester 4.0.7 ([issue #196](https://github.com/PowerShell/DscResource.Tests/issues/196)).
* Improved WikiPages.psm1 to include the EmbeddedInstance to the datatype in the
  generated wiki page ([issue #201](https://github.com/PowerShell/DscResource.Tests/issues/201))
* Added basic support for analyzing TypeDefinitionAst related code e.g. Enum & Class definitions to include
  Basic Brace newline rules
  * Created new unit tests to validate the Analyzer rules pass or fail as expected for these new rules
* Added Test-IsClass Cmdlet to determine if particular Ast objects are members of a Class or not
  * Created new Unit Tests to validate the functionality of said cmdlet
* Modified current Parameter, and AttributeArgument Analyzer Rules to check for Class membership and properly validate in those cases as well as the current Function based Cmdlets
  * Created new unit tests to validate the new Analyzer rules pass or fail as expected for Class based resources
* Minor code cleanup in AppVeyor.psm1.
* Updated documentation in README.md and comment-based help in TestHelp.psm1 to
  use the new name of the renamed SqlServerDsc resource module.
* Fixed minor typo in manifest for the CodeCoverage module.
* Added a wrapper Set-PSModulePath for setting $env:PSModulePath to be able to
  write unit tests for the helper functions with more code coverage.
* Minor typos and cleanup in helper functions.
* Fixed a bug in Install-DependentModule when calling the helper function using
  a specific version to install. Now Get-Module will no longer throw an error
  that it does not have a parameter named 'Version'.
* Added unit test for helper function in TestHelper to increase code coverage.
* Added Invoke-AppveyorTestScriptTask cmdlet functionality for CodeCoverage for Class based resources ([issue #173](https://github.com/PowerShell/DscResource.Tests/issues/173))
* Add opt-in parameter RunInContainer for the helper function Invoke-AppveyorTestScriptTask
  which enables running unit tests in a Docker Windows container. The RunInContainer
  parameter can only be used when the parameter RunTestInOrder is also used.
* Moved helper function Write-Info to the TestHelpers module so it could be reused
  by other modules. The string was changed to output 'UTC' before the time to
  clarify that it is UTC time, and optional parameter 'ForegroundColor' was added
  so that it is possible to change the color of the text that is written.
* Added module DscResource.Container which contain logic to handle the container
  testing when unit tests are run in a Docker Windows container.
* Added Get-OptInStatus function to enable retrieving of an opt-in status
  by name. This is required for implementation of PSSA opt-in rules where
  the describe block contains multiple opt-ins in a single block.
* Added new opt-in flags to allow enforcement of script analyzer rules ([issue #161](https://github.com/PowerShell/DscResource.Tests/issues/161))
* Updated year in DscResources.Tests.psd1 manifest to 2018.
* Fixed bug where common test would throw an error if there were no
  .MetaTestOptIn.json file or it was empty (no opt-ins).
* Added more tests for custom Script Analazyer rules to increased code coverage.
  These new tests call the Measure-functions directly.
* Changed so that DscResource.Tests repository can analyze code coverage for the
  helper modules ([issue #208](https://github.com/PowerShell/DscResource.Tests/issues/208)).
* Importing of the TestHelper.psm1 module is now done at the top of the script of
  AppVeyor.psm1. Previously it was imported in each helper function. This was done
  to make it easier to mock the helper functions inside the TestHelper.psm1 module
  when testing AppVeyor.psm1.
* Changed Get-PSModulePathItem to trim end back slash ([issue #217](https://github.com/PowerShell/DscResource.Tests/issues/217))
* Updated to support running unit tests on PowerShell Core:
  * Updated helper function Test-FileHasByteOrderMark to use `AsByteStream`.
  * Install-PackageProvider will only run if `Find-PackageProvider -Name 'Nuget'`
    returns a package. Currently it is not found on the AppVeyor build worker for
    PowerShell Core.
  * Adding tests to AppVeyor test pane is done by using the RestAPI because the
    cmdlet Add-AppveyorTest is not supported on PowerShell Core yet.
  * All Push-AppveyorArtifact has been changed to use the helper function
    Push-TestArtifact instead.
  * The helper function Push-TestArtifact uses 'appveyor.exe' to upload
    artifacts because the cmdlet Push-AppveyorArtifact is not supported on
    PowerShell Core.
* Fix codecov no longer generates an error message when uploading test coverage
  ([issue #203](https://github.com/PowerShell/DscResource.Tests/issues/203)).
* Added new helper function Get-DscTestContainerInformation to read the container
  information in a particular PowerShell script test file (.Tests.ps1).
* BREAKING CHANGE: For those repositories that are using parameter `RunTestInOrder`
  for the helper function `Invoke-AppveyorTestScriptTask` the
  decoration `[Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1)]` need
  to move from the configuration file to the test file. This was done since unit
  tests do not have configuration files, and also to align the ability to
  define the order and the container information using the same decoration.
  It is also natural to have the decoration in the test files since those are
  the scripts that are actually run in order.
* BREAKING CHANGE: The parameter `RunInDocker` is removed in helper function
  `Invoke-AppveyorTestScriptTask`. Using parameter `RunTestInOrder` will now
  handle running tests in a container, but only if at least on test is decorated
  using `[Microsoft.DscResourceKit.IntegrationTest()]` or
  `[Microsoft.DscResourceKit.UnitTest()]`, together with the correct named arguments.
* Added support for the default shared module to run unit test and integration test
  in a container by decorating each test file with either
  `[Microsoft.DscResourceKit.IntegrationTest()]` or
  `[Microsoft.DscResourceKit.UnitTest()]`.
* DcsResource.Container
  * Now has support for verifying if image, with or without
    a tag, exists locally or needs to be pulled from Docker Hub.
  * Now shows the correct localized message when downloading
    an image.
  * If 'latest' tag is used on the image name, 'docker pull' will be called to
    make sure the local revision of 'latest' is actually the latest revision on
    Docker Hub. If it isn't, then the latest image will be pulled from Docker Hub.
* Updated AppVeyor.Tests
  * Mock for Resolve-CoverageInfo was removed since it was not used.
  * Moved importing of DscResource.CodeCoverage module to top of AppVeyor.psm1
    for easier mocking.
* Codecov is once again uploaded for "Harness"-model resource modules
  ([issue #229](https://github.com/PowerShell/DscResource.Tests/issues/229)).
* Changed Example common test
  * Added support for examples to have mandatory parameters.
  * Added support for all credential parameters, regardless of parameter name.
  * Added support to use the same name both for filename and configuration name.
    Supporting filenames starting with or without a numeric value and a dash,
    e.g '99-MyExample.ps1', or 'MyExample.ps'. Any filename starting with a
    numeric value followed by a dash will be removed. This is to support
    configurations to be able to compile in Azure Automation, but still support
    auto-documentation.
* Add support for publishing examples configurations to PowerShell Gallery if
  opt-in ([issue #234](https://github.com/PowerShell/DscResource.Tests/issues/234)).
* Added new opt-in common test 'Common Tests - Validate Example Files To Be Published'.
  This common test verifies that the examples those name ending with '*Config'
  passes testing of script meta data, and that there are no duplicate GUID's in
  the script meta data (within the examples in the repository).
* Fix bug in `Invoke-AppveyorAfterTestTask` to prevent Wiki generation function
  from getting documentation files from variable `$MainModulePath` defined in
  AppVeyor.yml ([issue #245](https://github.com/PowerShell/DscResource.Tests/issues/245)).
* Added support for example and integration test configurations compilation using
  a certificate, so that there are no more need for PSDscAllowPlainTextPassword
  in configurations ([issue #240](https://github.com/PowerShell/DscResource.Tests/issues/240)).
* Refactored `WikiPages.psm1` to meet guidelines and improve testability.
* Added unit test coverage for `WikiPages.psm1`.
* Added support to Wiki generation for Example files that are formatted in the
  way required by the automatic example publishing code ([issue #247](https://github.com/PowerShell/DscResource.Tests/issues/247)).
* Added `.gitattributes` to force EOL to be CRLF to make testing more consistent
  in unit tests.
* Make sure the latest PowerShellGet is installed on the AppVeyor Build Worker
  ([issue #252](https://github.com/PowerShell/DscResource.Tests/issues/252)).
* Update the example pusblishing example to not use `.EXTERNALMODULEDEPENDENCIES`
  (only #Requires is needed). `.EXTERNALMODULEDEPENDENCIES` is used for external
  dependencies (outside of PowerShell Gallery).
* Example publishing can now use a filename without number prefix
  ([issue #254](https://github.com/PowerShell/DscResource.Tests/issues/254)).
* Update `New-DscSelfSignedCertificate` to set environment variables even if
  certificate already exists.
* Change `Invoke-AppveyorTestScriptTask` to also create a self-signed certificate
  using `New-DscSelfSignedCertificate` so that the certificate environment variables
  are still assigned if the test machine reboots after calling
  `Invoke-AppveyorInstallTask` ([issue #255](https://github.com/PowerShell/DscResource.Tests/issues/255)).
* Change `New-DscSelfSignedCertificate` to write information about certificate
  creation or usage so that `Invoke-AppveyorInstallTask` and
  `Invoke-AppveyorTestScriptTask` does not have to ([issue #259](https://github.com/PowerShell/DscResource.Tests/issues/259)).
* Remove option to use CustomTaskModulePath. It was not used, nor documented. To
  make the unit tests easier the option was removed
  ([issue #263](https://github.com/PowerShell/DscResource.Tests/issues/263)).
* Improved the unit tests for the helper function `Invoke-AppveyorTestScriptTask`,
  adding more test coverage, especially for the container part.
* Moved the import of module DscResource.Container to the top of the module file
  AppVeyor.psm1 to simplify the unit tests.
* Rearranging the `Import-Module` and the comment-based help, in the module file
  AppVeyor.psm1, so that the comment-based help is at the top of the file.
* Fix informational message when publishing examples
  ([issue #261](https://github.com/PowerShell/DscResource.Tests/issues/261)).
* When cloning this repo and checking out the dev branch, the file
  DscResource.AnalyzerRules.Tests.ps1 was always unstaged. This was probably
  due to the .gitattributes file that was introduced in a previous PR.
  EOL in DscResource.AnalyzerRules.Tests.ps1 is now fixed.
* Adding regression tests for
  [issue #70](https://github.com/PowerShell/DscResource.Tests/issues/70)).
* Migrate Pester Test Syntax from v3 -> v4
  ([issue #199](https://github.com/PowerShell/DscResource.Tests/issues/199)).

### 0.2.0.0

* Fixed unicode and path bugs in tests

### 0.1.0.0

* Initial release
