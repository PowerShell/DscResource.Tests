$projectRootPath = Split-Path -Path $PSScriptRoot -Parent
$testHelperPath = Join-Path -Path $projectRootPath -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

$script:localizedData = Get-LocalizedData -ModuleName 'DscResource.Container' -ModuleRoot $PSScriptRoot

<#
    .SYNOPSIS
        This is the function that is executed inside the container to run
        the tests.

    .PARAMETER ContainerName
        The name of the container that the script is running in.

    .PARAMETER Path
        The project path in the container.

    .PARAMETER TestPath
        The path to on or more tests to run.

    .PARAMETER CodeCoverage
        The path to on or more script or module files to use calculate
        code coverage. This parameter is optional.
#>
function Start-ContainerTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ContainerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $TestPath,

        [Parameter()]
        [System.String[]]
        $CodeCoverage
    )

    $transcriptPath = Join-Path -Path $Path -ChildPath ('{0}_Transcript.txt' -f $ContainerName)
    Start-Transcript -Path $transcriptPath -IncludeInvocationHeader

    $startTime = Get-Date

    Write-Info -Message $script:localizedData.InstallingPester

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module -Name Pester -Force -SkipPublisherCheck

    Write-Info -Message ($script:localizedData.InvokePesterOnTheseTests -f ($TestPath -join ', ')) -Verbose

    # TODO: ExcludeTag is not honored here, but is on the build worker. Should send that in here as well.
    $invokePesterParameters = @{
        OutputFormat = 'NUnitXML'
        OutputFile   = Join-Path -Path $Path -ChildPath ('{0}_TestsResults.xml' -f $ContainerName)
        PassThru     = $True
        Path         = $TestPath
    }

    if ($PSBoundParameters.ContainsKey('CodeCoverage'))
    {
        Write-Info -Message ($script:localizedData.UsingTheseFilesForCodeCoverage -f ($CodeCoverage -join ', ')) -Verbose

        $invokePesterParameters['CodeCoverage'] = $CodeCoverage
    }
    else
    {
        Write-Info -Message $script:localizedData.NoFilesForCodeCoverage
    }

    $invokePesterResult = Invoke-Pester @invokePesterParameters

    <#
        Using depth 10 to get any future changes to Pester (currently it seems to
        only need a depth of 4).
    #>
    $jsonPesterResult = $invokePesterResult | ConvertTo-Json -Compress -Depth 10

    # Write the pester result object to file as JSON.
    $outFileParameters = @{
        FilePath = Join-Path -Path $Path -ChildPath ('{0}_TestsResults.json' -f $ContainerName)
        Encoding = 'ascii'
    }

    $jsonPesterResult | Out-File @outFileParameters

    $timeElapsed = New-TimeSpan -Start $startTime -End (Get-Date)
    Write-Verbose -Message ($script:localizedData.TestRanForTime -f $timeElapsed.ToString('mm\:ss')) -Verbose

    Stop-Transcript
}

<#
    .SYNOPSIS
        Creates a new container and prepares it to run tests.

    .PARAMETER Name
        The name of the container.

    .PARAMETER ImageName
        The name of the image that the container should use.
        Defaults to 'microsoft/windowsservercore:latest'.

    .PARAMETER TestPath
        An array with paths to tests that should be run.

    .PARAMETER ProjectPath
        The path to the project, in the container, that is being tested.
        Normally this is $env:APPVEYOR_BUILD_FOLDER.

    .PARAMETER CodeCoverage
        The path to on or more script or module files to use calculate
        code coverage. This parameter is optional.

    .OUTPUTS
        Returns the container identifier of the container that was created.
