# AzureDataCollectionRule

## Description

Configures Data Collection Rules (DCRs) in Azure Monitor. Data Collection Rules
define what data the Azure Monitor Agent (AMA) collects (for example Windows
Event Logs and Windows Firewall Logs), how it is transformed, and which Log
Analytics workspaces it is sent to.

Users will need to grant permissions to the associated scope by running the
following command in Azure Cloud Shell:

```powershell
New-AzRoleAssignment -ObjectId "<Service Principal Object ID>" -Scope "/subscriptions/<Subscription Id>/resourceGroups/<Resource Group Name>" -RoleDefinitionName 'Monitoring Contributor' -ObjectType 'ServicePrincipal'
```
