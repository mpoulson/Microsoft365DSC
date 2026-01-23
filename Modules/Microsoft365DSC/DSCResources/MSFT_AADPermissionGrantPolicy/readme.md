# AADPermissionGrantPolicy

## Description

Creates, updates, or removes Microsoft Entra permission grant policies.

## Parameters

* **Id**: Key. Identifier of the permission grant policy.
* **DisplayName**: Display name of the policy.
* **Description**: Description of the policy.
* **Ensure**: Specifies whether the policy should exist. { Present | Absent }
* **Credential**: Credentials for Microsoft Graph delegated authentication.
* **ApplicationId**: Client ID for app-based authentication.
* **TenantId**: Tenant ID for authentication.
* **ApplicationSecret**: Client secret credential.
* **CertificateThumbprint**: Certificate thumbprint credential.
* **ManagedIdentity**: Use managed identity authentication.
* **AccessTokens**: Access tokens to use for authentication.

## Examples

### Ensure permission grant policy is present

```PowerShell
Configuration Example
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicy 'GrantPolicy'
        {
            Id          = 'm365dsc-custom'
            DisplayName = 'Custom Consent Policy'
            Description = 'Custom policy for delegated permissions'
            Credential  = $Credential
            Ensure      = 'Present'
        }
    }
}
```

### Remove permission grant policy

```PowerShell
Configuration Example
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicy 'GrantPolicy'
        {
            Id         = 'm365dsc-custom'
            Credential = $Credential
            Ensure     = 'Absent'
        }
    }
}
```