#>
function New-Container
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $ImageName = 'microsoft/windowsservercore:latest',

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $TestPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ProjectPath,

        [Parameter()]
        [System.String[]]
        $CodeCoverage
    )

    <#
        Make sure Docker executable exist. If it does, then we assume that docker
        is properly installed and configured for running Windows containers.
    #>
    if (-not (Get-Command -Name 'docker' -ErrorAction SilentlyContinue))
    {
        throw $script:localizedData.DockerIsNotAvailable
    }

    # Make sure we have the correct container images available.
    if ($ImageName -match ':')
    {
        $dockerImagesFormat = '{{.Repository}}:{{.Tag}}'
    }
    else
    {
        $dockerImagesFormat = '{{.Repository}}'
    }

    [System.String[]] $dockerImages = docker images --format $dockerImagesFormat
    if ($ImageName -match ':latest$' -or (-not $dockerImages.Contains($ImageName)))
    {
        Write-Info -Message ($script:localizedData.DownloadingImage -f $ImageName)

        <#
            Pulling the latest image. Using Out-Null so it does
            not output download information.
        #>
        docker pull $ImageName | Out-Null
    }

    Write-Info -Message ($script:localizedData.CreatingContainer -f $Name, $ImageName)

    <#
        Builds a array of strings on a single line with all the test paths, and
        with each test path surrounded with double quotes. This format is needed
        when adding the array to the Docker command line, when creating the
        container.
    #>
    $containerTestPath = '@("{0}")' -f ($TestPath -join '", "')

    # Builds the final command arguments that is used with the call to powershell.exe.
    $containerScript = 'Import-Module -Name ''{0}\DscResource.Tests\DscResource.Container'';Start-ContainerTest -ContainerName {1} -Path {0} -TestPath {2}' -f $ProjectPath, $Name, $containerTestPath

    if ($PSBoundParameters.ContainsKey('CodeCoverage'))
    {
        <#
            Builds a array of strings on a single line with all the code coverage
            paths, and with each test path surrounded with double quotes. This format
            is needed when adding the array to the Docker command line, when creating
            the container.
        #>
        $containerCodeCoveragePath = '@("{0}")' -f ($CodeCoverage -join '", "')

        <#
            Add the code coverage parameter to the final command line.
            Note: Must start with a single space.
        #>
        $containerScript += ' -CodeCoverage {0}' -f $containerCodeCoveragePath
    }

    Write-Info -Message ($script:localizedData.ContainerUsingScript -f $Name, $containerScript)

    <#
        There are a max limit to how long a command or encoded command can be, so
        we have to write the script to a file and upload that to the container,
        and then the powershell.exe -EncodedCommand can kick off that script.

        The start script will be uploaded after the container is create below.
    #>
    $startScriptFileName = '{0}_StartTest.ps1' -f $Name
    $startScriptFilePath = Join-Path -Path $env:TEMP -ChildPath $startScriptFileName
    $containerScript | Out-File -FilePath $startScriptFilePath -Encoding ascii

    $containerCommand = '. C:\{0}' -f $startScriptFileName

    <#
        Encode the command so it can be used with -EncodeCommand
        argument of the powershell.exe.
    #>
    $containerCommandBytes = [System.Text.Encoding]::Unicode.GetBytes($containerCommand)
    $containerEncodedCommand = [System.Convert]::ToBase64String($containerCommandBytes)

    <#
        Start our container to run unit tests in.

        docker create [OPTIONS] IMAGE [COMMAND] [ARG...]

        OPTIONS:
        --name   - Named so it is easy to identify our container
                    for debugging purposes.

        IMAGE    - the image we base our container on;
                    microsoft/windowsservercore

        COMMAND  - the command we run when the container start;
                    powershell.exe

        ARGUMENT - the arguments for the COMMAND;
s                   -ExecutionPolicy ByPass
                    -EncodedCommand $containerEncodedCommand
    #>
    $containerIdentifier = docker create --name $Name $ImageName powershell.exe -ExecutionPolicy ByPass -EncodedCommand $containerEncodedCommand

    Write-Info -Message ($script:localizedData.CopyStartScript -f $Name)

    $copyItemToContainer = @{
        ContainerIdentifier = $containerIdentifier
        Path                = $startScriptFilePath
        Destination         = 'C:\'
    }

    Copy-ItemToContainer @copyItemToContainer

    Write-Info -Message ($script:localizedData.CopyStartScript -f $Name)

    <#
        Cannot copy to a destination if any part of the destination
        folder structure is missing. So here the root project folder
        is copied, which is expected to be 'c:\projects'. C:\ does
        exist so it can successfully create 'projects' folder and
        copy the rest of the child folders.
    #>
    $appVeyorProjectRootFolder = (Split-Path $ProjectPath -Parent)

    $copyItemToContainer = @{
        ContainerIdentifier = $containerIdentifier
        Path                = $appVeyorProjectRootFolder
        Destination         = $appVeyorProjectRootFolder
    }

    Copy-ItemToContainer @copyItemToContainer

    Write-Info -Message ($script:localizedData.ContainerUsingCommand -f $Name, $containerCommand)

    return $containerIdentifier
}

