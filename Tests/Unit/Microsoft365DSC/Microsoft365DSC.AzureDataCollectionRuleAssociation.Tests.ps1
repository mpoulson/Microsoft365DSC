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

            Mock -CommandName New-AzDataCollectionRuleAssociation -MockWith {
            }

            Mock -CommandName Remove-AzDataCollectionRuleAssociation -MockWith {
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        # Test contexts
        Context -Name "The AzureDataCollectionRuleAssociation should exist but it DOES NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    AssociationName       = "Contoso-WindowsSecurityEventsAMA"
                    ResourceUri           = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020"
                    DataCollectionRuleId  = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                    Description           = "Associates the DCR to the tenant monitored object."
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential
                }

                Mock -CommandName Get-AzDataCollectionRuleAssociation -MockWith {
                    return $null
                }
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call New-AzDataCollectionRuleAssociation from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName New-AzDataCollectionRuleAssociation -Exactly 1
            }
        }

        Context -Name "The AzureDataCollectionRuleAssociation exists but it SHOULD NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    AssociationName       = "Contoso-WindowsSecurityEventsAMA"
                    ResourceUri           = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020"
                    DataCollectionRuleId  = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                    Ensure                = 'Absent'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential
                }

                Mock -CommandName Get-AzDataCollectionRuleAssociation -MockWith {
                    return [PSCustomObject]@{
                        Name                     = "Contoso-WindowsSecurityEventsAMA"
                        Id                       = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020/providers/Microsoft.Insights/dataCollectionRuleAssociations/Contoso-WindowsSecurityEventsAMA"
                        DataCollectionRuleId     = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                        DataCollectionEndpointId = $null
                        Description              = "Associates the DCR to the tenant monitored object."
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call Remove-AzDataCollectionRuleAssociation from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Remove-AzDataCollectionRuleAssociation -Exactly 1
            }
        }

        Context -Name "The AzureDataCollectionRuleAssociation Exists and Values are already in the Desired State" -Fixture {
            BeforeAll {
                $testParams = @{
                    AssociationName       = "Contoso-WindowsSecurityEventsAMA"
                    ResourceUri           = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020"
                    DataCollectionRuleId  = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                    Description           = "Associates the DCR to the tenant monitored object."
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential
                }

                Mock -CommandName Get-AzDataCollectionRuleAssociation -MockWith {
                    return [PSCustomObject]@{
                        Name                     = "Contoso-WindowsSecurityEventsAMA"
                        Id                       = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020/providers/Microsoft.Insights/dataCollectionRuleAssociations/Contoso-WindowsSecurityEventsAMA"
                        DataCollectionRuleId     = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                        DataCollectionEndpointId = $null
                        Description              = "Associates the DCR to the tenant monitored object."
                    }
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The AzureDataCollectionRuleAssociation exists and values are NOT in the Desired State" -Fixture {
            BeforeAll {
                $testParams = @{
                    AssociationName       = "Contoso-WindowsSecurityEventsAMA"
                    ResourceUri           = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020"
                    DataCollectionRuleId  = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                    Description           = "Associates the DCR to the tenant monitored object."
                    Ensure                = 'Present'
                    SubscriptionId        = "00000000-0000-0000-0000-000000000000"
                    Credential            = $Credential
                }

                Mock -CommandName Get-AzDataCollectionRuleAssociation -MockWith {
                    return [PSCustomObject]@{
                        Name                     = "Contoso-WindowsSecurityEventsAMA"
                        Id                       = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020/providers/Microsoft.Insights/dataCollectionRuleAssociations/Contoso-WindowsSecurityEventsAMA"
                        DataCollectionRuleId     = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsFirewallEventsAMA" # Drift
                        DataCollectionEndpointId = $null
                        Description              = "Associates the DCR to the tenant monitored object."
                    }
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call New-AzDataCollectionRuleAssociation from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName New-AzDataCollectionRuleAssociation -Exactly 1
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    SubscriptionId = "00000000-0000-0000-0000-000000000000"
                    Credential     = $Credential
                }

                Mock -CommandName Get-AzDataCollectionRule -MockWith {
                    return @(
                        [PSCustomObject]@{
                            Name = "WindowsSecurityEventsAMA"
                            Id   = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                        }
                    )
                }

                Mock -CommandName Get-AzDataCollectionRuleAssociation -MockWith {
                    return @(
                        [PSCustomObject]@{
                            Name                     = "Contoso-WindowsSecurityEventsAMA"
                            Id                       = "/providers/Microsoft.Insights/monitoredObjects/00000000-0000-0000-0000-000000000020/providers/Microsoft.Insights/dataCollectionRuleAssociations/Contoso-WindowsSecurityEventsAMA"
                            DataCollectionRuleId     = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.Insights/dataCollectionRules/WindowsSecurityEventsAMA"
                            DataCollectionEndpointId = $null
                            Description              = "Associates the DCR to the tenant monitored object."
                        }
                    )
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
