<# 
.SYNOPSIS
Removes a permission grant policy include condition.
#>
Configuration AADPermissionGrantPolicyInclude_Remove
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
            Id                          = 'include-delegated'
            PermissionGrantPolicyId     = 'm365dsc-custom'
            Credential                  = $Credential
            Ensure                      = 'Absent'
        }
    }
}
