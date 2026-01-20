
# AADCertificateBasedApplicationConfiguration

## Description

Manages certificate-based application configurations that define trusted certificate authorities for application authentication in Azure AD. These configurations are global tenant-wide objects that can be referenced by multiple app management policies.

## Properties

- **DisplayName** (Key): Display name for the configuration
- **Id**: The unique identifier for the configuration (read-only)
- **Description**: Optional description for the configuration
- **TrustedCertificateAuthorities**: Array of trusted certificate authorities (max 10)
  - **Certificate**: Base64-encoded certificate (DER format)
  - **IsRootAuthority**: Boolean indicating if this is a root CA
  - **Issuer**: Certificate issuer Distinguished Name
  - **IssuerSubjectKeyIdentifier**: Subject key identifier

## Permissions Required

- **Delegated**: `AppCertTrustConfiguration.ReadWrite.All`
- **Application**: `AppCertTrustConfiguration.ReadWrite.All`

## Notes

- This feature requires the Microsoft Graph beta API
- Requires Entra Workload ID Premium license for full functionality
- Certificate configurations are tenant-wide and can be referenced by multiple app management policies
- Changes may take several minutes to propagate
- Maximum of 10 trusted CAs per configuration
