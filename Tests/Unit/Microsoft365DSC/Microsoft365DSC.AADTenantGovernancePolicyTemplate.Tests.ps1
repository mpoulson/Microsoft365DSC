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
    -DscResource "AADTenantGovernancePolicyTemplate" -GenericStubModule $GenericStubPath
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
                    id                                     = "FakeTemplateId"
                    displayName                            = "FakeTemplateName"
                    description                            = "FakeDescription"
                    delegatedAdministrationRoleAssignments = @(
                        @{
                            group = @{
                                id          = "FakeGroupId"
                                displayName = "FakeGroupName"
                            }
                            roleTemplates = @(
                                @{
                                    id   = "62e90394-69f5-4237-9190-012177145e10"
                                    name = "Global Administrator"
                                }
                            )
                        }
                    )
                    multiTenantApplicationsToProvision    = @()
                }
            }

            Mock -CommandName Get-MgBetaGroup -MockWith {
                return @{
                    Id          = "FakeGroupId"
                    DisplayName = "FakeGroupName"
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
        Context -Name "The AADTenantGovernancePolicyTemplate should exist but it DOES NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName = "FakeTemplateName"
                    Description = "FakeDescription"
                    Id          = "FakeTemplateId"
                    Ensure      = "Present"
                    Credential  = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return $null
                }
            }
            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }
            It 'Should Create the resource from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -ParameterFilter { $Method -eq 'POST' } -Exactly 1
            }
        }

        Context -Name "The AADTenantGovernancePolicyTemplate exists but it SHOULD NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName = "FakeTemplateName"
                    Description = "FakeDescription"
                    Id          = "FakeTemplateId"
                    Ensure      = 'Absent'
                    Credential  = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        id                                     = "FakeTemplateId"
                        displayName                            = "FakeTemplateName"
                        description                            = "FakeDescription"
                        delegatedAdministrationRoleAssignments = @()
                        multiTenantApplicationsToProvision    = @()
                    }
                }
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should Remove the resource from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -ParameterFilter { $Method -eq 'DELETE' } -Exactly 1
            }
        }
        Context -Name "The AADTenantGovernancePolicyTemplate Exists and Values are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName = "FakeTemplateName"
                    Description = "FakeDescription"
                    Id          = "FakeTemplateId"
                    Ensure      = 'Present'
                    Credential  = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        id                                     = "FakeTemplateId"
                        displayName                            = "FakeTemplateName"
                        description                            = "FakeDescription"
                        delegatedAdministrationRoleAssignments = @()
                        multiTenantApplicationsToProvision    = @()
                    }
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The AADTenantGovernancePolicyTemplate exists and values are NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName = "FakeTemplateName"
                    Description = "FakeDescriptionDrift"
                    Id          = "FakeTemplateId"
                    Ensure      = 'Present'
                    Credential  = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return @{
                        id                                     = "FakeTemplateId"
                        displayName                            = "FakeTemplateName"
                        description                            = "FakeDescription"
                        delegatedAdministrationRoleAssignments = @()
                        multiTenantApplicationsToProvision    = @()
                    }
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
                Should -Invoke -CommandName Invoke-MgGraphRequest -ParameterFilter { $Method -eq 'PATCH' } -Exactly 1
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
                                id                                     = "FakeTemplateId"
                                displayName                            = "FakeTemplateName"
                                description                            = "FakeDescription"
                                delegatedAdministrationRoleAssignments = @()
                                multiTenantApplicationsToProvision    = @()
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
