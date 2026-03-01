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
        AzureRoleAssignmentScheduleRequest "MyAssignmentRequest"
        {
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
            DirectoryScopeId      = "/subscriptions/00000000-0000-0000-0000-000000000000";
            Ensure                = "Absent";
            Principal             = "AdeleV@$TenantId";
            PrincipalType         = "User";
            RoleDefinition        = "Contributor";
            ScheduleInfo          = MSFT_AzureRoleAssignmentScheduleRequestSchedule {
                expiration = MSFT_AzureRoleAssignmentScheduleRequestScheduleExpiration
                    {
                        type = 'noExpiration'
                    }
            };
        }
    }
}
