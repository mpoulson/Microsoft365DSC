<# 
.SYNOPSIS
Removes a permission grant policy exclude condition.
#>
Configuration AADPermissionGrantPolicyExclude_Remove
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
            Id                          = 'exclude-app'
            PermissionGrantPolicyId     = 'm365dsc-custom'
            Credential                  = $Credential
            Ensure                      = 'Absent'
        }
    }
}
