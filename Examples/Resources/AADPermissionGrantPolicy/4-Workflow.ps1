<# 
.SYNOPSIS
Demonstrates configuring a permission grant policy with include and exclude condition sets.
#>
Configuration AADPermissionGrantPolicy_Workflow
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicy 'Policy'
        {
            Id          = 'm365dsc-workflow'
            DisplayName = 'Workflow Policy'
            Description = 'Policy supporting delegated app consent workflow'
            Credential  = $Credential
            Ensure      = 'Present'
        }

        AADPermissionGrantPolicyInclude 'IncludeDelegated'
        {
            Id                                        = 'include-delegated'
            PermissionGrantPolicyId                   = 'm365dsc-workflow'
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

        AADPermissionGrantPolicyExclude 'ExcludeApp'
        {
            Id                                        = 'exclude-app'
            PermissionGrantPolicyId                   = 'm365dsc-workflow'
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
