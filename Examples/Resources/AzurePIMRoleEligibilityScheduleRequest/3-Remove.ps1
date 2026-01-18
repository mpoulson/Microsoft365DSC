<#
This example removes an Azure PIM role eligibility schedule.
#>

Configuration Example
{
    param
    (
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $Credscredential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        AzurePIMRoleEligibilityScheduleRequest "RemoveEligibility"
        {
            Principal             = "AdeleV@contoso.onmicrosoft.com"
            RoleDefinitionName    = "Owner"
            Scope                 = "/subscriptions/12345678-1234-1234-1234-123456789012"
            PrincipalType         = "User"
            Ensure                = "Absent"
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
        }
    }
}
