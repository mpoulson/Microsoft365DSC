[CmdletBinding()]
param(
)
$M365DSCTestFolder = Join-Path -Path $PSScriptRoot `
    -ChildPath '..\..\Unit' `
    -Resolve
$CmdletModule = Join-Path -Path $M365DSCTestFolder `
    -ChildPath '\Stubs\Microsoft365.psm1' `
    -Resolve
$GenericStubPath = Join-Path -Path $M365DSCTestFolder `
    -ChildPath '\Stubs\Generic.psm1' `
    -Resolve
Import-Module -Name (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\UnitTestHelper.psm1' `
        -Resolve)

$CurrentScriptPath = $PSCommandPath.Split('\')
$CurrentScriptName = $CurrentScriptPath[$CurrentScriptPath.Length - 1]
$ResourceName = $CurrentScriptName.Split('.')[1]
$Global:DscHelper = New-M365DscUnitTestHelper -StubModule $CmdletModule `
    -DscResource $ResourceName `
    -GenericStubModule $GenericStubPath

Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope

        BeforeAll {
            $securePassword = ConvertTo-SecureString (New-Guid | Out-String) -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential (
                'tenantadmin@contoso.com',
                $securePassword
            )
            $relationshipId = 'aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb'
            $relationship = @{
                id                  = $relationshipId
                governedTenantId    = 'bbbbcccc-1111-dddd-2222-eeee3333ffff'
                governedTenantName  = 'Fabrikam'
                governingTenantId   = 'aaaabbbb-0000-cccc-1111-dddd2222eeee'
                governingTenantName = 'Contoso'
                creationDateTime    = '2026-01-01T00:00:00Z'
                status              = 'active'
                createdType         = 'approvedByAdmin'
                policySnapshot      = @{
                    policyId                               = 'default'
                    governedTenantCanTerminate              = $false
                    delegatedAdministrationRoleAssignments = @(
                        @{
                            groupDisplayName = 'Tenant administrators'
                            groupId          = 'cccccccc-2222-3333-4444-dddddddddddd'
                            roleTemplates    = @(
                                @{
                                    id   = 'f2ef992c-3afb-46b9-b7cf-a126ee74c451'
                                    name = 'Global Reader'
                                }
                            )
                        }
                    )
                    multiTenantApplicationsToProvision     = @(
                        @{
                            appId                    = '66667777-aaaa-8888-bbbb-9999cccc0000'
                            objectId                 = 'dddddddd-3333-4444-5555-eeeeeeeeeeee'
                            displayName              = 'Monitoring application'
                            requiredResourceAccesses = @(
                                @{
                                    resourceAppId = '00000003-0000-0000-c000-000000000000'
                                    permissions   = @(
                                        @{
                                            id   = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
                                            name = 'User.Read'
                                            type = 'scope'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies
            Mock -CommandName New-M365DSCConnection -MockWith {
                return 'Credentials'
            }
            Mock -CommandName Get-MSCloudLoginConnectionProfile -MockWith {
                return @{
                    ResourceUrl = 'https://graph.microsoft.com/'
                }
            }
            Mock -CommandName Get-M365DSCDRGComplexTypeToHashtable -MockWith {
                return $ComplexObject
            }
            Mock -CommandName Write-M365DSCHost
            Mock -CommandName Invoke-MgGraphRequest -MockWith {
                return @{
                    value = @($relationship)
                }
            } -ParameterFilter {
                $Method -eq 'GET'
            }
            Mock -CommandName Invoke-MgGraphRequest -ParameterFilter {
                $Method -eq 'PATCH'
            }
            $Script:exportedInstance = $null
            $Script:ExportMode = $false
        }

        Context -Name 'When the relationship exists in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id         = $relationshipId
                    Status     = 'active'
                    Ensure     = 'Present'
                    Credential = $Credential
                }
            }

            It 'Returns the relationship and complete policy snapshot' {
                $result = Get-TargetResource @testParams

                $result.Ensure | Should -Be 'Present'
                $result.Id | Should -Be $relationshipId
                $result.CreationDateTime | Should -Be '2026-01-01T00:00:00Z'
                $result.PolicySnapshot.MultiTenantApplicationsToProvision[0].DisplayName |
                    Should -Be 'Monitoring application'
            }

            It 'Uses the current Microsoft Graph tenant governance endpoint' {
                Get-TargetResource @testParams | Out-Null

                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 1 -ParameterFilter {
                    $Method -eq 'GET' -and
                    $Uri -like 'https://graph.microsoft.com/beta/directory/tenantGovernance/governanceRelationships*'
                }
            }

            It 'Returns true from Test-TargetResource' {
                Test-TargetResource @testParams | Should -BeTrue
            }
        }

        Context -Name 'When the relationship status must change' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id         = $relationshipId
                    Status     = 'terminationRequestedByGoverningTenant'
                    Ensure     = 'Present'
                    Credential = $Credential
                }
            }

            It 'Returns false from Test-TargetResource' {
                Test-TargetResource @testParams | Should -BeFalse
            }

            It 'Updates the status through the supported endpoint' {
                Set-TargetResource @testParams

                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 1 -ParameterFilter {
                    $Method -eq 'PATCH' -and
                    $Uri -eq "https://graph.microsoft.com/beta/directory/tenantGovernance/governanceRelationships/$relationshipId" -and
                    $Body -match 'terminationRequestedByGoverningTenant'
                }
            }
        }

        Context -Name 'When the relationship does not exist' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id         = 'ffffffff-5555-6666-7777-aaaaaaaaaaaa'
                    Ensure     = 'Present'
                    Credential = $Credential
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        value = @()
                    }
                } -ParameterFilter {
                    $Method -eq 'GET'
                }
            }

            It 'Returns the key and Absent from Get-TargetResource' {
                $result = Get-TargetResource @testParams

                $result.Id | Should -Be $testParams.Id
                $result.Ensure | Should -Be 'Absent'
            }

            It 'Rejects direct relationship creation' {
                { Set-TargetResource @testParams } |
                    Should -Throw '*cannot create a tenant governance relationship*'
            }
        }

        Context -Name 'When deletion is requested' -Fixture {
            It 'Rejects direct relationship deletion' {
                {
                    Set-TargetResource -Id $relationshipId `
                        -Ensure 'Absent' `
                        -Credential $Credential
                } | Should -Throw '*cannot delete a tenant governance relationship*'
            }
        }

        Context -Name 'When an unsupported status transition is requested' -Fixture {
            BeforeAll {
                $terminatedRelationship = $relationship.Clone()
                $terminatedRelationship.status = 'terminated'
                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        value = @($terminatedRelationship)
                    }
                } -ParameterFilter {
                    $Method -eq 'GET'
                }
            }

            It 'Rejects an attempt to reactivate the relationship' {
                {
                    Set-TargetResource -Id $relationshipId `
                        -Status 'active' `
                        -Ensure 'Present' `
                        -Credential $Credential
                } | Should -Throw "*cannot change the status to 'active'*"
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $secondRelationship = $relationship.Clone()
                $secondRelationship.id = 'eeeeeeee-4444-5555-6666-ffffffffffff'

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        value             = @($relationship)
                        '@odata.nextLink' = 'https://graph.microsoft.com/beta/nextPage'
                    }
                } -ParameterFilter {
                    $Method -eq 'GET' -and $Uri -like '*%27active%27'
                }
                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        value = @($secondRelationship)
                    }
                } -ParameterFilter {
                    $Method -eq 'GET' -and $Uri -eq 'https://graph.microsoft.com/beta/nextPage'
                }
            }

            It 'Honours the filter and exports every page' {
                $result = Export-TargetResource `
                    -Filter "status eq 'active'" `
                    -Credential $Credential

                $result | Should -Not -BeNullOrEmpty
                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 2 -ParameterFilter {
                    $Method -eq 'GET'
                }
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
