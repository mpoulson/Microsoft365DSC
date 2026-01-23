<# 
.SYNOPSIS
Removes a permission grant policy.
#>
Configuration AADPermissionGrantPolicy_Remove
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicy 'RemovePolicy'
        {
            Id         = 'm365dsc-custom'
            Credential = $Credential
            Ensure     = 'Absent'
        }
    }
}
