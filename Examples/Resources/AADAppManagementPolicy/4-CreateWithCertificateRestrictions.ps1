<#
This example creates an app management policy with certificate authority restrictions.
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
        AADAppManagementPolicy "MyAppManagementPolicyWithCA"
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            Description           = "Policy with certificate authority restrictions";
            DisplayName           = "AppManagementPolicyWithCA";
            Ensure                = "Present";
            IsEnabled             = $True;
            Restrictions          = MSFT_AADAppManagementPolicyRestrictions{
                passwordCredentials = @(
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "01/01/0001 00:00:00"
                        restrictionType = "passwordAddition"
                        state = "enabled"
                    }
                )
            };
            CertificateBasedApplicationConfigurations = @(
                MSFT_AADAppManagementPolicyCertificateBasedApplicationConfiguration{
                    DisplayName = "Contoso Root CA Configuration"
                    Description = "Trusted certificate authorities from Contoso"
                    TrustedCertificateAuthorities = @(
                        MSFT_AADAppManagementPolicyCertificateAuthority{
                            Certificate = "MIIC...base64encodedcert..."
                            IsRootAuthority = $true
                            Issuer = "CN=Contoso Root CA, O=Contoso, C=US"
                            IssuerSubjectKeyIdentifier = "1234567890ABCDEF"
                        }
                    )
                }
            );
            TenantId              = $TenantId;
        }
    }
}