<#
    .SYNOPSIS
        Starts a container. This is a wrapper for 'docker start'.

    .PARAMETER ContainerIdentifier
        The identifier of the container to start.

    .OUTPUTS
        Returns the container identifier of the container that was started.
        This will be the same identifier as was passed in to the parameter
        ContainerIdentifier.
#>
function Start-Container
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ContainerIdentifier
    )

    $containerName = Split-Path -Path (docker inspect $ContainerIdentifier --format '{{.Name}}') -Leaf

    Write-Info -Message ($script:localizedData.StartContainer -f $containerName, $ContainerIdentifier)

    return docker start $ContainerIdentifier
}

<#
    .SYNOPSIS
        Waits for a container to stop (exit).

    .PARAMETER ContainerIdentifier
        The identifier of the container to wait for.

    .PARAMETER Timeout
        A value in seconds for the timeout waiting for the container to
        finish. Defaults to 3600 seconds (1 hour).

    .OUTPUTS
        Returns the container exit code.
#>
function Wait-Container
{
    [CmdletBinding()]
    [OutputType([System.Int64])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ContainerIdentifier,

        [Parameter()]
        [System.UInt32]
        $Timeout = 3600
    )

    $containerName = Split-Path -Path (docker inspect $ContainerIdentifier --format '{{.Name}}') -Leaf

    $timeoutTimer = [System.Diagnostics.StopWatch]::StartNew()

    try
    {
        # This returns a string with either 'false' or 'true'.
        $containerRunning = docker inspect $ContainerIdentifier --format '{{.State.Running}}'
        if ($containerRunning -ne 'false')
        {
            Write-Info -Message ('-' * 80)
            Write-Info -Message ($script:localizedData.WaitContainer -f $containerName)
            Write-Info -Message ('-' * 80)

            # Wait for the container to stop (exit).
            do
            {
                Start-Sleep -Seconds 2

                # This returns a string with either 'false' or 'true'.
                $containerRunning = docker inspect $ContainerIdentifier --format '{{.State.Running}}'
            } until ($containerRunning -eq 'false' -or $timeoutTimer.Elapsed.Seconds -ge $Timeout)
        }
    }
    catch
    {
        throw $_
    }
    finally
    {
        $timeoutTimer.Stop()
    }

    # If the timeout period was reach before the container stopped, then throw.
    if ($containerRunning -eq 'true')
    {
        throw ($script:localizedData.ContainerTimeout -f $Timeout)
    }

    [System.Int64] $containerExitCode = docker inspect $containerIdentifier --format '{{.State.ExitCode}}'
    Write-Info -Message ($script:localizedData.ContainerExited -f $containerName, $containerExitCode)

    return $containerExitCode
}

<#
    .SYNOPSIS
        Get the logs of a container.

    .PARAMETER ContainerIdentifier
        The identifier of the container to get logs for.

    .OUTPUTS
        Returns the log as an array of objects.
#>
function Get-ContainerLog
{
    [CmdletBinding()]
    [OutputType([Object[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ContainerIdentifier
    )

    $containerName = Split-Path -Path (docker inspect $ContainerIdentifier --format '{{.Name}}') -Leaf

    Write-Info -Message ($script:localizedData.GetContainerLogs -f $containerName)
    $containerErrorObject = docker logs $ContainerIdentifier 2>&1

    return $containerErrorObject
}

<#
    .SYNOPSIS
        Copy an item from a containers file system to the local host file system.

    .PARAMETER ContainerIdentifier
        The identifier of the container to get logs for.

    .PARAMETER Path
        The path to the item in the containers file system that should be copied
        to the host.

    .PARAMETER Destination
        The destination path to where the files will be copied on the local host
        file system.
#>
function Copy-ItemFromContainer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ContainerIdentifier,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Destination
    )

    $containerName = Split-Path -Path (docker inspect $ContainerIdentifier --format '{{.Name}}') -Leaf

    Write-Info -Message ($script:localizedData.CopyItemFromContainer -f $ContainerIdentifier, $Path, $containerName, $Destination)
    docker cp "$($ContainerIdentifier):$Path" $Destination
}

<#
    .SYNOPSIS
        Copy an item from the local host file system to a containers file system.

    .PARAMETER ContainerIdentifier
        The identifier of the container to get logs for.

    .PARAMETER Path
        The path to the item in the local host file system that should be copied
        to the containers file system.

    .PARAMETER Destination
        The destination path to where the files will be copied on the containers
        file system.
#>
function Copy-ItemToContainer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ContainerIdentifier,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Destination
    )

    $containerName = Split-Path -Path (docker inspect $ContainerIdentifier --format '{{.Name}}') -Leaf

    Write-Info -Message ($script:localizedData.CopyItemToContainer -f $ContainerIdentifier, $Path, $containerName, $Destination)
    docker cp $Path "$($ContainerIdentifier):$Destination"
}

