<#
.Synopsis
   Template for creating DSC Resource Unit Tests
.DESCRIPTION
   To Use:
     1. Copy to \Tests\Integration\ folder and rename MSFT_x<ResourceName>.tests.ps1
     2. Customize TODO sections.

.NOTES
   Code in HEADER and FOOTER regions are standard and may be moved into DSCResource.Tools in
   Future and therefore should not be altered if possible.
#>


# TODO: Customize these paramters...
$DSCModuleName      = 'x<ModuleName>' # Example xNetworking
$DSCResourceName    = 'MSFT_x<ResourceName>' # Example MSFT_xFirewall
# /TODO

#region HEADER
Import-Module DSCResource.Tools\TestHelper.psm1
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $DSCModuleName `
    -DSCResourceName $DSCResourceName `
    -TestType Unit 
#endregion

# TODO: Other Optional Init Code Goes Here...

# Begin Testing
try
{

    #region Pester Tests

    InModuleScope $DSCResourceName {

        #region Pester Test Initialization
        # TODO: Optopnal Load Mock for use in Pester tests here...
        #endregion


        #region Function Get-TargetResource
        Describe 'Get-TargetResource' {
            # TODO: Complete Tests...
        }
        #endregion


        #region Function Test-TargetResource
        Describe 'Test-TargetResource' {
            # TODO: Complete Tests...
        }
        #endregion


        #region Function Set-TargetResource
        Describe 'Set-TargetResource' {
            # TODO: Complete Tests...
        }
        #endregion

        # TODO: Pester Tests for any Helper Cmdlets

    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion

    # TODO: Other Optional Cleanup Code Goes Here...
}
