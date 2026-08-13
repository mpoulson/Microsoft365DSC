# AzureDataCollectionEndpoint

## Description

Configures Data Collection Endpoints (DCEs) in Azure Monitor. Data Collection
Endpoints provide a connection where the Azure Monitor Agent (AMA) can send
collected data, and are required for private-link scenarios and custom log
ingestion.

Users will need to grant permissions to the associated scope by running the
following command in Azure Cloud Shell:

```powershell
New-AzRoleAssignment -ObjectId "<Service Principal Object ID>" -Scope "/subscriptions/<Subscription Id>/resourceGroups/<Resource Group Name>" -RoleDefinitionName 'Monitoring Contributor' -ObjectType 'ServicePrincipal'
```
