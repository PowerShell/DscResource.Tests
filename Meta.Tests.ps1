<#
    .SYNOPSIS
        Common tests for all resource modules in the DSC Resource Kit.
#>
# Suppressing this because we need to generate a mocked credentials that will be passed along to the examples that are needed in the tests.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

Set-StrictMode -Version 'Latest'
$errorActionPreference = 'Stop'

$testHelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperModulePath

# Check if there is a request to override the common tests in this file.
$skipAllCommonTests = Get-Item -Path 'env:\SkipAllCommonTests' -ErrorAction 'SilentlyContinue'
if ($null -ne $skipAllCommonTests -and $skipAllCommonTests.Value -eq $true)
{
    Write-Warning -Message 'DEBUG WARNING: Overriding common test because environment variable OverrideCommonTests is set to $true.'
    return
}

$moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent

<#
    This is a workaround to be able to run these common test on DscResource.Tests
    module, for testing itself.
#>
if (Test-IsRepositoryDscResourceTests)
{
    $moduleRootFilePath = $PSScriptRoot

    <#
        Because the repository name of 'DscResource.Tests' has punctuation in
        the name, AppVeyor replaces that with a dash when it creates the folder
        structure, so the folder name becomes 'dscresource-tests'.
        This sets the module name to the correct name.
        If the name can be detected in a better way, for DscResource.Tests
        and all other modules, then this could be removed.
    #>
    $moduleName = 'DscResource.Tests'
}
else
{
    $moduleName = (Get-Item -Path $moduleRootFilePath).Name
}

$dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath 'DscResources'

if (-not (Test-Path -Path $dscResourcesFolderFilePath))
{
    $dscResourcesFolderFilePath = $moduleRootFilePath
}

# Identify the repository root path of the resource module
$repoRootPath = $moduleRootFilePath
$repoRootPathFound = $false
while (-not $repoRootPathFound `
        -and -not ([String]::IsNullOrEmpty((Split-Path -Path $repoRootPath -Parent))))
{
    if (Get-ChildItem -Path $repoRootPath -Filter '.git' -Directory -Force)
    {
        $repoRootPathFound = $true
        break
    }
    else
    {
        $repoRootPath = Split-Path -Path $repoRootPath -Parent
    }
}
if (-not $repoRootPathFound)
{
    Write-Warning -Message ('The root folder of the DSC Resource repository could ' + `
            'not be located. This may prevent some markdown files from being checked for ' + `
            'errors. Please ensure this repository has been cloned using Git.')
    $repoRootPath = $moduleRootFilePath
}

$testOptInFilePath = Join-Path -Path $repoRootPath -ChildPath '.MetaTestOptIn.json'
# .MetaTestOptIn.json should be in the following format
# [
#     "Common Tests - Validate Module Files",
#     "Common Tests - Validate Markdown Files",
#     "Common Tests - Validate Example Files",
#     "Common Tests - Validate Script Files"
# ]

$optIns = @()
if (Test-Path $testOptInFilePath)
{
    $optIns = Get-Content -LiteralPath $testOptInFilePath | ConvertFrom-Json
}


Describe 'Common Tests - Relative Path Length' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    Context -Name 'When the resource should be used to compile a configuration in Azure Automation' {
        <#
            129 characters is the current maximum for a relative path to be
            able to compile configurations in Azure Automation.
        #>
        $fullPathHardLimit = 129
        $allModuleFiles = Get-ChildItem -Path $moduleRootFilePath -Recurse

        $allModuleFiles = $allModuleFiles | Where-Object -FilterScript {
            # Skip all files under DscResource.Tests.
            $_.FullName -notmatch 'DscResource\.Tests'
        }

        $testCaseModuleFile = @()

        $allModuleFiles | ForEach-Object -Process {
            $testCaseModuleFile += @(
                @{
                    FullRelativePath = $_.FullName -replace ($moduleRootFilePath -replace '\\', '\\')
                }
            )
        }

        It 'The length of the relative full path <FullRelativePath> should not exceed the max hard limit' -TestCases $testCaseModuleFile -Skip:(!$optIn) {
            param
            (
                [Parameter()]
                [System.String]
                $FullRelativePath
            )

            $FullRelativePath.Length | Should -Not -BeGreaterThan $fullPathHardLimit
        }
    }
}

Describe 'Common Tests - File Formatting' {
    $textFiles = Get-TextFilesList $moduleRootFilePath

    It "Should not contain any files with Unicode file encoding" {
        $containsUnicodeFile = $false

        foreach ($textFile in $textFiles)
        {
            if (Test-FileInUnicode $textFile)
            {
                if ($textFile.Extension -ieq '.mof')
                {
                    Write-Warning -Message "File $($textFile.FullName) should be converted to ASCII. Use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-ASCII'."
                }
                else
                {
                    Write-Warning -Message "File $($textFile.FullName) should be converted to UTF-8. Use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-UTF8'."
                }

                $containsUnicodeFile = $true
            }
        }

        $containsUnicodeFile | Should -Be $false
    }

    It 'Should not contain any files with tab characters' {
        $containsFileWithTab = $false

        foreach ($textFile in $textFiles)
        {
            $fileName = $textFile.FullName
            $fileContent = Get-Content -Path $fileName -Raw

            $tabCharacterMatches = $fileContent | Select-String "`t"

            if ($null -ne $tabCharacterMatches)
            {
                Write-Warning -Message "Found tab character(s) in $fileName."
                $containsFileWithTab = $true
            }
        }

        $containsFileWithTab | Should -Be $false
    }

    It 'Should not contain empty files' {
        $containsEmptyFile = $false

        foreach ($textFile in $textFiles)
        {
            $fileContent = Get-Content -Path $textFile.FullName -Raw

            if ([String]::IsNullOrWhiteSpace($fileContent))
            {
                Write-Warning -Message "File $($textFile.FullName) is empty. Please remove this file."
                $containsEmptyFile = $true
            }
        }

        $containsEmptyFile | Should -Be $false
    }

    It 'Should not contain files without a newline at the end' {
        $containsFileWithoutNewLine = $false

        foreach ($textFile in $textFiles)
        {
            $fileContent = Get-Content -Path $textFile.FullName -Raw

            if (-not [String]::IsNullOrWhiteSpace($fileContent) -and $fileContent[-1] -ne "`n")
            {
                if (-not $containsFileWithoutNewLine)
                {
                    Write-Warning -Message 'Each file must end with a new line.'
                }

                Write-Warning -Message "$($textFile.FullName) does not end with a new line. Use fixer function 'Add-NewLine'"

                $containsFileWithoutNewLine = $true
            }
        }


        $containsFileWithoutNewLine | Should -Be $false
    }

    Context 'When repository contains markdown files' {
        $markdownFileExtensions = @('.md')

        $markdownFiles = $textFiles |
        Where-Object { $markdownFileExtensions -contains $_.Extension }

        foreach ($markdownFile in $markdownFiles)
        {
            $filePathOutputName = Get-RelativePathFromModuleRoot `
                -FilePath $markdownFile.FullName `
                -ModuleRootFilePath $moduleRootFilePath

            It ('Markdown file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) {
                $markdownFileHasBom = Test-FileHasByteOrderMark -FilePath $markdownFile.FullName

                if ($markdownFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $markdownFileHasBom | Should -Be $false
            }
        }
    }
}