<#
    .SYNOPSIS
        Output the Pester test results, including missed commands, in a pretty
        Pester like format.

    .PARAMETER TestResult
        The test results from the object that Pester outputs.

    .PARAMETER ShowOnlyFailed
        When this is set, then only failed tests will be listed. The default is to
        list all tests, both successful and failed.

    .PARAMETER WaitForAppVeyorConsole
        When this is set the output will pause at the end to let AppVeyor console
        to keep up. With a lot of (fast) output the AppVeyor console can have
        trouble keeping up and garble the output. This helps mitigate that.

    .PARAMETER Timeout
        The number of seconds to wait when the parameter WaitForAppVeyorConsole
        is used. This defaults to 5 seconds. This parameter is ignore if
        WaitForAppVeyorConsole is not used at the same time.

    .NOTES
        For SqlServerDsc this output, including missed commands, takes
        approximately one minute to list.

        Note: It will loop thru all Context-blocks, even those that were nested,
        but nested Context-blocks will be shown as they were listed directly
        under the Describe-block. Nested Context-blocks will be shown as
        'Context\NestedContext'.
#>
function Out-TestResult
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        $TestResult,

        [Parameter()]
        [Switch]
        $ShowOnlyFailed,

        [Parameter()]
        [Switch]
        $WaitForAppVeyorConsole,

        [Parameter()]
        [System.UInt32]
        $Timeout = 5
    )

    if ($ShowOnlyFailed.IsPresent)
    {
        $testsToOutput = $TestResult |
        Where-Object -FilterScript {
            $_.Passed -eq $false
        }
    }
    else
    {
        $testsToOutput = $TestResult.Clone()
    }

    $uniqueDescribeBlockName = $testsToOutput |
    Select-Object -ExpandProperty 'Describe' -Unique

    foreach ($describeBlockName in $uniqueDescribeBlockName)
    {
        Describe -Name $describeBlockName {
            <#
                Get all unique Context-blocks with the same
                Describe-block, and where the Context-block is
                not equal to an empty string (which means that
                the It-block is directly in a Describe-block).
            #>
            $uniqueContextBlockName = $testsToOutput |
            Where-Object -FilterScript {
                $_.Describe -eq $describeBlockName -and $_.Context -ne ''
            } | Select-Object -ExpandProperty 'Context' -Unique

            foreach ($contextBlockName in $uniqueContextBlockName)
            {
                Context -Name $contextBlockName {
                    $itBlocks = $testsToOutput |
                    Where-Object -FilterScript {
                        $_.Describe -eq $describeBlockName `
                            -and $_.Context -eq $contextBlockName
                    }

                    foreach ($itBlock in $itBlocks)
                    {
                        Write-PesterItBlock -TestResult $itBlock
                    }
                }
            }

            <#
                Get all It-blocks with the same Describe-block,
                and where the Context-block is equal to an empty
                string (which means that the It-block is directly
                in a Describe-block).
            #>
            $itBlocks = $testsToOutput |
            Where-Object -FilterScript {
                $_.Describe -eq $describeBlockName `
                    -and $_.Context -eq ''
            }

            foreach ($itBlock in $itBlocks)
            {
                Write-PesterItBlock -TestResult $itBlock
            }
        }
    }

    if ($WaitForAppVeyorConsole.IsPresent)
    {
        # Let's hold back a bit so AppVeyor console can keep up with output.
        Start-Sleep -Seconds $Timeout
    }

    # End with a blank line to show where the output of results end.
    Write-Output -InputObject ''
}

<#
    .SYNOPSIS
        Output the Pester test result It-block.

    .PARAMETER TestResult
        The test result object containing the It-block to output.

    .NOTES
        This function is a helper function for the cmdlet Out-TestResult and is
        not exported by the module.
#>
function Write-PesterItBlock
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $TestResult
    )

    $isSkipped = $false

    if ($TestResult.Result -eq 'Skipped')
    {
        $isSkipped = $true
    }

    It -Name $TestResult.Name -Skip:$isSkipped {
        $TestResult.Passed | Should -Be $true
    } -ErrorVariable itBlockError

    # Check if the It-block failed.
    if ($itBlockError.Count -ne 0)
    {
        Write-Output -InputObject ''
        Write-Info -ForegroundColor 'Red' -Object ($script:localizedData.ItBlockFailureMessage -f $TestResult.FailureMessage)
        Write-Output -InputObject ''

        $itBlockError = $null
    }
}

