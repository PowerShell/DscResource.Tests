<#
    .SYNOPSIS
        This module provides functions for building and testing DSC Resources in AppVeyor.

        These functions will only work if called within an AppVeyor CI build task.
#>

$customTasksModulePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                   -ChildPath '.AppVeyor\CustomAppVeyorTasks.psm1'
if (Test-Path -Path $customTasksModulePath)
{
    Import-Module -Name $customTasksModulePath
    $customTaskModuleLoaded = $true
}
else
{
    $customTaskModuleLoaded = $false
}

<#
    .SYNOPSIS
        Prepares the AppVeyor build environment to perform tests and packaging on a
        DSC Resource module.

        Performs the following tasks:
        1. Installs Nuget Package Provider DLL.
        2. Installs Nuget.exe to the AppVeyor Build Folder.
        3. Installs the Pester PowerShell Module.
        4. Executes Invoke-CustomAppveyorInstallTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
           in resource module repository.

    .EXAMPLE
        Invoke-AppveyorInstallTask -PesterMaximumVersion 3.4.3
#>
function Invoke-AppveyorInstallTask
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [Version]
        $PesterMaximumVersion
    )

    # Load the test helper module
    $testHelperPath = Join-Path -Path $PSScriptRoot `
                                -ChildPath 'TestHelper.psm1'
    Import-Module -Name $testHelperPath -Force

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    # Install Nuget.exe to enable package creation
    $nugetExePath = Join-Path -Path $env:TEMP `
                              -ChildPath 'nuget.exe'
    Install-NugetExe -OutFile $nugetExePath

    $installPesterParameters = @{
        Name = 'Pester'
        Force = $true
    }

    $installModuleSupportsSkipPublisherCheck = (Get-Command Install-Module).Parameters['SkipPublisherCheck']
    if ($installModuleSupportsSkipPublisherCheck)
    {
        $installPesterParameters['SkipPublisherCheck'] = $true
    }

    if ($PesterMaximumVersion)
    {
        $installPesterParameters['MaximumVersion'] = $PesterMaximumVersion
    }

    Install-Module @installPesterParameters

    # Execute the custom install task if defined
    if ($customTaskModuleLoaded `
        -and (Get-Command -Module $CustomAppVeyorTasks `
                          -Name Invoke-CustomAppveyorInstallTask `
                          -ErrorAction SilentlyContinue))
    {
        Invoke-CustomAppveyorInstallTask
    }

    Write-Info -Message 'Install Task Complete.'
}

<#
    .SYNOPSIS
        Executes the tests on a DSC Resource in the AppVeyor build environment.

        Executes Start-CustomAppveyorTestTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
        in resource module repository.

    .PARAMETER Type
        This controls the method of running the tests.
        To use execute tests using a test harness function specify 'Harness', otherwise
        leave empty to use default value 'Default'.

    .PARAMETER MainModulePath
        This is the relative path of the folder that contains the module manifest.
        If not specified it will default to the root folder of the repository.

    .PARAMETER CodeCoverage
        This will switch on Code Coverage evaluation in Pester.

    .PARAMETER ExcludeTag
        This is the list of tags that will be used to prevent tests from being run if
        the tag is set in the describe block of the test.
        This wll default to 'Examples' and 'Markdown'.

    .PARAMETER HarnessModulePath
        This is the full path and filename of the test harness module.
        If not specified it will default to 'Tests\TestHarness.psm1'.

    .PARAMETER HarnessFunctionName
        This is the function name in the harness module to call to execute tests.
        If not specified it will default to 'Invoke-TestHarness'.

    .PARAMETER CodeCovIo
        This will switch on reporting of code coverage to codecov.io.  Require -CodeCoverage when running with -type default.
#>
function Invoke-AppveyorTestScriptTask
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [ValidateSet('Default','Harness')]
        [String]
        $Type = 'Default',

        [ValidateNotNullOrEmpty()]
        [String]
        $MainModulePath = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter(ParameterSetName = 'DefaultCodeCoverage')]
        [Switch]
        $CodeCoverage,

        [Parameter(ParameterSetName = 'Harness')]
        [Parameter(ParameterSetName = 'DefaultCodeCoverage')]
        [Switch]
        $CodeCovIo,

        [Parameter(ParameterSetName = 'DefaultCodeCoverage')]
        [Parameter(ParameterSetName = 'Default')]
        [String[]]
        $ExcludeTag = @('Examples','Markdown'),

        [Parameter(ParameterSetName = 'Harness',
            Mandatory = $true)]
        [String]
        $HarnessModulePath = 'Tests\TestHarness.psm1',

        [Parameter(ParameterSetName = 'Harness',
            Mandatory = $true)]
        [String]
        $HarnessFunctionName = 'Invoke-TestHarness',

        [Parameter()]
        [Switch]
        $DisableConsistency,

        [Parameter()]
        [Switch]
        $RunTestInOrder
    )

    # Load the test helper module
    $testHelperPath = Join-Path -Path $PSScriptRoot `
                                -ChildPath 'TestHelper.psm1'
    Import-Module -Name $testHelperPath -Force

    # Convert the Main Module path into an absolute path if it is relative
    if (-not ([System.IO.Path]::IsPathRooted($MainModulePath)))
    {
        $MainModulePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                    -ChildPath $MainModulePath
    }

    $testResultsFile = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                 -ChildPath 'TestsResults.xml'

    # Execute custom test task if defined
    if ($customTaskModuleLoaded `
        -and (Get-Command -Module $CustomAppVeyorTasks `
                          -Name Start-CustomAppveyorTestTask `
                          -ErrorAction SilentlyContinue))
    {
        Start-CustomAppveyorTestTask
    }

    if ($DisableConsistency.IsPresent)
    {
        $disableConsistencyMofPath = Join-Path -Path $env:temp -ChildPath 'DisableConsistency'
        if (-not (Test-Path -Path $disableConsistencyMofPath))
        {
            $null = New-Item -Path $disableConsistencyMofPath -ItemType Directory -Force
        }

        # have LCM Apply only once.
        Configuration Meta
        {
            LocalConfigurationManager
            {
                ConfigurationMode = 'ApplyOnly'
            }
        }
        meta -outputPath $disableConsistencyMofPath

        Set-DscLocalConfigurationManager -Path $disableConsistencyMofPath -Force -Verbose
        $null = Remove-Item -LiteralPath $disableConsistencyMofPath -Recurse -Force -Confirm:$false
    }

    $moduleName = Split-Path -Path $env:APPVEYOR_BUILD_FOLDER -Leaf
    $testsPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath 'Tests'

    $configurationFiles = Get-ChildItem -Path $testsPath -Include '*.config.ps1' -Recurse
    foreach ($configurationFile in $configurationFiles)
    {
        # Get the list of additional modules required by the example
        $requiredModules = Get-ResourceModulesInConfiguration -ConfigurationPath $configurationFile.FullName |
            Where-Object -Property Name -ne $moduleName

        if ($requiredModules)
        {
            Install-DependentModule -Module $requiredModules
        }
    }

    switch ($Type)
    {
        'Default'
        {
            # Execute the standard tests using Pester.
            $pesterParameters = @{
                OutputFormat = 'NUnitXML'
                OutputFile   = $testResultsFile
                PassThru     = $True
            }
            if ($ExcludeTag.Count -gt 0)
            {
                $pesterParameters += @{
                    ExcludeTag = $ExcludeTag
                }
            }
            if ($CodeCoverage)
            {
                Write-Warning -Message 'Code coverage statistics are being calculated. This will slow the start of the tests while the code matrix is built. Please be patient.'

                # Only add code path for DSCResources if they exist.
                $codeCoveragePaths = @(
                    "$env:APPVEYOR_BUILD_FOLDER\*.psm1"
                )

                # Define the folders to check, if found add the path for codecoverage
                $possibleModulePaths = @(
                    'DSCResources',
                    'DSCClassResources'
                )

                foreach ($possibleModulePath in $possibleModulePaths)
                {
                    if (Test-Path -Path $MainModulePath\$possibleModulePath)
                    {
                        $codeCoveragePaths += "$env:APPVEYOR_BUILD_FOLDER\$possibleModulePath\*.psm1"
                        $codeCoveragePaths += "$env:APPVEYOR_BUILD_FOLDER\$possibleModulePath\**\*.psm1"
                    }
                }

                $pesterParameters += @{
                    CodeCoverage = $codeCoveragePaths
                }
            }

            $getChildItemParameters = @{
                Path = $env:APPVEYOR_BUILD_FOLDER
                Recurse = $true
            }

            # Get all tests '*.Tests.ps1'.
            $getChildItemParameters['Filter'] = '*.Tests.ps1'
            $testFiles = Get-ChildItem @getChildItemParameters

            <#
                If it is another repository other than DscResource.Tests
                then remove the DscResource.Tests unit tests from the list
                of tests to run. Issue #189.
            #>
            if (-not (Test-IsRepositoryDscResourceTests))
            {
                $testFiles = $testFiles | Where-Object -FilterScript {
                    $_.FullName -notmatch 'DSCResource.Tests\\Tests'
                }
            }

            if ($RunTestInOrder)
            {
                <#
                    This is an array of test files containing path
                    and optional order number.
                #>
                $testObjects = @()

                # Add all tests to the array with order number set to $null
                foreach ($testFile in $testFiles)
                {
                    $testObjects += @(
                        [PSCustomObject] @{
                            TestPath = $testFile.FullName
                            OrderNumber = $null
                        }
                    )
                }

                <#
                    Make sure all common tests are always run first
                    by setting order number to zero (0).
                #>
                $testObjects | Where-Object -FilterScript {
                    $_.TestPath -match 'DSCResource.Tests'
                } | ForEach-Object -Process {
                    $_.OrderNumber = 0
                }

                # Get each integration test config files ('*.config.ps1').
                $getChildItemParameters['Filter'] = '*.config.ps1'
                $integrationTestConfigurationFiles = Get-ChildItem @getChildItemParameters

                <#
                    In each file, search for existens of attribute 'IntegrationTest' with a
                    named attribute argument 'OrderNumber'.
                #>
                foreach ($integrationTestConfigurationFile in $integrationTestConfigurationFiles)
                {
                    $orderNumber = Get-DscIntegrationTestOrderNumber `
                        -Path $integrationTestConfigurationFile.FullName

                    if ($orderNumber)
                    {
                        <#
                            Build the correct integration test file name, by
                            replacing '.config.ps1' with '.Integration.Tests.ps1'.
                        #>
                        $testFileName = $integrationTestConfigurationFile.FullName `
                            -replace '.config.ps1', '.Integration.Tests.ps1'

                        <#
                            If the test must run in order, find the correct
                            test and add the order number to object in the array..
                        #>
                        ($testObjects | Where-Object -FilterScript {
                            $_.TestPath -eq $testFileName
                        }).OrderNumber = $orderNumber
                    }
                }

                <#
                    This is an array of the test files in the correct
                    order they will be run.

                    First the common tests will always run.
                    Secondly the tests that use mocks will run (unit tests).
                    Thirdly, those the tests that actually changes things
                    (integration tests) will run in order.
                #>
                $testObjectOrder = @()

                # Add tests that have OrderNumber -eq 0
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $_.OrderNumber -eq 0
                }

                # Add tests that uses mocks (unit tests).
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $null -eq $_.OrderNumber `
                    -and $_.TestPath -notmatch 'Integration.Tests'
                }

                # Add integration tests that must run in the correct order
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $null -ne $_.OrderNumber `
                    -and $_.OrderNumber -ne 0
                } | Sort-Object -Property 'OrderNumber'

                # Then add the rest of the integration tests.
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $null -eq $_.OrderNumber `
                    -and $_.TestPath -match 'Integration.Tests'
                }

                # Add all the paths to the Invoke-Pester Path parameter.
                $pesterParameters += @{
                    Path = $testObjectOrder.TestPath
                }
                               
                $results = Invoke-Pester @pesterParameters
            }
            else
            {
                $pesterParameters += @{
                    Path = $testFiles.FullName
                }

                $results = Invoke-Pester @pesterParameters
            }

            break
        }
        'Harness'
        {
            # Copy the DSCResource.Tests folder into the folder containing the resource PSD1 file.
            $dscTestsPath = Join-Path -Path $MainModulePath `
                                      -ChildPath 'DSCResource.Tests'
            Copy-Item -Path $PSScriptRoot -Destination $MainModulePath -Recurse
            $testHarnessPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                         -ChildPath $HarnessModulePath

            # Execute the resource tests as well as the DSCResource.Tests\meta.tests.ps1
            Import-Module -Name $testHarnessPath
            $results = & $HarnessFunctionName -TestResultsFile $testResultsFile `
                                             -DscTestsPath $dscTestsPath

            # Delete the DSCResource.Tests folder because it is not needed
            Remove-Item -Path $dscTestsPath -Force -Recurse
            break
        }
        default
        {
            throw "An unhandled type '$Type' was specified."
        }
    }

    foreach ($result in $results.TestResult)
    {
        [string] $describeName = $result.Describe -replace '\\', '/'
        [string] $contextName = $result.Context -replace '\\', '/'
        $componentName = '{0}; Context: {1}' -f $describeName, $contextName
        $appVeyorResult = $result.Result
        # Convert any result not know by AppVeyor to an AppVeyor Result
        switch ($result.Result)
        {
            'Pending'
            {
                $appVeyorResult = 'Skipped'
            }
        }

        $addAppVeyorTestParameters = @{
            Name = $result.Name
            Framework = 'NUnit'
            Filename = $componentName
            Outcome = $appVeyorResult
            Duration = $result.Time.TotalMilliseconds
        }

        if ($result.FailureMessage)
        {
            $addAppVeyorTestParameters += @{
                ErrorMessage = $result.FailureMessage
                ErrorStackTrace = $result.StackTrace
            }
        }

        Add-AppveyorTest @addAppVeyorTestParameters
    }

    Push-TestArtifact -Path $testResultsFile

    if ($CodeCovIo.IsPresent)
    {
        if ($results.CodeCoverage)
        {
            Write-Info -Message 'Uploading CodeCoverage to CodeCov.io...'
            Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.CodeCoverage')
            $jsonPath = Export-CodeCovIoJson -CodeCoverage $results.CodeCoverage -repoRoot $env:APPVEYOR_BUILD_FOLDER
            Invoke-UploadCoveCoveIoReport -Path $jsonPath
        }
        else
        {
            Write-Warning -Message 'Could not create CodeCov.io report because pester results object did not contain a CodeCoverage object'
        }
    }

    Write-Verbose -Message "Test result Type: $($results.GetType().FullName)"

    Write-Info -Message 'Done running tests.'

    if ($results.FailedCount -gt 0)
    {
        throw "$($results.FailedCount) tests failed."
    }

    Write-Info -Message 'Test Script Task Complete.'
}

