<#
    .SYNOPSIS
        Runs all tests (including common tests) on all DSC resources in the given folder.

    .PARAMETER ResourcesPath
        The path to the folder containing the resources to be tested.

    .EXAMPLE
        Start-DscResourceTests -ResourcesPath C:\DscResources\DscResources
#>
function Start-DscResourceTests
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourcesPath
    )

    $testsPath = $pwd
    Push-Location -Path $ResourcesPath

    Get-ChildItem | ForEach-Object {
        $moduleName = $_.Name
        $destinationPath = Join-Path -Path $ResourcesPath -ChildPath $moduleName

        Write-Verbose -Message "Copying common tests from $testsPath to $destinationPath"
        Copy-Item -Path $testsPath -Destination $destinationPath -Recurse -Force

        Push-Location -Path $moduleName

        Write-Verbose "Running tests for $moduleName"
        Invoke-Pester

        Pop-Location
    }

    Pop-Location
}

Export-ModuleMember -Function @( 'Start-DscResourceTests' )
