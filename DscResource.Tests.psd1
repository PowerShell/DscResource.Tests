@{
    # Version number of this module.
    moduleVersion = '0.3.0.0'

    # ID used to uniquely identify this module
    GUID               = '06ac3e4f-9a59-4961-b261-28e0b3e31035'

    # Author of this module
    Author             = 'Microsoft Corporation'

    # Company or vendor of this module
    CompanyName        = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright          = '(c) 2018 Microsoft Corporation. All rights reserved.'

    # Description of the functionality provided by this module
    Description        = 'Module for common meta tests and other shared functions for PowerShell DSC resources repositories.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion  = '4.0'

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData        = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/PowerShell/DscResource.Tests/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/PowerShell/DscResource.Tests'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
        ReleaseNotes = '- Extra whitespace trimmed from TestHelper.psm1 (feature of VS Code).
- Removed code to Remove-Module from Initialize-TestEnvironment because not
  required: Import-Module -force should do the same thing.
- Initialize-TestEnvironment changed to import module being tested into Global
  scope so that InModuleScope not required in tests.
- Fixed aliases in files
- Initialize-TestEnvironment changed to update the execution policy for the
  current process only
- Restore-TestEnvironment changed to update the execution policy for the
  current process only.
- Cleaned all common tests
  - Added tests for PS Script Analyzer
- Cleaned TestHelper
  - Removed Force parameter from Install-ModuleFromPowerShellGallery
  - Added more test helper functions
- Cleaned MetaFixers and TestRunner
- Updated common test output format
- Added ```Install-NuGetExe``` to TestHelper.psm1
- Fixed up Readme.md to remove markdown violations and resolve duplicate information
- Added ```AppVeyor.psm1``` module
- Added ```DscResource.DocumentationHelper``` modules
- Added new tests for testing Examples and Markdown (using Node/NPM/Gulp)
- Clean up layout of Readme.md to be more logically structured and added more information
  about the new tests and modules
- Added documentation for new tests and features
- Added phased Meta Test roll-out
- Added code coverage report with [codecov.io](http://codecove.io)
- Added default parameter values for HarnessFunctionName and HarnessModulePath in AppVeyor\Invoke-AppveyorTestScriptTask cmdlet
- Fixed bug in DscResource.DocumentationHelper\MofHelper.psm1 when "class" mentioned in MOF file outside of header
- Added ability for DscResource.DocumentationHelper\WikiPages.psm1 to display Array type parameters correctly
- Fixed Wiki Generation to create Markdown that does not violate markdown rules
- Removed violation of markdown rules from Readme.md
- Fixed Wiki Generation when Example header contains parentheses.
- Added so that any error message for each test are also published to the AppVeyor "Tests-view".
- Added a common test to verify so that no markdown files contains Byte Order Mark (BOM) (issue 108).
- Fixed bug where node_modules or .git directories caused errors with long file
  paths for tests
- Added SkipPublisherCheck to Install-Module calls for installing Pester.
  This way it does not conflict with signed Pester module included in Windows.
  - Fixed bug when SkipPublisherCheck does not exist in older versions of the
    Install-Module cmdlet.
- Changed so that markdown lint rules MD013 and MD024 is disabled by default for the markdown common test.
- Added an option to use a markdown lint settings file in the repository which will
  override the default markdown lint settings file in DscResource.Tests repository.
- Added a new parameter ResourceType to the test helper function Initialize-TestEnvironment
  to be able to test class-based resources in the folder DscClassResources.
  The new parameter ResourceType can be set to either "Mof" or "Class".
  Default value for parameter ResourceType is "Mof".
- Changed markdown lint rule MD029 to use the "one" style for ordered lists (issue 115).
- Removed the reference to the function ConvertTo-SpaceIndentation from the warning
  message in the test that checks for tabs in module files. The function
  ConvertTo-SpaceIndentation does not exist anymore ([issue 4](https://github.com/PowerShell/DscResource.Tests/issues/4)).
- Removed Byte Order Mark (BOM) from the module file TestRunner.psm1.
- Updated so that checking for Byte Order Mark (BOM) in markdown file lists the
  full path so it easier to distinguish when filenames are equal in different
  locations.
- Updated so that module files (.psm1) are checked for Byte Order Mark (BOM)
  (issue 143).
- Updated It-blocks for File Parsing tests so that they are more descriptive for
  the AppVeyor "Tests-view".
- Changed debug message which outputs the type of the $results variable (in
  AppVeyor.psm1) to use Write-Verbose instead of Write-Info ([issue 99](https://github.com/PowerShell/DscResource.Tests/issues/99)).
- Added `Get-ResourceModulesInConfiguration` to `TestHelper.psm1` to get support installing
  DSC Resource modules when testing examples.
- Enable "Common Tests - Validate Example Files" to install missing required modules if
  running in AppVeyor or show warning if run by user.
- Added new common test so that script files (.ps1) are checked for Byte Order
  Mark (BOM) ([issue 160](https://github.com/PowerShell/DscResource.Tests/issues/160)).
  This test is opt-in using .MetaTestOptIn.json.
- Added minimum viable product for applying custom PS Script Analyzer rules to
  check adherence to DSC Resource Kit style guidelines
  ([issue 86](https://github.com/PowerShell/DscResource.Tests/issues/86)).
  The current rules checks the [Parameter()] attribute format is correct in all parameter blocks.
  - Fixed Byte Order Mark (BOM) in files; DscResource.AnalyzerRules.psd1,
  DscResource.AnalyzerRules.psm1 and en-US/DscResource.AnalyzerRules.psd1
  ([issue 169](https://github.com/PowerShell/DscResource.Tests/issues/169)).
  - Extended the parameter custom rule to also validate the Mandatory attribute.
- Fixed so that code coverage can be scan for code even if there is no DSCResource
  folder.
- Added workaround for AppVeyor replaces punctuation in folder structure for
  DscResource.Tests.
- Remove the $repoName variable and replace it with $moduleName as it was a
  duplicate.
- Added so that DscResource.Tests is testing it self with it"s own common tests
  ([issue 170](https://github.com/PowerShell/DscResource.Tests/issues/170)).
- Change README.md to resolve lint error MD029 and MD036.
- Added module manifest for manifest common tests to pass.
- Added status badges to README.md.
- Fixed the markdown test so that node_modules can be deleted when path contains
  an apostrophe ([issue 166](https://github.com/PowerShell/DscResource.Tests/issues/166)).
  - Fixed typo in It-blocks when uninstalling dependencies.
- Code was moved from the example tests into a new helper function Install-DependentModule
  ([issue 168](https://github.com/PowerShell/DscResource.Tests/issues/168)).
  Also fixed bug with Version, where Install-Module would not use the correct
  variable for splatting.
- Enable so that missing required modules for integration tests is installed if
  running in AppVeyor or show warning if run by user ([issue 168](https://github.com/PowerShell/DscResource.Tests/issues/168)).
- Set registry key HKLM:\Software\Microsoft\PowerShell\DisablePromptToUpdateHelp
  to 1 when running in AppVeyor to suppress warning caused by running custom rules
  in PSScriptAnalyzer in the GetExternalRule() method of `Engine/ScriptAnalyzer.cs`
  ([issue 176](https://github.com/PowerShell/DscResource.Tests/issues/176)).
- Added unit tests for helper function Start-DscResourceTests.
- Updated AppVeyor code so that common tests and unit tests is run on the working
  branch"s tests. This is to be able to test changes to tests in pull requests
  without having to merge the pull request before seeing the result.
- Add opt-in parameter RunTestInOrder for the helper function Invoke-AppveyorTestScriptTask
  which enables running integration tests in order ([issue 184](https://github.com/PowerShell/DscResource.Tests/issues/184)).
  - Refactored the class IntegrationTest to be a public sealed class and using
    a named property for OrderNumber
    ([issue 191](https://github.com/PowerShell/DscResource.Tests/issues/191)).
- Add Script Analyzer custom rule to test functions and statements so that
  opening braces are set according to the style guideline ([issue 27](https://github.com/PowerShell/DscResource.Tests/issues/27)).
- When common tests are running on another repository than DscResource.Tests the
  DscResource.Tests unit and integration tests are removed from the list of tests
  to run ([issue 189](https://github.com/PowerShell/DscResource.Tests/issues/189)).
- Fix ModuleVersion number value inserted into manifest in NuGet package produced
  in Invoke-AppveyorAfterTestTask ([issue 193](https://github.com/PowerShell/DscResource.Tests/issues/193)).
- Fix TestRunner.Tests.ps1 to make compatible with Pester 4.0.7 ([issue 196](https://github.com/PowerShell/DscResource.Tests/issues/196)).
- Improved WikiPages.psm1 to include the EmbeddedInstance to the datatype in the
  generated wiki page ([issue 201](https://github.com/PowerShell/DscResource.Tests/issues/201))
- Added basic support for analyzing TypeDefinitionAst related code e.g. Enum & Class definitions to include
  Basic Brace newline rules
  - Created new unit tests to validate the Analyzer rules pass or fail as expected for these new rules
- Added Test-IsClass Cmdlet to determine if particular Ast objects are members of a Class or not
  - Created new Unit Tests to validate the functionality of said cmdlet
- Modified current Parameter, and AttributeArgument Analyzer Rules to check for Class membership and properly validate in those cases as well as the current Function based Cmdlets
  - Created new unit tests to validate the new Analyzer rules pass or fail as expected for Class based resources
- Minor code cleanup in AppVeyor.psm1.
- Updated documentation in README.md and comment-based help in TestHelp.psm1 to
  use the new name of the renamed SqlServerDsc resource module.
- Fixed minor typo in manifest for the CodeCoverage module.
- Added a wrapper Set-PSModulePath for setting $env:PSModulePath to be able to
  write unit tests for the helper functions with more code coverage.
- Minor typos and cleanup in helper functions.
- Fixed a bug in Install-DependentModule when calling the helper function using
  a specific version to install. Now Get-Module will no longer throw an error
  that it does not have a parameter named "Version".
- Added unit test for helper function in TestHelper to increase code coverage.
- Added Invoke-AppveyorTestScriptTask cmdlet functionality for CodeCoverage for Class based resources ([issue 173](https://github.com/PowerShell/DscResource.Tests/issues/173))
- Add opt-in parameter RunInContainer for the helper function Invoke-AppveyorTestScriptTask
  which enables running unit tests in a Docker Windows container. The RunInContainer
  parameter can only be used when the parameter RunTestInOrder is also used.
- Moved helper function Write-Info to the TestHelpers module so it could be reused
  by other modules. The string was changed to output "UTC" before the time to
  clarify that it is UTC time, and optional parameter "ForegroundColor" was added
  so that it is possible to change the color of the text that is written.
- Added module DscResource.Container which contain logic to handle the container
  testing when unit tests are run in a Docker Windows container.
- Added Get-OptInStatus function to enable retrieving of an opt-in status
  by name. This is required for implementation of PS Script Analyzer opt-in rules
  where the describe block contains multiple opt-ins in a single block.
- Added new opt-in flags to allow enforcement of script analyzer rules ([issue 161](https://github.com/PowerShell/DscResource.Tests/issues/161))
- Updated year in DscResources.Tests.psd1 manifest to 2018.
- Fixed bug where common test would throw an error if there were no
  .MetaTestOptIn.json file or it was empty (no opt-ins).
- Added more tests for custom PS Script Analyzer rules to increased code coverage.
  These new tests call the Measure-functions directly.
- Changed so that DscResource.Tests repository can analyze code coverage for the
  helper modules ([issue 208](https://github.com/PowerShell/DscResource.Tests/issues/208)).
- Importing of the TestHelper.psm1 module is now done at the top of the script of
  AppVeyor.psm1. Previously it was imported in each helper function. This was done
  to make it easier to mock the helper functions inside the TestHelper.psm1 module
  when testing AppVeyor.psm1.
- Changed Get-PSModulePathItem to trim end back slash ([issue 217](https://github.com/PowerShell/DscResource.Tests/issues/217))
- Updated to support running unit tests on PowerShell Core:
  - Updated helper function Test-FileHasByteOrderMark to use `AsByteStream`.
  - Install-PackageProvider will only run if `Find-PackageProvider -Name "NuGet"`
    returns a package. Currently it is not found on the AppVeyor build worker for
    PowerShell Core.
  - Adding tests to AppVeyor test pane is done by using the RestAPI because the
    cmdlet Add-AppveyorTest is not supported on PowerShell Core yet.
  - All Push-AppveyorArtifact has been changed to use the helper function
    Push-TestArtifact instead.
  - The helper function Push-TestArtifact uses "appveyor.exe" to upload
    artifacts because the cmdlet Push-AppveyorArtifact is not supported on
    PowerShell Core.
- Fix codecov no longer generates an error message when uploading test coverage
  ([issue 203](https://github.com/PowerShell/DscResource.Tests/issues/203)).
- Added new helper function Get-DscTestContainerInformation to read the container
  information in a particular PowerShell script test file (.Tests.ps1).
- BREAKING CHANGE: For those repositories that are using parameter `RunTestInOrder`
  for the helper function `Invoke-AppveyorTestScriptTask` the
  decoration `[Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1)]` need
  to move from the configuration file to the test file. This was done since unit
  tests do not have configuration files, and also to align the ability to
  define the order and the container information using the same decoration.
  It is also natural to have the decoration in the test files since those are
  the scripts that are actually run in order.
- BREAKING CHANGE: The parameter `RunInDocker` is removed in helper function
  `Invoke-AppveyorTestScriptTask`. Using parameter `RunTestInOrder` will now
  handle running tests in a container, but only if at least on test is decorated
  using `[Microsoft.DscResourceKit.IntegrationTest()]` or
  `[Microsoft.DscResourceKit.UnitTest()]`, together with the correct named arguments.
- Added support for the default shared module to run unit test and integration test
  in a container by decorating each test file with either
  `[Microsoft.DscResourceKit.IntegrationTest()]` or
  `[Microsoft.DscResourceKit.UnitTest()]`.
- DcsResource.Container
  - Now has support for verifying if image, with or without
    a tag, exists locally or needs to be pulled from Docker Hub.
  - Now shows the correct localized message when downloading
    an image.
  - If "latest" tag is used on the image name, "docker pull" will be called to
    make sure the local revision of "latest" is actually the latest revision on
    Docker Hub. If it isn"t, then the latest image will be pulled from Docker Hub.
- Updated AppVeyor.Tests
  - Mock for Resolve-CoverageInfo was removed since it was not used.
  - Moved importing of DscResource.CodeCoverage module to top of AppVeyor.psm1
    for easier mocking.
- Codecov is once again uploaded for "Harness"-model resource modules
  ([issue 229](https://github.com/PowerShell/DscResource.Tests/issues/229)).
- Changed Example common test
  - Added support for examples to have mandatory parameters.
  - Added support for all credential parameters, regardless of parameter name.
  - Added support to use the same name both for filename and configuration name.
    Supporting filenames starting with or without a numeric value and a dash,
    e.g "99-MyExample.ps1", or "MyExample.ps". Any filename starting with a
    numeric value followed by a dash will be removed. This is to support
    configurations to be able to compile in Azure Automation, but still support
    auto-documentation.
- Add support for publishing examples configurations to PowerShell Gallery if
  opt-in ([issue 234](https://github.com/PowerShell/DscResource.Tests/issues/234)).
- Added new opt-in common test "Common Tests - Validate Example Files To Be Published".
  This common test verifies that the examples those name ending with "*Config"
  passes testing of script meta data, and that there are no duplicate GUIDs in
  the script meta data (within the examples in the repository).
- Fix bug in `Invoke-AppveyorAfterTestTask` to prevent Wiki generation function
  from getting documentation files from variable `$MainModulePath` defined in
  AppVeyor.yml ([issue 245](https://github.com/PowerShell/DscResource.Tests/issues/245)).
- Added support for example and integration test configurations compilation using
  a certificate, so that there are no more need for PSDscAllowPlainTextPassword
  in configurations ([issue 240](https://github.com/PowerShell/DscResource.Tests/issues/240)).
- Refactored `WikiPages.psm1` to meet guidelines and improve testability.
- Added unit test coverage for `WikiPages.psm1`.
- Added support to Wiki generation for Example files that are formatted in the
  way required by the automatic example publishing code ([issue 247](https://github.com/PowerShell/DscResource.Tests/issues/247)).
- Added `.gitattributes` to force EOL to be CRLF to make testing more consistent
  in unit tests.
- Make sure the latest PowerShellGet is installed on the AppVeyor Build Worker
  ([issue 252](https://github.com/PowerShell/DscResource.Tests/issues/252)).
- Update the example publishing example to not use `.EXTERNALMODULEDEPENDENCIES`
  (only Requires is needed). `.EXTERNALMODULEDEPENDENCIES` is used for external
  dependencies (outside of PowerShell Gallery).
- Example publishing can now use a filename without number prefix
  ([issue 254](https://github.com/PowerShell/DscResource.Tests/issues/254)).
- Update `New-DscSelfSignedCertificate` to set environment variables even if
  certificate already exists.
- Change `Invoke-AppveyorTestScriptTask` to also create a self-signed certificate
  using `New-DscSelfSignedCertificate` so that the certificate environment variables
  are still assigned if the test machine reboots after calling
  `Invoke-AppveyorInstallTask` ([issue 255](https://github.com/PowerShell/DscResource.Tests/issues/255)).
- Change `New-DscSelfSignedCertificate` to write information about certificate
  creation or usage so that `Invoke-AppveyorInstallTask` and
  `Invoke-AppveyorTestScriptTask` does not have to ([issue 259](https://github.com/PowerShell/DscResource.Tests/issues/259)).
- Remove option to use CustomTaskModulePath. It was not used, nor documented. To
  make the unit tests easier the option was removed
  ([issue 263](https://github.com/PowerShell/DscResource.Tests/issues/263)).
- Improved the unit tests for the helper function `Invoke-AppveyorTestScriptTask`,
  adding more test coverage, especially for the container part.
- Moved the import of module DscResource.Container to the top of the module file
  AppVeyor.psm1 to simplify the unit tests.
- Rearranging the `Import-Module` and the comment-based help, in the module file
  AppVeyor.psm1, so that the comment-based help is at the top of the file.
- Fix informational message when publishing examples
  ([issue 261](https://github.com/PowerShell/DscResource.Tests/issues/261)).
- When cloning this repo and checking out the dev branch, the file
  DscResource.AnalyzerRules.Tests.ps1 was always unstaged. This was probably
  due to the .gitattributes file that was introduced in a previous PR.
  EOL in DscResource.AnalyzerRules.Tests.ps1 is now fixed.
- Adding regression tests for
  [issue 70](https://github.com/PowerShell/DscResource.Tests/issues/70)).
- Migrate Pester Test Syntax from v3 -> v4
  ([issue 199](https://github.com/PowerShell/DscResource.Tests/issues/199)).
- Activate GitHub App Review Me.
- Removed the default values of the parameter `ExcludeTag` in favor of using
  opt-in. Default is that those tests are opt-out, and must be opt-in
  ([issue 274](https://github.com/PowerShell/DscResource.Tests/issues/274)).
- Excluding tag "Examples" when calling `Invoke-AppveyorTestScriptTask` since
  this repository will never have examples.
- Added Rule Name to PS Script Analyzer custom rules.
- Added PS Script Analyzer Rule Name to Write-Warning output in meta.tests.
- Removed sections "Goals" and "Git and Unicode" as they have become redundant
  ([issue 282](https://github.com/PowerShell/DscResource.Tests/issues/282)).
- Add a new parameter `-CodeCoveragePath` in the function
  `Invoke-AppveyorTestScriptTask` to be able to add one or more relative
  paths which will be searched for PowerShell modules files (.psm1) to be used
  for evaluating code coverage
  ([issue 114](https://github.com/PowerShell/DscResource.Tests/issues/114)).
- The Modules folder, in the resource module root path, was added as a
  default path to be searched for PowerShell modules files (.psm1) to be
  used for evaluating code coverage.
- Added a pull request template as PULL_REQUEST_TEMPLATE.md that will be shown
  to the contributor when a pull requests are sent in.
- Added a common tests to test the length of the relative file path so the paths
  are not exceeding the current path hard limit in Azure Automation
  ([issue 188](https://github.com/PowerShell/DscResource.Tests/issues/188)).
- Add new opt-in common test for markdown link linting
  ([issue 211](https://github.com/PowerShell/DscResource.Tests/issues/211)).
- Adding opt-in common test for spellchecking markdown files. Opt-in by
  adding "Common Tests - Spellcheck Markdown Files" in the file
  .MetaTestOptIn.json ([issue 211](https://github.com/PowerShell/DscResource.Tests/issues/211)).
- Opt-in for the test "Common Tests - Spellcheck Markdown Files", and added the
  settings file `.vscode\cSpell.json`.
- Move section Phased Meta test Opt-In in the README.md, and renamed it to
  Common Meta test Opt-In ([issue 281](https://github.com/PowerShell/DscResource.Tests/issues/281)).
- Move the change log from README.md to CHANGELOG.md
  ([issue 284](https://github.com/PowerShell/DscResource.Tests/issues/284)).
- Opt-in to the common test ([issue 287](https://github.com/PowerShell/DscResource.Tests/issues/287)).
  - Common Tests - Relative Path Length
  - Common Tests - Validate Markdown Links
- Change the section "PowerShell Gallery API key" in README.md to to use
  `.gitattributes` file instead of `git config --global core.autocrlf true`
  ([issue 280](https://github.com/PowerShell/DscResource.Tests/issues/280)).

'

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}









