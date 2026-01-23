# AADPermissionGrantPolicyInclude

## Description

Manages include condition sets for Microsoft Entra permission grant policies.

## Parameters

* **Id**: Key. Identifier of the permission grant condition set.
* **PermissionGrantPolicyId**: Key. Id of the permission grant policy containing this include condition.
* **PermissionType**: Permission type. { delegated | application }
* **ResourceApplication**: Identifier of the resource application (API).
* **Permissions**: Permissions included by this condition.
* **PermissionClassification**: Classification for the permissions. { low | medium | high | all }
* **ClientApplicationIds**: Allowed client application Ids.
* **ClientApplicationTenantIds**: Allowed client application tenant Ids.
* **ClientApplicationPublisherIds**: Allowed client application publisher Ids.
* **ClientApplicationsFromVerifiedPublisherOnly**: Whether only verified publisher apps are allowed.
* **Ensure**: Specifies whether the include condition should exist. { Present | Absent }
* **Credential**: Credentials for Microsoft Graph delegated authentication.
* **ApplicationId**: Client ID for app-based authentication.
* **TenantId**: Tenant ID for authentication.
* **ApplicationSecret**: Client secret credential.
* **CertificateThumbprint**: Certificate thumbprint credential.
* **ManagedIdentity**: Use managed identity authentication.
* **AccessTokens**: Access tokens to use for authentication.

## Examples

### Ensure include condition is present

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
        AADPermissionGrantPolicyInclude 'IncludeExample'
        {
            Id                                        = 'include-delegated'
            PermissionGrantPolicyId                   = 'm365dsc-custom'
            PermissionType                            = 'delegated'
            ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
            Permissions                               = @('user.read')
            PermissionClassification                  = 'low'
            ClientApplicationIds                      = @('11111111-1111-1111-1111-111111111111')
            ClientApplicationTenantIds                = @('22222222-2222-2222-2222-222222222222')
            ClientApplicationPublisherIds             = @('33333333-3333-3333-3333-333333333333')
            ClientApplicationsFromVerifiedPublisherOnly = $true
            Credential                                = $Credential
            Ensure                                    = 'Present'
        }
    }
}
```

### Remove include condition

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
        AADPermissionGrantPolicyInclude 'IncludeExample'
        {
            Id                          = 'include-delegated'
            PermissionGrantPolicyId     = 'm365dsc-custom'
            Credential                  = $Credential
            Ensure                      = 'Absent'
        }
    }
}
```
