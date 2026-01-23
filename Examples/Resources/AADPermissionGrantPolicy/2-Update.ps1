<# 
.SYNOPSIS
Updates an existing permission grant policy.
#>
Configuration AADPermissionGrantPolicy_Update
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicy 'UpdatePolicy'
        {
            Id          = 'm365dsc-custom'
            DisplayName = 'Custom Consent Policy Updated'
            Description = 'Updated description for custom consent policy'
            Credential  = $Credential
            Ensure      = 'Present'
        }
    }
}
