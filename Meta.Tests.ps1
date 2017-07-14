<#
    .SYNOPSIS
        Common tests for all resource modules in the DSC Resource Kit.
#>
# Suppressing this because we need to generate a mocked credentials that will be passed along to the examples that are needed in the tests.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param()

Set-StrictMode -Version 'Latest'
$errorActionPreference = 'Stop'

$testHelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperModulePath

$moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent
$dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath 'DscResources'

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
$repoName = Split-Path -Path $repoRootPath -Leaf
$testOptInFilePath = Join-Path -Path $repoRootPath -ChildPath '.MetaTestOptIn.json'
# .MetaTestOptIn.json should be in the following format
# [
#     "Common Tests - Validate Markdown Files",
#     "Common Tests - Validate Example Files"
# ]

$optIns = @()
if(Test-Path $testOptInFilePath)
{
    $optIns = Get-Content -LiteralPath $testOptInFilePath | ConvertFrom-Json
}


Describe 'Common Tests - File Formatting' {
    $textFiles = Get-TextFilesList $moduleRootFilePath

    It "Should not contain any files with Unicode file encoding" {
        $containsUnicodeFile = $false

        foreach ($textFile in $textFiles)
        {
            if (Test-FileInUnicode $textFile)
            {
                if($textFile.Extension -ieq '.mof')
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

        $containsUnicodeFile | Should Be $false
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

        $containsFileWithTab | Should Be $false
    }

    It 'Should not contain empty files' {
        $containsEmptyFile = $false

        foreach ($textFile in $textFiles)
        {
            $fileContent = Get-Content -Path $textFile.FullName -Raw

            if([String]::IsNullOrWhiteSpace($fileContent))
            {
                Write-Warning -Message "File $($textFile.FullName) is empty. Please remove this file."
                $containsEmptyFile = $true
            }
        }

        $containsEmptyFile | Should Be $false
    }

    It 'Should not contain files without a newline at the end' {
        $containsFileWithoutNewLine = $false

        foreach ($textFile in $textFiles)
        {
            $fileContent = Get-Content -Path $textFile.FullName -Raw

            if(-not [String]::IsNullOrWhiteSpace($fileContent) -and $fileContent[-1] -ne "`n")
            {
                if (-not $containsFileWithoutNewLine)
                {
                    Write-Warning -Message 'Each file must end with a new line.'
                }

                Write-Warning -Message "$($textFile.FullName) does not end with a new line. Use fixer function 'Add-NewLine'"

                $containsFileWithoutNewLine = $true
            }
        }


        $containsFileWithoutNewLine | Should Be $false
    }

    Context 'When repository contains markdown files' {
        $markdownFileExtensions = @('.md')

        $markdownFiles = $textFiles |
                            Where-Object { $markdownFileExtensions -contains $_.Extension }

        foreach ($markdownFile in $markdownFiles)
        {
            It ('Markdown file ''{0}'' should not have Byte Order Mark (BOM)' -f $markdownFile.Name) {
                # This reads the first three bytes of the first row.
                $firstThreeBytes = Get-Content -Path $markdownFile.FullName -Encoding Byte -ReadCount 3 -TotalCount 3

                # Check for the correct byte order (239,187,191) which equal the Byte Order Mark (BOM).
                $markdownFileHasBom = ($firstThreeBytes[0] -eq 239 `
                    -and $firstThreeBytes[1] -eq 187 `
                    -and $firstThreeBytes[2] -eq 191)

                if ($markdownFileHasBom) {
                    Write-Warning -Message "$($markdownFile.FullName) contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $markdownFileHasBom | Should Be $false
            }
        }
    }
}

Describe 'Common Tests - .psm1 File Parsing' {
    $psm1Files = Get-Psm1FileList -FilePath $moduleRootFilePath

    foreach ($psm1File in $psm1Files)
    {
        Context $psm1File.Name {
            It 'Should not contain parse errors' {
                $containsParseErrors = $false

                $parseErrors = Get-FileParseErrors -FilePath $psm1File.FullName

                if ($null -ne $parseErrors)
                {
                    Write-Warning -Message "There are parse errors in $($psm1File.FullName):"
                    Write-Warning -Message ($parseErrors | Format-List | Out-String)

                    $containsParseErrors = $true
                }

                $containsParseErrors | Should Be $false
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

    $moduleName = (Get-Item -Path $moduleRootFilePath).Name
    $moduleManifestPath = Join-Path -Path $moduleRootFilePath -ChildPath "$moduleName.psd1"

    <#
        ErrorAction specified as SilentelyContinue because this call will throw an error
        on machines with an older PS version than the manifest requires. WMF 5.1 machines
        are not yet available on AppVeyor, so modules that require 5.1 (PSDscResources)
        would always crash this test.
    #>
    $moduleManifestProperties = Test-ModuleManifest -Path $moduleManifestPath -ErrorAction 'SilentlyContinue'

    It "Should contain a PowerShellVersion property of at least $minimumPSVersion based on resource types" {
        $moduleManifestProperties.PowerShellVersion -ge $minimumPSVersion | Should Be $true
    }

    if ($containsClassResource)
    {
        $classResourcesInModule = Get-ClassResourceNameFromFile -FilePath $moduleRootFilePath

        Context 'Requirements for manifest of module with class-based resources' {
            foreach ($classResourceInModule in $classResourcesInModule)
            {
                It "Should explicitly export $classResourceInModule in DscResourcesToExport" {
                    $moduleManifestProperties.ExportedDscResources -contains $classResourceInModule | Should Be $true
                }

                It "Should include class module $classResourceInModule.psm1 in NestedModules" {
                    $moduleManifestProperties.NestedModules.Name -contains $classResourceInModule | Should Be $true
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
                Test-xDscResource -Name $scriptResourcePath | Should Be $true
            }

            It 'Should pass Test-xDscSchema' {
                $mofSchemaFilePath = Join-Path -Path $scriptResourcePath -ChildPath "$scriptResourceName.schema.mof"
                Test-xDscSchema -Path $mofSchemaFilePath | Should Be $true
            }
        }
    }
}

<#
    PSSA = PS Script Analyzer
    Only the first and last tests here will pass/fail correctly at the moment. The other 3 tests
    will currently always pass, but print warnings based on the problems they find.
    These automatic passes are here to give contributors time to fix the PSSA
    problems before we turn on these tests. These 'automatic passes' should be removed
    along with the first test (which is replaced by the following 3) around Jan-Feb
    2017.
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
                Path = $dscResourcesPsm1File.FullName
                ErrorAction = 'SilentlyContinue'
                Recurse = $true
            }

            Context $dscResourcesPsm1File.Name {
                It 'Should pass all error-level PS Script Analyzer rules' {
                    $errorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -Severity 'Error'

                    if ($null -ne $errorPssaRulesOutput)
                    {
                        Write-Warning -Message 'Error-level PSSA rule(s) did not pass.'
                        Write-Warning -Message 'The following PSScriptAnalyzer errors need to be fixed:'

                        foreach ($errorPssaRuleOutput in $errorPssaRulesOutput)
                        {
                            Write-Warning -Message "$($errorPssaRuleOutput.ScriptName) (Line $($errorPssaRuleOutput.Line)): $($errorPssaRuleOutput.Message)"
                        }

                        Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/PSScriptAnalyzer'
                    }

                    $errorPssaRulesOutput | Should Be $null
                }

                It 'Should pass all required PS Script Analyzer rules' {
                    $requiredPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $requiredPssaRuleNames

                    if ($null -ne $requiredPssaRulesOutput)
                    {
                        Write-Warning -Message 'Required PSSA rule(s) did not pass.'
                        Write-Warning -Message 'The following PSScriptAnalyzer errors need to be fixed:'

                        foreach ($requiredPssaRuleOutput in $requiredPssaRulesOutput)
                        {
                            Write-Warning -Message "$($requiredPssaRuleOutput.ScriptName) (Line $($requiredPssaRuleOutput.Line)): $($requiredPssaRuleOutput.Message)"
                        }

                        Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/PSScriptAnalyzer'
                    }

                    <#
                        Automatically passing this test since it may break several resource modules at the moment.
                        Automatic pass to be removed Jan-Feb 2017.
                    #>
                    $requiredPssaRulesOutput = $null
                    $requiredPssaRulesOutput | Should Be $null
                }

                It 'Should pass all flagged PS Script Analyzer rules' {
                    $flaggedPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $flaggedPssaRuleNames

                    if ($null -ne $flaggedPssaRulesOutput)
                    {
                        Write-Warning -Message 'Flagged PSSA rule(s) did not pass.'
                        Write-Warning -Message 'The following PSScriptAnalyzer errors need to be fixed or approved to be suppressed:'

                        foreach ($flaggedPssaRuleOutput in $flaggedPssaRulesOutput)
                        {
                            Write-Warning -Message "$($flaggedPssaRuleOutput.ScriptName) (Line $($flaggedPssaRuleOutput.Line)): $($flaggedPssaRuleOutput.Message)"
                        }

                        Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/PSScriptAnalyzer'
                    }

                    <#
                        Automatically passing this test since it may break several resource modules at the moment.
                        Automatic pass to be removed Jan-Feb 2017.
                    #>
                    $flaggedPssaRulesOutput = $null
                    $flaggedPssaRulesOutput | Should Be $null
                }

                It 'Should pass any recently-added, error-level PS Script Analyzer rules' {
                    $knownPssaRuleNames = $requiredPssaRuleNames + $flaggedPssaRuleNames + $ignorePssaRuleNames

                    $newErrorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -ExcludeRule $knownPssaRuleNames -Severity 'Error'

                    if ($null -ne $newErrorPssaRulesOutput)
                    {
                        Write-Warning -Message 'Recently-added, error-level PSSA rule(s) did not pass.'
                        Write-Warning -Message 'The following PSScriptAnalyzer errors need to be fixed or approved to be suppressed:'

                        foreach ($newErrorPssaRuleOutput in $newErrorPssaRulesOutput)
                        {
                            Write-Warning -Message "$($newErrorPssaRuleOutput.ScriptName) (Line $($newErrorPssaRuleOutput.Line)): $($newErrorPssaRuleOutput.Message)"
                        }

                        Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/PSScriptAnalyzer'
                    }

                    <#
                        Automatically passing this test since it may break several resource modules at the moment.
                        Automatic pass to be removed Jan-Feb 2017.
                    #>
                    $newErrorPssaRulesOutput = $null
                    $newErrorPssaRulesOutput | Should Be $null
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

                    $requiredRuleIsSuppressed | Should Be $false
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
    $optin = Get-PesterDescribeOptInStatus -OptIns $optIns

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
            $psHomePSModulePathItem = Get-PSHomePSModulePathItem
            $powershellModulePath = Join-Path -Path $psHomePSModulePathItem -ChildPath $repoName

            Write-Verbose -Message ('Copying module from ''{0}'' to ''{1}''' -f $moduleRootFilePath, $powershellModulePath) -Verbose

            # Creates the destination module folder.
            New-Item -Path $powershellModulePath -ItemType Directory -Force

            # Copies all module files into the destination module folder.
            Copy-Item -Path (Join-Path -Path $moduleRootFilePath -ChildPath '*') `
                      -Destination $powershellModulePath `
                      -Exclude @('node_modules','.*') `
                      -Recurse `
                      -Force
        }

        $exampleFile = Get-ChildItem -Path (Join-Path -Path $moduleRootFilePath -ChildPath 'Examples') -Filter '*.ps1' -Recurse
        foreach ($exampleToValidate in $exampleFile)
        {
            $exampleDescriptiveName = Join-Path -Path (Split-Path $exampleToValidate.Directory -Leaf) -ChildPath (Split-Path $exampleToValidate -Leaf)

            Context -Name $exampleDescriptiveName {
                It "Should compile MOFs for example correctly" -Skip:(!$optin) {
                    {
                        $mockPassword = ConvertTo-SecureString '&iPm%M5q3K$Hhq=wcEK' -AsPlainText -Force
                        $mockCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @('username', $mockPassword)
                        $mockConfigurationData = @{
                            AllNodes = @(
                                @{
                                    NodeName = 'localhost'
                                    PSDscAllowPlainTextPassword = $true
                                }
                            )
                        }

                        try
                        {
                            . $exampleToValidate.FullName

                            $exampleCommand = Get-Command -Name Example -ErrorAction SilentlyContinue
                            if ($exampleCommand)
                            {
                                    $params = @{}

                                    # Each credential parameter in the Example function is assigned the mocked credential. 'PsDscRunAsCredential' is not assigned because that broke the example.
                                    $credentialParameterToMockCredentialFor = $exampleCommand.Parameters.Keys | Where-Object {
                                        $_ -like '*Account' `
                                        -or ($_ -like '*Credential' -and $_ -ne 'PsDscRunAsCredential') `
                                        -or $_ -like '*Passphrase'
                                    }

                                    foreach ($currentParameter in $credentialParameterToMockCredentialFor)
                                    {
                                        $params.Add($currentParameter, $mockCredential)
                                    }

                                    <#
                                        If there is a $ConfigurationData variable that was dot-sources.
                                        Then use that as the configuration data instead of the mocked confgiuration data.
                                    #>
                                    if (Get-Item -Path variable:ConfigurationData -ErrorAction SilentlyContinue)
                                    {
                                        $mockConfigurationData = $ConfigurationData
                                    }

                                    Example @params -ConfigurationData $mockConfigurationData -OutputPath 'TestDrive:\' -ErrorAction Continue -WarningAction SilentlyContinue | Out-Null
                            }
                            else
                            {
                                throw "The example '$exampleDescriptiveName' does not contain a function 'Example'."
                            }
                        }
                        finally
                        {
                            # Remove the function we dot-sourced so next example file doesn't use the previous Example-function.
                            Remove-Item -Path function:Example -ErrorAction SilentlyContinue

                            # Remove the variable $ConfigurationData if it existed in the file we dot-sourced so next example file doesn't use the previous examples configuration.
                            Remove-Item -Path variable:ConfigurationData -ErrorAction SilentlyContinue
                        }
                    } | Should Not Throw
                }
            }
        }

        if ($env:APPVEYOR -eq $true)
        {
            Remove-item -Path $powershellModulePath -Recurse -Force -Confirm:$false

            # Restore the load of the module to ensure future tests have access to it
            Import-Module -Name (Join-Path -Path $moduleRootFilePath `
                                           -ChildPath "$repoName.psd1") `
                          -Global
        }
    }
}

Describe 'Common Tests - Validate Markdown Files' -Tag 'Markdown' {
    $optin = Get-PesterDescribeOptInStatus -OptIns $optIns

    if (Get-Command -Name 'npm' -ErrorAction SilentlyContinue)
    {
        Write-Warning -Message "NPM is checking Gulp is installed. This may take a few moments."

        $null = Start-Process `
            -FilePath "npm" `
            -ArgumentList @('install','--silent') `
            -Wait `
            -WorkingDirectory $PSScriptRoot `
            -PassThru `
            -NoNewWindow
        $null = Start-Process `
            -FilePath "npm" `
            -ArgumentList @('install','-g','gulp','--silent') `
            -Wait `
            -WorkingDirectory $PSScriptRoot `
            -PassThru `
            -NoNewWindow

        if (Test-Path -Path (Join-Path -Path $repoRootPath -ChildPath '.markdownlint.json'))
        {
            Write-Verbose -Message ('Using markdownlint settings file from repository folder ''{0}''.' -f $repoRootPath) -Verbose
            $markdownlintSettingsFilePath = Join-Path -Path $repoRootPath -Childpath '.markdownlint.json'
        }
        else
        {
            Write-Verbose -Message 'Using markdownlint settings file from DscResource.Test repository.' -Verbose
            $markdownlintSettingsFilePath = $null
        }

        It "Should not have errors in any markdown files" {

            $mdErrors = 0
            try
            {

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

                Start-Process -FilePath "gulp" -ArgumentList $gulpArgumentList `
                    -Wait -WorkingDirectory $PSScriptRoot -PassThru -NoNewWindow
                Start-Sleep -Seconds 3
                $mdIssuesPath = Join-Path -Path $PSScriptRoot -ChildPath "markdownissues.txt"

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
                Write-Warning -Message ("Unable to run gulp to test markdown files. Please " + `
                                        "be sure that you have installed nodejs and have " + `
                                        "run 'npm install -g gulp' in order to have this " + `
                                        "text execute.")
            }
            if($optin)
            {
                $mdErrors | Should Be 0
            }
        }

        # We're using this tool to delete the node_modules folder because it gets too long
        # for PowerShell to remove.
        $null = Start-Process `
            -FilePath "npm" `
            -ArgumentList @('install','rimraf','-g','--silent') `
            -Wait `
            -WorkingDirectory $PSScriptRoot `
            -PassThru `
            -NoNewWindow
        $null = Start-Process `
            -FilePath "rimraf" `
            -ArgumentList @(Join-Path -Path $PSScriptRoot -ChildPath 'node_modules') `
            -Wait `
            -WorkingDirectory $PSScriptRoot `
            -PassThru `
            -NoNewWindow
    }
    else
    {
        Write-Warning -Message ("Unable to run gulp to test markdown files. Please " + `
                                "be sure that you have installed nodejs and npm in order " + `
                                "to have this text execute.")
    }
}