Describe 'Common Tests - Validate Script Files' -Tag 'Script' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    $scriptFilesFilterScript = {
        '.ps1' -eq $_.Extension
    }

    $scriptFiles = Get-TextFilesList -Root $moduleRootFilePath | Where-Object -FilterScript $scriptFilesFilterScript

    foreach ($scriptFile in $scriptFiles)
    {
        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $scriptFile.FullName `
            -ModuleRootFilePath $moduleRootFilePath

        Context $filePathOutputName {
            It ('Script file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) -Skip:(!$optIn) {
                $scriptFileHasBom = Test-FileHasByteOrderMark -FilePath $scriptFile.FullName

                if ($scriptFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $scriptFileHasBom | Should -Be $false
            }
        }
    }
}

Describe 'Common Tests - .psm1 File Parsing' {
    $psm1Files = Get-Psm1FileList -FilePath $moduleRootFilePath

    foreach ($psm1File in $psm1Files)
    {
        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $psm1File.FullName `
            -ModuleRootFilePath $moduleRootFilePath

        Context $filePathOutputName {
            It ('Module file ''{0}'' should not contain parse errors' -f $filePathOutputName) {
                $containsParseErrors = $false

                $parseErrors = Get-FileParseErrors -FilePath $psm1File.FullName

                if ($null -ne $parseErrors)
                {
                    Write-Warning -Message "There are parse errors in $($psm1File.FullName):"
                    Write-Warning -Message ($parseErrors | Format-List | Out-String)

                    $containsParseErrors = $true
                }

                $containsParseErrors | Should -Be $false
            }
        }
    }
}

