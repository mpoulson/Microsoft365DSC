# AADTenantGovernancePolicyTemplate

## Description

This resource configures Azure AD Tenant Governance Policy Templates, which define
the configuration for governance relationships including delegated administration
role assignments and multi-tenant applications to provision.

Policy templates are used when creating governance requests and are stored as
snapshots in established governance relationships.

The system provides a default policy template with the ID 'default'. This template
serves as a reusable configuration that is applied when governance relationships
are automatically created for add-on tenants. The default template cannot be deleted.
