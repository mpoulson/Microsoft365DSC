
# AADAppManagementPolicy

## Description

Manages an app management policy that can be assigned to an application or service principal object.

## Certificate-Based Application Configurations

App management policies can reference certificate-based application configurations that define trusted certificate authorities for application authentication. These configurations are managed separately using the `AADCertificateBasedApplicationConfiguration` resource.

### Properties

- **CertificateBasedApplicationConfigurationIds**: Array of IDs referencing certificate-based application configurations at the policy level
  - These IDs reference global tenant configurations managed by the `AADCertificateBasedApplicationConfiguration` resource
  - Multiple policies can reference the same configuration
  - The referenced configurations must exist before being referenced by a policy
- **Restrictions.KeyCredentials.TrustedCertificateAuthority**: Optional reference (GUID or display name) to the certificate-based application configuration root chain. If a display name is provided, the resource resolves it to the corresponding configuration Id.
- **Restrictions.KeyCredentials.CertificateBasedApplicationConfigurationIds**: Array of certificate-based application configuration IDs to associate with a specific key credential restriction. Used with `restrictionType = "trustedCertificateAuthority"` to enforce certificate chain validation. Accepts GUIDs or display names; display names are resolved to configuration IDs during processing.
- **AssignedApplications**: Optional list of application display names or object GUIDs to which the policy should be assigned. Names are resolved to IDs during processing.

### Example

See example `4-CreateWithCertificateReferences.ps1` for a configuration that demonstrates how to create a certificate configuration with certificate chains and reference it from a policy using the `trustedCertificateAuthority` restriction type.

See example `5-UpdateDefaultPolicyWithCertificateChain.ps1` for a configuration that updates the default tenant app management policy with certificate chain restrictions.

### Notes

- Certificate configurations are global tenant-wide objects
- Use the `AADCertificateBasedApplicationConfiguration` resource to manage the actual certificate authorities
- Use `DependsOn` in your DSC configuration to ensure certificate configurations are created before policies that reference them
- The `trustedCertificateAuthority` restriction type with `certificateBasedApplicationConfigurationIds` enables enforcing specific certificate chains on key credentials
