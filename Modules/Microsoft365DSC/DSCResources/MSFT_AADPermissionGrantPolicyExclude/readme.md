# AADPermissionGrantPolicyExclude

## Description

This resource configures an exclude condition for an Azure Active Directory Permission Grant Policy.

Exclude conditions define permissions that are explicitly BLOCKED from consent and override
any include conditions. These are used to create exceptions to broader include rules.

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **Id** | Key | String | The unique identifier for the condition. | |
| **PermissionGrantPolicyId** | Key | String | The unique identifier of the parent permission grant policy. | |
| **PermissionType** | Write | String | The permission type. | `delegated`, `application` |
| **ResourceApplication** | Write | String | The resource application ID (e.g., 00000003-0000-0000-c000-000000000000 for Microsoft Graph). | |
| **Permissions** | Write | StringArray[] | The list of permission IDs to exclude, or @('all') for all permissions. | |
| **PermissionClassification** | Write | String | The permission classification. | `low`, `medium`, `high`, `all` |
| **ClientApplicationIds** | Write | StringArray[] | The list of client application IDs, or @('all') for all applications. | |
| **ClientApplicationTenantIds** | Write | StringArray[] | The list of client application tenant IDs, or @('all') for all tenants. | |
| **ClientApplicationPublisherIds** | Write | StringArray[] | The list of client application publisher IDs, or @('all') for all publishers. | |
| **ClientApplicationsFromVerifiedPublisherOnly** | Write | Boolean | Indicates whether client applications must be from a verified publisher. | |
| **Ensure** | Write | String | Specify if the condition should exist. | `Present`, `Absent` |
| **Credential** | Write | PSCredential | Credentials for the Microsoft Graph delegated permissions. | |
| **ApplicationId** | Write | String | Id of the Azure Active Directory application to authenticate with. | |
| **TenantId** | Write | String | Id of the Azure Active Directory tenant used for authentication. | |
| **ApplicationSecret** | Write | PSCredential | Secret of the Azure Active Directory application to authenticate with. | |
| **CertificateThumbprint** | Write | String | Thumbprint of the Azure Active Directory application's authentication certificate to use for authentication. | |
| **ManagedIdentity** | Write | Boolean | Managed ID being used for authentication. | |
| **AccessTokens** | Write | StringArray[] | Access token used for authentication. | |

## Description

Exclude conditions specify permissions that users CANNOT consent to, even if they match
an include condition. Excludes take precedence over includes.
Note: Include/Exclude conditions do NOT support updates. To modify, you must remove and recreate.

## Example

```powershell
AADPermissionGrantPolicyExclude 'BlockExternal'
{
    Id                         = "exclude-external-tenants"
    PermissionGrantPolicyId    = "custom-directory-devices-consent"
    PermissionType             = "application"
    ResourceApplication        = "00000003-0000-0000-c000-000000000000"
    Permissions                = @("all")
    ClientApplicationTenantIds = @("all")
    Ensure                     = "Present"
    Credential                 = $Credential
}
```
