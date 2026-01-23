# TeamsMessagingConfiguration

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **IsSingleInstance** | Key | String | Only valid value is 'Yes'. | `Yes` |
| **EnableVideoMessageCaptions** | Write | Boolean | This setting determines if closed captions will be displayed, for Teams Video Clips, during playback. Possible values: True, False | |
| **EnableInOrganizationChatControl** | Write | Boolean | This setting determines if chat regulation for internal communication in tenant is allowed. Possible Values: True, False | |
| **CustomEmojis** | Write | Boolean | This setting enables/disables the use of custom emojis and reactions across the whole tenant. Upon enablement, admins and/or users can define a user group that is allowed. Possible Values: True, False | |
| **Storyline** | Write | String | This setting enables/disables the availability of Viva Engage storylines in Teams chats across the whole tenant. | `Disabled`, `Enabled` |
| **MessagingNotes** | Write | String | This setting enables/disables MessagingNotes integration across the whole tenant. Possible Values: Disabled, Enabled | `Disabled`, `Enabled` |
| **FileTypeCheck** | Write | String | This setting enables weaponizable file detection in Teams messages in the tenant. Possible Values: Enabled, Disabled | `Disabled`, `Enabled` |
| **UrlReputationCheck** | Write | String | This setting enables malicious URL detection in Teams messages in the tenant. Possible Values: Enabled, Disabled | `Disabled`, `Enabled` |
| **ContentBasedPhishingCheck** | Write | String | This setting enables content-based phishing detection for Teams messages in the tenant. | `Disabled`, `Enabled` |
| **ReportIncorrectSecurityDetections** | Write | String | This setting enables the end users to Report incorrect security detections in Teams messages in the tenant. Possible Values: Enabled, Disabled | `Disabled`, `Enabled` |
| **Credential** | Write | PSCredential | Credentials of the workload's Admin | |
| **ApplicationId** | Write | String | Id of the Azure Active Directory application to authenticate with. | |
| **TenantId** | Write | String | Id of the Azure Active Directory tenant used for authentication. | |
| **CertificateThumbprint** | Write | String | Thumbprint of the Azure Active Directory application's authentication certificate to use for authentication. | |


## Description

The TeamsMessagingConfiguration determines the messaging settings for users in your tenant.

## Permissions

### Microsoft Graph

To authenticate with the Microsoft Graph API, this resource required the following permissions:

#### Delegated permissions

- **Read**

    - None

- **Update**

    - None

#### Application permissions

- **Read**

    - Organization.Read.All

- **Update**

    - Organization.Read.All

## Examples

### Example 1

This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.

```powershell
Configuration Example
{
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $Credscredential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        TeamsMessagingConfiguration 'Global'
        {
            ContentBasedPhishingCheck         = "Disabled";
            CustomEmojis                      = $True;
            EnableInOrganizationChatControl   = $False;
            EnableVideoMessageCaptions        = $True;
            FileTypeCheck                     = "Disabled";
            IsSingleInstance                  = "Yes";
            MessagingNotes                    = "Enabled";
            ReportIncorrectSecurityDetections = "Disabled";
            Storyline                         = "Enabled";
            Credential                        = $Credscredential;
            UrlReputationCheck                = "Disabled";
        }
    }
}
```

