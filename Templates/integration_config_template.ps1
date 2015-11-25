<#
.Synopsis
   DSC Configuration Template for DSC Resource Integration tests.
.DESCRIPTION
   To Use:
     1. Copy to \Tests\Integration\ folder and rename MSFT_x<ResourceName>.config.ps1 (e.g. MSFT_xFirewall.config.ps1)
     2. Customize TODO sections.

.NOTES
#>


# TODO: Modify ResourceName
configuration 'MSFT_<xResourceName>_config' {
    Import-DscResource -ModuleName xNetworking
    node localhost {
       # TODO: Modify ResourceName
       '<xResourceName>' Integration_Test {
            # TODO: Fill Configuration Code Here
       }
    }
}

# TODO: (Optional): Add More Configuration Templates
