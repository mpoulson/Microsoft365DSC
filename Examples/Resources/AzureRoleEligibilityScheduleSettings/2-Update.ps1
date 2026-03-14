<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.
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
        AzureRoleEligibilityScheduleSettings "Owner-Expiration_EndUser_Assignment"
        {
            ExpirationRule            = MSFT_AADRoleManagementPolicyExpirationRule{
                isExpirationRequired = $True
                maximumDuration = 'PT4H'
            };
            Id                        = "Expiration_EndUser_Assignment";
            RoleDefinitionDisplayName = "Owner";
            Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000";
            RuleType                  = "RoleManagementPolicyExpirationRule";
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            CertificateThumbprint     = $CertificateThumbprint
        }

        AzureRoleEligibilityScheduleSettings "Owner-Enablement_EndUser_Assignment"
        {
            EnablementRule            = MSFT_AADRoleManagementPolicyEnablementRule{
                enabledRules = @("Justification", "Ticketing")
            };
            Id                        = "Enablement_EndUser_Assignment";
            RoleDefinitionDisplayName = "Owner";
            Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000";
            RuleType                  = "RoleManagementPolicyEnablementRule";
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            CertificateThumbprint     = $CertificateThumbprint
        }

        AzureRoleEligibilityScheduleSettings "Owner-Approval_EndUser_Assignment"
        {
            ApprovalRule              = MSFT_AADRoleManagementPolicyApprovalRule{
                setting = MSFT_AADRoleManagementPolicyApprovalSettings{
                    isApprovalRequired = $True
                    isApprovalRequiredForExtension = $False
                    isRequestorJustificationRequired = $True
                    approvalMode = "SingleStage"
                    approvalStages = @(
                        MSFT_AADRoleManagementPolicyApprovalStage{
                            approvalStageTimeOutInDays = 1
                            isApproverJustificationRequired = $True
                            escalationTimeInMinutes = 0
                            isEscalationEnabled = $False
                        }
                    )
                }
            };
            Id                        = "Approval_EndUser_Assignment";
            RoleDefinitionDisplayName = "Owner";
            Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000";
            RuleType                  = "RoleManagementPolicyApprovalRule";
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            CertificateThumbprint     = $CertificateThumbprint
        }

        AzureRoleEligibilityScheduleSettings "Owner-Notification_Admin_EndUser_Assignment"
        {
            NotificationRule          = MSFT_AADRoleManagementPolicyNotificationRule{
                notificationType = "Email"
                recipientType = "Admin"
                notificationLevel = "All"
                isDefaultRecipientsEnabled = $True
                notificationRecipients = @("admin@contoso.com")
            };
            Id                        = "Notification_Admin_EndUser_Assignment";
            RoleDefinitionDisplayName = "Owner";
            Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000";
            RuleType                  = "RoleManagementPolicyNotificationRule";
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            CertificateThumbprint     = $CertificateThumbprint
        }

        AzureRoleEligibilityScheduleSettings "Owner-Notification_Admin_Admin_Eligibility"
        {
            NotificationRule          = MSFT_AADRoleManagementPolicyNotificationRule{
                notificationType = "Email"
                recipientType = "Admin"
                notificationLevel = "Critical"
                isDefaultRecipientsEnabled = $True
                notificationRecipients = @("eligibility-admin@contoso.com")
            };
            Id                        = "Notification_Admin_Admin_Eligibility";
            RoleDefinitionDisplayName = "Owner";
            Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000";
            RuleType                  = "RoleManagementPolicyNotificationRule";
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            CertificateThumbprint     = $CertificateThumbprint
        }

        AzureRoleEligibilityScheduleSettings "Owner-Notification_Admin_Admin_Assignment"
        {
            NotificationRule          = MSFT_AADRoleManagementPolicyNotificationRule{
                notificationType = "Email"
                recipientType = "Admin"
                notificationLevel = "All"
                isDefaultRecipientsEnabled = $True
                notificationRecipients = @("assignment-admin@contoso.com")
            };
            Id                        = "Notification_Admin_Admin_Assignment";
            RoleDefinitionDisplayName = "Owner";
            Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000";
            RuleType                  = "RoleManagementPolicyNotificationRule";
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            CertificateThumbprint     = $CertificateThumbprint
        }
    }
}
