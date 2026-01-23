<# 
.SYNOPSIS
Configures a permission grant policy in GCC High (USGov) environment.
#>
Configuration AADPermissionGrantPolicy_GCCHigh
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
            Id          = 'm365dsc-gcch'
            DisplayName = 'GCC High Policy'
            Description = 'Policy for GCC High'
            Credential  = $Credential
            Ensure      = 'Present'
        }
    }
}
