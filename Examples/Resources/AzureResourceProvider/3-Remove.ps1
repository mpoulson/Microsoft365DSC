<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.

Unregistering a namespace fails while resources of that type still exist in the
subscription, and can break anything that depends on it.
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
        AzureResourceProvider "AzureResourceProvider-Microsoft.DesktopVirtualization"
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            Ensure                = "Absent";
            ProviderNamespace     = "Microsoft.DesktopVirtualization";
            SubscriptionId        = "00000000-0000-0000-0000-000000000000";
            TenantId              = $TenantId;
        }
    }
}
