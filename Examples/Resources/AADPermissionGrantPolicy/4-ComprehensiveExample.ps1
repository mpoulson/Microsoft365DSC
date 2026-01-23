<#
.SYNOPSIS
    Comprehensive example demonstrating delegation of admin consent for specific
    Microsoft Graph permissions to a security group using Permission Grant Policies.

.DESCRIPTION
    This example creates a complete permission grant policy configuration that:
    1. Creates a custom permission grant policy
    2. Adds include conditions for Directory.ReadWrite.All and Devices.ReadWrite.All
    3. Adds an exclude condition to block apps from external tenants
    
    This allows designated security group members to consent to these specific
    permissions for applications without Global Admin privileges.

.NOTES
    Permission IDs reference:
    - Directory.ReadWrite.All: 19dbc75e-c2e2-444c-a770-ec69d8559fc7
    - Devices.ReadWrite.All: 1138cb37-bd11-4084-a2b7-9f71582aeddb
    - Microsoft Graph Resource ID: 00000003-0000-0000-c000-000000000000
#>

Configuration DelegateConsentToGroup
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
        # Step 1: Create the main policy container
        AADPermissionGrantPolicy 'CustomConsentPolicy'
        {
            Id                    = "custom-directory-devices-consent"
            DisplayName           = "Directory & Device Consent Policy"
            Description           = "Allows delegation of consent for Directory.ReadWrite.All and Devices.ReadWrite.All to specific security groups"
            Ensure                = "Present"
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
        }

        # Step 2: Include Directory.ReadWrite.All permission
        AADPermissionGrantPolicyInclude 'IncludeDirectoryRW'
        {
            Id                              = "include-directory-rw"
            PermissionGrantPolicyId         = "custom-directory-devices-consent"
            PermissionType                  = "application"
            ResourceApplication             = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph
            Permissions                     = @("19dbc75e-c2e2-444c-a770-ec69d8559fc7")  # Directory.ReadWrite.All
            PermissionClassification        = "all"
            ClientApplicationIds            = @("all")
            ClientApplicationTenantIds      = @($TenantId)  # Only same tenant
            ClientApplicationPublisherIds   = @("all")
            ClientApplicationsFromVerifiedPublisherOnly = $false
            Ensure                          = "Present"
            ApplicationId                   = $ApplicationId
            TenantId                        = $TenantId
            CertificateThumbprint           = $CertificateThumbprint
            DependsOn                       = "[AADPermissionGrantPolicy]CustomConsentPolicy"
        }

        # Step 3: Include Devices.ReadWrite.All permission
        AADPermissionGrantPolicyInclude 'IncludeDevicesRW'
        {
            Id                              = "include-devices-rw"
            PermissionGrantPolicyId         = "custom-directory-devices-consent"
            PermissionType                  = "application"
            ResourceApplication             = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph
            Permissions                     = @("1138cb37-bd11-4084-a2b7-9f71582aeddb")  # Devices.ReadWrite.All
            PermissionClassification        = "all"
            ClientApplicationIds            = @("all")
            ClientApplicationTenantIds      = @($TenantId)  # Only same tenant
            ClientApplicationPublisherIds   = @("all")
            ClientApplicationsFromVerifiedPublisherOnly = $false
            Ensure                          = "Present"
            ApplicationId                   = $ApplicationId
            TenantId                        = $TenantId
            CertificateThumbprint           = $CertificateThumbprint
            DependsOn                       = "[AADPermissionGrantPolicy]CustomConsentPolicy"
        }

        # Step 4: Exclude apps from external tenants (security measure)
        AADPermissionGrantPolicyExclude 'BlockExternal'
        {
            Id                         = "exclude-external-tenants"
            PermissionGrantPolicyId    = "custom-directory-devices-consent"
            PermissionType             = "application"
            ResourceApplication        = "00000003-0000-0000-c000-000000000000"
            Permissions                = @("all")
            ClientApplicationIds       = @("all")
            ClientApplicationTenantIds = @("all")  # Block ALL external tenants
            Ensure                     = "Present"
            ApplicationId              = $ApplicationId
            TenantId                   = $TenantId
            CertificateThumbprint      = $CertificateThumbprint
            DependsOn                  = "[AADPermissionGrantPolicy]CustomConsentPolicy"
        }
    }
}

<#
.NOTES
    After applying this configuration:
    
    1. Assign the policy to a security group using AADAuthorizationPolicy:
       
       AADAuthorizationPolicy 'UpdateAuthPolicy'
       {
           IsSingleInstance = 'Yes'
           PermissionGrantPolicyIdsAssignedToDefaultUserRole = @(
               'managePermissionGrantsForSelf.custom-directory-devices-consent'
           )
           # ... other parameters
       }
    
    2. Or create a custom directory role with this policy and assign users/groups to it.
    
    3. Members can now consent to apps requesting Directory.ReadWrite.All or
       Devices.ReadWrite.All, but only for same-tenant applications.
#>
