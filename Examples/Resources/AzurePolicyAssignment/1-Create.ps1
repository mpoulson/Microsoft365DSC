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
        AzurePolicyAssignment "AzurePolicyAssignment-AuditVMs"
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            DisplayName           = "Audit VMs without managed disks";
            EnforcementMode       = "Default";
            Ensure                = "Present";
            PolicyAssignmentName  = "audit-vms-managed-disks";
            PolicyDefinitionId    = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d";
            Scope                 = "/subscriptions/00000000-0000-0000-0000-000000000000";
            TenantId              = $TenantId;
        }
    }
}