<#
    .SYNOPSIS
        Output the Pester code coverage missed commands, in a pretty Pester like
        format.

    .PARAMETER MissedCommand
        The object containing the missed command from the code coverage object
        of the test result object that Pester outputs.

    .PARAMETER WaitForAppVeyorConsole
        When this is set the output will pause at the end to let AppVeyor console
        to keep up. With a lot of (fast) output the AppVeyor console can have
        trouble keeping up and garble the output. This helps mitigate that.

    .PARAMETER Timeout
        The number of seconds to wait when the parameter WaitForAppVeyorConsole
        is used. This defaults to 5 seconds. This parameter is ignore if
        WaitForAppVeyorConsole is not used at the same time.

    .NOTES
        If we would just have outputted the object $MissedCommand to the
        stream the output would be garbled with other output since the
        AppVeyor console wouldn't keep up. Looping and outputting each row
        individually mitigated that problem.

        Parameter MissedCommand should not be mandatory, when it's non-mandatory
        the function can handle when sent in an empty array or $null value, which
        will output a correct informational message.
#>
function Out-MissedCommand
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [PSCustomObject[]]
        $MissedCommand,

        [Parameter()]
        [Switch]
        $WaitForAppVeyorConsole,

        [Parameter()]
        [System.UInt32]
        $Timeout = 5
    )

    # Output the missed commands.
    if ($MissedCommand.Count -gt 0)
    {
        # Start with a blank line to show where the output of missed commands start.
        Write-Output -InputObject ''
        Write-Info -ForegroundColor Red -Message ($script:localizedData.MissedCommandsInCodeCoverage -f $MissedCommand.Count)

        [PSCustomObject[]] $MissedCommand = $MissedCommand |
            Select-Object -Property @{
                Name       = 'File'
                Expression = {
                    $_.File -replace ("$env:APPVEYOR_BUILD_FOLDER\" -replace '\\', '\\')
                }
            }, Function, Line, Command

        $fileFieldMaxLength = ($MissedCommand.File | Measure-Object -Maximum -Property Length).Maximum
        $functionFieldMaxLength = ($MissedCommand.Function | Measure-Object -Maximum -Property Length).Maximum
        $lineFieldMaxLength = 5

        # Write out header
        Write-Output -InputObject ('{0}{1}{2}{3}' -f @(
                'File'.PadRight($fileFieldMaxLength + 1)
                'Function'.PadRight($functionFieldMaxLength + 1)
                'Line'.PadLeft($lineFieldMaxLength).PadRight($lineFieldMaxLength + 1)
                'Command'
            )
        )

        # Write out header underlines
        Write-Output -InputObject ('{0}{1}{2}{3}' -f @(
                '----'.PadRight($fileFieldMaxLength + 1)
                '--------'.PadRight($functionFieldMaxLength + 1)
                '----'.PadLeft($lineFieldMaxLength).PadRight($lineFieldMaxLength + 1)
                '-------'
            )
        )

        # Write out missed commands
        foreach ($currentMissedCommand in $MissedCommand)
        {
            Write-Output -InputObject ('{0}{1}{2}{3}' -f @(
                    $currentMissedCommand.File.PadRight($fileFieldMaxLength + 1)
                    $currentMissedCommand.Function.PadRight($functionFieldMaxLength + 1)
                    $currentMissedCommand.Line.ToString().PadLeft(5).PadRight(6)
                    $currentMissedCommand.Command
                )
            )
        }

        if ($WaitForAppVeyorConsole.IsPresent)
        {
            # Let's hold back a bit so AppVeyor console can keep up with output.
            Start-Sleep -Seconds $Timeout
        }
    }
    else
    {
        Write-Output -InputObject $script:localizedData.NoMissedCommandsInCodeCoverage
    }

    # End with a blank line to show where the output of missed commands end.
    Write-Output -InputObject ''
}
