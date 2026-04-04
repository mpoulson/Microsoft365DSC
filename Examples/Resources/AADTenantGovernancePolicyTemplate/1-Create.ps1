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
        AADTenantGovernancePolicyTemplate "AADTenantGovernancePolicyTemplate-Example"
        {
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
            DisplayName           = "Monitor Entra resource configurations"
            Description           = "Grants Global reader and provisions a custom multi-tenant application"
            DelegatedAdministrationRoleAssignments = @(
                MSFT_AADTenantGovernancePolicyTemplateDelegatedAdminRoleAssignment
                {
                    GroupDisplayName = "Governance Admins"
                    GroupId         = "00000000-0000-0000-0000-000000000001"
                    RoleTemplates   = @(
                        MSFT_AADTenantGovernancePolicyTemplateRoleTemplate
                        {
                            Id   = "f2ef992c-3afb-46b9-b7cf-a126ee74c451"
                            Name = "Global Reader"
                        }
                    )
                }
            )
            Ensure                = "Present"
        }
    }
}