<#
    .SYNOPSIS
        Performs the after tests tasks for the AppVeyor build process.

        This includes:
        1. Optional: Produce and upload Wiki documentation to AppVeyor.
        2. Set version number in Module Manifest to build version
        3. Zip up the module content and produce a checksum file and upload to AppVeyor.
        4. Pack the module into a Nuget Package.
        5. Upload the Nuget Package to AppVeyor.

        Executes Start-CustomAppveyorAfterTestTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
        in resource module repository.

    .PARAMETER Type
        This controls the additional processes that can be run after testing.
        To produce wiki documentation specify 'Wiki', otherwise leave empty to use
        default value 'Default'.

    .PARAMETER MainModulePath
        This is the relative path of the folder that contains the module manifest.
        If not specified it will default to the root folder of the repository.

    .PARAMETER ResourceModuleName
        Name of the Resource Module being produced.
        If not specified will default to GitHub repository name.

    .PARAMETER Author
        The Author string to insert into the NUSPEC file for the package.
        If not specified will default to 'Microsoft'.

    .PARAMETER Owners
        The Owners string to insert into the NUSPEC file for the package.
        If not specified will default to 'Microsoft'.
#>
function Invoke-AppveyorAfterTestTask
{

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [Parameter()]
        [ValidateSet('Default','Wiki')]
        [String]
        $Type = 'Default',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $MainModulePath = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter()]
        [String]
        $ResourceModuleName = (($env:APPVEYOR_REPO_NAME -split '/')[1]),

        [Parameter()]
        [String]
        $Author = 'Microsoft',

        [Parameter()]
        [String]
        $Owners = 'Microsoft'
    )

    # Convert the Main Module path into an absolute path if it is relative
    if (-not ([System.IO.Path]::IsPathRooted($MainModulePath)))
    {
        $MainModulePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                    -ChildPath $MainModulePath
    }

    if ($Type -eq 'Wiki')
    {
        # Write the PowerShell help files
        $docoPath = Join-Path -Path $MainModuleFolder `
                              -ChildPath 'en-US'
        New-Item -Path $docoPath -ItemType Directory

        # Clone the DSCResources Module to the repository folder
        $docoHelperPath = Join-Path -Path $PSScriptRoot `
                                    -ChildPath 'DscResource.DocumentationHelper\DscResource.DocumentationHelper.psd1'
        Import-Module -Name $docoHelperPath
        New-DscResourcePowerShellHelp -OutputPath $docoPath -ModulePath $MainModulePath -Verbose

        # Generate the wiki content for the release and zip/publish it to appveyor
        $wikiContentPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath "wikicontent"
        New-Item -Path $wikiContentPath -ItemType Directory
        New-DscResourceWikiSite -OutputPath $wikiContentPath -ModulePath $MainModulePath -Verbose

        $zipFileName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                 -ChildPath "$($ResourceModuleName)_$($env:APPVEYOR_BUILD_VERSION)_wikicontent.zip"
        Compress-Archive -Path (Join-Path -Path $wikiContentPath -ChildPath '*') `
                         -DestinationPath $zipFileName
        Get-ChildItem -Path $zipFileName | ForEach-Object -Process {
            Push-AppveyorArtifact -Path $_.FullName -FileName $_.Name
        }

        # Remove the readme files that are used to generate documentation so they aren't shipped
        $readmePaths = Join-Path -Path $MainModuleFolder `
                                 -ChildPath '**\readme.md'
        Get-ChildItem -Path $readmePaths -Recurse | Remove-Item -Confirm:$false
    }

    # Set the Module Version in the Manifest to the AppVeyor build version
    $manifestPath = Join-Path -Path $MainModulePath `
                              -ChildPath "$ResourceModuleName.psd1"
    $manifestContent = Get-Content -Path $manifestPath -Raw
    $regex = '(?<=ModuleVersion\s+=\s+'')(?<ModuleVersion>.*)(?='')'
    $manifestContent = $manifestContent -replace $regex,$env:APPVEYOR_BUILD_VERSION
    Set-Content -Path $manifestPath -Value $manifestContent -Force

    # Zip and Publish the Main Module Folder content
    $zipFileName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                             -ChildPath "$($ResourceModuleName)_$($env:APPVEYOR_BUILD_VERSION).zip"
    Compress-Archive -Path (Join-Path -Path $MainModulePath -ChildPath '*') `
                     -DestinationPath $zipFileName
    New-DscChecksum -Path $env:APPVEYOR_BUILD_FOLDER -Outpath $env:APPVEYOR_BUILD_FOLDER
    Get-ChildItem -Path $zipFileName | ForEach-Object -Process {
        Push-AppveyorArtifact -Path $_.FullName -FileName $_.Name
    }
    Get-ChildItem -Path "$zipFileName.checksum" | ForEach-Object -Process {
        Push-AppveyorArtifact -Path $_.FullName -FileName $_.Name
    }

    # Create the Nuspec file for the Nuget Package in the Main Module Folder
    $nuspecPath = Join-Path -Path $MainModulePath `
                            -ChildPath "$ResourceModuleName.nuspec"
    $nuspecParams = @{
        packageName = $ResourceModuleName
        destinationPath = $MainModulePath
        version = $env:APPVEYOR_BUILD_VERSION
        author = $Author
        owners = $Owners
        licenseUrl = "https://github.com/PowerShell/DscResources/blob/master/LICENSE"
        projectUrl = "https://github.com/$($env:APPVEYOR_REPO_NAME)"
        packageDescription = $ResourceModuleName
        tags = "DesiredStateConfiguration DSC DSCResourceKit"
    }
    New-Nuspec @nuspecParams

    # Create the Nuget Package
    $nugetExePath = Join-Path -Path $env:TEMP `
                              -ChildPath 'nuget.exe'
    Start-Process -FilePath $nugetExePath -Wait -ArgumentList @(
        'Pack',$nuspecPath
        '-OutputDirectory',$env:APPVEYOR_BUILD_FOLDER
        '-BasePath',$MainModulePath
    )

    # Push the Nuget Package up to AppVeyor
    $nugetPackageName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                  -ChildPath "$ResourceModuleName.$($env:APPVEYOR_BUILD_VERSION).nupkg"
    Get-ChildItem $nugetPackageName | ForEach-Object -Process {
        Push-AppveyorArtifact -Path $_.FullName -FileName $_.Name
    }

    # Execute custom after test task if defined
    if ($customTaskModuleLoaded `
        -and (Get-Command -Module $CustomAppVeyorTasks `
                          -Name Start-CustomAppveyorAfterTestTask `
                          -ErrorAction SilentlyContinue))
    {
        Start-CustomAppveyorAfterTestTask
    }

    Write-Info -Message 'After Test Task Complete.'
}

<#
    .SYNOPSIS
        Writes information to the build log

    .PARAMETER Message
        The Message to write

    .EXAMPLE
        Write-Info -Message "Some build info"

#>
function Write-Info
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Message
    )

    Write-Host -ForegroundColor Yellow  "[Build Info] [$([datetime]::UtcNow)] $message"
}

<#
    .SYNOPSIS
        Uploads test artifacts

    .PARAMETER Path
        The path to the test artifacts

    .EXAMPLE
        Push-TestArtifact -Path .\TestArtifact.log

#>
function Push-TestArtifact
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Path
    )

    $resolvedPath = (Resolve-Path $Path).ProviderPath
    if (${env:APPVEYOR_JOB_ID})
    {
        <# does not work with Pester 4.0.2
        $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        Write-Info -Message "Uploading Test Results: $resolvedPath ; to: $url"
        (New-Object 'System.Net.WebClient').UploadFile($url, $resolvedPath)
        #>

        Write-Info -Message "Uploading Test Artifact: $resolvedPath"
        Push-AppveyorArtifact $resolvedPath
    }
    else
    {
        Write-Info -Message "Test Artifact: $resolvedPath"
    }
}

Export-ModuleMember -Function *
