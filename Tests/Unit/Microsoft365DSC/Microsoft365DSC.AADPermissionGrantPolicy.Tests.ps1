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

            $Global:PartialExportFileName = 'c:\TestPath'

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName Save-M365DSCPartialExport -MockWith {
            }

            Mock -CommandName Get-PSSession -MockWith {
            }

            Mock -CommandName New-MgPolicyPermissionGrantPolicy -MockWith {
            }

            Mock -CommandName Update-MgPolicyPermissionGrantPolicy -MockWith {
            }

            Mock -CommandName Remove-MgPolicyPermissionGrantPolicy -MockWith {
            }

            Mock -CommandName Get-MgPolicyPermissionGrantPolicy -MockWith {
                param($PermissionGrantPolicyId)
                if ($PermissionGrantPolicyId -eq 'missing')
                {
                    throw 'not found'
                }

                return [pscustomobject]@{
                    Id          = 'm365dsc-custom'
                    DisplayName = 'Custom Consent Policy'
                    Description = 'Policy used for custom consent scenarios'
                }
            }

            Mock -CommandName Remove-PSSession -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return 'Credentials'
            }

            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances =$null
            $Script:ExportMode = $false
        }

        Context -Name 'Policy exists and is in desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id          = 'm365dsc-custom'
                    DisplayName = 'Custom Consent Policy'
                    Description = 'Policy used for custom consent scenarios'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }
            }

            It 'Should call Get once' {
                Get-TargetResource @testParams
                Should -Invoke -CommandName 'Get-MgPolicyPermissionGrantPolicy' -Exactly 1
            }

            It 'Should return true from Test' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'Policy exists but needs update' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id          = 'm365dsc-custom'
                    DisplayName = 'Custom Consent Policy Updated'
                    Description = 'Updated description'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }
            }

            It 'Should return false from Test' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call Update' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Update-MgPolicyPermissionGrantPolicy' -Exactly 1
            }
        }

        Context -Name 'Policy does not exist and must be created' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id          = 'missing'
                    DisplayName = 'Missing'
                    Description = 'Create it'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }
            }

            It 'Should return false from Test' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call Create' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'New-MgPolicyPermissionGrantPolicy' -Exactly 1
            }
        }

        Context -Name 'Policy exists and should be removed' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id          = 'm365dsc-custom'
                    Ensure      = 'Absent'
                    Credential  = $Credential
                }
            }

            It 'Should return false from Test' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call Remove' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Remove-MgPolicyPermissionGrantPolicy' -Exactly 1
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }
            }

            It 'Should reverse engineer resource from the export method' {
                Mock -CommandName Get-MgPolicyPermissionGrantPolicy -MockWith {
                    return @(
                        [pscustomobject]@{
                            Id          = 'm365dsc-custom'
                            DisplayName = 'Custom Consent Policy'
                            Description = 'Policy used for custom consent scenarios'
                        }
                    )
                }
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
