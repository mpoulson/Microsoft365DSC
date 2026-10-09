# AzureManagementGroup

## Description

Configures an Azure management group and the subscriptions assigned to it.

The resource is the declarative equivalent of `Get-AzManagementGroup`,
`New-AzManagementGroup`, `Remove-AzManagementGroup`,
`New-AzManagementGroupSubscription` and `Remove-AzManagementGroupSubscription`,
implemented against the `Microsoft.Management/managementGroups` Azure Resource
Manager provider so that no additional Az module is required.

## Identity

`GroupId` is the key. It is the immutable identifier Azure stores the group
under and it cannot be changed after creation, so renaming a group means
removing it and creating a new one. `DisplayName` is the friendly name and can
be changed freely.

## Hierarchy

`ParentGroupId` accepts either the bare name of the parent group or an already
qualified resource id. Omitting it at creation places the group directly under
the tenant root group, which is what Azure does by default.

Display name and parent changes are applied with a PATCH rather than a PUT,
because a PUT against an existing group is rejected unless the caller owns the
whole hierarchy.

## Subscriptions

`Subscriptions` holds the subscription identifiers assigned to the group. It is
authoritative: a subscription present in Azure but missing from the list is
removed from the group, which moves it back under the tenant root group. That is
where Azure places any subscription that is not explicitly assigned, so a
subscription is never left without a parent.

Leaving `Subscriptions` out of the configuration entirely leaves the current
assignments untouched.

Removing the management group moves its subscriptions back to the tenant root
first, because Azure refuses to delete a group that still holds children. Child
management groups are not moved, so a group that still contains other groups
fails to delete and the error is surfaced.

## Export

Export walks every management group returned by the tenant wide list operation
and reads each one with its children expanded, which is the only way the
subscription assignments are reported. Groups the caller cannot read are
surfaced as errors rather than silently skipped.
