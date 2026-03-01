.\Set-AzurePIMRoleSettings.ps1 -ResourceType ManagementGroup -ResourceName "Tenant Root Group" -TenantName m365.onmicrosoft.us
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -RoleName Contributor -ResourceName "Tenant Root Group" -TenantName m365.onmicrosoft.us -Group sg-azure-users-mg-root-contributor -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -RoleName owner -ResourceName "Tenant Root Group" -TenantName m365.onmicrosoft.us -Group sg-azure-users-mg-root-owner -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "Tenant Root Group" -TenantName m365.onmicrosoft.us -role "billing reader" -Group sg-azure-users-mg-root-billingreader -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "Tenant Root Group" -TenantName m365.onmicrosoft.us -role "user access administrator" -Group sg-azure-users-mg-root-useraccessadmin -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "Tenant Root Group" -TenantName m365.onmicrosoft.us -role "reader" -Group sg-azure-users-mg-root-reader -ExpirationDays -1

.\Set-AzurePIMRoleSettings.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us -role "Contributor" -Group sg-azure-users-kcsls-contibutors -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us -role "owner" -Group sg-azure-users-kcsls-owner -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us -role "Support request contributor" -Group sg-azure-users-kcsls-support-contibutors -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us -role "Microsoft Sentinel Responder" -Group sg-azure-users-kcsls-Sentinel-Responder -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us -role "Microsoft Sentinel Playbook Operator" -Group sg-azure-users-kcsls-Sentinel-Playbook-Operator -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us -role "Microsoft Sentinel Reader" -Group sg-azure-users-kcsls-Sentinel-Reader -ExpirationDays -1
.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -ResourceName "FOO" -TenantName m365.onmicrosoft.us -role "Microsoft Sentinel Contributor" -Group sg-azure-users-kcsls-Sentinel-Contributor -ExpirationDays -1
