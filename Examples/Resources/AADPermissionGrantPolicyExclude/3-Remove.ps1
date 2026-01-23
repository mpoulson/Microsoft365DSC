<#
This example removes an Azure AD Permission Grant Policy Exclude condition.
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
            Id                      = "exclude-external-tenants"
            PermissionGrantPolicyId = "custom-directory-devices-consent"
            Ensure                  = "Absent"
            ApplicationId           = $ApplicationId
            TenantId                = $TenantId
            CertificateThumbprint   = $CertificateThumbprint
        }
    }
}
