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
                    StatusCode = 200
                    Content = ConvertTo-Json @{
                        name = 'audit-vms-managed-disks'
                        location = 'eastus'
                        identity = @{
                            type = 'SystemAssigned'
                        }
                        properties = @{
                            displayName        = 'Audit VMs without managed disks'
                            description        = 'This policy audits VMs without managed disks'
                            policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'
                            scope              = '/subscriptions/00000000-0000-0000-0000-000000000000'
                            enforcementMode    = 'Default'
                            parameters         = @{}
                            notScopes          = @()
                            nonComplianceMessages = @(
                                @{
                                    message = 'VMs must use managed disks'
                                }
                            )
                        }
                    } -Depth 10
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }
        # Test contexts
        Context -Name "The instance should exist but it DOES NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    PolicyAssignmentName  = "audit-vms-managed-disks"
                    Scope                 = "/subscriptions/00000000-0000-0000-0000-000000000000"
                    DisplayName           = "Audit VMs without managed disks"
                    Description           = "This policy audits VMs without managed disks"
                    PolicyDefinitionId    = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
                    EnforcementMode       = "Default"
                    Location              = "eastus"
                    IdentityType          = "SystemAssigned"
                    Ensure                = 'Present'
                    Credential            = $Credential;
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        StatusCode = 404
                        Content = '{}'
                    }
                }
            }
            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should create a new instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRest -Exactly 2
            }
        }

        Context -Name "The instance exists but it SHOULD NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    PolicyAssignmentName  = "audit-vms-managed-disks"
                    Scope                 = "/subscriptions/00000000-0000-0000-0000-000000000000"
                    DisplayName           = "Audit VMs without managed disks"
                    Description           = "This policy audits VMs without managed disks"
                    PolicyDefinitionId    = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
                    EnforcementMode       = "Default"
                    Location              = "eastus"
                    IdentityType          = "SystemAssigned"
                    Ensure                = 'Absent'
                    Credential            = $Credential;
                }
            }
            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should remove the instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRest -Exactly 2
            }
        }

        Context -Name "The instance exists and values are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    PolicyAssignmentName  = "audit-vms-managed-disks"
                    Scope                 = "/subscriptions/00000000-0000-0000-0000-000000000000"
                    DisplayName           = "Audit VMs without managed disks"
                    Description           = "This policy audits VMs without managed disks"
                    PolicyDefinitionId    = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
                    EnforcementMode       = "Default"
                    Location              = "eastus"
                    IdentityType          = "SystemAssigned"
                    Ensure                = 'Present'
                    Credential            = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The instance exists and values are NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    PolicyAssignmentName  = "audit-vms-managed-disks"
                    Scope                 = "/subscriptions/00000000-0000-0000-0000-000000000000"
                    DisplayName           = "Audit VMs without managed disks"
                    Description           = "This policy audits VMs without managed disks"
                    PolicyDefinitionId    = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
                    EnforcementMode       = "DoNotEnforce"  # Drift
                    Location              = "eastus"
                    IdentityType          = "SystemAssigned"
                    Ensure                = 'Present'
                    Credential            = $Credential;
                }
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRest -Exactly 2
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential  = $Credential;
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        StatusCode = 200
                        Content = ConvertTo-Json @{
                            value = @(
                                @{
                                    subscriptionId = '00000000-0000-0000-0000-000000000000'
                                }
                            )
                        } -Depth 10
                    }
                } -ParameterFilter { $Uri -like '*/subscriptions?*' }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        StatusCode = 200
                        Content = ConvertTo-Json @{
                            value = @(
                                @{
                                    name = 'audit-vms-managed-disks'
                                    location = 'eastus'
                                    identity = @{
                                        type = 'SystemAssigned'
                                    }
                                    properties = @{
                                        displayName        = 'Audit VMs without managed disks'
                                        description        = 'This policy audits VMs'
                                        policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'
                                        scope              = '/subscriptions/00000000-0000-0000-0000-000000000000'
                                        enforcementMode    = 'Default'
                                        parameters         = @{}
                                        notScopes          = @()
                                        nonComplianceMessages = @()
                                    }
                                }
                            )
                        } -Depth 10
                    }
                } -ParameterFilter { $Uri -like '*/policyAssignments*' }
            }
            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
