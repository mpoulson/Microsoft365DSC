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
        AzureRoleManagementPolicyRule "AzureRoleManagementPolicyRule-Expiration_EndUser_Assignment"
        {
            ExpirationRule            = MSFT_AADRoleManagementPolicyExpirationRule{
                isExpirationRequired = $True
                maximumDuration = 'PT4H'
            };
            Id                        = "Expiration_EndUser_Assignment";
            RoleDefinitionDisplayName = "Owner";
            Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000";
            RuleType                  = "RoleManagementPolicyExpirationRule";
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            CertificateThumbprint     = $CertificateThumbprint
        }
    }
}
