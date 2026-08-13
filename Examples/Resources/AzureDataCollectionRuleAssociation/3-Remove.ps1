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
        AzureDataCollectionRuleAssociation "AzureDataCollectionRuleAssociation-Contoso-WindowsSecurityEventsAMA"
        {
            AssociationName       = "Contoso-WindowsSecurityEventsAMA";
            ResourceUri           = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020";
            Ensure                = "Absent";
            ApplicationId         = $ApplicationId;
            TenantId              = $TenantId;
            CertificateThumbprint = $CertificateThumbprint;
        }
    }
}
