# AADPermissionGrantPolicy

## Description

This resource configures an Azure Active Directory Permission Grant Policy.

Permission Grant Policies allow organizations to delegate admin consent capabilities
for specific Microsoft Graph permissions to non-Global Administrator users and groups.

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **Id** | Key | String | The unique identifier for the permission grant policy. | |
| **DisplayName** | Write | String | The display name for the permission grant policy. | |
| **Description** | Write | String | The description for the permission grant policy. | |
| **Ensure** | Write | String | Specify if the policy should exist. | `Present`, `Absent` |
| **Credential** | Write | PSCredential | Credentials for the Microsoft Graph delegated permissions. | |
| **ApplicationId** | Write | String | Id of the Azure Active Directory application to authenticate with. | |
| **TenantId** | Write | String | Id of the Azure Active Directory tenant used for authentication. | |
| **ApplicationSecret** | Write | PSCredential | Secret of the Azure Active Directory application to authenticate with. | |
| **CertificateThumbprint** | Write | String | Thumbprint of the Azure Active Directory application's authentication certificate to use for authentication. | |
| **ManagedIdentity** | Write | Boolean | Managed ID being used for authentication. | |
| **AccessTokens** | Write | StringArray[] | Access token used for authentication. | |

## Description

Permission Grant Policies are the foundation for delegating admin consent capabilities.
They define a container that can have include and exclude conditions added to it.

## Example

```powershell
AADPermissionGrantPolicy 'CustomConsentPolicy'
{
    Id          = "custom-directory-devices-consent"
    DisplayName = "Directory & Device Consent Policy"
    Description = "Allows specific groups to consent Directory.ReadWrite.All and Devices.ReadWrite.All"
    Ensure      = "Present"
    Credential  = $Credential
}
```
