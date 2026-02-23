<#
This example updates the default app management policy to enforce trusted certificate
authority restrictions. It configures the policy so that key credentials on applications
created after a specific date must use certificates from a trusted certificate chain.
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
        # Manage the certificate-based application configuration with root + intermediate CAs
        AADCertificateBasedApplicationConfiguration "ContosoCertChain"
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            Description           = "Full certificate chain from Contoso";
            DisplayName           = "Contoso Certificate Chain";
            Ensure                = "Present";
            TenantId              = $TenantId;
            TrustedCertificateAuthorities = @(
                MSFT_AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority{
                    Certificate = "MIIDPzCCAiegAwIBAgIQPbcHn..."
                    IsRootAuthority = $true
                    Issuer = "CN=Contoso Root CA, O=Contoso, C=US"
                    IssuerSubjectKeyIdentifier = "1234567890ABCDEF"
                }
                MSFT_AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority{
                    Certificate = "MIIDQzCCAiugAwIBAgIRAJkLm..."
                    IsRootAuthority = $false
                    Issuer = "CN=Contoso Intermediate CA, O=Contoso, C=US"
                    IssuerSubjectKeyIdentifier = "ABCDEF1234567890"
                }
            );
        }

        # Update the default tenant app management policy with certificate chain restrictions
        AADAppManagementPolicy "DefaultAppManagementPolicy"
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            Description           = "Default tenant policy with certificate authority restrictions";
            DisplayName           = "Tenant Default Policy";
            Ensure                = "Present";
            IsEnabled             = $True;
            Restrictions          = MSFT_AADAppManagementPolicyRestrictions{
                keyCredentials = @(
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
                        restrictionType = "trustedCertificateAuthority"
                        state = "enabled"
                        certificateBasedApplicationConfigurationIds = @("Contoso Certificate Chain")
                    }
                )
            };
            TenantId              = $TenantId;
            DependsOn             = "[AADCertificateBasedApplicationConfiguration]ContosoCertChain"
        }
    }
}
