
# AADAppManagementPolicy

## Description

Manages an app management policy that can be assigned to an application or service principal object.

## Certificate Authority Restrictions

Starting with this version, the AADAppManagementPolicy resource supports restricting which Certificate Authorities are trusted for application authentication.

### Properties

- **CertificateBasedApplicationConfigurations**: Array of certificate authority configurations
  - **Id**: The unique identifier for the configuration (read-only)
  - **DisplayName**: Display name for the configuration
  - **Description**: Optional description
  - **TrustedCertificateAuthorities**: Array of trusted CAs (max 10)
    - **Certificate**: Base64-encoded certificate (DER format)
    - **IsRootAuthority**: Boolean indicating if this is a root CA
    - **Issuer**: Certificate issuer DN
    - **IssuerSubjectKeyIdentifier**: Subject key identifier

### Example

See example `4-CreateWithCertificateRestrictions.ps1` for a complete configuration.

### Permissions Required

- **Delegated**: `Policy.ReadWrite.ApplicationConfiguration`, `Directory.ReadWrite.All`
- **Application**: `Policy.ReadWrite.ApplicationConfiguration`, `Directory.ReadWrite.All`

### Notes

- This feature requires the Microsoft Graph beta API
- Requires Entra Workload ID Premium license for full functionality
- Changes may take several minutes to propagate
- Certificate configurations are tenant-wide and apply to all applications/service principals unless overridden
