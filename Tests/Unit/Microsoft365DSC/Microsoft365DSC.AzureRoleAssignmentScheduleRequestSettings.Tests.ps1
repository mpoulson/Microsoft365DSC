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
                return 'Credentials'
            }

            Mock -CommandName Get-MSCloudLoginConnectionProfile -MockWith {
                return @{
                    ManagementUrl = 'https://management.usgovcloudapi.net/'
                }
            }

            Mock -CommandName Invoke-AzRestMethod -MockWith {
                return @{
                    StatusCode = 200
                    Content    = '{}'
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }

            # The policy that every Context reads back. It carries the eligibility, active assignment and
            # activation rule families so the tests can prove the resource only rewrites the active ones.
            $Script:policyContent = @'
{
    "name": "policy-owner",
    "properties": {
        "lastModifiedDateTime": "2026-01-15T00:00:00Z",
        "rules": [
            {
                "id": "Expiration_Admin_Eligibility",
                "ruleType": "RoleManagementPolicyExpirationRule",
                "isExpirationRequired": false,
                "maximumDuration": "P365D",
                "target": { "caller": "Admin" }
            },
            {
                "id": "Expiration_Admin_Assignment",
                "ruleType": "RoleManagementPolicyExpirationRule",
                "isExpirationRequired": true,
                "maximumDuration": "P90D",
                "target": { "caller": "Admin" }
            },
            {
                "id": "Enablement_Admin_Assignment",
                "ruleType": "RoleManagementPolicyEnablementRule",
                "enabledRules": [ "Justification", "MultiFactorAuthentication" ],
                "target": { "caller": "Admin" }
            },
            {
                "id": "Enablement_EndUser_Assignment",
                "ruleType": "RoleManagementPolicyEnablementRule",
                "enabledRules": [ "Justification" ],
                "target": { "caller": "EndUser" }
            },
            {
                "id": "Notification_Admin_Admin_Assignment",
                "ruleType": "RoleManagementPolicyNotificationRule",
                "notificationType": "Email",
                "recipientType": "Admin",
                "notificationLevel": "All",
                "isDefaultRecipientsEnabled": true,
                "notificationRecipients": [ "assignment-admin@contoso.com" ],
                "target": { "caller": "Admin" }
            },
            {
                "id": "Notification_Requestor_Admin_Assignment",
                "ruleType": "RoleManagementPolicyNotificationRule",
                "notificationType": "Email",
                "recipientType": "Requestor",
                "notificationLevel": "All",
                "isDefaultRecipientsEnabled": true,
                "notificationRecipients": [],
                "target": { "caller": "Admin" }
            },
            {
                "id": "Notification_Approver_Admin_Assignment",
                "ruleType": "RoleManagementPolicyNotificationRule",
                "notificationType": "Email",
                "recipientType": "Approver",
                "notificationLevel": "Critical",
                "isDefaultRecipientsEnabled": false,
                "notificationRecipients": [],
                "target": { "caller": "Admin" }
            },
            {
                "id": "Notification_Admin_EndUser_Assignment",
                "ruleType": "RoleManagementPolicyNotificationRule",
                "notificationType": "Email",
                "recipientType": "Admin",
                "notificationLevel": "All",
                "isDefaultRecipientsEnabled": true,
                "notificationRecipients": [],
                "target": { "caller": "EndUser" }
            }
        ]
    }
}
'@

            $Script:assignmentsContent = @'
{
    "value": [
        {
            "name": "assignment-owner",
            "properties": {
                "policyId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicies/policy-owner",
                "roleDefinitionId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-1111-1111-1111-111111111111",
                "policyAssignmentProperties": {
                    "roleDefinition": {
                        "id": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-1111-1111-1111-111111111111",
                        "displayName": "Owner"
                    }
                }
            }
        }
    ]
}
'@

            # The resource reaches ARM through three shaped GETs: the policy assignment list, the single policy,
            # and (only when the display name is missing) the role definition list. One mock answers by uri.
            $Script:standardRestMock = {
                if ($Uri -like '*roleManagementPolicyAssignments*')
                {
                    return @{
                        StatusCode = 200
                        Content    = $Script:assignmentsContent
                    }
                }
                if ($Uri -like '*roleManagementPolicies*')
                {
                    return @{
                        StatusCode = 200
                        Content    = $Script:policyContent
                    }
                }
                return @{
                    StatusCode = 200
                    Content    = '{"value":[]}'
                }
            }

            $Script:exportedInstance = $null
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        # Test contexts
        Context -Name 'The policy values are already in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                     = 'Owner'
                    ScopeId                                       = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    PermanentActiveAssignmentisExpirationRequired = $True
                    ExpireActiveAssignment                        = 'P90D'
                    AssignmentReqMFA                              = $True
                    AssignmentReqJustification                    = $True
                    ActiveAlertNotificationDefaultRecipient       = $True
                    ActiveAlertNotificationAdditionalRecipient    = @('assignment-admin@contoso.com')
                    ActiveAlertNotificationOnlyCritical           = $False
                    ActiveAssigneeNotificationDefaultRecipient    = $True
                    ActiveAssigneeNotificationAdditionalRecipient = @()
                    ActiveAssigneeNotificationOnlyCritical        = $False
                    ActiveApproveNotificationDefaultRecipient     = $False
                    ActiveApproveNotificationAdditionalRecipient  = @()
                    ActiveApproveNotificationOnlyCritical         = $True
                    Credential                                    = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $Script:standardRestMock
            }

            It 'Should return the active assignment settings from the Get method' {
                $result = Get-TargetResource @testParams
                $result.PermanentActiveAssignmentisExpirationRequired | Should -Be $True
                $result.ExpireActiveAssignment | Should -Be 'P90D'
                $result.AssignmentReqMFA | Should -Be $True
                $result.AssignmentReqJustification | Should -Be $True
            }

            It 'Should resolve the policy id from the assignment' {
                (Get-TargetResource @testParams).PolicyId | Should -Be 'policy-owner'
            }

            It 'Should translate a Critical notification level into OnlyCritical' {
                $result = Get-TargetResource @testParams
                $result.ActiveApproveNotificationOnlyCritical | Should -Be $True
                $result.ActiveAlertNotificationOnlyCritical | Should -Be $False
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'The expiration settings are NOT in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                     = 'Owner'
                    ScopeId                                       = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    PermanentActiveAssignmentisExpirationRequired = $True
                    ExpireActiveAssignment                        = 'P30D'
                    Credential                                    = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $Script:standardRestMock
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should PATCH the policy with the new maximum duration' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PATCH' -and $Payload -like '*P30D*'
                } -Exactly 1
            }
        }

        Context -Name 'Only one half of the expiration pair is supplied' -Fixture {
            BeforeAll {
                # Azure rejects a rule that requires expiration without a maximum duration, so the resource
                # deliberately leaves the expiration rule alone unless both properties are present.
                $testParams = @{
                    RoleDefinitionDisplayName                     = 'Owner'
                    ScopeId                                       = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    PermanentActiveAssignmentisExpirationRequired = $False
                    Credential                                    = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $Script:standardRestMock
            }

            It 'Should not issue a PATCH' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Method -eq 'PATCH' } -Exactly 0
            }
        }

        Context -Name 'The MFA requirement is turned off' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = 'Owner'
                    ScopeId                   = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    AssignmentReqMFA          = $False
                    Credential                = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $Script:standardRestMock
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should keep the justification requirement that was not specified' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PATCH' -and
                    $Payload -like '*"Enablement_Admin_Assignment"*' -and
                    $Payload -like '*Justification*'
                } -Exactly 1
            }
        }

        Context -Name 'A notification recipient list is changed' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName                  = 'Owner'
                    ScopeId                                    = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    ActiveAlertNotificationAdditionalRecipient = @('pim-alerts@contoso.com')
                    Credential                                 = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $Script:standardRestMock
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should PATCH the admin notification rule with the new recipient' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PATCH' -and
                    $Payload -like '*pim-alerts@contoso.com*' -and
                    $Payload -like '*"recipientType":"Admin"*'
                } -Exactly 1
            }

            It 'Should carry over the notification level that was not specified' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PATCH' -and $Payload -like '*"notificationLevel":"All"*'
                } -Exactly 1
            }
        }

        Context -Name 'Rules outside the active assignment families are left alone' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName           = 'Owner'
                    ScopeId                             = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    ActiveAlertNotificationOnlyCritical = $True
                    Credential                          = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $Script:standardRestMock
            }

            It 'Should write back the eligibility and activation rules unchanged' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PATCH' -and
                    $Payload -like '*Expiration_Admin_Eligibility*' -and
                    $Payload -like '*Enablement_EndUser_Assignment*' -and
                    $Payload -like '*Notification_Admin_EndUser_Assignment*'
                } -Exactly 1
            }
        }

        Context -Name 'Nothing mutable is supplied' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = 'Owner'
                    ScopeId                   = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    Credential                = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $Script:standardRestMock
            }

            It 'Should not issue a PATCH' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Method -eq 'PATCH' } -Exactly 0
            }
        }

        Context -Name 'The role has no policy assignment at the scope' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = 'Owner'
                    ScopeId                   = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    AssignmentReqMFA          = $True
                    Credential                = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith {
                    return @{
                        StatusCode = 200
                        Content    = '{"value":[]}'
                    }
                }
            }

            It 'Should not report a policy id from the Get method' {
                (Get-TargetResource @testParams).PolicyId | Should -BeNullOrEmpty
            }

            It 'Should throw from the Set method rather than PATCH nothing' {
                { Set-TargetResource @testParams } | Should -Throw
            }
        }

        Context -Name 'The display name is only resolvable through the role definition list' -Fixture {
            BeforeAll {
                $testParams = @{
                    RoleDefinitionDisplayName = 'Owner'
                    ScopeId                   = 'subscriptions/00000000-0000-0000-0000-000000000000'
                    Credential                = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith {
                    if ($Uri -like '*roleManagementPolicyAssignments*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = @'
{
    "value": [
        {
            "name": "assignment-owner",
            "properties": {
                "policyId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleManagementPolicies/policy-owner",
                "roleDefinitionId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-1111-1111-1111-111111111111"
            }
        }
    ]
}
'@
                        }
                    }
                    if ($Uri -like '*roleDefinitions*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = @'
{
    "value": [
        {
            "id": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-1111-1111-1111-111111111111",
            "properties": { "roleName": "Owner" }
        }
    ]
}
'@
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = $Script:policyContent
                    }
                }
            }

            It 'Should fall back to a filtered role definition lookup' {
                (Get-TargetResource @testParams).PolicyId | Should -Be 'policy-owner'
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Uri -like "*roleDefinitions*roleName eq 'Owner'*"
                }
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith {
                    if ($Uri -like '*subscriptions?api-version*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value":[{"subscriptionId":"00000000-0000-0000-0000-000000000000","displayName":"Test"}]}'
                        }
                    }
                    if ($Uri -like '*resourcegroups*' -or $Uri -like '*managementGroups*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value":[]}'
                        }
                    }
                    if ($Uri -like '*roleManagementPolicyAssignments*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = $Script:assignmentsContent
                        }
                    }
                    if ($Uri -like '*roleManagementPolicies?api-version*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = "{`"value`":[$Script:policyContent]}"
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = '{"value":[]}'
                    }
                }
            }

            AfterAll {
                $Script:exportedInstance = $null
            }

            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Should bulk-fetch the policies for the scope rather than reading them one at a time' {
                $null = Export-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Uri -like '*roleManagementPolicies?api-version*'
                }
            }

            It 'Should skip unmodified policies when the ModifiedOnly filter is supplied' {
                Mock -CommandName Invoke-AzRestMethod -MockWith {
                    if ($Uri -like '*subscriptions?api-version*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value":[{"subscriptionId":"00000000-0000-0000-0000-000000000000","displayName":"Test"}]}'
                        }
                    }
                    if ($Uri -like '*roleManagementPolicyAssignments*')
                    {
                        return @{
                            StatusCode = 200
                            Content    = $Script:assignmentsContent
                        }
                    }
                    if ($Uri -like '*roleManagementPolicies?api-version*')
                    {
                        # lastModifiedDateTime null means the policy still carries Azure defaults.
                        return @{
                            StatusCode = 200
                            Content    = '{"value":[{"name":"policy-owner","properties":{"lastModifiedDateTime":null,"rules":[]}}]}'
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = '{"value":[]}'
                    }
                }

                $result = Export-TargetResource @testParams -Filter 'ModifiedOnly'
                $result | Should -BeNullOrEmpty
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
