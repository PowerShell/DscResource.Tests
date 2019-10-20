<#
    .SYNOPSIS
        This module provides functions for building and testing DSC Resources in AppVeyor.

        These functions will only work if called within an AppVeyor CI build task.
#>

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelper.psm1') -Force
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.CodeCoverage')
# Import the module containing the container helper functions.
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.Container')

# Load the test helper module.
$testHelperPath = Join-Path -Path $PSScriptRoot -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

<#
    .SYNOPSIS
        Prepares the AppVeyor build environment to perform tests and packaging on a
        DSC Resource module.

        Performs the following tasks:
        1. Installs Nuget Package Provider DLL.
        2. Installs Nuget.exe to the AppVeyor Build Folder.
        3. Installs the Pester PowerShell Module.
        4. Creates a self-signed certificate for encrypting credentials in configurations.
        5. Executes Invoke-CustomAppveyorInstallTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
           in resource module repository.

    .EXAMPLE
        Invoke-AppveyorInstallTask -PesterMaximumVersion 3.4.3
#>
function Invoke-AppveyorInstallTask
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [Parameter()]
        [Version]
        $PesterMaximumVersion
    )

    <#
        Parameter ForceBootstrap automatically installs the NuGet package provider
        if your computer does not have the NuGet package provider installed.
    #>
    Write-Info -Message 'Installing the latest NuGet package provider.'
    $getPackageProviderResult = Get-PackageProvider -Name NuGet -ForceBootstrap
    $getPackageProviderResult | Format-Table -Property @('Name', 'ProviderName', 'Version')

    Write-Info -Message 'Installing the latest PowerShellGet from the PowerShell Gallery.'
    Install-Module -Name PowerShellGet -Force -Repository PSGallery -AllowClobber

    $nuGetExePath = Join-Path -Path $env:TEMP -ChildPath 'nuget.exe'
    Write-Info -Message 'Installing nuget.exe to enable package creation.'
    Install-NugetExe -OutFile $nuGetExePath -RequiredVersion '3.4.4'

    Write-Info -Message 'Installing the latest Pester module.'

    $installPesterParameters = @{
        Name  = 'Pester'
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

    Write-Info -Message 'Create a self-signed certificate for encrypting DSC configuration credentials.'
    $null = New-DscSelfSignedCertificate

    Write-Info -Message 'Install Task Complete.'
}

<#
    .SYNOPSIS
        Executes the tests on a DSC Resource in the AppVeyor build environment.

        Executes Start-CustomAppveyorTestTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
        in resource module repository.

        Creates a self-signed certificate for encrypting credentials in configurations
        if it doesn't already exist.

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

    .PARAMETER HarnessModulePath
        This is the full path and filename of the test harness module.
        If not specified it will default to 'Tests\TestHarness.psm1'.

    .PARAMETER HarnessFunctionName
        This is the function name in the harness module to call to execute tests.
        If not specified it will default to 'Invoke-TestHarness'.

    .PARAMETER CodeCovIo
        This will switch on reporting of code coverage to codecov.io.
        Require -CodeCoverage when running with -type default.

    .PARAMETER DisableConsistency
        This will switch off monitoring (consistency) for the Local Configuration
        Manager (LCM), setting ConfigurationMode to 'ApplyOnly', on the node
        running tests.

    .PARAMETER RunTestInOrder
        This will cause the integration tests to be run in order. First, the
        common tests will run, followed by the unit tests. Finally the integration
        tests will be run in the order defined.
        Each integration test configuration file ('*.config.ps1') must be decorated
        with an attribute `Microsoft.DscResourceKit.IntegrationTest` containing
        a named attribute argument 'OrderNumber' and be assigned a numeric value
        (`1`, `2`, `3`,..). If the integration test is not decorated with the
        attribute, then that test will run among the last tests, after all the
        integration test with a specific order has run.
        This will also enable running unit tests and integration tests in a
        Docker Windows container.

    .PARAMETER CodeCoveragePath
        One or more relative paths to PowerShell modules, from the root module
        folder. For each relative folder it will recursively search the first
        level subfolders for PowerShell module files (.psm1).
        Default to 'DSCResources', 'DSCClassResources', and 'Modules'.
        This parameter is ignored when testing the DscResource.Tests repository
        since that repository is treated differently, and has hard-coded paths.
