# AADPermissionGrantPolicyExclude

## Description

Manages exclude condition sets for Microsoft Entra permission grant policies.

## Parameters

* **Id**: Key. Identifier of the permission grant condition set.
* **PermissionGrantPolicyId**: Key. Id of the permission grant policy containing this exclude condition.
* **PermissionType**: Permission type. { delegated | application }
* **ResourceApplication**: Identifier of the resource application (API).
* **Permissions**: Permissions excluded by this condition.
* **PermissionClassification**: Classification for the permissions. { low | medium | high | all }
* **ClientApplicationIds**: Client application Ids excluded.
* **ClientApplicationTenantIds**: Client application tenant Ids excluded.
* **ClientApplicationPublisherIds**: Client application publisher Ids excluded.
* **ClientApplicationsFromVerifiedPublisherOnly**: Whether only verified publisher apps are excluded.
* **Ensure**: Specifies whether the exclude condition should exist. { Present | Absent }
* **Credential**: Credentials for Microsoft Graph delegated authentication.
* **ApplicationId**: Client ID for app-based authentication.
* **TenantId**: Tenant ID for authentication.
* **ApplicationSecret**: Client secret credential.
* **CertificateThumbprint**: Certificate thumbprint credential.
* **ManagedIdentity**: Use managed identity authentication.
* **AccessTokens**: Access tokens to use for authentication.

## Examples

### Ensure exclude condition is present

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
        AADPermissionGrantPolicyExclude 'ExcludeExample'
        {
            Id                                        = 'exclude-app'
            PermissionGrantPolicyId                   = 'm365dsc-custom'
            PermissionType                            = 'application'
            ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
            Permissions                               = @('files.read.all')
            PermissionClassification                  = 'high'
            ClientApplicationIds                      = @('44444444-4444-4444-4444-444444444444')
            ClientApplicationsFromVerifiedPublisherOnly = $false
            Credential                                = $Credential
            Ensure                                    = 'Present'
        }
    }
}
```

### Remove exclude condition

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
        AADPermissionGrantPolicyExclude 'ExcludeExample'
        {
            Id                          = 'exclude-app'
            PermissionGrantPolicyId     = 'm365dsc-custom'
            Credential                  = $Credential
            Ensure                      = 'Absent'
        }
    }
}
```
