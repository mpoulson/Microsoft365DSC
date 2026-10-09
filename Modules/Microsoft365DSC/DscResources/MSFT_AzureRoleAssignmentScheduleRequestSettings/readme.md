# AzureRoleAssignmentScheduleRequestSettings

## Description

Configures the Azure PIM (Privileged Identity Management) settings that govern **active** role assignments: whether a
permanent active assignment is allowed, how long a time-bound active assignment may last, whether MFA and
justification are required when someone is assigned as active, and the three notification rules that fire when a
member is assigned as active to the role.

Applies to Azure roles at Management Group, Subscription, and Resource Group scopes.

## Overlap with AzureRoleEligibilityScheduleSettings

> **Set these properties in one place only.**

Azure keeps a **single** role management policy per (role, scope) pair. Its 17 rules cover eligibility, active
assignment, and activation. `AzureRoleEligibilityScheduleSettings` already exposes all 17, including the 13
active-assignment properties this resource exposes.

That means a configuration declaring both resources for the same `RoleDefinitionDisplayName` and `ScopeId` writes to
the same underlying object. If the two blocks disagree on any shared property, each run will report drift and flip the
value back, and the tenant will never converge.

Pick one of the following for a given role and scope:

- Use `AzureRoleAssignmentScheduleRequestSettings` alone when active-assignment settings are all you manage. This is
  the smaller surface and the properties it does not carry are left exactly as Azure returned them.
- Use `AzureRoleEligibilityScheduleSettings` alone when you also manage eligibility or activation settings.
- Use both **only** if you omit every shared property from one of them. Since all 13 properties of this resource are
  shared, in practice that means not declaring both.

Property names are deliberately identical between the two resources, so moving a configuration from one to the other
is a matter of changing the resource type and dropping the properties that no longer apply.

## Properties written

Only these five rules of the policy are touched. Everything else is read and written back unchanged:

| Rule id | Properties |
|---|---|
| `Expiration_Admin_Assignment` | `PermanentActiveAssignmentisExpirationRequired`, `ExpireActiveAssignment` |
| `Enablement_Admin_Assignment` | `AssignmentReqMFA`, `AssignmentReqJustification` |
| `Notification_Admin_Admin_Assignment` | `ActiveAlertNotification*` |
| `Notification_Requestor_Admin_Assignment` | `ActiveAssigneeNotification*` |
| `Notification_Approver_Admin_Assignment` | `ActiveApproveNotification*` |

`PermanentActiveAssignmentisExpirationRequired` and `ExpireActiveAssignment` are written together: the expiration
rule is only updated when **both** are present in the configuration, because Azure rejects a rule that requires
expiration without a maximum duration. The other rule families accept either property on its own; any value you omit
is carried over from what Azure currently has.

## Required Permissions

- **Owner** or **User Access Administrator** at the scope, or a custom role with:
  - `Microsoft.Authorization/roleManagementPolicies/read`
  - `Microsoft.Authorization/roleManagementPolicies/write`
  - `Microsoft.Authorization/roleManagementPolicyAssignments/read`
  - `Microsoft.Authorization/roleDefinitions/read`

## Notes

- There is no `Ensure` property. A role management policy cannot be created or deleted, only reverted to Azure
  defaults, so this resource only ever updates an existing policy.
- `PolicyId` is reported by the Get method for traceability. It is resolved from the role and scope on every run and
  does not need to be supplied.
- Export enumerates every subscription, resource group, and management group the caller can see. Pass
  `-Filter 'ModifiedOnly'` to skip policies that have never been customised from Azure defaults, which cuts the output
  down considerably on a tenant with many scopes.
- `ExpireActiveAssignment` is an ISO 8601 duration, for example `PT8H` or `P30D`.