Describe 'Common Tests - Validate Module Files' -Tag 'Module' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    $moduleFiles = Get-Psm1FileList -FilePath $moduleRootFilePath

    foreach ($moduleFile in $moduleFiles)
    {
        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $moduleFile.FullName `
            -ModuleRootFilePath $moduleRootFilePath

        Context $filePathOutputName {
            It ('Module file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) -Skip:(!$optIn) {
                $moduleFileHasBom = Test-FileHasByteOrderMark -FilePath $moduleFile.FullName

                if ($moduleFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $moduleFileHasBom | Should -Be $false
            }
        }
    }
}

Describe 'Common Tests - Module Manifest' {
    $containsClassResource = Test-ModuleContainsClassResource -ModulePath $moduleRootFilePath

    if ($containsClassResource)
    {
        $minimumPSVersion = [Version]'5.0'
    }
    else
    {
        $minimumPSVersion = [Version]'4.0'
    }

    $moduleManifestPath = Join-Path -Path $moduleRootFilePath -ChildPath "$moduleName.psd1"

    <#
        ErrorAction specified as SilentelyContinue because this call will throw an error
        on machines with an older PS version than the manifest requires. WMF 5.1 machines
        are not yet available on AppVeyor, so modules that require 5.1 (PSDscResources)
        would always crash this test.
    #>
    $moduleManifestProperties = Test-ModuleManifest -Path $moduleManifestPath -ErrorAction 'SilentlyContinue'

    It "Should contain a PowerShellVersion property of at least $minimumPSVersion based on resource types" {
        $moduleManifestProperties.PowerShellVersion -ge $minimumPSVersion | Should -Be $true
    }

    if ($containsClassResource)
    {
        $classResourcesInModule = Get-ClassResourceNameFromFile -FilePath $moduleRootFilePath

        Context 'Requirements for manifest of module with class-based resources' {
            foreach ($classResourceInModule in $classResourcesInModule)
            {
                It "Should explicitly export $classResourceInModule in DscResourcesToExport" {
                    $moduleManifestProperties.ExportedDscResources -contains $classResourceInModule | Should -Be $true
                }

                It "Should include class module $classResourceInModule.psm1 in NestedModules" {
                    $moduleManifestProperties.NestedModules.Name -contains $classResourceInModule | Should -Be $true
                }
            }
        }
    }
}

Describe 'Common Tests - Script Resource Schema Validation' {
    Import-xDscResourceDesigner

    $scriptResourceNames = Get-ModuleScriptResourceNames -ModulePath $moduleRootFilePath
    foreach ($scriptResourceName in $scriptResourceNames)
    {
        Context $scriptResourceName {
            $scriptResourcePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $scriptResourceName

            It 'Should pass Test-xDscResource' {
                Test-xDscResource -Name $scriptResourcePath | Should -Be $true
            }

            It 'Should pass Test-xDscSchema' {
                $mofSchemaFilePath = Join-Path -Path $scriptResourcePath -ChildPath "$scriptResourceName.schema.mof"
                Test-xDscSchema -Path $mofSchemaFilePath | Should -Be $true
            }
        }
    }
}

<#
    PSSA = PS Script Analyzer

    The following PSSA tests will always fail if any violations are found:
    - Common Tests - Error-Level Script Analyzer Rules
    - Common Tests - Custom Script Analyzer Rules

    The following PSSA tests will only fail if a violation is found and
    a matching option is found in the opt-in file.
    - Common Tests - Required Script Analyzer Rules
    - Common Tests - Flagged Script Analyzer Rules
    - Common Tests - New Error-Level Script Analyzer Rules
    - Common Tests - Custom Script Analyzer Rules
#>
Describe 'Common Tests - PS Script Analyzer on Resource Files' {

    # PSScriptAnalyzer requires PowerShell 5.0 or higher
    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        Import-PSScriptAnalyzer

        $requiredPssaRuleNames = @(
            'PSAvoidDefaultValueForMandatoryParameter',
            'PSAvoidDefaultValueSwitchParameter',
            'PSAvoidInvokingEmptyMembers',
            'PSAvoidNullOrEmptyHelpMessageAttribute',
            'PSAvoidUsingCmdletAliases',
            'PSAvoidUsingComputerNameHardcoded',
            'PSAvoidUsingDeprecatedManifestFields',
            'PSAvoidUsingEmptyCatchBlock',
            'PSAvoidUsingInvokeExpression',
            'PSAvoidUsingPositionalParameters',
            'PSAvoidShouldContinueWithoutForce',
            'PSAvoidUsingWMICmdlet',
            'PSAvoidUsingWriteHost',
            'PSDSCReturnCorrectTypesForDSCFunctions',
            'PSDSCStandardDSCFunctionsInResource',
            'PSDSCUseIdenticalMandatoryParametersForDSC',
            'PSDSCUseIdenticalParametersForDSC',
            'PSMissingModuleManifestField',
            'PSPossibleIncorrectComparisonWithNull',
            'PSProvideCommentHelp',
            'PSReservedCmdletChar',
            'PSReservedParams',
            'PSUseApprovedVerbs',
            'PSUseCmdletCorrectly',
            'PSUseOutputTypeCorrectly'
        )

        $flaggedPssaRuleNames = @(
            'PSAvoidGlobalVars',
            'PSAvoidUsingConvertToSecureStringWithPlainText',
            'PSAvoidUsingPlainTextForPassword',
            'PSAvoidUsingUsernameAndPasswordParams',
            'PSDSCUseVerboseMessageInDSCResource',
            'PSShouldProcess',
            'PSUseDeclaredVarsMoreThanAssigments',
            'PSUsePSCredentialType'
        )

        $ignorePssaRuleNames = @(
            'PSDSCDscExamplesPresent',
            'PSDSCDscTestsPresent',
            'PSUseBOMForUnicodeEncodedFile',
            'PSUseShouldProcessForStateChangingFunctions',
            'PSUseSingularNouns',
            'PSUseToExportFieldsInManifest',
            'PSUseUTF8EncodingForHelpFile'
        )

        $dscResourcesPsm1Files = Get-Psm1FileList -FilePath $dscResourcesFolderFilePath

        foreach ($dscResourcesPsm1File in $dscResourcesPsm1Files)
        {
            $invokeScriptAnalyzerParameters = @{
                Path        = $dscResourcesPsm1File.FullName
                ErrorAction = 'SilentlyContinue'
                Recurse     = $true
            }

            Context $dscResourcesPsm1File.Name {
                It 'Should pass all error-level PS Script Analyzer rules' {
                    $errorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -Severity 'Error'

                    if ($null -ne $errorPssaRulesOutput)
                    {
                        Write-PsScriptAnalyzerWarning -PssaRuleOutput $errorPssaRulesOutput -RuleType 'Error-Level'
                    }

                    $errorPssaRulesOutput | Should -Be $null
                }

                It 'Should pass all required PS Script Analyzer rules' {
                    $requiredPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $requiredPssaRuleNames

                    if ($null -ne $requiredPssaRulesOutput)
                    {
                        Write-PsScriptAnalyzerWarning -PssaRuleOutput $requiredPssaRulesOutput -RuleType 'Required'
                    }

                    if ($null -ne $requiredPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - Required Script Analyzer Rules'))
                    {
                        <#
                            If opted into 'Common Tests - Required Script Analyzer Rules' then
                            test that there were no violations
                        #>
                        $requiredPssaRulesOutput | Should -Be $null
                    }
                }

                It 'Should pass all flagged PS Script Analyzer rules' {
                    $flaggedPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $flaggedPssaRuleNames

                    if ($null -ne $flaggedPssaRulesOutput)
                    {
                        Write-PsScriptAnalyzerWarning -PssaRuleOutput $flaggedPssaRulesOutput -RuleType 'Flagged'
                    }

                    if ($null -ne $flaggedPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - Flagged Script Analyzer Rules'))
                    {
                        <#
                            If opted into 'Common Tests - Flagged Script Analyzer Rules' then
                            test that there were no violations
                        #>
                        $flaggedPssaRulesOutput | Should -Be $null
                    }
                }

                It 'Should pass any recently-added, error-level PS Script Analyzer rules' {
                    $knownPssaRuleNames = $requiredPssaRuleNames + $flaggedPssaRuleNames + $ignorePssaRuleNames

                    $newErrorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -ExcludeRule $knownPssaRuleNames -Severity 'Error'

                    if ($null -ne $newErrorPssaRulesOutput)
                    {
                        Write-PsScriptAnalyzerWarning -PssaRuleOutput $newErrorPssaRulesOutput -RuleType 'Recently-added'
                    }

                    if ($null -ne $newErrorPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - New Error-Level Script Analyzer Rules'))
                    {
                        <#
                            If opted into 'Common Tests - New Error-Level Script Analyzer Rules' then
                            test that there were no violations
                        #>
                        $newErrorPssaRulesOutput | Should -Be $null
                    }
                }

                It 'Should not suppress any required PS Script Analyzer rules' {
                    $requiredRuleIsSuppressed = $false

                    $suppressedRuleNames = Get-SuppressedPSSARuleNameList -FilePath $dscResourcesPsm1File.FullName

                    foreach ($suppressedRuleName in $suppressedRuleNames)
                    {
                        $suppressedRuleNameNoQuotes = $suppressedRuleName.Replace("'", '')

                        if ($requiredPssaRuleNames -icontains $suppressedRuleNameNoQuotes)
                        {
                            Write-Warning -Message "The file $($dscResourcesPsm1File.Name) contains a suppression of the required PS Script Analyser rule $suppressedRuleNameNoQuotes. Please remove the rule suppression."
                            $requiredRuleIsSuppressed = $true
                        }
                    }

                    $requiredRuleIsSuppressed | Should -Be $false
                }

                It 'Should pass all custom DSC Resource Kit PSSA rules' {
                    $customDscResourceAnalyzerRulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.AnalyzerRules'
                    $customPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters `
                        -CustomRulePath $customDscResourceAnalyzerRulesPath `
                        -Severity 'Warning'

                    if ($null -ne $customPssaRulesOutput)
                    {
                        Write-PsScriptAnalyzerWarning -PssaRuleOutput $customPssaRulesOutput -RuleType 'Custom DSC Resource Kit'
                    }

                    if ($null -ne $customPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - Custom Script Analyzer Rules'))
                    {
                        <#
                            If opted into 'Common Tests - Custom Script Analyzer Rules' then
                            test that there were no violations
                        #>
                        $customPssaRulesOutput | Should -Be $null
                    }
                }
            }
        }
    }
    else
    {
        Write-Warning -Message 'PS Script Analyzer could not run on this machine. Please run tests on a machine with WMF 5.0+.'
    }
}

Describe 'Common Tests - Validate Example Files' -Tag 'Examples' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    $examplesPath = Join-Path -Path $moduleRootFilePath -ChildPath 'Examples'
    if (Test-Path -Path $examplesPath)
    {
        <#
            For Appveyor builds copy the module to the system modules directory so it falls in to a PSModulePath folder and is
            picked up correctly.
            For a user to run the test, they need to make sure that the module exists in one of the paths in env:PSModulePath, i.e.
            '%USERPROFILE%\Documents\WindowsPowerShell\Modules'.
            No copying is done when a user runs the test, because that could potentially be destructive.
        #>
        if ($env:APPVEYOR -eq $true)
        {
            $powershellModulePath = Copy-ResourceModuleToPSModulePath -ResourceModuleName $moduleName -ModuleRootPath $moduleRootFilePath
        }

        $exampleFile = Get-ChildItem -Path (Join-Path -Path $moduleRootFilePath -ChildPath 'Examples') -Filter '*.ps1' -Recurse
        foreach ($exampleToValidate in $exampleFile)
        {
            $exampleDescriptiveName = Join-Path -Path (Split-Path $exampleToValidate.Directory -Leaf) -ChildPath (Split-Path $exampleToValidate -Leaf)

            Context -Name $exampleDescriptiveName {
                It "Should compile MOFs for example correctly" -Skip:(!$optIn) {
                    {
                        $mockPassword = ConvertTo-SecureString '&iPm%M5q3K$Hhq=wcEK' -AsPlainText -Force
                        $mockCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @('username', $mockPassword)
                        $mockConfigurationData = @{
                            AllNodes = @(
                                @{
                                    NodeName        = 'localhost'
                                    CertificateFile = $env:DscPublicCertificatePath
                                }
                            )
                        }

                        try
                        {
                            <#
                                Set this first because it is used in the final block,
                                and must be set otherwise it fails on not being assigned.
                            #>
                            $existingCommandName = $null

                            # Get the list of additional modules required by the example
                            $requiredModules = Get-ResourceModulesInConfiguration -ConfigurationPath $exampleToValidate.FullName |
                            Where-Object -Property Name -ne $moduleName

                            if ($requiredModules)
                            {
                                Install-DependentModule -Module $requiredModules
                            }

                            . $exampleToValidate.FullName

                            <#
                                Test for either a configuration named 'Example',
                                or parse the name from the filename and try that
                                as the configuration name (requirement for Azure
                                Automation).
                            #>
                            $commandName = @('Example')
                            $azureCommandName = Get-PublishFileName -Path $exampleToValidate.FullName
                            $commandName += $azureCommandName

                            # Get the first one that matches.
                            $existingCommand = Get-ChildItem -Path 'function:' |
                            Where-Object { $_.Name -in $commandName } |
                            Select-Object -First 1

                            if ($existingCommand)
                            {
                                $existingCommandName = $existingCommand.Name

                                $exampleCommand = Get-Command -Name $existingCommandName -ErrorAction SilentlyContinue
                                if ($exampleCommand)
                                {
                                    $exampleParameters = @{ }

                                    # Remove any common parameters that are available.
                                    $commandParameters = $exampleCommand.Parameters.Keys | Where-Object -FilterScript {
                                        ($_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters) -and `
                                        ($_ -notin [System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
                                    }

                                    foreach ($parameterName in $commandParameters)
                                    {
                                        $parameterType = $exampleCommand.Parameters[$parameterName].ParameterType.FullName

                                        <#
                                            Each credential parameter in the Example function is assigned the
                                            mocked credential. 'PsDscRunAsCredential' is not assigned because
                                            that brakes the example.
                                        #>
                                        if ($parameterName -ne 'PsDscRunAsCredential' `
                                                -and $parameterType -eq 'System.Management.Automation.PSCredential')
                                        {
                                            $exampleParameters.Add($parameterName, $mockCredential)
                                        }
                                        else
                                        {
                                            <#
                                                Check for mandatory parameters.
                                                Assume the parameters are all in the 'all' parameter set.
                                            #>
                                            $isParameterMandatory = $exampleCommand.Parameters[$parameterName].ParameterSets['__AllParameterSets'].IsMandatory
                                            if ($isParameterMandatory)
                                            {
                                                <#
                                                    Convert '1' to the type that the parameter expects.
                                                    Using '1' since it can be converted to String, Numeric
                                                    and Boolean.
                                                #>
                                                $exampleParameters.Add($parameterName, ('1' -as $parameterType))
                                            }
                                        }
                                    }

                                    <#
                                        If there is a $ConfigurationData variable that was dot-sources.
                                        Then use that as the configuration data instead of the mocked configuration data.
                                    #>
                                    if (Get-Item -Path variable:ConfigurationData -ErrorAction SilentlyContinue)
                                    {
                                        # Adding certificate to the examples configuration data.
                                        foreach ($node in $ConfigurationData.AllNodes.GetEnumerator())
                                        {
                                            if ($node.ContainsKey('PSDscAllowPlainTextPassword') -eq $true -and $node.PSDscAllowPlainTextPassword -eq $true)
                                            {
                                                Write-Warning -Message ('The example ''{0}'' is using PSDscAllowPlainTextPassword = $true in the configuration data for node name ''{1}'', this should be removed so the example is secure. PSDscAllowPlainTextPassword was overridden in the tests so the example can be tested securely.' -f $exampleDescriptiveName, $node.NodeName)

                                                # Override PSDscAllowPlainTextPassword.
                                                $node.PSDscAllowPlainTextPassword = $false
                                            }

                                            $node.CertificateFile = $env:DscPublicCertificatePath
                                        }

                                        $mockConfigurationData = $ConfigurationData
                                    }

                                    & $exampleCommand.Name @exampleParameters -ConfigurationData $mockConfigurationData -OutputPath 'TestDrive:\' -ErrorAction Continue -WarningAction SilentlyContinue | Out-Null
                                }
                            }
                            else
                            {
                                throw "The example '$exampleDescriptiveName' does not contain a configuration named 'Example' or '$azureCommandName'."
                            }

                        }
                        finally
                        {
                            # Remove the function we dot-sourced so next example file doesn't use the previous Example-function.
                            if ($existingCommandName)
                            {
                                Remove-Item -Path "function:$existingCommandName" -ErrorAction SilentlyContinue
                            }

                            # Remove the variable $ConfigurationData if it existed in the file we dot-sourced so next example file doesn't use the previous examples configuration.
                            Remove-Item -Path variable:ConfigurationData -ErrorAction SilentlyContinue
                        }
                    } | Should -Not -Throw
                }
            }
        }

        if ($env:APPVEYOR -eq $true)
        {
            Remove-Item -Path $powershellModulePath -Recurse -Force -Confirm:$false

            # Restore the load of the module to ensure future tests have access to it
            Import-Module -Name (Join-Path -Path $moduleRootFilePath `
                    -ChildPath "$moduleName.psd1") `
                -Global
        }
    }
}

Describe 'Common Tests - Validate Example Files To Be Published' -Tag 'Examples' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns
    $examplesPath = Join-Path -Path $moduleRootFilePath -ChildPath 'Examples'

    # Due to speed, only run these test if opt-in and the examples folder exist.
    if ($optIn -and (Test-Path -Path $examplesPath))
    {
        # We need helper functions from this module.
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.GalleryDeploy')

        <#
            For Appveyor builds copy the module to the system modules directory so it falls in to a PSModulePath folder and is
            picked up correctly.
            For a user to run the test, they need to make sure that the module exists in one of the paths in env:PSModulePath, i.e.
            '%USERPROFILE%\Documents\WindowsPowerShell\Modules'.
            No copying is done when a user runs the test, because that could potentially be destructive.
        #>
        if ($env:APPVEYOR -eq $true)
        {
            $powershellModulePath = Copy-ResourceModuleToPSModulePath -ResourceModuleName $moduleName -ModuleRootPath $moduleRootFilePath
        }

        Context 'When there are examples that should be published' {
            $exampleScriptFiles = Get-ChildItem -Path (Join-Path -Path $examplesPath -ChildPath '*Config.ps1')

            It 'Should not contain any duplicate GUID is script file metadata' -Skip:(!$optIn) {
                $exampleScriptMetadata = $exampleScriptFiles | ForEach-Object -Process {
                    <#
                        The cmdlet Test-ScriptFileInfo ignores the parameter ErrorAction and $ErrorActionPreference.
                        Instead a try-catch need to be used to ignore files that does not have the correct metadata.
                    #>
                    try
                    {
                        Test-ScriptFileInfo -Path $_.FullName
                    }
                    catch
                    {
                        # Intentionally left blank. Files with missing metadata will be caught in the next test.
                    }
                }

                $duplicateGuid = $exampleScriptMetadata |
                Group-Object -Property Guid |
                Where-Object { $_.Count -gt 1 }

                if ($duplicateGuid -and $duplicateGuid.Count -gt 0)
                {
                    $duplicateGuid |
                    ForEach-Object -Process {
                        Write-Warning -Message ('Guid {0} is duplicated in the files ''{1}''' -f $_.Name, ($_.Group.Name -join ', '))
                    }
                }

                $duplicateGuid | Should -BeNullOrEmpty
            }

            foreach ($exampleToValidate in $exampleScriptFiles)
            {
                $exampleDescriptiveName = Join-Path -Path (Split-Path -Path $exampleToValidate.Directory -Leaf) `
                    -ChildPath (Split-Path -Path $exampleToValidate -Leaf)

                Context -Name "When publishing example '$exampleDescriptiveName'" {
                    It 'Should pass testing of script file metadata' -Skip:(!$optIn) {
                        {
                            Test-ScriptFileInfo -Path $exampleToValidate.FullName
                        } | Should -Not -Throw
                    }

                    It 'Should have the correct naming convention, and the same file name as the configuration name' -Skip:(!$optIn) {
                        $result = Test-ConfigurationName -Path $exampleToValidate.FullName
                        $result | Should -Be $true
                    }
                }
            }
        }

        if ($env:APPVEYOR -eq $true)
        {
            Remove-Item -Path $powershellModulePath -Recurse -Force -Confirm:$false

            # Restore the load of the module to ensure future tests have access to it
            Import-Module -Name (Join-Path -Path $moduleRootFilePath `
                    -ChildPath "$moduleName.psd1") `
                -Global
        }
    }
}

