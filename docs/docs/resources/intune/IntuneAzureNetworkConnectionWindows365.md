# IntuneAzureNetworkConnectionWindows365

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **AdDomainName** | Write | String | The fully qualified domain name (FQDN) of the Active Directory domain you want to join. Optional. | |
| **AdDomainPassword** | Write | String | The password associated with adDomainUsername. Cannot be exported and must be manually added before deploying the network connection. | |
| **AdDomainUsername** | Write | String | The username of an Active Directory account (user or service account) that has permissions to create computer objects in Active Directory. Required format: admincontoso.com. Optional. | |
| **ConnectionType** | Write | String | Specifies the method by which a provisioned Cloud PC is joined to Microsoft Entra. The azureADJoin option indicates the absence of an on-premises Active Directory (AD) in the current tenant that results in the Cloud PC device only joining to Microsoft Entra. The hybridAzureADJoin option indicates the presence of an on-premises AD in the current tenant and that the Cloud PC joins both the on-premises AD and Microsoft Entra. The selected option also determines the types of users who can be assigned and can sign into a Cloud PC. The azureADJoin option allows both cloud-only and hybrid users to be assigned and sign in, whereas hybridAzureADJoin is restricted to hybrid users only. The default value is hybridAzureADJoin. The possible values are: hybridAzureADJoin, azureADJoin. | `hybridAzureADJoin`, `azureADJoin` |
| **DisplayName** | Key | String | The display name for the Azure network connection. | |
| **OrganizationalUnit** | Write | String | The organizational unit (OU) in which the computer account is created. If left null, the OU configured as the default (a well-known computer object container) in your Active Directory domain (OU) is used. Optional. Only applicable for the connection type 'hybridAzureADJoin'. | |
| **ResourceGroupId** | Required | String | The ID of the target resource group. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}. | |
| **RoleScopeTagIds** | Write | StringArray[] | List of Scope Tags for this Entity instance. | |
| **SubnetId** | Required | String | The ID of the target subnet. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkId}/subnets/{subnetName}. | |
| **SubscriptionName** | Required | String | The name of the target Azure subscription. | |
| **VirtualNetworkId** | Required | String | The ID of the target virtual network. Required format: /subscriptions/{subscription-id}/{resourceGroups/resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{virtualNetworkName}. | |
| **Id** | Write | String | The unique identifier for an entity. Read-only. | |
| **Ensure** | Write | String | Present ensures the policy exists, absent ensures it is removed. | `Present`, `Absent` |
| **Credential** | Write | PSCredential | Credentials of the Admin | |
| **ApplicationId** | Write | String | Id of the Azure Active Directory application to authenticate with. | |
| **TenantId** | Write | String | Id of the Azure Active Directory tenant used for authentication. | |
| **ApplicationSecret** | Write | PSCredential | Secret of the Azure Active Directory tenant used for authentication. | |
| **CertificateThumbprint** | Write | String | Thumbprint of the Azure Active Directory application's authentication certificate to use for authentication. | |
| **ManagedIdentity** | Write | Boolean | Managed ID being used for authentication. | |
| **AccessTokens** | Write | StringArray[] | Access token used for authentication. | |


## Description

Intune Azure Network Connection for Windows365

**NOTE:** To resolve the subscription and resource group name, the identity requires the `Microsoft.Resources/subscriptions/read` Azure permission.
You can either assign it with a built-in role with more permissions, or use a custom Azure RBAC role with this specific permission.
The role scope can be configured at management group or at an individual subscription level, but it must be the subscription where the Azure Network Connection was deployed to.

Make sure that the value of `SubscriptionName` is the same as the one in the subnet and resource group specification.

## Permissions

### Microsoft Graph

To authenticate with the Microsoft Graph API, this resource required the following permissions:

#### Delegated permissions

- **Read**

    - CloudPC.Read.All

- **Update**

    - CloudPC.ReadWrite.All

#### Application permissions

- **Read**

    - CloudPC.Read.All

- **Update**

    - CloudPC.ReadWrite.All

## Examples

### Example 1

This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.

```powershell
Configuration Example
{
    param(
        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        IntuneAzureNetworkConnectionWindows365 "IntuneAzureNetworkConnectionWindows365-IntuneWindows365AzureNetworkConnection_Hybrid"
        {
            AdDomainName          = "contoso.com";
            AdDomainUsername      = "username@contoso.com";
            AdDomainPassword      = "securePassword";
            ConnectionType        = "hybridAzureADJoin";
            DisplayName           = "IntuneWindows365AzureNetworkConnection_Hybrid";
            Ensure                = "Present";
            OrganizationalUnit    = "OU=Test,DC=contoso,DC=com";
            ResourceGroupId       = "/subscriptions/subscription-name/resourceGroups/resource-group-name";
            RoleScopeTagIds       = @("0");
            SubnetId              = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name/subnets/default";
            SubscriptionName      = "subscription-name";
            VirtualNetworkId      = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name";
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            TenantId              = $TenantId;
        }
        IntuneAzureNetworkConnectionWindows365 "IntuneAzureNetworkConnectionWindows365-IntuneWindows365AzureNetworkConnection_Entra"
        {
            ConnectionType        = "azureADJoin";
            DisplayName           = "IntuneWindows365AzureNetworkConnection_Entra_1";
            Ensure                = "Present";
            ResourceGroupId       = "/subscriptions/subscription-name/resourceGroups/resource-group-name";
            RoleScopeTagIds       = @("0");
            SubnetId              = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name/subnets/default";
            SubscriptionName      = "subscription-name";
            VirtualNetworkId      = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name";
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            TenantId              = $TenantId;
        }
    }
}
```

### Example 2

This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.

```powershell
Configuration Example
{
    param(
        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        IntuneAzureNetworkConnectionWindows365 "IntuneAzureNetworkConnectionWindows365-IntuneWindows365AzureNetworkConnection_Hybrid"
        {
            AdDomainName          = "contoso.com";
            AdDomainUsername      = "username@contoso.com";
            AdDomainPassword      = "securePassword";
            ConnectionType        = "hybridAzureADJoin";
            DisplayName           = "IntuneWindows365AzureNetworkConnection_Hybrid";
            Ensure                = "Present";
            OrganizationalUnit    = "OU=Test,DC=contoso,DC=com";
            ResourceGroupId       = "/subscriptions/subscription-name/resourceGroups/resource-group-name";
            RoleScopeTagIds       = @("0");
            SubnetId              = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name-2/subnets/default"; # Updated property
            SubscriptionName      = "subscription-name";
            VirtualNetworkId      = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name-2"; # Updated property
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            TenantId              = $TenantId;
        }
        IntuneAzureNetworkConnectionWindows365 "IntuneAzureNetworkConnectionWindows365-IntuneWindows365AzureNetworkConnection_Entra"
        {
            ConnectionType        = "azureADJoin";
            DisplayName           = "IntuneWindows365AzureNetworkConnection_Entra_1";
            Ensure                = "Present";
            ResourceGroupId       = "/subscriptions/subscription-name/resourceGroups/resource-group-name";
            RoleScopeTagIds       = @("0");
            SubnetId              = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name-2/subnets/default"; # Updated property
            SubscriptionName      = "subscription-name";
            VirtualNetworkId      = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name-2"; # Updated property
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            TenantId              = $TenantId;
        }
    }
}
```

### Example 3

This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.

```powershell
Configuration Example
{
    param(
        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        IntuneAzureNetworkConnectionWindows365 "IntuneAzureNetworkConnectionWindows365-IntuneWindows365AzureNetworkConnection_Hybrid"
        {
            AdDomainName          = "contoso.com";
            AdDomainUsername      = "username@contoso.com";
            AdDomainPassword      = "securePassword";
            ConnectionType        = "hybridAzureADJoin";
            DisplayName           = "IntuneWindows365AzureNetworkConnection_Hybrid";
            Ensure                = "Absent";
            OrganizationalUnit    = "OU=Test,DC=contoso,DC=com";
            ResourceGroupId       = "/subscriptions/subscription-name/resourceGroups/resource-group-name";
            SubnetId              = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name/subnets/default";
            SubscriptionName      = "subscription-name";
            VirtualNetworkId      = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name";
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            TenantId              = $TenantId;
        }
        IntuneAzureNetworkConnectionWindows365 "IntuneAzureNetworkConnectionWindows365-IntuneWindows365AzureNetworkConnection_Entra"
        {
            ConnectionType        = "azureADJoin";
            DisplayName           = "IntuneWindows365AzureNetworkConnection_Entra_1";
            Ensure                = "Absent";
            ResourceGroupId       = "/subscriptions/subscription-name/resourceGroups/resource-group-name";
            SubnetId              = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name/subnets/default";
            SubscriptionName      = "subscription-name";
            VirtualNetworkId      = "/subscriptions/subscription-name/resourceGroups/resource-group-name/providers/Microsoft.Network/virtualNetworks/virtual-network-name";
            ApplicationId         = $ApplicationId;
            CertificateThumbprint = $CertificateThumbprint;
            TenantId              = $TenantId;
        }
    }
}
```

