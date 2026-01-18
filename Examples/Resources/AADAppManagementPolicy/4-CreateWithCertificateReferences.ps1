<#
This example creates an app management policy that references a certificate-based application configuration.
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
        # First, create the certificate-based application configuration
        AADCertificateBasedApplicationConfiguration "ContosoRootCA"
        {
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            Description           = "Trusted certificate authorities from Contoso";
            DisplayName           = "Contoso Root CA Configuration";
            Ensure                = "Present";
            TenantId              = $TenantId;
            TrustedCertificateAuthorities = @(
                MSFT_AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority{
                    Certificate = "MIIDPzCCAiegAwIBAgIQPbcHn..."
                    IsRootAuthority = $true
                    Issuer = "CN=Contoso Root CA, O=Contoso, C=US"
                    IssuerSubjectKeyIdentifier = "1234567890ABCDEF"
                }
            );
        }

        # Then create the app management policy that references it
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
            # Reference the certificate configuration by ID
            # Note: You would need to get the actual ID from the configuration
            CertificateBasedApplicationConfigurationIds = @("config-id-here");
            TenantId              = $TenantId;
            DependsOn             = "[AADCertificateBasedApplicationConfiguration]ContosoRootCA"
        }
    }
}
