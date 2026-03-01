<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.
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
        AzureRoleEligibilityScheduleRequest "MyEligibilityRequest"
        {
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
            DirectoryScopeId      = "/subscriptions/00000000-0000-0000-0000-000000000000";
            Ensure                = "Present";
            Principal             = "AdeleV@$TenantId";
            PrincipalType         = "User";
            RoleDefinition        = "Reader";
            ScheduleInfo          = MSFT_AzureRoleEligibilityScheduleRequestSchedule {
                startDateTime = '2023-09-01T02:40:44Z'
                expiration    = MSFT_AzureRoleEligibilityScheduleRequestScheduleExpiration
                    {
                        endDateTime = '2026-10-31T02:40:09Z'
                        type        = 'afterDateTime'
                    }
            };
        }
    }
}
