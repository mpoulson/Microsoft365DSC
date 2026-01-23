<#
This example creates a new Azure AD Permission Grant Policy Exclude condition
to block applications from external tenants.
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
        AADPermissionGrantPolicyExclude 'BlockExternal'
        {
            Id                         = "exclude-external-tenants"
            PermissionGrantPolicyId    = "custom-directory-devices-consent"
            PermissionType             = "application"
            ResourceApplication        = "00000003-0000-0000-c000-000000000000"
            Permissions                = @("all")
            ClientApplicationTenantIds = @("all")
            Ensure                     = "Present"
            ApplicationId              = $ApplicationId
            TenantId                   = $TenantId
            CertificateThumbprint      = $CertificateThumbprint
        }
    }
}
