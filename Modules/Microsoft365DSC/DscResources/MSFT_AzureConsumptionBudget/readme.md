# AzureConsumptionBudget

## Description

Configures an Azure consumption budget at any Azure Resource Manager scope.

The resource is the declarative equivalent of `Get-AzConsumptionBudget` and
`New-AzConsumptionBudget`, implemented against the `Microsoft.Consumption/budgets`
Azure Resource Manager provider so that no additional Az module is required.

## Scope

`Scope` accepts any scope the Consumption Budgets api supports, with or without
the surrounding slashes:

| Scope | Example |
|---|---|
| Billing account | `providers/Microsoft.Billing/billingAccounts/5538726` |
| Enrollment account | `providers/Microsoft.Billing/billingAccounts/5538726/enrollmentAccounts/123456` |
| Department | `providers/Microsoft.Billing/billingAccounts/5538726/departments/123456` |
| Management group | `providers/Microsoft.Management/managementGroups/mg-kuiper` |
| Subscription | `subscriptions/00000000-0000-0000-0000-000000000000` |
| Resource group | `subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared` |

`Name` and `Scope` together form the key, so the same budget name can be used at
more than one scope.

## Notifications

The api stores notifications as a dictionary keyed by notification name. DSC
cannot model an open ended dictionary, so each entry carries that key as its
`Name` property. A notification name must be unique within the budget.

`ThresholdType` of `Forecasted` compares against forecasted rather than actual
spend. `Threshold` is a percentage of `Amount` between 0 and 1000.

## Filters

The api represents a single filter criterion directly and multiple criteria
under an `and` array. This resource flattens both shapes into
`FilterDimensions` and `FilterTags`; every criterion supplied in either
property is combined with a logical and. The `or` and `not` filter shapes are
not modelled.

## Export

Budgets are scoped resources and Azure offers no tenant wide list operation for
them. Export therefore walks the scopes an Enterprise Agreement tenant actually
uses: every billing account returned by the billing plane and every subscription
visible to the caller. Budgets defined at a management group, department,
enrollment account or resource group scope are not discovered automatically and
have to be authored by hand.

A scope the caller cannot read is skipped with a verbose message rather than
failing the export.

## Api version

The resource pins api-version `2023-05-01`. That version is stable in every
Azure cloud including the US Government clouds and carries every property this
resource models, so it is preferred over the newer previews.
