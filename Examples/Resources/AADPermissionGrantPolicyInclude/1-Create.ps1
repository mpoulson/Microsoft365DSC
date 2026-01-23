<#
This example creates a new Azure AD Permission Grant Policy Include condition.
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
        AADPermissionGrantPolicyInclude 'IncludeDirectoryRW'
        {
            Id                              = "include-directory-rw"
            PermissionGrantPolicyId         = "custom-directory-devices-consent"
            PermissionType                  = "application"
            ResourceApplication             = "00000003-0000-0000-c000-000000000000"
            Permissions                     = @("19dbc75e-c2e2-444c-a770-ec69d8559fc7")
            PermissionClassification        = "all"
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
