<#
This example creates a new Azure PIM role eligibility schedule at subscription level.
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
        AzurePIMRoleEligibilityScheduleRequest "SubscriptionOwnerEligibility"
        {
            Principal             = "AdeleV@contoso.onmicrosoft.com"
            RoleDefinitionName    = "Owner"
            Scope                 = "/subscriptions/12345678-1234-1234-1234-123456789012"
            PrincipalType         = "User"
            Ensure                = "Present"
            ScheduleInfo          = MSFT_AzurePIMRoleEligibilityScheduleRequestSchedule {
                startDateTime = '2024-01-15T08:00:00Z'
                expiration    = MSFT_AzurePIMRoleEligibilityScheduleRequestScheduleExpiration
                {
                    type        = 'afterDateTime'
                    endDateTime = '2025-12-31T23:59:59Z'
                }
            }
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
        }
    }
}