#>
function Invoke-AppveyorTestScriptTask
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [Parameter()]
        [ValidateSet('Default', 'Harness')]
        [String]
        $Type = 'Default',

        [Parameter(ParameterSetName = 'Harness')]
        [ValidateNotNullOrEmpty()]
        [String]
        $MainModulePath = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'Harness')]
        [Switch]
        $CodeCoverage,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'Harness')]
        [Switch]
        $CodeCovIo,

        [Parameter(ParameterSetName = 'Default')]
        [String[]]
        $ExcludeTag,

        [Parameter(ParameterSetName = 'Harness')]
        [String]
        $HarnessModulePath = 'Tests\TestHarness.psm1',

        [Parameter(ParameterSetName = 'Harness')]
        [String]
        $HarnessFunctionName = 'Invoke-TestHarness',

        [Parameter()]
        [Switch]
        $DisableConsistency,

        [Parameter(ParameterSetName = 'Default')]
        [Switch]
        $RunTestInOrder,

        [Parameter(ParameterSetName = 'Default')]
        [String[]]
        $CodeCoveragePath = @(
            'DSCResources',
            'DSCClassResources',
            'Modules'
        )
    )

    # Convert the Main Module path into an absolute path if it is relative
    if (-not ([System.IO.Path]::IsPathRooted($MainModulePath)))
    {
        $MainModulePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
            -ChildPath $MainModulePath
    }

    # Create a self-signed certificate for encrypting configuration credentials if it doesn't exist
    $null = New-DscSelfSignedCertificate

    $testResultsFile = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
        -ChildPath 'TestsResults.xml'

    Initialize-LocalConfigurationManager -Encrypt:$true -DisableConsistency:$DisableConsistency

    $moduleName = Split-Path -Path $env:APPVEYOR_BUILD_FOLDER -Leaf
    $testsPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath 'Tests'

    if (Test-Path -Path $testsPath)
    {
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
    }
    else
    {
        Write-Warning -Message 'The ''Tests'' folder is missing, the test framework will only run the common tests.'
    }

    <#
        Initiate the test container array so that even if no containers is
        started the logic can correctly evaluate that using $testContainer.Count
    #>
    $testContainer = @()

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
                <#
                    This code path is used to get the correct files for code
                    coverage for the tests that are run by the build worker.

                    If the container testing functionality is enabled by passing
                    the switch parameter 'RunTestInOrder', then the container
                    logic will handle the gathering of the files that are used
                    for the correct CodeCoverage.
                    Although even if the container logic is handling code coverage,
                    it will still depend on the $codeCoveragePaths array below to
                    determine the possible paths that can be used to gather the
                    files that will be used for code coverage.
                    The container logic will make sure those files that are not
                    used for code coverage in a container will be used for the
                    tests that run in the build worker.
                #>

                Write-Warning -Message 'Code coverage statistics are being calculated. This will slow the start of the tests while the code matrix is built. Please be patient.'

                # Only add code path for DSCResources if they exist.
                $codeCoveragePaths = @(
                    "$env:APPVEYOR_BUILD_FOLDER\*.psm1"
                )

                if (Test-IsRepositoryDscResourceTests)
                {
                    <#
                        The repository being tested is DscResource.Tests.
                        DscResource.Tests need a different set of paths for
                        code coverage.
                    #>
                    $codeCoveragePaths += "$env:APPVEYOR_BUILD_FOLDER\**\*.psm1"
                }
                else
                {
                    <#
                        Define the folders to check, if found add the path for
                        code coverage.
                    #>
                    $possibleModulePaths = $CodeCoveragePath

                    foreach ($possibleModulePath in $possibleModulePaths)
                    {
                        if (Test-Path -Path "$env:APPVEYOR_BUILD_FOLDER\$possibleModulePath")
                        {
                            $codeCoveragePaths += "$env:APPVEYOR_BUILD_FOLDER\$possibleModulePath\*.psm1"
                            $codeCoveragePaths += "$env:APPVEYOR_BUILD_FOLDER\$possibleModulePath\**\*.psm1"
                        }
                    }
                }

                $pesterParameters += @{
                    CodeCoverage = $codeCoveragePaths
                }
            }

            $getChildItemParameters = @{
                Path    = $env:APPVEYOR_BUILD_FOLDER
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

            if ($RunTestInOrder.IsPresent)
            {
                <#
                    This is an array of test files containing path
                    and optional order number.
                #>
                $testObjects = @()

                <#
                    Add all tests to the $testObjects array with properties set
                    to $null.
                    This array will be used to run tests in order and the correct
                    container if specified.
                #>
                foreach ($testFile in $testFiles)
                {
                    $testObjects += @(
                        [PSCustomObject] @{
                            TestPath       = $testFile.FullName
                            OrderNumber    = $null
                            ContainerName  = $null
                            ContainerImage = $null
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

                <#
                    In each file, search for existens of attribute 'IntegrationTest'
                    or 'UnitTest' with named attribute arguments.
                #>
                foreach ($testObject in $testObjects)
                {
                    # Only check for order number if it is an integration test.
                    if ($testObject.TestPath -match '\.Integration\.')
                    {
                        $orderNumber = Get-DscIntegrationTestOrderNumber `
                            -Path $testObject.TestPath

                        if ($orderNumber)
                        {
                            $testObject.OrderNumber = $orderNumber
                        }
                    }

                    $containerInformation = Get-DscTestContainerInformation `
                        -Path $testObject.TestPath

                    if ($containerInformation)
                    {
                        $testObject.ContainerName = $containerInformation.ContainerName
                        $testObject.ContainerImage = $containerInformation.ContainerImage
                    }
                }

                <#
                    This is an array of the test files in the correct
                    order they will be run.

                    - First the common tests will always run.
                    - Secondly the tests that use mocks will run (unit tests),
                      unless they should be run in a container.
                    - Finally, those the tests that actually changes things
                      (integration tests) will run in order.
                #>
                $testObjectOrder = @()

                <#
                    Add tests that have OrderNumber -eq 0 and are not assigned a
                    container. This is the common tests.
                #>
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $_.OrderNumber -eq 0 `
                        -and $null -eq $_.ContainerName
                }


                <#
                    Get all tests that have a container assigned so those can be
                    started.
                #>
                $testObjectUsingContainer = $testObjects | Where-Object -FilterScript {
                    $null -ne $_.ContainerName
                }

                <#
                    If we should run tests in one or more Docker Windows containers,
                    then those should be kicked off first.
                #>
                if ($testObjectUsingContainer)
                {
                    # Get unique container names with the corresponding container image.
                    $uniqueContainersFromTestObjects = $testObjectUsingContainer |
                        Sort-Object -Property 'ContainerName' -Unique

                    # Build all container objects
                    foreach ($uniqueContainer in $uniqueContainersFromTestObjects)
                    {
                        $testContainer += @(
                            [PSCustomObject] @{
                                ContainerName       = $uniqueContainer.ContainerName
                                ContainerImage      = $uniqueContainer.ContainerImage
                                ContainerIdentifier = $null
                                PesterResult        = $null
                                TranscriptPath      = $null
                            }
                        )
                    }

                    Write-Info -Message 'Using one or more Docker Windows containers to run tests.'

                    <#
                        Read all module files. This array list will end up
                        with only the module files that should be used for
                        code coverage in the build worker.

                        The $codeCoveragePaths array is built at the beginning
                        where the switch-statement start. This is so that
                        we only have one location where those are specified.
                    #>
                    [System.Collections.ArrayList] $moduleFile = `
                        Get-ChildItem -Path $codeCoveragePaths

                    foreach ($currentContainer in $testContainer)
                    {
                        Write-Info -Message (
                            'Building container ''{0}'' using image ''{1}''.' `
                                -f $currentContainer.ContainerName, $currentContainer.ContainerImage
                        )
                        <#
                            Filter out tests that should be run in the current
                            container, also sorts the tests in the correct order
                            if any has been set to run in specific order.
                        #>
                        $containerTestObjectOrder = $testObjectUsingContainer | Where-Object -FilterScript {
                            $_.ContainerName -eq $currentContainer.ContainerName
                        } | Sort-Object -Property 'OrderNumber'

                        $containerName = $currentContainer.ContainerName
                        $newContainerParameters = @{
                            Name        = $containerName
                            Image       = $currentContainer.ContainerImage
                            TestPath    = $containerTestObjectOrder.TestPath
                            ProjectPath = $env:APPVEYOR_BUILD_FOLDER
                        }

                        <#
                            If code coverage was chosen, then evaluate the files
                            needed to be able to calculate coverage for the files
                            tested in the container. The rest of the files are left
                            for the tests running in the build worker.
                        #>
                        if ($CodeCoverage)
                        {
                            # Read all the test files to get an object for each.
                            $testFilePath = Get-ChildItem -Path $containerTestObjectOrder.TestPath -File

                            <#
                                This will contain all the modules files that will be
                                used for code coverage in the container.
                            #>
                            $codeCoverageFile = @()

                            foreach ($currentTestFilePath in $testFilePath)
                            {
                                <#
                                    Get the base name of the test file, in other
                                    words the resource name, so we can match it
                                    against it's module script file.
                                #>
                                if ($currentTestFilePath.BaseName -match '\.Integration\.Tests')
                                {
                                    # integration test
                                    $scriptBaseName = $currentTestFilePath.BaseName -replace '\.Integration\.Tests'
                                }
                                else
                                {
                                    # Unit test
                                    $scriptBaseName = $currentTestFilePath.BaseName -replace '\.Tests'
                                }

                                $coverageFile = $moduleFile | Where-Object -FilterScript {
                                    $_.FullName -match "$scriptBaseName\.psm1"
                                }

                                if ($coverageFile)
                                {
                                    $codeCoverageFile += $coverageFile.FullName

                                    <#
                                        Remove the module script file since it should not
                                        be used for code coverage on the build worker,
                                        it should only be used for code coverage in the
                                        container.
                                    #>
                                    $moduleFile.Remove($coverageFile)
                                }
                            }

                            <#
                                The container gets the module files it needs for
                                calculating code coverage.
                            #>
                            $newContainerParameters['CodeCoverage'] = $codeCoverageFile
                        }

                        <#
                            Create the new Docker container and assign the identifier
                            to the hash table object.
                        #>
                        $currentContainer.ContainerIdentifier = New-Container @newContainerParameters

                        <#
                            This will always start the container. If for some reason
                            the container fails, the problem will be handled after
                            waiting for the container to finish (or fail). At that
                            point if the container exits with a code other than 0,
                            then the docker logs will be gathered and sent as an
                            artifact. If PowerShell.exe returned an error record then
                            that will be thrown.

                            We could have waited here for X seconds to check
                            whether the container seems to have started the task
                            (and not exited with an error code). But to save seconds
                            we assume that the container will always be able to start
                            the task successfully.
                        #>
                        Start-Container -ContainerIdentifier $currentContainer.ContainerIdentifier | Out-Null
                    }

                    <#
                        If we run in a container then the result file that is
                        generated by the test running in the build worker should
                        use a different name than the default, to differentiate
                        it from the container test result files.
                    #>
                    $testResultsFile = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                        -ChildPath 'worker_TestsResults.xml'

                    $pesterParameters['OutputFile'] = $testResultsFile

                    <#
                        The array $moduleFile will contain all the module files
                        that wasn't added for code coverage in a container.
                        The build worker gets the remaining module files to
                        calculate code coverage on.
                    #>
                    $pesterParameters['CodeCoverage'] = $moduleFile.FullName


                    Write-Info -Message 'One or more containers have been started. Build worker will continue to run other tests.'
                }

                <#
                    Add tests that uses mocks (unit tests) which does not have an
                    order number, nor have a container assigned.
                #>
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $null -eq $_.OrderNumber `
                        -and $null -eq $_.ContainerName `
                        -and $_.TestPath -notmatch 'Integration\.Tests'
                }

                <#
                    Add integration tests that must run in the correct order.
                    These test have an order number higher than 0, and contain
                    'Integration.Tests' in the filename, but does not have a
                    container assigned.
                #>
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $null -eq $_.ContainerName `
                        -and $_.OrderNumber -gt 0 `
                        -and $_.TestPath -match 'Integration\.Tests'
                } | Sort-Object -Property 'OrderNumber'

                <#
                    Finally add integration tests that can run unordered.
                    These tests do not have an order number, and do not have
                    a container assigned, but do contain 'Integration.Tests' in
                    the filename.
                #>
                $testObjectOrder += $testObjects | Where-Object -FilterScript {
                    $null -eq $_.OrderNumber `
                        -and $null -eq $_.ContainerName `
                        -and $_.TestPath -match 'Integration\.Tests'
                }

                # Add all the paths to the Invoke-Pester Path parameter.
                $pesterParameters += @{
                    Path = $testObjectOrder.TestPath
                }

                <#
                    This runs the tests on the build worker.

                    If the option was to run tests in a container, then this
                    will only run the remaining tests. The name of the result
                    file that is generated by this test run was changed by the
                    container logic, to differentiate the test result from the
                    container test result.
                #>
                $results = Invoke-Pester @pesterParameters

                <#
                    If we ran unit test in a Docker Windows container, then
                    we need to wait for the container to finish running tests.
                #>
                if ($testContainer.Count -gt 0)
                {
                    foreach ($currentContainer in $testContainer)
                    {
                        $waitContainerParameters = @{
                            ContainerIdentifier = $currentContainer.ContainerIdentifier

                            <#
                                Wait 1 hour for the container to finish the tests.
                                If the container has not returned before that time,
                                the test will fail.
                            #>
                            Timeout             = 3600
                        }

                        $containerExitCode = Wait-Container @waitContainerParameters

                        if ($containerExitCode -ne 0)
                        {
                            $containerErrorObject = Get-ContainerLog -ContainerIdentifier $currentContainer.ContainerIdentifier

                            # Upload the Docker Windows container log.
                            $containerDockerLogFileName = '{0}-DockerLog.txt' -f $currentContainer.ContainerName
                            $containerDockerLogPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath $containerDockerLogFileName
                            $containerErrorObject | Out-File -FilePath $containerDockerLogPath -Encoding ascii -Force
                            Push-TestArtifact -Path $containerDockerLogPath

                            Write-Warning -Message ('The container named ''{0}'' failed with exit code {1}. See artifact ''{2}'' for the logs. Throwing the error reported by Docker (in the log output):' -f $currentContainer.ContainerName, $containerExitCode, $containerDockerLogFileName)

                            <#
                                Loop thru the output and throw if PowerShell, that was
                                started in the container, returned an error record.
                                All other other output is ignored (sent to Out-Null).
                            #>
                            $containerErrorObject | ForEach-Object -Process {
                                if ($_ -is [System.Management.Automation.ErrorRecord])
                                {
                                    throw $_
                                }
                            } | Out-Null

                            <#
                                No error record was found that could be thrown above.
                                Write a warning that we couldn't find an error.
                            #>
                            Write-Warning -Message 'Container exited with an error, but no error record was found in the container log, so the error could not be caught.'
                        }

                        Write-Info -Message ('Container named ''{0}'' has finish running tests.' -f $currentContainer.ContainerName)

                        <#
                            Get the <container>_Transcript.txt from the container
                            and upload it as an artifact.
                        #>
                        $currentContainer.TranscriptPath = Join-Path `
                            -Path $env:APPVEYOR_BUILD_FOLDER `
                            -ChildPath ('{0}_Transcript.txt' -f $currentContainer.ContainerName)

                        $copyItemFromContainerParameters = @{
                            ContainerIdentifier = $currentContainer.ContainerIdentifier
                            Path                = $currentContainer.TranscriptPath
                            Destination         = $env:APPVEYOR_BUILD_FOLDER
                        }

                        Copy-ItemFromContainer @copyItemFromContainerParameters
                        Push-TestArtifact -Path $currentContainer.TranscriptPath

                        <#
                            Get the <container>TestsResults.xml from the container
                            and upload it as an artifact.
                        #>
                        $containerTestsResultsFilePath = Join-Path `
                            -Path $env:APPVEYOR_BUILD_FOLDER `
                            -ChildPath ('{0}_TestsResults.xml' -f $currentContainer.ContainerName)

                        $copyItemFromContainerParameters['Path'] = $containerTestsResultsFilePath
                        Copy-ItemFromContainer @copyItemFromContainerParameters
                        Push-TestArtifact -Path $containerTestsResultsFilePath

                        <#
                            Get the <container>TestsResults.json from the container
                            and upload it as an artifact.
                        #>
                        $containerTestsResultsJsonPath = Join-Path `
                            -Path $env:APPVEYOR_BUILD_FOLDER `
                            -ChildPath ('{0}_TestsResults.json' -f $currentContainer.ContainerName)

                        $copyItemFromContainerParameters['Path'] = $containerTestsResultsJsonPath
                        Copy-ItemFromContainer @copyItemFromContainerParameters
                        Push-TestArtifact -Path $containerTestsResultsJsonPath

                        Write-Info -Message ('Start listing test results from container named ''{0}''.' -f $currentContainer.ContainerName)

                        $currentContainer.PesterResult = Get-Content -Path $containerTestsResultsJsonPath | ConvertFrom-Json

                        if ($currentContainer.PesterResult.TestResult)
                        {
                            # Output the final unit test results.
                            $outTestResultParameters = @{
                                TestResult             = $currentContainer.PesterResult.TestResult
                                WaitForAppVeyorConsole = $true
                                Timeout                = 5
                            }

                            Out-TestResult @outTestResultParameters
                        }
                        else
                        {
                            throw 'The container did not report any test result! This indicates that an error occurred in the container.'
                        }

                        # Output the missed commands when code coverage is used.
                        if ($CodeCoverage.IsPresent)
                        {
                            $outMissedCommandParameters = @{
                                MissedCommand          = $currentContainer.PesterResult.CodeCoverage.MissedCommands
                                WaitForAppVeyorConsole = $true
                                Timeout                = 5
                            }

                            Out-MissedCommand @outMissedCommandParameters
                        }

                        Write-Info -Message ('End of test results from container named ''{0}''.' -f $currentContainer.ContainerName)
                    }
                }
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
    }

    $pesterTestResult = $results.TestResult

    # If tests were run in a container, add those Pester results as well.
    if ($testContainer.Count -gt 0)
    {
        foreach ($currentContainer in $testContainer)
        {
            $pesterTestResult += $currentContainer.PesterResult.TestResult
        }
    }

    Write-Info -Message 'Adding test result to AppVeyor test pane.'
    foreach ($result in $pesterTestResult)
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
            Name      = $result.Name
            Framework = 'NUnit'
            Filename  = $componentName
            Outcome   = $appVeyorResult
            Duration  = $result.Time.TotalMilliseconds
        }

        if ($result.FailureMessage)
        {
            $addAppVeyorTestParameters += @{
                ErrorMessage    = $result.FailureMessage
                ErrorStackTrace = $result.StackTrace
            }
        }

        <#
            This is a workaround until AppVeyor PowerShell module is supported
            on PowerShell Core.
        #>
        if ($PSVersionTable.PSEdition -eq 'Core')
        {
            $requestObject = @{
                testName             = $addAppVeyorTestParameters.Name
                testFramework        = $addAppVeyorTestParameters.Framework
                fileName             = $addAppVeyorTestParameters.Filename
                outcome              = $addAppVeyorTestParameters.Outcome
                durationMilliseconds = $addAppVeyorTestParameters.Duration
            }

            if ($result.FailureMessage)
            {
                $requestObject['ErrorMessage'] = $addAppVeyorTestParameters.ErrorMessage
                $requestObject['ErrorStackTrace'] = $addAppVeyorTestParameters.ErrorStackTrace
            }

            <#
                ConvertTo-Json will handle all escaping for us, like escaping
                double quotes and backslashes.
            #>
            $requestBody = $requestObject | ConvertTo-Json

            Invoke-RestMethod -Method Post -Uri "$env:APPVEYOR_API_URL/api/tests" -Body $requestBody -ContentType 'application/json' | Out-Null
        }
        else
        {
            Add-AppveyorTest @addAppVeyorTestParameters
        }
    }

    Push-TestArtifact -Path $testResultsFile

    if ($CodeCovIo.IsPresent)
    {
        # Get the code coverage result from build worker test run.
        $entireCodeCoverage = $results.CodeCoverage

        # Check whether we run in a container, and the build worker reported coverage
        if ($testContainer.Count -gt 0)
        {
            # Loop thru each container result and add it to the main coverage.
            foreach ($currentContainer in $testContainer)
            {
                if ($entireCodeCoverage)
                {
                    # Concatenate the code coverage result from the container test run.
                    $containerCodeCoverage = $currentContainer.PesterResult.CodeCoverage
                    if ($containerCodeCoverage)
                    {
                        $entireCodeCoverage.NumberOfCommandsAnalyzed += $containerCodeCoverage.NumberOfCommandsAnalyzed
                        $entireCodeCoverage.NumberOfFilesAnalyzed += $containerCodeCoverage.NumberOfFilesAnalyzed
                        $entireCodeCoverage.NumberOfCommandsExecuted += $containerCodeCoverage.NumberOfCommandsExecuted
                        $entireCodeCoverage.NumberOfCommandsMissed += $containerCodeCoverage.NumberOfCommandsMissed
                        $entireCodeCoverage.MissedCommands += $containerCodeCoverage.MissedCommands
                        $entireCodeCoverage.HitCommands += $containerCodeCoverage.HitCommands
                        $entireCodeCoverage.AnalyzedFiles += $containerCodeCoverage.AnalyzedFiles
                    }
                }
                else
                {
                    # The container was the first to report code coverage.
                    $entireCodeCoverage = $currentContainer.PesterResult.CodeCoverage
                }
            }
        }

        if ($entireCodeCoverage)
        {
            Write-Info -Message 'Uploading CodeCoverage to CodeCov.io...'
            $jsonPath = Export-CodeCovIoJson -CodeCoverage $entireCodeCoverage -repoRoot $env:APPVEYOR_BUILD_FOLDER
            Invoke-UploadCoveCoveIoReport -Path $jsonPath
        }
        else
        {
            Write-Warning -Message 'Could not create CodeCov.io report because Pester results object did not contain a CodeCoverage object'
        }
    }

    Write-Verbose -Message "Test result Type: $($results.GetType().FullName)"

    Write-Info -Message 'Done running tests.'

    $pesterFailedCount = $results.FailedCount

    if ($testContainer.Count -gt 0)
    {
        foreach ($currentContainer in $testContainer)
        {
            if ($currentContainer.PesterResult.FailedCount)
            {
                Write-Warning -Message ('The tests that ran in the container named ''{0}'' report errors. Please look at the artifact ''{1}'' for more detailed errors.' -f $currentContainer.ContainerName, (Split-Path -Path $currentContainer.TranscriptPath -Leaf))
                $pesterFailedCount += $currentContainer.PesterResult.FailedCount
            }
        }
    }

    if ($pesterFailedCount -gt 0)
    {
        throw ('{0} tests failed.' -f $pesterFailedCount)
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
        [ValidateSet('Default', 'Wiki')]
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
        $docoPath = Join-Path -Path $MainModulePath `
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
            Push-TestArtifact -Path $_.FullName -FileName $_.Name
        }

        # Remove the readme files that are used to generate documentation so they aren't shipped
        $readmePaths = Join-Path -Path $MainModulePath `
                                 -ChildPath '**\readme.md'
        Get-ChildItem -Path $readmePaths -Recurse | Remove-Item -Confirm:$false
    }

    # Set the Module Version in the Manifest to the AppVeyor build version
    $manifestPath = Join-Path -Path $MainModulePath `
        -ChildPath "$ResourceModuleName.psd1"
    $manifestContent = Get-Content -Path $manifestPath -Raw
    $regex = '(?<=ModuleVersion\s+=\s+'')(?<ModuleVersion>.*)(?='')'
    $manifestContent = $manifestContent -replace $regex, $env:APPVEYOR_BUILD_VERSION
    Set-Content -Path $manifestPath -Value $manifestContent -Force

    # Zip and Publish the Main Module Folder content
    $zipFileName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
        -ChildPath "$($ResourceModuleName)_$($env:APPVEYOR_BUILD_VERSION).zip"
    Compress-Archive -Path (Join-Path -Path $MainModulePath -ChildPath '*') `
        -DestinationPath $zipFileName
    New-DscChecksum -Path $env:APPVEYOR_BUILD_FOLDER -Outpath $env:APPVEYOR_BUILD_FOLDER
    Get-ChildItem -Path $zipFileName | ForEach-Object -Process {
        Push-TestArtifact -Path $_.FullName -FileName $_.Name
    }
    Get-ChildItem -Path "$zipFileName.checksum" | ForEach-Object -Process {
        Push-TestArtifact -Path $_.FullName -FileName $_.Name
    }

    # Create the Nuspec file for the Nuget Package in the Main Module Folder
    $nuspecPath = Join-Path -Path $MainModulePath `
        -ChildPath "$ResourceModuleName.nuspec"
    $nuspecParams = @{
        packageName        = $ResourceModuleName
        destinationPath    = $MainModulePath
        version            = $env:APPVEYOR_BUILD_VERSION
        author             = $Author
        owners             = $Owners
        licenseUrl         = "https://github.com/PowerShell/DscResources/blob/master/LICENSE"
        projectUrl         = "https://github.com/$($env:APPVEYOR_REPO_NAME)"
        packageDescription = $ResourceModuleName
        tags               = "DesiredStateConfiguration DSC DSCResourceKit"
    }
    New-Nuspec @nuspecParams

    # Create the Nuget Package
    $nugetExePath = Join-Path -Path $env:TEMP `
        -ChildPath 'nuget.exe'
    Start-Process -FilePath $nugetExePath -Wait -ArgumentList @(
        'Pack', $nuspecPath
        '-OutputDirectory', $env:APPVEYOR_BUILD_FOLDER
        '-BasePath', $MainModulePath
    )

    # Push the Nuget Package up to AppVeyor
    $nugetPackageName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
        -ChildPath "$ResourceModuleName.$($env:APPVEYOR_BUILD_VERSION).nupkg"
    Get-ChildItem $nugetPackageName | ForEach-Object -Process {
        Push-TestArtifact -Path $_.FullName -FileName $_.Name
    }

    Write-Info -Message 'After Test Task Complete.'
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
        [String]
        $Path,

        [Parameter()]
        [String]
        $FileName
    )

    $resolvedPath = (Resolve-Path $Path).ProviderPath
    if (${env:APPVEYOR_JOB_ID})
    {
        <# does not work with Pester 4.0.2
        $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        Write-Info -Message "Uploading Test Results: $resolvedPath ; to: $url"
        (New-Object 'System.Net.WebClient').UploadFile($url, $resolvedPath)
        #>

        $uploadingInformationMessage = "Uploading Test Artifact '$resolvedPath'"
        if ($FileName)
        {
            $uploadingInformationMessage = '{0}{1}' -f $uploadingInformationMessage, ", using filename '$FileName'"
        }
        $uploadingInformationMessage = '{0}{1}' -f $uploadingInformationMessage, '.'

        Write-Info -Message $uploadingInformationMessage

        # This is a workaround until AppVeyor module is supported on Core
        if ($PSVersionTable.PSEdition -eq 'Core')
        {
            if ($FileName)
            {
                & appveyor PushArtifact $resolvedPath -FileName $FileName
            }
            else
            {
                & appveyor PushArtifact $resolvedPath
            }
        }
        else
        {
            $pushAppVeyorArtifactParameters = @{
                Path = $resolvedPath
            }

            if ($FileName)
            {
                $pushAppVeyorArtifactParameters['FileName'] = $FileName
            }

            Push-AppveyorArtifact @pushAppVeyorArtifactParameters
        }
    }
    else
    {
        Write-Info -Message "Test Artifact: $resolvedPath"
    }
}

<#
    .SYNOPSIS
        Performs the deploy tasks for the AppVeyor build process.

        This includes:
        1. Optional: Publish examples that opt-in to being published to
           PowerShell Gallery.

    .PARAMETER OptIn
        This controls the deploy steps that will be executed.
        If not specified will default to opt-in for all deploy tasks.

    .PARAMETER ModuleRootPath
        This is the relative path of the folder that contains the repository
        being deployed. If not specified it will default to the root folder
        of the repository ($env:APPVEYOR_BUILD_FOLDER).

    .PARAMETER MainModulePath
        This is the relative path of the folder that contains the Examples
        folder. If not specified it will default to the root folder of the
        repository ($env:APPVEYOR_BUILD_FOLDER).

    .PARAMETER ResourceModuleName
        Name of the resource module being deployed.
        If not specified will default to GitHub repository name.

    .PARAMETER Branch
        Name of the branch or branches to execute the deploy tasks on.
        If not specified will default to the branch 'master'.
        The default value is normally correct, but can be changed for
        debug purposes.
#>
function Invoke-AppVeyorDeployTask
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [Parameter()]
        [ValidateSet('PublishExample', 'PublishWikiContent')]
        [String[]]
        $OptIn = @(
            'PublishExample'
        ),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $ModuleRootPath = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $MainModulePath = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $ResourceModuleName = (($env:APPVEYOR_REPO_NAME -split '/')[1]),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Branch = @(
            'master'
        )
    )

    # Will only publish examples on pull request merge to master.
    if ($OptIn -contains 'PublishExample' -and $Branch -contains $env:APPVEYOR_REPO_BRANCH)
    {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.GalleryDeploy')

        $startGalleryDeployParameters = @{
            ResourceModuleName = $ResourceModuleName
            Path               = (Join-Path -Path $MainModulePath -ChildPath 'Examples')
            Branch             = $env:APPVEYOR_REPO_BRANCH
            ModuleRootPath     = $ModuleRootPath
        }

        Start-GalleryDeploy @startGalleryDeployParameters
    }
    else
    {
        Write-Info -Message 'Skip publish examples to Gallery. Either not opt-in, or building on the wrong branch.'
    }

    # Will only publish Wiki Content on pull request merge to master.
    if ($OptIn -contains 'PublishWikiContent' -and $Branch -contains $env:APPVEYOR_REPO_BRANCH)
    {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.DocumentationHelper')

        $publishWikiContentParameters = @{
            RepoName           = $env:APPVEYOR_REPO_NAME
            JobId              = $env:APPVEYOR_JOB_ID
            ResourceModuleName = $ResourceModuleName
            Verbose            = $true
        }

        Publish-WikiContent @publishWikiContentParameters
    }
    else
    {
        Write-Info -Message 'Skip publish Wiki Content. Either not opt-in, or building on the wrong branch.'
    }
}

Export-ModuleMember -Function *
