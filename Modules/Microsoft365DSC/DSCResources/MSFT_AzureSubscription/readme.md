# AzureSubscription

## Description

This resource controls the properties of an Azure subscription.

To grant permissions, go to the Cost Management + Billing blade in Azure Portal --> Billing Scopes --> Select your desired billing account --> then Access Control (IAM) to grant 'Billing Account Contributor' permissions to manage billing accounts.
If the resource is only used for backup, the `Billing Account Reader` role is sufficient.

## Export filters
This resource supports filtering only roles that have had the settings modified/customized. Pass `ModifiedOnly` as filter to only export roles that have settings modified.

```
-Filters @{MSFT_AzureRoleEligibilityScheduleSettings = 'ModifiedOnly'}
```

