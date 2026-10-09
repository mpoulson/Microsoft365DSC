# AzureBillingaccountsRoleAssignment

## Description

Manages roles on billing accounts.

## Enterprise Agreement billing accounts

The billing plane reports role assignments differently depending on the agreement type of the billing
account, and Enterprise Agreement enrollments omit fields that Microsoft Customer Agreement accounts always
return:

* `principalType` is never returned. The principal type is established by resolving `principalId` through
  the directory, trying User, then ServicePrincipal, then Group.
* Assignments created through the legacy Enterprise Agreement portal identify their principal only by
  `principalPuid` and `userEmailAddress`, with no `principalId` and no `principalTenantId`. Those are
  exported with the email address as `PrincipalName`, and the Get method matches them on that address so
  they are reported as `Present` instead of being recreated on every run. The email address is frequently
  an external one that has no object in the directory, which is expected.
* `PrincipalTenantId` falls back to the tenant currently connected to when the billing plane does not
  report one.
* Some role definitions have no friendly `roleName` and are returned as `EaRoleId_<guid>`. Since
  `RoleDefinition` is a key, the role definition identifier is used when the name is empty.

Only a subset of Enterprise Agreement roles can be assigned to a service principal, and those assignments
are not visible in the portal. See the `AzureSubscription` resource documentation for the role table.

An assignment that carries no resolvable principal at all is skipped with a verbose message rather than
failing the export.
