# AADPermissionGrantPolicy

## Description

This resource configures an Azure Active Directory Permission Grant Policy with its associated include and exclude condition sets.

Permission Grant Policies allow organizations to delegate admin consent capabilities for specific Microsoft Graph permissions to non-Global Administrator users and groups.

This resource combines the parent policy and its condition sets into a single configuration, managing:
- The parent permission grant policy properties (Id, DisplayName, Description)
- Include condition sets as an embedded CIM instance array
- Exclude condition sets as an embedded CIM instance array

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **Id** | Key | String | The unique identifier for the permission grant policy. | |
| **DisplayName** | Write | String | The display name for the permission grant policy. | |
| **Description** | Write | String | The description for the permission grant policy. | |
| **Includes** | Write | MSFT_AADPermissionGrantConditionSet[] | Condition sets which are included in this permission grant policy. | |
| **Excludes** | Write | MSFT_AADPermissionGrantConditionSet[] | Condition sets which are excluded in this permission grant policy. | |
| **Ensure** | Write | String | Specify if the policy should exist. | `Present`, `Absent` |
| **Credential** | Write | PSCredential | Credentials for the Microsoft Graph delegated permissions. | |
| **ApplicationId** | Write | String | Id of the Azure Active Directory application to authenticate with. | |
| **TenantId** | Write | String | Id of the Azure Active Directory tenant used for authentication. | |
| **ApplicationSecret** | Write | PSCredential | Secret of the Azure Active Directory application to authenticate with. | |
| **CertificateThumbprint** | Write | String | Thumbprint of the Azure Active Directory application's authentication certificate to use for authentication. | |
| **ManagedIdentity** | Write | Boolean | Managed ID being used for authentication. | |
| **AccessTokens** | Write | StringArray[] | Access token used for authentication. | |

### MSFT_AADPermissionGrantConditionSet

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **Id** | Write | String | The unique identifier for the condition set. | |
| **CertifiedClientApplicationsOnly** | Write | Boolean | Set to true to only match on client applications with a verified publisher. | |
| **ClientApplicationIds** | Write | StringArray[] | A list of appId values for the client applications to match with, or @("all") to match any client application. | |
| **ClientApplicationPublisherIds** | Write | StringArray[] | A list of Microsoft Partner Network (MPN) IDs for verified publishers of the client application, or @("all") to match with client apps from any publisher. | |
| **ClientApplicationTenantIds** | Write | StringArray[] | A list of Azure Active Directory tenant IDs in which the client application is registered, or @("all") to match with client apps registered in any tenant. | |
| **ClientApplicationsFromVerifiedPublisherOnly** | Write | Boolean | Set to true to only match on client applications with a verified publisher. | |
| **PermissionClassification** | Write | String | The permission classification for the permission being granted, or "all" to match with any permission classification. | |
| **Permissions** | Write | StringArray[] | The list of id values for the specific permissions to match with, or @("all") to match with any permission. | |
| **PermissionType** | Write | String | The permission type of the permission being granted. Possible values: "application" for application permissions, or "delegated" for delegated permissions. | |
| **ResourceApplication** | Write | String | The appId of the resource application (e.g. the API) for which a permission is being granted, or "any" to match with any resource application or API. | |

## Description

Permission Grant Policies are the foundation for delegating admin consent capabilities. They define a container with include and exclude conditions that determine when consent can be granted.

## Example

```powershell
AADPermissionGrantPolicy 'CustomConsentPolicy'
{
    Id           = "my-custom-consent-policy"
    DisplayName  = "My Custom Consent Policy"
    Description  = "Custom policy for app consent with specific conditions"
    Includes     = @(
        MSFT_AADPermissionGrantConditionSet {
            Id                              = "include-low-risk-delegated"
            PermissionType                  = "delegated"
            PermissionClassification        = "low"
            ClientApplicationIds            = @("all")
            ClientApplicationTenantIds      = @($TenantId)
            ClientApplicationPublisherIds   = @("all")
            ClientApplicationsFromVerifiedPublisherOnly = $false
            ResourceApplication             = "00000003-0000-0000-c000-000000000000"
            Permissions                     = @("User.Read", "openid", "profile")
        }
    )
    Excludes     = @(
        MSFT_AADPermissionGrantConditionSet {
            Id                       = "exclude-high-risk-permissions"
            PermissionType           = "delegated"
            PermissionClassification = "high"
            ClientApplicationIds     = @("all")
            ResourceApplication      = "any"
            Permissions              = @("all")
        }
    )
    Ensure                = "Present"
    ApplicationId         = $ApplicationId
    TenantId              = $TenantId
    CertificateThumbprint = $CertificateThumbprint
}
```
