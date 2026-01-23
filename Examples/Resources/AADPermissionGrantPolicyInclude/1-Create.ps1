<# 
.SYNOPSIS
Creates a permission grant policy include condition.
#>
Configuration AADPermissionGrantPolicyInclude_Create
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicyInclude 'IncludeCondition'
        {
            Id                                        = 'include-delegated'
            PermissionGrantPolicyId                   = 'm365dsc-custom'
            PermissionType                            = 'delegated'
            ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
            Permissions                               = @('user.read')
            PermissionClassification                  = 'low'
            ClientApplicationIds                      = @('11111111-1111-1111-1111-111111111111')
            ClientApplicationsFromVerifiedPublisherOnly = $true
            Credential                                = $Credential
            Ensure                                    = 'Present'
        }
    }
}
