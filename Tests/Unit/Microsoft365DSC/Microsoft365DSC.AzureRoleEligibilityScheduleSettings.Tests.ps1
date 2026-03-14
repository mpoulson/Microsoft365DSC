[CmdletBinding()]
param(
)
$M365DSCTestFolder = Join-Path -Path $PSScriptRoot `
                        -ChildPath '..\..\Unit' `
                        -Resolve
$CmdletModule = (Join-Path -Path $M365DSCTestFolder `
            -ChildPath '\Stubs\Microsoft365.psm1' `
            -Resolve)
$GenericStubPath = (Join-Path -Path $M365DSCTestFolder `
    -ChildPath '\Stubs\Generic.psm1' `
    -Resolve)
Import-Module -Name (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\UnitTestHelper.psm1' `
        -Resolve)

$CurrentScriptPath = $PSCommandPath.Split('\')
$CurrentScriptName = $CurrentScriptPath[$CurrentScriptPath.Length -1]
$ResourceName      = $CurrentScriptName.Split('.')[1]
$Global:DscHelper = New-M365DscUnitTestHelper -StubModule $CmdletModule `
    -DscResource $ResourceName -GenericStubModule $GenericStubPath

Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope
        BeforeAll {

            $secpasswd = ConvertTo-SecureString (New-Guid | Out-String) -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('tenantadmin@mydomain.com', $secpasswd)

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return "Credentials"
            }

            Mock -CommandName Get-MSCloudLoginConnectionProfile -MockWith {
                return @{
                    ManagementUrl = 'https://management.azure.com/'
                }
            }

            $Script:mockRules = @(
                @{
                    id = "Expiration_EndUser_Assignment"
                    ruleType = "RoleManagementPolicyExpirationRule"
                    isExpirationRequired = $true
                    maximumDuration = "PT4H"
                    target = @{ caller = "EndUser"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Enablement_EndUser_Assignment"
                    ruleType = "RoleManagementPolicyEnablementRule"
                    enabledRules = @("Justification", "Ticketing")
                    target = @{ caller = "EndUser"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Approval_EndUser_Assignment"
                    ruleType = "RoleManagementPolicyApprovalRule"
                    setting = @{
                        isApprovalRequired = $true
                        isApprovalRequiredForExtension = $false
                        isRequestorJustificationRequired = $true
                        approvalMode = "SingleStage"
                        approvalStages = @(
                            @{
                                approvalStageTimeOutInDays = 1
                                isApproverJustificationRequired = $true
                                escalationTimeInMinutes = 0
                                isEscalationEnabled = $false
                                primaryApprovers = @()
                                escalationApprovers = @()
                            }
                        )
                    }
                    target = @{ caller = "EndUser"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Expiration_Admin_Eligibility"
                    ruleType = "RoleManagementPolicyExpirationRule"
                    isExpirationRequired = $true
                    maximumDuration = "P180D"
                    target = @{ caller = "Admin"; operations = @("All"); level = "Eligibility" }
                }
                @{
                    id = "Expiration_Admin_Assignment"
                    ruleType = "RoleManagementPolicyExpirationRule"
                    isExpirationRequired = $true
                    maximumDuration = "P90D"
                    target = @{ caller = "Admin"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Enablement_Admin_Assignment"
                    ruleType = "RoleManagementPolicyEnablementRule"
                    enabledRules = @("Justification")
                    target = @{ caller = "Admin"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Enablement_Admin_Eligibility"
                    ruleType = "RoleManagementPolicyEnablementRule"
                    enabledRules = @()
                    target = @{ caller = "Admin"; operations = @("All"); level = "Eligibility" }
                }
                @{
                    id = "Notification_Admin_Admin_Eligibility"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Admin"
                    notificationLevel = "Critical"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @("eligibility-admin@contoso.com")
                    target = @{ caller = "Admin"; operations = @("All"); level = "Eligibility" }
                }
                @{
                    id = "Notification_Requestor_Admin_Eligibility"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Requestor"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @()
                    target = @{ caller = "Admin"; operations = @("All"); level = "Eligibility" }
                }
                @{
                    id = "Notification_Approver_Admin_Eligibility"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Approver"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @()
                    target = @{ caller = "Admin"; operations = @("All"); level = "Eligibility" }
                }
                @{
                    id = "Notification_Admin_Admin_Assignment"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Admin"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @("assignment-admin@contoso.com")
                    target = @{ caller = "Admin"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Notification_Requestor_Admin_Assignment"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Requestor"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @()
                    target = @{ caller = "Admin"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Notification_Approver_Admin_Assignment"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Approver"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @()
                    target = @{ caller = "Admin"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Notification_Admin_EndUser_Assignment"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Admin"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @("admin@contoso.com")
                    target = @{ caller = "EndUser"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Notification_Requestor_EndUser_Assignment"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Requestor"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @()
                    target = @{ caller = "EndUser"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "Notification_Approver_EndUser_Assignment"
                    ruleType = "RoleManagementPolicyNotificationRule"
                    notificationType = "Email"; recipientType = "Approver"
                    notificationLevel = "All"
                    isDefaultRecipientsEnabled = $true
                    notificationRecipients = @()
                    target = @{ caller = "EndUser"; operations = @("All"); level = "Assignment" }
                }
                @{
                    id = "AuthenticationContext_EndUser_Assignment"
                    ruleType = "RoleManagementPolicyAuthenticationContextRule"
                    isEnabled = $false
                    claimValue = ""
                    target = @{ caller = "EndUser"; operations = @("All"); level = "Assignment" }
                }
            )

            Mock -CommandName Invoke-AzRest -MockWith {
                return @{
                    Content = ConvertTo-Json (@{
                        value = @(
                            @{
                                id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicyAssignments/test_assignment"
                                properties = @{
                                    roleDefinitionId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000001"
                                    policyId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicies/test_policy_id"
                                    roleDefinitionDisplayName = "Owner"
                                    policyAssignmentProperties = @{
                                        roleDefinition = @{
                                            displayName = "Owner"
                                        }
                                    }
                                }
                            }
                        )
                        properties = @{
                            rules = $Script:mockRules
                        }
                    }) -Depth 20
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstance = $null
            $Script:ExportMode = $false
        }

        Context -Name "The activation settings are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    ActivationMaxDuration     = "PT4H"
                    ActivationReqJustification = $true
                    ActivationReqTicket       = $true
                    ActivationReqMFA          = $false
                    ApprovaltoActivate        = $true
                    ActivateApprover          = @()
                    Credential                = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The activation settings are NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    ActivationMaxDuration     = "PT8H" # drift
                    ActivationReqJustification = $true
                    ActivationReqTicket       = $true
                    ActivationReqMFA          = $false
                    Credential                = $Credential;
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                { Set-TargetResource @testParams } | Should -Not -Throw
            }
        }

        Context -Name "The eligible assignment notification is already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                    = "Owner"
                    Scope                                        = "subscriptions/00000000-0000-0000-0000-000000000000"
                    EligibleAlertNotificationDefaultRecipient    = $true
                    EligibleAlertNotificationAdditionalRecipient = @("eligibility-admin@contoso.com")
                    EligibleAlertNotificationOnlyCritical        = $true
                    Credential                                   = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The eligible assignment notification is NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                    = "Owner"
                    Scope                                        = "subscriptions/00000000-0000-0000-0000-000000000000"
                    EligibleAlertNotificationDefaultRecipient    = $false # drift
                    EligibleAlertNotificationAdditionalRecipient = @("eligibility-admin@contoso.com")
                    EligibleAlertNotificationOnlyCritical        = $true
                    Credential                                   = $Credential;
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                { Set-TargetResource @testParams } | Should -Not -Throw
            }
        }

        Context -Name "The activation alert notification is already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                       = "Owner"
                    Scope                                           = "subscriptions/00000000-0000-0000-0000-000000000000"
                    ActivationAlertNotificationDefaultRecipient     = $true
                    ActivationAlertNotificationAdditionalRecipient  = @("admin@contoso.com")
                    ActivationAlertNotificationOnlyCritical         = $false
                    Credential                                      = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The expiration settings for eligible assignments are in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                       = "Owner"
                    Scope                                           = "subscriptions/00000000-0000-0000-0000-000000000000"
                    PermanentEligibleAssignmentisExpirationRequired = $true
                    ExpireEligibleAssignment                        = "P180D"
                    Credential                                      = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The expiration settings for eligible assignments are NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                       = "Owner"
                    Scope                                           = "subscriptions/00000000-0000-0000-0000-000000000000"
                    PermanentEligibleAssignmentisExpirationRequired = $false # drift
                    ExpireEligibleAssignment                        = "P180D"
                    Credential                                      = $Credential;
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }
        }

        Context -Name "The enablement rule for active assignment is in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    AssignmentReqMFA          = $false
                    AssignmentReqJustification = $true
                    Credential                = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The enablement rule for active assignment is NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    AssignmentReqMFA          = $true # drift
                    AssignmentReqJustification = $true
                    Credential                = $Credential;
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                { Set-TargetResource @testParams } | Should -Not -Throw
            }
        }

        Context -Name "The approval settings with ServicePrincipal approver are in the desired state" -Fixture {
            BeforeAll {
                $Script:mockRulesWithSPApprover = $Script:mockRules | ForEach-Object {
                    if ($_.id -eq 'Approval_EndUser_Assignment')
                    {
                        @{
                            id = $_.id
                            ruleType = $_.ruleType
                            setting = @{
                                isApprovalRequired = $true
                                isApprovalRequiredForExtension = $false
                                isRequestorJustificationRequired = $true
                                approvalMode = "SingleStage"
                                approvalStages = @(
                                    @{
                                        approvalStageTimeOutInDays = 1
                                        isApproverJustificationRequired = $true
                                        escalationTimeInMinutes = 0
                                        isEscalationEnabled = $false
                                        primaryApprovers = @(
                                            @{
                                                id = "11111111-1111-1111-1111-111111111111"
                                                userType = "ServicePrincipal"
                                                isBackup = $false
                                            }
                                        )
                                        escalationApprovers = @()
                                    }
                                )
                            }
                            target = $_.target
                        }
                    }
                    else
                    {
                        $_
                    }
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicyAssignments/test_assignment"
                                    properties = @{
                                        roleDefinitionId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000001"
                                        policyId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicies/test_policy_id"
                                        roleDefinitionDisplayName = "Owner"
                                        policyAssignmentProperties = @{
                                            roleDefinition = @{
                                                displayName = "Owner"
                                            }
                                        }
                                    }
                                }
                            )
                            properties = @{
                                rules = $Script:mockRulesWithSPApprover
                            }
                        }) -Depth 20
                    }
                }

                $testParams = @{
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    ApprovaltoActivate        = $true
                    ActivateApprover          = @("ServicePrincipal:11111111-1111-1111-1111-111111111111")
                    Credential                = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }

            It 'Should return the ServicePrincipal approver with type prefix from the Get method' {
                $result = Get-TargetResource @testParams
                $result.ActivateApprover | Should -Contain "ServicePrincipal:11111111-1111-1111-1111-111111111111"
            }
        }

        Context -Name "The approval settings with mixed approver types should call Set without error" -Fixture {
            BeforeAll {
                $Script:mockRulesWithMixedApprovers = $Script:mockRules | ForEach-Object {
                    if ($_.id -eq 'Approval_EndUser_Assignment')
                    {
                        @{
                            id = $_.id
                            ruleType = $_.ruleType
                            setting = @{
                                isApprovalRequired = $true
                                isApprovalRequiredForExtension = $false
                                isRequestorJustificationRequired = $true
                                approvalMode = "SingleStage"
                                approvalStages = @(
                                    @{
                                        approvalStageTimeOutInDays = 1
                                        isApproverJustificationRequired = $true
                                        escalationTimeInMinutes = 0
                                        isEscalationEnabled = $false
                                        primaryApprovers = @(
                                            @{
                                                id = "22222222-2222-2222-2222-222222222222"
                                                userType = "User"
                                                isBackup = $false
                                            },
                                            @{
                                                id = "33333333-3333-3333-3333-333333333333"
                                                userType = "Group"
                                                isBackup = $false
                                            },
                                            @{
                                                id = "44444444-4444-4444-4444-444444444444"
                                                userType = "ServicePrincipal"
                                                isBackup = $false
                                            }
                                        )
                                        escalationApprovers = @()
                                    }
                                )
                            }
                            target = $_.target
                        }
                    }
                    else
                    {
                        $_
                    }
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicyAssignments/test_assignment"
                                    properties = @{
                                        roleDefinitionId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000001"
                                        policyId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicies/test_policy_id"
                                        roleDefinitionDisplayName = "Owner"
                                        policyAssignmentProperties = @{
                                            roleDefinition = @{
                                                displayName = "Owner"
                                            }
                                        }
                                    }
                                }
                            )
                            properties = @{
                                rules = $Script:mockRulesWithMixedApprovers
                            }
                        }) -Depth 20
                    }
                }

                $testParams = @{
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    ApprovaltoActivate        = $true
                    ActivateApprover          = @("User:22222222-2222-2222-2222-222222222222", "Group:33333333-3333-3333-3333-333333333333", "ServicePrincipal:44444444-4444-4444-4444-444444444444")
                    Credential                = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }

            It 'Should call the Set method without error' {
                { Set-TargetResource @testParams } | Should -Not -Throw
            }

            It 'Should return all approvers with correct type prefixes from the Get method' {
                $result = Get-TargetResource @testParams
                $result.ActivateApprover | Should -HaveCount 3
                $result.ActivateApprover | Should -Contain "User:22222222-2222-2222-2222-222222222222"
                $result.ActivateApprover | Should -Contain "Group:33333333-3333-3333-3333-333333333333"
                $result.ActivateApprover | Should -Contain "ServicePrincipal:44444444-4444-4444-4444-444444444444"
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    subscriptionId = "00000000-0000-0000-0000-000000000000"
                                    displayName = "TestSubscription"
                                }
                            )
                        }) -Depth 10
                    }
                } -ParameterFilter { $Uri -like "*subscriptions?*" }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        Content = ConvertTo-Json (@{
                            value = @()
                        }) -Depth 10
                    }
                } -ParameterFilter { $Uri -like "*resourcegroups*" }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        Content = ConvertTo-Json (@{
                            value = @()
                        }) -Depth 10
                    }
                } -ParameterFilter { $Uri -like "*managementGroups*" }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicyAssignments/test_assignment"
                                    properties = @{
                                        roleDefinitionId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000001"
                                        policyId = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicies/test_policy_id"
                                        policyAssignmentProperties = @{
                                            roleDefinition = @{
                                                displayName = "Owner"
                                            }
                                        }
                                    }
                                }
                            )
                        }) -Depth 10
                    }
                } -ParameterFilter { $Uri -like "*roleManagementPolicyAssignments*" }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        Content = ConvertTo-Json (@{
                            properties = @{
                                rules = $Script:mockRules
                            }
                        }) -Depth 20
                    }
                } -ParameterFilter { $Uri -like "*roleManagementPolicies/*" }
            }

            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
