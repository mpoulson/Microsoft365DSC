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

$Global:DscHelper = New-M365DscUnitTestHelper -StubModule $CmdletModule `
    -DscResource "AADTenantGovernanceRelationship" -GenericStubModule $GenericStubPath
Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope
        BeforeAll {

            $secpasswd = ConvertTo-SecureString (New-Guid | Out-String) -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('tenantadmin@mydomain.com', $secpasswd)

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName Get-PSSession -MockWith {
            }

            Mock -CommandName Remove-PSSession -MockWith {
            }

            Mock -CommandName Invoke-MgGraphRequest -MockWith {
                return @{
                    id                  = "FakeRelationshipId"
                    governedTenantId    = "00000000-0000-0000-0000-000000000001"
                    governedTenantName  = "Governed Tenant"
                    governingTenantId   = "00000000-0000-0000-0000-000000000002"
                    governingTenantName = "Governing Tenant"
                    status              = "active"
                    createdType         = "approvedByAdmin"
                    policySnapshot      = @{
                        policyId                               = "default"
                        governedTenantCanTerminate              = $false
                        delegatedAdministrationRoleAssignments = @()
                    }
                }
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return "Credentials"
            }

            Mock -CommandName Get-MSCloudLoginConnectionProfile -MockWith {
                return @{
                    ResourceUrl = "https://graph.microsoft.com"
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }
        # Test contexts
        Context -Name "The AADTenantGovernanceRelationship exists and values are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    GovernedTenantId = "00000000-0000-0000-0000-000000000001"
                    Id               = "FakeRelationshipId"
                    Status           = "active"
                    Ensure           = "Present"
                    Credential       = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        id                  = "FakeRelationshipId"
                        governedTenantId    = "00000000-0000-0000-0000-000000000001"
                        governedTenantName  = "Governed Tenant"
                        governingTenantId   = "00000000-0000-0000-0000-000000000002"
                        governingTenantName = "Governing Tenant"
                        status              = "active"
                        createdType         = "approvedByAdmin"
                        policySnapshot      = @{
                            policyId                               = "default"
                            governedTenantCanTerminate              = $false
                            delegatedAdministrationRoleAssignments = @()
                        }
                    }
                }
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The AADTenantGovernanceRelationship exists and status needs to change" -Fixture {
            BeforeAll {
                $testParams = @{
                    GovernedTenantId = "00000000-0000-0000-0000-000000000001"
                    Id               = "FakeRelationshipId"
                    Status           = "terminationRequestedByGoverningTenant"
                    Ensure           = "Present"
                    Credential       = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        id                  = "FakeRelationshipId"
                        governedTenantId    = "00000000-0000-0000-0000-000000000001"
                        governedTenantName  = "Governed Tenant"
                        governingTenantId   = "00000000-0000-0000-0000-000000000002"
                        governingTenantName = "Governing Tenant"
                        status              = "active"
                        createdType         = "approvedByAdmin"
                        policySnapshot      = @{
                            policyId                               = "default"
                            governedTenantCanTerminate              = $false
                            delegatedAdministrationRoleAssignments = @()
                        }
                    }
                }
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should update the status from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -ParameterFilter { $Method -eq 'PATCH' } -Exactly 1
            }
        }

        Context -Name "The AADTenantGovernanceRelationship does not exist" -Fixture {
            BeforeAll {
                $testParams = @{
                    GovernedTenantId = "00000000-0000-0000-0000-000000000099"
                    Ensure           = "Present"
                    Credential       = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return $null
                }
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        value = @(
                            @{
                                id                  = "FakeRelationshipId"
                                governedTenantId    = "00000000-0000-0000-0000-000000000001"
                                governedTenantName  = "Governed Tenant"
                                governingTenantId   = "00000000-0000-0000-0000-000000000002"
                                governingTenantName = "Governing Tenant"
                                status              = "active"
                                createdType         = "approvedByAdmin"
                                policySnapshot      = @{
                                    policyId                               = "default"
                                    governedTenantCanTerminate              = $false
                                    delegatedAdministrationRoleAssignments = @()
                                }
                            }
                        )
                    }
                }
            }
            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
