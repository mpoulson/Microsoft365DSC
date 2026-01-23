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
    -DscResource 'AADPermissionGrantPolicy' -GenericStubModule $GenericStubPath
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

            Mock -CommandName Get-PSSession -MockWith {
            }

            Mock -CommandName Remove-PSSession -MockWith {
            }

            Mock -CommandName New-MgBetaPolicyPermissionGrantPolicy -MockWith {
            }

            Mock -CommandName Update-MgBetaPolicyPermissionGrantPolicy -MockWith {
            }

            Mock -CommandName Remove-MgBetaPolicyPermissionGrantPolicy -MockWith {
            }

            Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                if ($All)
                {
                    return @(
                        @{
                            Id          = 'test-policy'
                            DisplayName = 'Test Permission Grant Policy'
                            Description = 'Test policy description'
                        }
                    )
                }
                elseif ($PermissionGrantPolicyId)
                {
                    return @{
                        Id          = $PermissionGrantPolicyId
                        DisplayName = 'Test Permission Grant Policy'
                        Description = 'Test policy description'
                    }
                }
                return @{
                    Id          = 'test-policy'
                    DisplayName = 'Test Permission Grant Policy'
                    Description = 'Test policy description'
                }
            }

            Mock -CommandName Write-M365DSCHost -MockWith {
            }

            Mock -CommandName Save-M365DSCPartialExport -MockWith {
            }

            Mock -CommandName Update-M365DSCExportAuthenticationResults -MockWith {
                return @{}
            }

            Mock -CommandName Get-M365DSCExportContentForResource -MockWith {
                return "AADPermissionGrantPolicy 'TestPolicy' {}`r`n"
            }

            Mock -CommandName New-M365DSCLogEntry -MockWith {
            }

            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        # Test contexts
        Context -Name 'The Policy should exist but it DOES NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id          = 'test-policy'
                    DisplayName = 'Test Permission Grant Policy'
                    Description = 'Test policy description'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }

                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    return $null
                }
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
                Should -Invoke -CommandName 'Get-MgBetaPolicyPermissionGrantPolicy' -Exactly 1
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should create the Policy from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'New-MgBetaPolicyPermissionGrantPolicy' -Exactly 1
            }
        }

        Context -Name 'The Policy exists but it SHOULD NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id         = 'test-policy'
                    Ensure     = 'Absent'
                    Credential = $Credential
                }

                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    return @{
                        Id          = 'test-policy'
                        DisplayName = 'Test Permission Grant Policy'
                        Description = 'Test policy description'
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
                Should -Invoke -CommandName 'Get-MgBetaPolicyPermissionGrantPolicy' -Exactly 1
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should remove the Policy from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Remove-MgBetaPolicyPermissionGrantPolicy' -Exactly 1
            }
        }

        Context -Name 'The Policy Exists and Values are already in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id          = 'test-policy'
                    DisplayName = 'Test Permission Grant Policy'
                    Description = 'Test policy description'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }

                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    return @{
                        Id          = 'test-policy'
                        DisplayName = 'Test Permission Grant Policy'
                        Description = 'Test policy description'
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
                Should -Invoke -CommandName 'Get-MgBetaPolicyPermissionGrantPolicy' -Exactly 1
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'Values are NOT in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id          = 'test-policy'
                    DisplayName = 'Updated Permission Grant Policy'
                    Description = 'Updated policy description'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }

                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    return @{
                        Id          = 'test-policy'
                        DisplayName = 'Test Permission Grant Policy'
                        Description = 'Test policy description'
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
                Should -Invoke -CommandName 'Get-MgBetaPolicyPermissionGrantPolicy' -Exactly 1
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Update-MgBetaPolicyPermissionGrantPolicy' -Exactly 1
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    if ($All)
                    {
                        return @(
                            @{
                                Id          = 'test-policy-1'
                                DisplayName = 'Test Policy 1'
                                Description = 'First test policy'
                            },
                            @{
                                Id          = 'test-policy-2'
                                DisplayName = 'Test Policy 2'
                                Description = 'Second test policy'
                            }
                        )
                    }
                    return $null
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
