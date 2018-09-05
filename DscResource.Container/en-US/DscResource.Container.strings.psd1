ConvertFrom-StringData @'
# English strings
InstallingPester = Installing Pester.
InvokePesterOnTheseTests = Invoking pester on all tests in the path: {0}
UsingTheseFilesForCodeCoverage = Using these files to calculate code coverage: {0}
NoFilesForCodeCoverage = No files for code coverage, running test without code coverage.
TestRanForTime = Tests ran for {0} minutes.
DockerIsNotAvailable = Docker is not available on the node running tests.
DownloadingImage = Downloading Docker image '{0}'. This can take a long time.
CreatingContainer = Creating container with name '{0}' using Docker image '{1}'.
ContainerUsingScript = Container with name '{0}' will use the following script to run tests: {1}
CopyStartScript = Copy the start script to the root of the system drive in the container named '{0}'.
CopyProjectFiles = Copy the project files into the same location in the container named '{0}'.
ContainerUsingCommand = Container with name '{0}' will use the following (encoded) command when it is started: {1}
StartContainer = Starting container named '{0}' with id '{1}'. This can take a while.
WaitContainer = Waiting for container named '{0}' to finish running tests.
ContainerExited = Container named '{0}' has exited (stopped) with exit code '{1}'.
GetContainerLogs = Gathering logs from container named '{0}'.
CopyItemFromContainer = Copying item '{0}:{1}' from the container '{2}' to the path '{3}' on the host.
CopyItemToContainer = Copying item '{1}' from the host to the container '{2}' to the path '{0}:{3}'.
ItBlockFailureMessage = Failure message: {0}
MissedCommandsInCodeCoverage = There was {0} missed commands in the code coverage report:
NoMissedCommandsInCodeCoverage = There was no missed commands in the code coverage report.
ContainerTimeout = The timeout period of {0} seconds was reached before the container stopped.
'@
