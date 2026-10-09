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

            Mock -CommandName New-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
            }

            Mock -CommandName Remove-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
            }

            Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                return @{
                    value = @(
                        @{
                            id = '/assignment/22222-22222-22222-22222-22222'
                            properties = @{
                                principalId = '12345-12345-12345-12345-12345'
                                principalType = 'User'
                                RoleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/1e5b9e50-a1ea-581e-fb3a-778b93a06854:6487d5cf-0a7b-42e6-9549-23ca416fb8bf_2019-05-31/billingRoleDefinitions/22222-22222-22222-22222-22222'
                                principalTenantId = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                            }
                        }
                    )
                }
            }

            # The real helper answers two different shapes: the whole collection under 'value' when no
            # RoleDefinitionId is supplied, and a single definition when one is. Enterprise Agreement returns
            # some definitions with no friendly roleName, which is what 'EaRoleId_...' below stands in for.
            Mock -CommandName Get-M365DSCAzureBillingAccountsRoleDefinition -MockWith {
                $definitions = @(
                    @{
                        id         = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/22222-22222-22222-22222-22222'
                        name       = '22222-22222-22222-22222-22222'
                        properties = @{
                            roleName = 'Billing account owner'
                        }
                    }
                    @{
                        id         = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/33333-33333-33333-33333-33333'
                        name       = '33333-33333-33333-33333-33333'
                        properties = @{
                            roleName = 'Billing account reader'
                        }
                    }
                    @{
                        id         = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/EaRoleId_44444-44444-44444-44444-44444'
                        name       = 'EaRoleId_44444-44444-44444-44444-44444'
                        properties = @{
                        }
                    }
                )

                if ([System.String]::IsNullOrEmpty($RoleDefinitionId))
                {
                    return @{
                        value = $definitions
                    }
                }
                return ($definitions | Where-Object -FilterScript { $_.name -eq $RoleDefinitionId })
            }

            Mock -CommandName Get-M365DSCAzureBillingAccount -MockWith {
                return @{
                    value = @(
                        @{
                            name = "12345-12345-12345-12345-12345"
                            properties = @{
                                displayName = 'MyBillingAccount'
                            }
                        }
                    )
                }
            }

            Mock -CommandName Get-MgUser -MockWith {
                return @(
                    @{
                        id = '12345-12345-12345-12345-12345'
                        UserPrincipalName = 'John.Smith@Contoso.com'
                    }
                )
            }

            Mock -CommandName Get-MgServicePrincipal -MockWith {
                return $null
            }

            Mock -CommandName Get-MgGroup -MockWith {
                return $null
            }

            # The principal tenant identifier now comes from the TenantId the caller was already given.
            # Mocked so that the contexts below can assert it is never consulted.
            Mock -CommandName Get-MgContext -MockWith {
                return @{
                    TenantId = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances =$null
            $Script:ExportMode = $false
        }
        # Test contexts
        Context -Name "The instance should exist but it DOES NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    BillingAccount        = "MyBillingAccount";
                    PrincipalName         = "John.Smith@contoso.onmicrosoft.com";
                    PrincipalType         = "User";
                    PrincipalTenantId     = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                    RoleDefinition        = "Billing account owner";
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential;
                }

                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return $null
                }
            }
            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should create a new instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName New-M365DSCAzureBillingAccountsRoleAssignment -Exactly 1
            }
        }

        Context -Name "The instance exists but it SHOULD NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    BillingAccount        = "MyBillingAccount";
                    PrincipalName         = "John.Smith@contoso.onmicrosoft.com";
                    PrincipalType         = "User";
                    PrincipalTenantId     = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                    RoleDefinition        = "Billing account owner";
                    Ensure                = 'Absent'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential;
                }
            }
            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should remove the instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Remove-M365DSCAzureBillingAccountsRoleAssignment -Exactly 1
            }
        }

        Context -Name "The instance exists and values are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    BillingAccount        = "MyBillingAccount";
                    PrincipalName         = "John.Smith@contoso.onmicrosoft.com";
                    PrincipalType         = "User";
                    PrincipalTenantId     = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                    RoleDefinition        = "Billing account owner";
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "An Enterprise Agreement assignment that reports no principalType" -Fixture {
            BeforeAll {
                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return @{
                        value = @(
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/55555-55555-55555-55555-55555'
                                name = '55555-55555-55555-55555-55555'
                                properties = @{
                                    principalId = '12345-12345-12345-12345-12345'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/22222-22222-22222-22222-22222'
                                    principalTenantId = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                                }
                            }
                        )
                    }
                }

                $assignment = @{
                    name = '55555-55555-55555-55555-55555'
                    properties = @{
                        principalId = '12345-12345-12345-12345-12345'
                        principalTenantId = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                    }
                }
            }

            It 'Should resolve the principal as a user by probing the directory' {
                $principal = Get-M365DSCAzureBillingPrincipal -Assignment $assignment `
                    -TenantId '00000000-0000-0000-0000-000000000000'
                $principal.Type | Should -Be 'User'
                $principal.Name | Should -Be 'John.Smith@Contoso.com'
            }

            It 'Should keep the principal tenant reported by the billing plane' {
                $principal = Get-M365DSCAzureBillingPrincipal -Assignment $assignment `
                    -TenantId '00000000-0000-0000-0000-000000000000'
                $principal.TenantId | Should -Be '9c888910-6b3b-4c17-8cff-844fefb026d4'
            }

            It 'Should resolve the principal as a service principal when it is not a user' {
                Mock -CommandName Get-MgUser -MockWith {
                    throw 'Resource 12345-12345-12345-12345-12345 does not exist.'
                }
                Mock -CommandName Get-MgServicePrincipal -MockWith {
                    return @{
                        Id = '12345-12345-12345-12345-12345'
                        DisplayName = 'MyWorkerApp'
                    }
                }

                $principal = Get-M365DSCAzureBillingPrincipal -Assignment $assignment `
                    -TenantId '00000000-0000-0000-0000-000000000000'
                $principal.Type | Should -Be 'ServicePrincipal'
                $principal.Name | Should -Be 'MyWorkerApp'
            }

            It 'Should resolve the principal as a group when it is neither a user nor a service principal' {
                Mock -CommandName Get-MgUser -MockWith {
                    throw 'Resource 12345-12345-12345-12345-12345 does not exist.'
                }
                Mock -CommandName Get-MgServicePrincipal -MockWith {
                    throw 'Resource 12345-12345-12345-12345-12345 does not exist.'
                }
                Mock -CommandName Get-MgGroup -MockWith {
                    return @{
                        Id = '12345-12345-12345-12345-12345'
                        DisplayName = 'sg-billing-owners'
                    }
                }

                $principal = Get-M365DSCAzureBillingPrincipal -Assignment $assignment `
                    -TenantId '00000000-0000-0000-0000-000000000000'
                $principal.Type | Should -Be 'Group'
                $principal.Name | Should -Be 'sg-billing-owners'
            }

            It 'Should never fall back to the connected Graph context for the tenant identifier' {
                $null = Get-M365DSCAzureBillingPrincipal -Assignment $assignment `
                    -TenantId '00000000-0000-0000-0000-000000000000'
                Should -Invoke -CommandName Get-MgContext -Exactly 0
            }
        }

        Context -Name "A legacy Enterprise Agreement enrollment administrator identified only by email" -Fixture {
            BeforeAll {
                $testParams = @{
                    BillingAccount        = "MyBillingAccount";
                    PrincipalName         = "ea.admin@fabrikam.com";
                    PrincipalType         = "User";
                    PrincipalTenantId     = '7b4d2e18-3c5f-4a91-9d0e-1f2a3b4c5d6e'
                    RoleDefinition        = "EaRoleId_44444-44444-44444-44444-44444";
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential;
                }

                # No principalId and no principalTenantId, which is how the Enterprise Agreement portal
                # records an enrollment administrator invited by email address.
                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return @{
                        value = @(
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/99999-99999-99999-99999-99999'
                                name = '99999-99999-99999-99999-99999'
                                properties = @{
                                    principalPuid = '100320012F3A1B2C'
                                    userEmailAddress = 'ea.admin@fabrikam.com'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/EaRoleId_44444-44444-44444-44444-44444'
                                }
                            }
                        )
                    }
                }

                # The invited address is frequently external and has no object in the directory.
                Mock -CommandName Get-MgUser -MockWith {
                    return $null
                }
            }

            It 'Should report the assignment as Present by matching on the email address' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should fall back to the supplied PrincipalTenantId when the billing plane reports none' {
                (Get-TargetResource @testParams).PrincipalTenantId | Should -Be '7b4d2e18-3c5f-4a91-9d0e-1f2a3b4c5d6e'
            }

            It 'Should use the role definition identifier when the role has no friendly name' {
                (Get-TargetResource @testParams).RoleDefinition | Should -Be 'EaRoleId_44444-44444-44444-44444-44444'
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }

            It 'Should reapply the assignment with the supplied tenant identifier from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName New-M365DSCAzureBillingAccountsRoleAssignment -Exactly 1 `
                    -ParameterFilter { $Body.principalTenantId -eq '7b4d2e18-3c5f-4a91-9d0e-1f2a3b4c5d6e' }
            }

            It 'Should remove the assignment using its own identifier rather than the role definition' {
                $removeParams = $testParams.Clone()
                $removeParams.Ensure = 'Absent'
                Set-TargetResource @removeParams
                Should -Invoke -CommandName Remove-M365DSCAzureBillingAccountsRoleAssignment -Exactly 1 `
                    -ParameterFilter { $AssignmentId -eq '99999-99999-99999-99999-99999' }
            }

            It 'Should export the email address as the principal name' {
                $assignment = @{
                    name = '99999-99999-99999-99999-99999'
                    properties = @{
                        principalPuid = '100320012F3A1B2C'
                        userEmailAddress = 'ea.admin@fabrikam.com'
                    }
                }
                $principal = Get-M365DSCAzureBillingPrincipal -Assignment $assignment `
                    -TenantId '7b4d2e18-3c5f-4a91-9d0e-1f2a3b4c5d6e'
                $principal.Name | Should -Be 'ea.admin@fabrikam.com'
                $principal.Type | Should -Be 'User'
                $principal.TenantId | Should -Be '7b4d2e18-3c5f-4a91-9d0e-1f2a3b4c5d6e'
            }
        }

        Context -Name "A principal holding more than one role on the same billing account" -Fixture {
            BeforeAll {
                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return @{
                        value = @(
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/66666-66666-66666-66666-66666'
                                name = '66666-66666-66666-66666-66666'
                                properties = @{
                                    principalId = '12345-12345-12345-12345-12345'
                                    principalType = 'User'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/22222-22222-22222-22222-22222'
                                    principalTenantId = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                                }
                            }
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/77777-77777-77777-77777-77777'
                                name = '77777-77777-77777-77777-77777'
                                properties = @{
                                    principalId = '12345-12345-12345-12345-12345'
                                    principalType = 'User'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/33333-33333-33333-33333-33333'
                                    principalTenantId = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                                }
                            }
                        )
                    }
                }

                $testParams = @{
                    BillingAccount        = "MyBillingAccount";
                    PrincipalName         = "John.Smith@contoso.onmicrosoft.com";
                    PrincipalType         = "User";
                    PrincipalTenantId     = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                    RoleDefinition        = "Billing account reader";
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential;
                }
            }

            It 'Should return the requested role rather than the first one assigned' {
                (Get-TargetResource @testParams).RoleDefinition | Should -Be 'Billing account reader'
            }

            It 'Should return true from the Test method for the requested role' {
                Test-TargetResource @testParams | Should -Be $true
            }

            It 'Should report a role the principal does not hold as Absent' {
                $otherParams = $testParams.Clone()
                $otherParams.RoleDefinition = 'Billing account contributor'
                (Get-TargetResource @otherParams).Ensure | Should -Be 'Absent'
            }

            It 'Should accept the AnyRole sentinel used by the export' {
                $anyParams = $testParams.Clone()
                $anyParams.RoleDefinition = 'AnyRole'
                (Get-TargetResource @anyParams).RoleDefinition | Should -Be 'Billing account owner'
            }
        }

        Context -Name "Changing the role assigned to an existing principal" -Fixture {
            BeforeAll {
                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return @{
                        value = @(
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/77777-77777-77777-77777-77777'
                                name = '77777-77777-77777-77777-77777'
                                properties = @{
                                    principalId = '12345-12345-12345-12345-12345'
                                    principalType = 'User'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/33333-33333-33333-33333-33333'
                                    principalTenantId = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                                }
                            }
                        )
                    }
                }

                $testParams = @{
                    BillingAccount        = "MyBillingAccount";
                    PrincipalName         = "John.Smith@contoso.onmicrosoft.com";
                    PrincipalType         = "User";
                    PrincipalTenantId     = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                    RoleDefinition        = "Billing account owner";
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential;
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should apply the requested role and not the one already assigned' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName New-M365DSCAzureBillingAccountsRoleAssignment -Exactly 1 `
                    -ParameterFilter { $Body.roleDefinitionId -eq '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/22222-22222-22222-22222-22222' }
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    SubscriptionId = "00000000-0000-0000-0000-000000000000"
                    Credential     = $Credential;
                }
            }
            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }

        Context -Name 'ReverseDSC Tests for Enterprise Agreement billing accounts' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"

                Mock -CommandName Save-M365DSCPartialExport -MockWith {
                }

                Mock -CommandName Get-M365DSCExportContentForResource -MockWith {
                    return "        AzureBillingAccountsRoleAssignment 'Instance'`r`n        {`r`n        }`r`n"
                }
            }

            It 'Should skip an assignment whose principal cannot be identified instead of failing the export' {
                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return @{
                        value = @(
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/55555-55555-55555-55555-55555'
                                name = '55555-55555-55555-55555-55555'
                                properties = @{
                                    principalId = '12345-12345-12345-12345-12345'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/22222-22222-22222-22222-22222'
                                    principalTenantId = '9c888910-6b3b-4c17-8cff-844fefb026d4'
                                }
                            }
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/88888-88888-88888-88888-88888'
                                name = '88888-88888-88888-88888-88888'
                                properties = @{
                                    principalPuid = '100320012F3A1B2C'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/22222-22222-22222-22222-22222'
                                }
                            }
                        )
                    }
                }

                $exportParams = @{
                    SubscriptionId = "00000000-0000-0000-0000-000000000000"
                    TenantId       = 'contoso.onmicrosoft.com'
                    Credential     = $Credential
                }
                { Export-TargetResource @exportParams } | Should -Not -Throw
                Should -Invoke -CommandName Get-M365DSCExportContentForResource -Exactly 1
            }

            It 'Should use the TenantId it was given when the billing plane reports no principal tenant' {
                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return @{
                        value = @(
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/99999-99999-99999-99999-99999'
                                name = '99999-99999-99999-99999-99999'
                                properties = @{
                                    principalPuid = '100320012F3A1B2C'
                                    userEmailAddress = 'ea.admin@fabrikam.com'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/EaRoleId_44444-44444-44444-44444-44444'
                                }
                            }
                        )
                    }
                }
                Mock -CommandName Get-MgUser -MockWith {
                    return $null
                }

                $exportParams = @{
                    SubscriptionId = "00000000-0000-0000-0000-000000000000"
                    TenantId       = '7b4d2e18-3c5f-4a91-9d0e-1f2a3b4c5d6e'
                    Credential     = $Credential
                }
                $null = Export-TargetResource @exportParams
                Should -Invoke -CommandName Get-M365DSCExportContentForResource -Exactly 1 `
                    -ParameterFilter { $Results.PrincipalTenantId -eq '7b4d2e18-3c5f-4a91-9d0e-1f2a3b4c5d6e' }
                Should -Invoke -CommandName Get-MgContext -Exactly 0
            }

            It 'Should skip a legacy assignment when no tenant identifier is available at all' {
                Mock -CommandName Get-M365DSCAzureBillingAccountsRoleAssignment -MockWith {
                    return @{
                        value = @(
                            @{
                                id = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleAssignments/99999-99999-99999-99999-99999'
                                name = '99999-99999-99999-99999-99999'
                                properties = @{
                                    principalPuid = '100320012F3A1B2C'
                                    userEmailAddress = 'ea.admin@fabrikam.com'
                                    roleDefinitionId = '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/EaRoleId_44444-44444-44444-44444-44444'
                                }
                            }
                        )
                    }
                }
                Mock -CommandName Get-MgUser -MockWith {
                    return $null
                }

                $exportParams = @{
                    SubscriptionId = "00000000-0000-0000-0000-000000000000"
                    Credential     = $Credential
                }
                { Export-TargetResource @exportParams } | Should -Not -Throw
                Should -Invoke -CommandName Get-M365DSCExportContentForResource -Exactly 0
            }
        }

        Context -Name 'Resolving the billing role name' -Fixture {
            It 'Should return the friendly role name when the billing plane provides one' {
                Get-M365DSCAzureBillingRoleName -BillingAccountId '12345-12345-12345-12345-12345' `
                    -RoleDefinitionResourceId '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/22222-22222-22222-22222-22222' |
                    Should -Be 'Billing account owner'
            }

            It 'Should fall back to the role definition name when there is no friendly role name' {
                Get-M365DSCAzureBillingRoleName -BillingAccountId '12345-12345-12345-12345-12345' `
                    -RoleDefinitionResourceId '/providers/Microsoft.Billing/billingAccounts/12345-12345-12345-12345-12345/billingRoleDefinitions/EaRoleId_44444-44444-44444-44444-44444' |
                    Should -Be 'EaRoleId_44444-44444-44444-44444-44444'
            }

            It 'Should return nothing when the assignment carries no role definition' {
                Get-M365DSCAzureBillingRoleName -BillingAccountId '12345-12345-12345-12345-12345' `
                    -RoleDefinitionResourceId '' | Should -BeNullOrEmpty
                Should -Invoke -CommandName Get-M365DSCAzureBillingAccountsRoleDefinition -Exactly 0
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
