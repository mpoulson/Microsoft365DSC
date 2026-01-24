# AADDomainFederation

## Description

This resource manages Azure Active Directory Domain Federation configurations for federated domains. It allows administrators to configure and manage federation settings including SAML/WS-Fed parameters, signing certificates, and authentication protocols for domains that use federated authentication.

## Key Features

- **Create Federation Configurations**: Set up federation for managed domains with comprehensive SAML/WS-Fed settings
- **Update Federation Settings**: Modify existing federation configurations including URIs, certificates, and authentication protocols
- **Remove Federation**: Remove federation configurations to return domains to managed authentication
- **Certificate Management**: Support for both current and next signing certificates with automatic debugging information
- **Export Configurations**: Export existing federation settings for backup or migration purposes
- **Authentication Type Validation**: Ensures domains are in "Managed" state before creating federation configurations

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| DomainId | String | Yes | The domain ID for which the federation configuration is being managed (Key parameter) |
| Id | String | No | The unique identifier of the federation configuration |
| DisplayName | String | No | The display name of the federation configuration |
| IssuerUri | String | No | Issuer URI of the federation server |
| MetadataExchangeUri | String | No | URI of the metadata exchange endpoint used for authentication |
| SigningCertificate | String | No | Current certificate used to sign tokens (Base64 encoded string) |
| NextSigningCertificate | String | No | Next signing certificate for certificate rollover (Base64 encoded string) |
| PassiveSignInUri | String | No | URI that web-based clients are directed to when signing in |
| ActiveSignInUri | String | No | URI that active clients are directed to when signing in |
| SignOutUri | String | No | URI to which clients are redirected when signing out |
| PreferredAuthenticationProtocol | String | No | Preferred authentication protocol (wsFed or saml) |
| SigningCertificateUpdateStatus | String | No | Describes the status of the signing certificate update |
| PromptLoginBehavior | String | No | Prompt login behavior of the federated IdP |
| FederatedIdpMfaBehavior | String | No | MFA behavior (acceptIfMfaDoneByFederatedIdp, enforceMfaByFederatedIdp, rejectMfaByFederatedIdp) |
| IsSignedAuthenticationRequestRequired | Boolean | No | Specifies whether the federation requires signed authentication requests |
| Ensure | String | No | Present ensures the instance exists, absent ensures it is removed (Present or Absent) |
| Credential | PSCredential | No | Credentials of the workload's Admin |
| ApplicationId | String | No | Id of the Azure Active Directory application to authenticate with |
| TenantId | String | No | Id of the Azure Active Directory tenant used for authentication |
| ApplicationSecret | PSCredential | No | Secret of the Azure Active Directory application to authenticate with |
| CertificateThumbprint | String | No | Thumbprint of the Azure Active Directory application's authentication certificate |
| ManagedIdentity | Boolean | No | Managed ID being used for authentication |
| AccessTokens | String[] | No | Access token used for authentication |

## Example Usage

```powershell
AADDomainFederation 'ConfigureFederationForDomain'
{
    DomainId                            = 'contoso.com'
    DisplayName                         = 'Contoso Federation'
    IssuerUri                           = 'http://contoso.com/adfs/services/trust'
    MetadataExchangeUri                 = 'https://adfs.contoso.com/FederationMetadata/2007-06/FederationMetadata.xml'
    PassiveSignInUri                    = 'https://adfs.contoso.com/adfs/ls/'
    ActiveSignInUri                     = 'https://adfs.contoso.com/adfs/services/trust/2005/usernamemixed'
    SignOutUri                          = 'https://adfs.contoso.com/adfs/ls/?wa=wsignout1.0'
    PreferredAuthenticationProtocol     = 'wsFed'
    SigningCertificate                  = 'MIIDdzCCAl+gAwIBAgIQXWWjEQHsC...' # Base64 encoded certificate
    FederatedIdpMfaBehavior             = 'acceptIfMfaDoneByFederatedIdp'
    IsSignedAuthenticationRequestRequired = $true
    Ensure                              = 'Present'
    ApplicationId                       = 'your-app-id'
    TenantId                            = 'your-tenant-id'
    CertificateThumbprint               = 'your-cert-thumbprint'
}
```

## Certificate Debugging

When a signing certificate is provided (either `SigningCertificate` or `NextSigningCertificate`), the resource automatically displays certificate information during Set operations:

```
=====================
SigningCertificate Information
=====================
Thumbprint: 1234567890ABCDEF1234567890ABCDEF12345678
Subject: CN=ADFS Signing - adfs.contoso.com
Issuer: CN=ADFS Signing - adfs.contoso.com
Expires: 12/31/2025 11:59:59 PM
=====================
```

This helps administrators verify they are using the correct certificates and monitor certificate expiration dates.

## Authentication Type Validation

**Important**: Before creating a new federation configuration, the domain must have its `AuthenticationType` set to `Managed`. If you attempt to create a federation configuration on a domain with a different authentication type, the resource will throw an error:

```
Cannot create federation configuration. Domain 'contoso.com' must have AuthenticationType 'Managed' 
but found 'Federated'. Please ensure the domain is set to Managed authentication type before 
configuring federation.
```

## Notes

- Federation configurations require elevated permissions in Azure AD (Domain Administrator or Global Administrator)
- Certificate strings must be Base64 encoded without headers/footers
- The resource uses Microsoft Graph Beta API endpoints
- When updating federation settings, changes may take a few minutes to propagate
- Always test federation changes in a non-production environment first

## Required Permissions

### Microsoft Graph API Permissions

**Delegated**:
- Domain.Read.All (for read operations)
- Domain.ReadWrite.All (for write operations)

**Application**:
- Domain.Read.All (for read operations)
- Domain.ReadWrite.All (for write operations)

### Azure AD Roles

- Domain Administrator (for read and update operations)
- Global Administrator (for all operations)
- Global Reader (for read-only operations)
