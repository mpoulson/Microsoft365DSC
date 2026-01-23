<#
This example removes an Azure AD Permission Grant Policy Include condition.
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
            Id                      = "include-directory-rw"
            PermissionGrantPolicyId = "custom-directory-devices-consent"
            Ensure                  = "Absent"
            ApplicationId           = $ApplicationId
            TenantId                = $TenantId
            CertificateThumbprint   = $CertificateThumbprint
        }
    }
}
