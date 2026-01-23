<# 
.SYNOPSIS
Creates a new permission grant policy.
#>
Configuration AADPermissionGrantPolicy_Create
{
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADPermissionGrantPolicy 'CreatePolicy'
        {
            Id          = 'm365dsc-custom'
            DisplayName = 'Custom Consent Policy'
            Description = 'Policy used for custom consent scenarios'
            Credential  = $Credential
            Ensure      = 'Present'
        }
    }
}