Describe 'Common Tests - Validate Markdown Files' -Tag 'Markdown' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    if (Get-Command -Name 'npm' -ErrorAction SilentlyContinue)
    {
        $npmParametersForStartProcess = @{
            FilePath         = 'npm'
            ArgumentList     = ''
            WorkingDirectory = $PSScriptRoot
            Wait             = $true
            WindowStyle      = 'Hidden'
        }

        Context 'When installing markdown validation dependencies' {
            It 'Should not throw an error when installing package Gulp in global scope' {
                {
                    <#
                        gulp; gulp is a toolkit that helps you automate painful or time-consuming tasks in your development workflow.
                        gulp must be installed globally to be able to be called through Start-Process
                    #>
                    $npmParametersForStartProcess['ArgumentList'] = 'install -g gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package Gulp in local scope' {
                {
                    # gulp must also be installed locally to be able to be referenced in the javascript file.
                    $npmParametersForStartProcess['ArgumentList'] = 'install gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package through2' {
                {
                    # Used in gulpfile.js; A tiny wrapper around Node streams2 Transform to avoid explicit sub classing noise
                    $npmParametersForStartProcess['ArgumentList'] = 'install through2'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package markdownlint' {
                {
                    # Used in gulpfile.js; A Node.js style checker and lint tool for Markdown/CommonMark files.
                    $npmParametersForStartProcess['ArgumentList'] = 'install markdownlint'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package gulp-concat as a dev-dependency' {
                {
                    # gulp-concat is installed as devDependencies. Used in gulpfile.js; Concatenates files
                    $npmParametersForStartProcess['ArgumentList'] = 'install gulp-concat -D'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }
        }

        Context 'When there are markdown files' {
            if (Test-Path -Path (Join-Path -Path $repoRootPath -ChildPath '.markdownlint.json'))
            {
                Write-Verbose -Message ('Using markdownlint settings file from repository folder ''{0}''.' -f $repoRootPath) -Verbose
                $markdownlintSettingsFilePath = Join-Path -Path $repoRootPath -ChildPath '.markdownlint.json'
            }
            else
            {
                Write-Verbose -Message 'Using markdownlint settings file from DscResource.Test repository.' -Verbose
                $markdownlintSettingsFilePath = $null
            }

            It "Should not have errors in any markdown files"  {

                $mdErrors = 0
                try
                {
                    if ($dscResourcesFolderFilePath -eq $moduleRootFilePath)
                    {
                        # Reverting back to defaults
                        $dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath 'DscResources'
                    }

                    $gulpArgumentList = @(
                        'test-mdsyntax',
                        '--silent',
                        '--rootpath',
                        $repoRootPath,
                        '--dscresourcespath',
                        $dscResourcesFolderFilePath
                    )

                    if ($markdownlintSettingsFilePath)
                    {
                        $gulpArgumentList += @(
                            '--settingspath',
                            $markdownlintSettingsFilePath
                        )
                    }

                    Start-Process -FilePath 'gulp' -ArgumentList $gulpArgumentList `
                        -Wait -WorkingDirectory $PSScriptRoot -PassThru -NoNewWindow
                    Start-Sleep -Seconds 3
                    $mdIssuesPath = Join-Path -Path $PSScriptRoot -ChildPath 'markdownissues.txt'

                    if ((Test-Path -Path $mdIssuesPath) -eq $true)
                    {
                        Get-Content -Path $mdIssuesPath | ForEach-Object -Process {
                            if ([string]::IsNullOrEmpty($_) -eq $false)
                            {
                                Write-Warning -Message $_
                                $mdErrors ++
                            }
                        }
                    }
                    Remove-Item -Path $mdIssuesPath -Force -ErrorAction SilentlyContinue
                }
                catch [System.Exception]
                {
                    Write-Warning -Message ('Unable to run gulp to test markdown files. Please ' + `
                            'be sure that you have installed nodejs and have ' + `
                            'run ''npm install -g gulp'' in order to have this ' + `
                            'test execute.')
                }

                if ($optIn)
                {
                    $mdErrors | Should -Be 0
                }
            }
        }

        <#
            We're uninstalling the dependencies, in reverse order, so that the
            node_modules folder do not linger on a users computer if run locally.
            Also, this fixes so that when there is a apostrophe in the path for
            $PSScriptRoot, the node_modules folder is correctly removed.
        #>
        Context 'When uninstalling markdown validation dependencies' {
            It 'Should not throw an error when uninstalling package gulp-concat as a dev-dependency' {
                {
                    # gulp-concat is installed as devDependencies. Used in gulpfile.js; Concatenates files
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall gulp-concat -D'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package markdownlint' {
                {
                    # Used in gulpfile.js; A Node.js style checker and lint tool for Markdown/CommonMark files.
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall markdownlint'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package through2' {
                {
                    # Used in gulpfile.js; A tiny wrapper around Node streams2 Transform to avoid explicit sub classing noise
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall through2'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package Gulp in local scope' {
                {
                    # gulp must also be installed locally to be able to be referenced in the javascript file.
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package Gulp in global scope' {
                {
                    <#
                        gulp; gulp is a toolkit that helps you automate painful or time-consuming tasks in your development workflow.
                        gulp must be installed globally to be able to be called through Start-Process
                    #>
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall -g gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when removing the node_modules folder' {
                {
                    # Remove folder node_modules that npm created.
                    $npmNodeModulesPath = (Join-Path -Path $PSScriptRoot -ChildPath 'node_modules')
                    if ( Test-Path -Path $npmNodeModulesPath)
                    {
                        Remove-Item -Path $npmNodeModulesPath -Recurse -Force
                    }
                } | Should -Not -Throw
            }
        }
    }
    else
    {
        Write-Warning -Message ('Unable to run gulp to test markdown files. Please ' + `
                'be sure that you have installed nodejs and npm in order ' + `
                'to have this text execute.')
    }
}

Describe 'Common Tests - Spellcheck Files' -Tag 'Spellcheck' {
    BeforeAll {
        $npmParametersForStartProcess = @{
            FilePath         = 'npm'
            ArgumentList     = ''
            WorkingDirectory = $PSScriptRoot
            Wait             = $true
            WindowStyle      = 'Hidden'
        }
    }

    if ((Get-Command -Name 'npm' -ErrorAction SilentlyContinue))
    {
        $skipDependency = $false
    }
    else
    {
        Write-Warning -Message ('Unable to run cSpell to spellcheck markdown files. Please ' + `
                'be sure that you have installed nodejs and npm in order ' + `
                'to have this text execute.')

        $skipDependency = $true
    }

    Context 'When installing spellcheck dependencies' {
        It 'Should not throw an error when installing package cSpell in global scope' -Skip:$skipDependency {
            {
                # More information about cSpell: https://www.npmjs.com/package/cspell
                $npmParametersForStartProcess['ArgumentList'] = 'install -g cspell'
                Start-Process @npmParametersForStartProcess
            } | Should -Not -Throw
        }
    }

    # If npm wasn't installed then we can't run this test.
    $optIn = -not $skipDependency -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - Spellcheck Markdown Files')

    Context 'When there are markdown files' {
        $errorFileName = 'SpellingErrors.txt'

        It 'Should not have spelling errors in any markdown files' -Skip:(!$optIn) {
            $spellcheckSettingsFilePath = Join-Path -Path $repoRootPath -ChildPath '.vscode\cSpell.json'

            if (Test-Path -Path $spellcheckSettingsFilePath)
            {
                Write-Info -Message ('Using spellcheck settings file ''{0}''.' -f $spellcheckSettingsFilePath)
            }
            else
            {
                $spellcheckSettingsFilePath = $null
            }

            $cSpellArgumentList = @(
                '"**/*.md"',
                '--no-color'
            )

            if ($spellcheckSettingsFilePath)
            {
                $cSpellArgumentList += @(
                    '--config',
                    $spellcheckSettingsFilePath
                )
            }

            # This must be last, we send output to the error file.
            $cSpellArgumentList += @(
                ('>{0}' -f $errorFileName)
            )

            $startProcessParameters = @{
                FilePath     = 'cspell'
                ArgumentList = $cSpellArgumentList
                Wait         = $true
                PassThru     = $true
                NoNewWindow  = $true
            }

            $process = Start-Process @startProcessParameters
            $process.ExitCode | Should -Be 0
        } -ErrorVariable itBlockError

        # If the It-block did not pass the test, output the spelling errors.
        if ($itBlockError.Count -ne 0)
        {
            $message = @"
There were spelling errors. If these are false negatives, then please add the
word or phrase to the settings file '/.vscode/cSpell.json' in the repository.
See this section for more information.
https://github.com/PowerShell/DscResource.Tests/#common-tests-spellcheck-markdownfiles

"@

            Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
            Write-Host -ForegroundColor White -Object ''

            $misspelledErrors = Get-Content -Path $errorFileName

            foreach ($misspelledError in $misspelledErrors)
            {
                $message = '{0}' -f $misspelledError
                Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
            }
        }

        # Make sure we always remove the file if it exist.
        if (Test-Path $errorFileName)
        {
            Remove-Item -Path $errorFileName -Force | Out-Null
        }
    }

    Context 'When uninstalling spellcheck dependencies' {
        It 'Should not throw an error when uninstalling package cSpell in global scope' -Skip:$skipDependency {
            {
                $npmParametersForStartProcess['ArgumentList'] = 'uninstall -g cspell'
                Start-Process @npmParametersForStartProcess
            } | Should -Not -Throw
        }
    }
}

Describe 'Common Tests - Validate Markdown Links' -Tag 'Markdown' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    $dependencyModuleName = 'MarkdownLinkCheck'
    $uninstallMarkdownLinkCheck = $false

    Context 'When installing markdown link validation dependencies' {
        It "Should not throw an error when installing and importing the module MarkdownLinkCheck" -Skip:(!$optIn) {
            {
                if (-not (Get-Module -Name $dependencyModuleName -ListAvailable))
                {
                    # Remember that we installed the module, so that it gets uninstalled.
                    $uninstallMarkdownLinkCheck = $true
                    Install-Module -Name $dependencyModuleName -Force -Scope 'CurrentUser' -ErrorAction Stop
                }

                Import-Module -Name $dependencyModuleName -Force
            } | Should -Not -Throw
        }
    }

    $markdownFileExtensions = @('.md')

    $markdownFiles = Get-TextFilesList $moduleRootFilePath |
    Where-Object -FilterScript {
        $markdownFileExtensions -contains $_.Extension
    }

    foreach ($markdownFileToValidate in $markdownFiles)
    {
        $contextDescriptiveName = Join-Path -Path (Split-Path $markdownFileToValidate.Directory -Leaf) -ChildPath (Split-Path $markdownFileToValidate -Leaf)

        Context -Name $contextDescriptiveName {
            It "Should not contain any broken links" -Skip:(!$optIn) {
                $getMarkdownLinkParameters = @{
                    BrokenOnly = $true
                    Path       = $markdownFileToValidate.FullName
                }

                # Make sure it always returns an array even if Get-MarkdownLink returns $null.
                $brokenLinks = @(Get-MarkdownLink @getMarkdownLinkParameters)

                if ($brokenLinks.Count -gt 0)
                {
                    # Write out all the errors so the contributor can resolve.
                    foreach ($brokenLink in $brokenLinks)
                    {
                        $message = 'Line {0}: [{1}] has broken URL "{2}"' -f $brokenLink.Line, $brokenLink.Text, $brokenLink.Url
                        Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
                    }
                }

                $brokenLinks.Count | Should -Be 0
            }
        }
    }

    if ($uninstallMarkdownLinkCheck)
    {
        Context 'When uninstalling markdown link validation dependencies' {
            It "Should not throw an error when uninstalling the module MarkdownLinkCheck" -Skip:(!$optIn) {
                {
                    <#
                        Remove the module from the current session as
                        Uninstall-Module does not do that.
                    #>
                    Remove-Module -Name $dependencyModuleName -Force
                    Uninstall-Module -Name $dependencyModuleName -Force -ErrorAction Stop
                } | Should -Not -Throw
            }
        }
    }
}

Describe 'Common Tests - Validate Localization' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    # Due to verbose output, only run these test if opt-in.
    if ($optIn)
    {
        $allFolders = Get-ChildItem -Path (Join-Path -Path $moduleRootFilePath -ChildPath 'DscResources') -Directory
        $allFolders += Get-ChildItem -Path (Join-Path -Path $moduleRootFilePath -ChildPath 'Modules') -Directory
        $allFolders = $allFolders | Sort-Object -Property Name

        Context 'When a resource or module should have localization files' {
            BeforeAll {
                $foldersToTest = @()

                foreach ($folder in $allFolders)
                {
                    $foldersToTest += @{
                        Folder = $folder.Name
                        Path   = $folder.FullName
                    }
                }
            }

            It 'Should have en-US localization folder for the resource/module <Folder>' -TestCases $foldersToTest {
                param
                (
                    [Parameter()]
                    [System.String]
                    $Folder,

                    [Parameter()]
                    [System.String]
                    $Path
                )

                $localizationFolderPath = Join-Path -Path $Path -ChildPath 'en-US'

                Test-Path -Path $localizationFolderPath | Should -BeTrue -Because 'the en-US folder must exist'
            }

            It 'Should have en-US localization folder with the correct casing for the resource/module <Folder>' -TestCases $foldersToTest {
                param
                (
                    [Parameter()]
                    [System.String]
                    $Folder,

                    [Parameter()]
                    [System.String]
                    $Path
                )

                <#
                    This will return both 'en-us' and 'en-US' folders so we can
                    evaluate casing.
                #>
                $localizationFolderOnDisk = Get-ChildItem -Path $Path -Directory -Filter 'en-US'
                $localizationFolderOnDisk.Name | Should -MatchExactly 'en-US' -Because 'the en-US folder must have the correct casing'
            }

            It 'Should have en-US localization string resource file for the resource/module <Folder>' -TestCases $foldersToTest {
                param
                (
                    [Parameter()]
                    [System.String]
                    $Folder,

                    [Parameter()]
                    [System.String]
                    $Path
                )

                $localizationResourceFilePath = Join-Path -Path (Join-Path -Path $Path -ChildPath 'en-US') -ChildPath "$Folder.strings.psd1"

                Test-Path -Path $localizationResourceFilePath | Should -BeTrue -Because 'there must exist a string resource file in the localization folder en-US'
            }

            foreach ($testCase in $foldersToTest)
            {
                $skipTest_LocalizedKeys = $false
                $skipTest_UsedLocalizedKeys = $false

                $testCases_LocalizedKeys = @()
                $testCases_UsedLocalizedKeys = @()

                $sourceLocalizationFolderPath = Join-Path -Path $testCase.Path -ChildPath 'en-US'
                $localizationResourceFile = '{0}.strings.psd1' -f $testCase.Folder

                # Skip files that do not exist yet (they were caught in a previous test above)
                if (-not (Test-Path -Path (Join-Path -Path $sourceLocalizationFolderPath -ChildPath $localizationResourceFile)))
                {
                    Write-Warning -Message ('Missing the localized string resource file ''{0}''' -f $testCase.Path)

                    continue
                }

                Import-LocalizedData `
                    -BindingVariable 'englishLocalizedStrings' `
                    -FileName $localizationResourceFile `
                    -BaseDirectory $sourceLocalizationFolderPath

                foreach ($localizedKey in $englishLocalizedStrings.Keys)
                {
                    $testCases_LocalizedKeys += @{
                        LocalizedKey = $localizedKey
                    }
                }

                $modulePath = Join-Path -Path $testCase.Path -ChildPath "$($testCase.Folder).psm1"

                $parseErrors = $null
                $definitionAst = [System.Management.Automation.Language.Parser]::ParseFile($modulePath, [ref] $null, [ref] $parseErrors)

                if ($parseErrors)
                {
                    throw $parseErrors
                }

                $astFilter = {
                    $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] `
                        -and $args[0].Parent -is [System.Management.Automation.Language.MemberExpressionAst] `
                        -and $args[0].Parent.Expression -is [System.Management.Automation.Language.VariableExpressionAst] `
                        -and $args[0].Parent.Expression.VariablePath.UserPath -eq 'script:localizedData'
                }

                $localizationStringConstantsAst = $definitionAst.FindAll($astFilter, $true)

                if ($localizationStringConstantsAst)
                {
                    $usedLocalizationKeys = $localizationStringConstantsAst.Value | Sort-Object -Unique

                    foreach ($localizedKey in $usedLocalizationKeys)
                    {
                        $testCases_UsedLocalizedKeys += @{
                            LocalizedKey = $localizedKey
                        }
                    }
                }

                Context ('When validating resource/module {0}' -f $testCase.Folder) {
                    # If there are no test cases built, skip this test.
                    $skipTest_LocalizedKeys = -not $testCases_LocalizedKeys

                    It 'Should use the localized string key <LocalizedKey> from the localization resource file' -TestCases $testCases_LocalizedKeys -Skip:$skipTest_LocalizedKeys {
                        param
                        (
                            [Parameter()]
                            [System.String]
                            $LocalizedKey
                        )

                        $usedLocalizationKeys | Should -Contain $LocalizedKey -Because 'the key exists in the localized string resource file so it should also exist in the code'
                    }

                    # If there are no test cases built, skip this test.
                    $skipTest_UsedLocalizedKeys = -not $testCases_UsedLocalizedKeys

                    It 'Should not be missing the localized string key <LocalizedKey> from the localization resource file' -TestCases $testCases_UsedLocalizedKeys -Skip:$skipTest_UsedLocalizedKeys {
                        param
                        (
                            [Parameter()]
                            [System.String]
                            $LocalizedKey
                        )

                        $englishLocalizedStrings.Keys | Should -Contain $LocalizedKey -Because 'the key is used in the resource/module script file so it should also exist in the localized string resource files'
                    }
                }
            }
        }

        Context 'When a resource or module is localized to other languages' {
            BeforeAll {
                $otherLanguagesToTest = @()

                foreach ($folder in $allFolders)
                {
                    <#
                        Get all localization folders except the en-US.
                        We want all regardless of casing.
                    #>
                    $localizationFolders = Get-ChildItem -Path $folder.FullName -Directory -Filter '*-*' |
                    Where-Object -FilterScript {
                        $_.Name -ne 'en-US'
                    }

                    foreach ($localizationFolder in $localizationFolders)
                    {
                        $otherLanguagesToTest += @{
                            Folder             = $folder.Name
                            Path               = $folder.FullName
                            LocalizationFolder = $localizationFolder.Name
                        }
                    }
                }
            }

            # Only run these tests if there are test cases to be tested.
            $skipTests = -not $otherLanguagesToTest

            It 'Should have a localization string resource file for the resource/module <Folder> and localization folder <LocalizationFolder>' -TestCases $otherLanguagesToTest -Skip:$skipTests {
                param
                (
                    [Parameter()]
                    [System.String]
                    $Folder,

                    [Parameter()]
                    [System.String]
                    $Path,

                    [Parameter()]
                    [System.String]
                    $LocalizationFolder
                )

                $localizationResourceFilePath = Join-Path -Path (Join-Path -Path $Path -ChildPath $LocalizationFolder) -ChildPath "$Folder.strings.psd1"

                Test-Path -Path $localizationResourceFilePath | Should -BeTrue -Because ('there must exist a string resource file in the localization folder {0}' -f $LocalizationFolder)
            }

            It 'Should have a localization folder with the correct casing for the resource/module <Folder> and localization folder <LocalizationFolder>' -TestCases $otherLanguagesToTest -Skip:$skipTests {
                param
                (
                    [Parameter()]
                    [System.String]
                    $Folder,

                    [Parameter()]
                    [System.String]
                    $Path,

                    [Parameter()]
                    [System.String]
                    $LocalizationFolder
                )

                $localizationFolderOnDisk = Get-ChildItem -Path $Path -Directory -Filter $LocalizationFolder
                $localizationFolderOnDisk.Name | Should -MatchExactly '[a-z]{2}-[A-Z]{2}' -Because 'the localization folder must have the correct casing'
            }

            foreach ($testCase in $otherLanguagesToTest)
            {
                $testCases_CompareAgainstEnglishLocalizedKeys = @()
                $testCases_MissingEnglishLocalizedKeys = @()

                $sourceLocalizationFolderPath = Join-Path -Path $testCase.Path -ChildPath 'en-US'

                Import-LocalizedData `
                    -BindingVariable 'englishLocalizedStrings' `
                    -FileName "$($testCase.Folder).strings.psd1" `
                    -BaseDirectory $sourceLocalizationFolderPath

                $localizationFolderPath = Join-Path -Path $testCase.Path -ChildPath $testCase.LocalizationFolder

                Import-LocalizedData `
                    -BindingVariable 'localizedStrings' `
                    -FileName "$($testCase.Folder).strings.psd1" `
                    -BaseDirectory $localizationFolderPath

                foreach ($localizedKey in $englishLocalizedStrings.Keys)
                {
                    $testCases_CompareAgainstEnglishLocalizedKeys += @{
                        LocalizationFolder = $testCase.LocalizationFolder
                        Folder             = $testCase.Folder
                        LocalizedKey       = $localizedKey
                    }
                }

                foreach ($localizedKey in $localizedStrings.Keys)
                {
                    $testCases_MissingEnglishLocalizedKeys += @{
                        LocalizationFolder = $testCase.LocalizationFolder
                        Folder             = $testCase.Folder
                        LocalizedKey       = $localizedKey
                    }
                }

                Context ('When validating resource/module {0}' -f $testCase.Folder) {
                    It "Should have the english localization string key <LocalizedKey> in the localization resource file '<LocalizationFolder>\<Folder>.strings.psd1' for the resource/module <Folder>" -TestCases $testCases_CompareAgainstEnglishLocalizedKeys {
                        param
                        (
                            [Parameter()]
                            [System.String]
                            $LocalizedKey,

                            [Parameter()]
                            [System.String]
                            $Folder,

                            [Parameter()]
                            [System.String]
                            $LocalizationFolder
                        )

                        $localizedStrings.Keys | Should -Contain $LocalizedKey -Because 'the key exists in the en-US localization resource file so the key should also exist in this language file'
                    }  -ErrorVariable itBlockError

                    <#
                        If the It-block did not pass the test, output the a text
                        explaining how to resolve the issue.
                    #>
                    if ($itBlockError.Count -ne 0)
                    {
                        $message = @"
If you cannot translate the english string in the localized file,
then please just add the en-US localization string key together
with the en-US text string.
"@

                        Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
                        Write-Host -ForegroundColor White -Object ''
                    }

                    It "Should not be missing the localization string key <LocalizedKey> from the english resource file for the resource/module <Folder>" -TestCases $testCases_MissingEnglishLocalizedKeys {
                        param
                        (
                            [Parameter()]
                            [System.String]
                            $LocalizedKey,

                            [Parameter()]
                            [System.String]
                            $Folder,

                            [Parameter()]
                            [System.String]
                            $LocalizationFolder
                        )

                        $englishLocalizedStrings.Keys | Should -Contain $LocalizedKey -Because ('the key exists in the resource file for the location folder {0} so it should also exist in the en-US string resource file' -f $LocalizationFolder)
                    }
                }
            }
        }
    }
}
