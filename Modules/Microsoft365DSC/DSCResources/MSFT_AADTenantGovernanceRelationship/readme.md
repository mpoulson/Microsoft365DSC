# AADTenantGovernanceRelationship

## Description

This resource monitors and manages Azure AD Tenant Governance Relationships
between a governing tenant and governed tenants.

A governance relationship is created when a governance request is accepted by
the governed tenant. This resource allows you to monitor the status of
existing relationships and initiate termination when needed.

Governance relationships cannot be directly created or deleted through this
resource. Use governance invitations to establish new relationships.

The supported status values are:
- `active` - The relationship is currently active
- `terminated` - The relationship has been terminated
- `terminationRequestedByGoverningTenant` - Termination has been requested
