<# 
.SYNOPSIS
Creates a permission grant policy exclude condition.
#>
Configuration AADPermissionGrantPolicyExclude_Create
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicyExclude 'ExcludeCondition'
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
