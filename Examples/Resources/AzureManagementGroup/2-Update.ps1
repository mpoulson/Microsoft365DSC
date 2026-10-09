<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.
#>

Configuration Example
{
    param(
        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Import-DscResource -ModuleName Microsoft365DSC
    node localhost
    {
        AzureManagementGroup "AzureManagementGroup-mg-platform"
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            DisplayName           = "Platform and Shared Services"; # Drift
            Ensure                = "Present";
            GroupId               = "mg-platform";
            ParentGroupId         = "mg-contoso-root";
            Subscriptions         = @("00000000-0000-0000-0000-000000000000", "11111111-1111-1111-1111-111111111111");
            TenantId              = $TenantId;
        }
    }
}
