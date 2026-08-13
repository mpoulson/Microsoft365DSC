# AzureDataCollectionRuleAssociation

## Description

Associates an Azure Monitor Data Collection Rule (DCR) or Data Collection
Endpoint (DCE) with a target resource. The target is identified by its
`ResourceUri` and can be a virtual machine, an Arc-enabled server, or a
tenant-level monitored object (`/providers/Microsoft.Insights/monitoredObjects/<TenantId>`)
used to broadcast a DCR across an entire tenant.

Users will need to grant permissions to the associated scope by running the
following command in Azure Cloud Shell:

```powershell
New-AzRoleAssignment -ObjectId "<Service Principal Object ID>" -Scope "<Resource Uri>" -RoleDefinitionName 'Monitoring Contributor' -ObjectType 'ServicePrincipal'
```
