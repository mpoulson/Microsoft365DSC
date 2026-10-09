# AzureSubscription

## Description

This resource controls the properties of an Azure subscription.

Subscriptions are read from the billing plane, and the shape of that plane depends on the agreement type of
the billing account. Check the agreement type before granting permissions or authoring a configuration.

## Microsoft Customer Agreement (MCA)

MCA billing accounts are organized into billing profiles and invoice sections. Set `InvoiceSectionId` to
identify the billing scope of a subscription.

To grant permissions, go to the Cost Management + Billing blade in Azure Portal --> Billing Scopes --> Select
your desired billing account --> then Access Control (IAM) to grant 'Billing Account Contributor' permissions
to manage billing accounts.
If the resource is only used for backup, the `Billing Account Reader` role is sufficient.

## Enterprise Agreement (EA)

EA enrollments have no billing profiles and no invoice sections. Requesting them returns
`HTTP 400 InvalidBillingAccountName`. An EA subscription is scoped by enrollment account instead, so set
`BillingAccountId` and `EnrollmentAccountId` rather than `InvoiceSectionId`.

EA billing roles cannot be granted through the portal's Access Control (IAM) blade for a service principal, and
the resulting assignments are not visible in the portal. They must be assigned through the billing REST API. Only
these roles can be assigned to a service principal:

| Role | Role definition ID | Scope | Purpose |
|---|---|---|---|
| EnrollmentReader | 24f8edb6-1668-4659-b5e2-40bb5f3a7d7e | billingAccounts | Read subscriptions, sufficient for export and backup |
| EA purchaser | da6647fb-7651-49ee-be91-c43c4877f0c4 | billingAccounts | Reservations, includes EnrollmentReader |
| DepartmentReader | db609904-a47f-4794-9be8-9bd86fbffd8a | departments | Read a single department |
| SubscriptionCreator | a0bcee42-bf30-4d1b-926a-48d21664ef71 | enrollmentAccounts | Create subscriptions |

See [Assign Enterprise Agreement roles to service principals](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals).
Note that the billing API returns some EA role definitions with no friendly `roleName`, reporting them as
`EaRoleId_<guid>`, so they can only be matched on the role definition ID.

## Enabling, disabling and cancelling

Billing roles do not grant the ability to enable, disable or cancel a subscription. Those operations act on the
subscription itself and require Owner at `/subscriptions/<id>`, granted separately.

The `Status` reported by the billing plane is not always one of the values that can be set. EA subscriptions
commonly report `Other`. Only `Active` and `Disabled` are actionable; any other desired value is reported and
left alone rather than being forced.
