<#
This example demonstrates updating an Exclude condition by recreating it.
Note: Exclude conditions cannot be updated in place and must be deleted and recreated.
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
        AADPermissionGrantPolicyExclude 'BlockHighRiskPermissions'
        {
            Id                              = "exclude-high-risk"
            PermissionGrantPolicyId         = "custom-directory-devices-consent"
            PermissionType                  = "application"
            ResourceApplication             = "00000003-0000-0000-c000-000000000000"
            Permissions                     = @("all")
            PermissionClassification        = "high"
            ClientApplicationIds            = @("all")
            ClientApplicationTenantIds      = @($TenantId)
            ClientApplicationPublisherIds   = @("all")
            ClientApplicationsFromVerifiedPublisherOnly = $false
            Ensure                          = "Present"
            ApplicationId                   = $ApplicationId
            TenantId                        = $TenantId
            CertificateThumbprint           = $CertificateThumbprint
        }
    }
}
