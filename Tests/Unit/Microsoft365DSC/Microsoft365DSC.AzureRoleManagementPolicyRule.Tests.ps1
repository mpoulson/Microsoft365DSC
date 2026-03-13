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
                            rules = @(
                                @{
                                    id = "Expiration_EndUser_Assignment"
                                    ruleType = "RoleManagementPolicyExpirationRule"
                                    isExpirationRequired = $true
                                    maximumDuration = "PT4H"
                                    target = @{
                                        caller = "EndUser"
                                        operations = @("All")
                                        level = "Assignment"
                                    }
                                }
                                @{
                                    id = "Enablement_EndUser_Assignment"
                                    ruleType = "RoleManagementPolicyEnablementRule"
                                    enabledRules = @("Justification", "Ticketing")
                                    target = @{
                                        caller = "EndUser"
                                        operations = @("All")
                                        level = "Assignment"
                                    }
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
                                    target = @{
                                        caller = "EndUser"
                                        operations = @("All")
                                        level = "Assignment"
                                    }
                                }
                            )
                        }
                    }) -Depth 20
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        Context -Name "The AzureRoleManagementPolicyRule Exists and Values are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                        = "Expiration_EndUser_Assignment"
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    RuleType                  = "RoleManagementPolicyExpirationRule"
                    ExpirationRule            = (New-CimInstance -ClassName MSFT_AADRoleManagementPolicyExpirationRule -Property @{
                        isExpirationRequired = $true
                        maximumDuration      = "PT4H"
                    } -ClientOnly)
                    Credential                = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The AzureRoleManagementPolicyRule exists and values are NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                        = "Expiration_EndUser_Assignment"
                    RoleDefinitionDisplayName = "Owner"
                    Scope                     = "subscriptions/00000000-0000-0000-0000-000000000000"
                    RuleType                  = "RoleManagementPolicyExpirationRule"
                    ExpirationRule            = (New-CimInstance -ClassName MSFT_AADRoleManagementPolicyExpirationRule -Property @{
                        isExpirationRequired = $true
                        maximumDuration      = "PT8H" # drift
                    } -ClientOnly)
                    Credential                = $Credential;
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRest -Exactly 3
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
                                rules = @(
                                    @{
                                        id = "Expiration_EndUser_Assignment"
                                        ruleType = "RoleManagementPolicyExpirationRule"
                                        isExpirationRequired = $true
                                        maximumDuration = "PT4H"
                                    }
                                )
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
