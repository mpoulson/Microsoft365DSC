<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.

Ensure is the only mutable property on this resource, so an update means registering
an additional namespace in the subscription.
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
            Ensure                = "Present";
            ProviderNamespace     = "Microsoft.DesktopVirtualization";
            SubscriptionId        = "00000000-0000-0000-0000-000000000000";
            TenantId              = $TenantId;
        }
        AzureResourceProvider "AzureResourceProvider-Microsoft.Insights" # Drift
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            Ensure                = "Present";
            ProviderNamespace     = "Microsoft.Insights";
            SubscriptionId        = "00000000-0000-0000-0000-000000000000";
            TenantId              = $TenantId;
        }
    }
}
