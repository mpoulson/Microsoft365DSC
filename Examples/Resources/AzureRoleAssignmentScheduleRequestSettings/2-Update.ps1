<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.

Do not also declare AzureRoleEligibilityScheduleSettings for the same role and scope. Both resources
write the same Azure role management policy, so a shared property set in both places will flap.
#>

Configuration Example
{
    param(
        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        AzureRoleAssignmentScheduleRequestSettings "Owner-SubscriptionActiveAssignmentSettings"
        {
            RoleDefinitionDisplayName                     = "Owner"
            ScopeId                                       = "subscriptions/00000000-0000-0000-0000-000000000000"
            PermanentActiveAssignmentisExpirationRequired = $True
            ExpireActiveAssignment                        = "P90D"
            AssignmentReqMFA                              = $True
            AssignmentReqJustification                    = $True
            ActiveAlertNotificationDefaultRecipient       = $True
            ActiveAlertNotificationAdditionalRecipient    = @("assignment-admin@contoso.com")
            ActiveAlertNotificationOnlyCritical           = $False
            ActiveAssigneeNotificationDefaultRecipient    = $True
            ActiveAssigneeNotificationAdditionalRecipient = @()
            ActiveAssigneeNotificationOnlyCritical        = $False
            ActiveApproveNotificationDefaultRecipient     = $True
            ActiveApproveNotificationAdditionalRecipient  = @()
            ActiveApproveNotificationOnlyCritical         = $False
            ApplicationId                                 = $ApplicationId
            TenantId                                      = $TenantId
            CertificateThumbprint                         = $CertificateThumbprint
        }
    }
}
