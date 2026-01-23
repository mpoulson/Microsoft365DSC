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
    -DscResource 'AADPermissionGrantPolicyInclude' -GenericStubModule $GenericStubPath
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

            Mock -CommandName New-MgPolicyPermissionGrantPolicyInclude -MockWith {
            }

            Mock -CommandName Remove-MgPolicyPermissionGrantPolicyInclude -MockWith {
            }

            Mock -CommandName Get-MgPolicyPermissionGrantPolicyInclude -MockWith {
                param($PermissionGrantPolicyId, $PermissionGrantConditionSetId)
                if ($PermissionGrantConditionSetId -eq 'missing')
                {
                    throw 'not found'
                }

                return [pscustomobject]@{
                    Id                                        = 'include-delegated'
                    PermissionType                            = 'delegated'
                    ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
                    Permissions                               = @('user.read')
                    PermissionClassification                  = 'low'
                    ClientApplicationIds                      = @('11111111-1111-1111-1111-111111111111')
                    ClientApplicationTenantIds                = @('22222222-2222-2222-2222-222222222222')
                    ClientApplicationPublisherIds             = @('33333333-3333-3333-3333-333333333333')
                    ClientApplicationsFromVerifiedPublisherOnly = $true
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

        Context -Name 'Include exists and is in desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                                        = 'include-delegated'
                    PermissionGrantPolicyId                   = 'm365dsc-custom'
                    PermissionType                            = 'delegated'
                    ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
                    Permissions                               = @('user.read')
                    PermissionClassification                  = 'low'
                    ClientApplicationIds                      = @('11111111-1111-1111-1111-111111111111')
                    ClientApplicationTenantIds                = @('22222222-2222-2222-2222-222222222222')
                    ClientApplicationPublisherIds             = @('33333333-3333-3333-3333-333333333333')
                    ClientApplicationsFromVerifiedPublisherOnly = $true
                    Ensure                                    = 'Present'
                    Credential                                = $Credential
                }
            }

            It 'Should call Get once' {
                Get-TargetResource @testParams
                Should -Invoke -CommandName 'Get-MgPolicyPermissionGrantPolicyInclude' -Exactly 1
            }

            It 'Should return true from Test' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'Include exists but needs update (replace)' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                                        = 'include-delegated'
                    PermissionGrantPolicyId                   = 'm365dsc-custom'
                    PermissionType                            = 'delegated'
                    ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
                    Permissions                               = @('user.read', 'profile.read')
                    PermissionClassification                  = 'medium'
                    ClientApplicationIds                      = @('11111111-1111-1111-1111-111111111111')
                    ClientApplicationTenantIds                = @('22222222-2222-2222-2222-222222222222')
                    ClientApplicationPublisherIds             = @('33333333-3333-3333-3333-333333333333')
                    ClientApplicationsFromVerifiedPublisherOnly = $true
                    Ensure                                    = 'Present'
                    Credential                                = $Credential
                }
            }

            It 'Should return false from Test' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should delete then recreate' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Remove-MgPolicyPermissionGrantPolicyInclude' -Exactly 1
                Should -Invoke -CommandName 'New-MgPolicyPermissionGrantPolicyInclude' -Exactly 1
            }
        }

        Context -Name 'Include does not exist and must be created' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                                        = 'missing'
                    PermissionGrantPolicyId                   = 'm365dsc-custom'
                    PermissionType                            = 'delegated'
                    ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
                    Permissions                               = @('user.read')
                    PermissionClassification                  = 'low'
                    Ensure                                    = 'Present'
                    Credential                                = $Credential
                }
            }

            It 'Should return false from Test' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call Create' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'New-MgPolicyPermissionGrantPolicyInclude' -Exactly 1
            }
        }

        Context -Name 'Include exists and should be removed' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                          = 'include-delegated'
                    PermissionGrantPolicyId     = 'm365dsc-custom'
                    Ensure                      = 'Absent'
                    Credential                  = $Credential
                }
            }

            It 'Should return false from Test' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call Remove' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Remove-MgPolicyPermissionGrantPolicyInclude' -Exactly 1
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
                        [pscustomobject]@{ Id = 'm365dsc-custom' }
                    )
                }
                Mock -CommandName Get-MgPolicyPermissionGrantPolicyInclude -MockWith {
                    return @(
                        [pscustomobject]@{
                            Id                                        = 'include-delegated'
                            PermissionType                            = 'delegated'
                            ResourceApplication                       = '00000003-0000-0000-c000-000000000000'
                            Permissions                               = @('user.read')
                            PermissionClassification                  = 'low'
                            ClientApplicationIds                      = @('11111111-1111-1111-1111-111111111111')
                            ClientApplicationTenantIds                = @('22222222-2222-2222-2222-222222222222')
                            ClientApplicationPublisherIds             = @('33333333-3333-3333-3333-333333333333')
                            ClientApplicationsFromVerifiedPublisherOnly = $true
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
