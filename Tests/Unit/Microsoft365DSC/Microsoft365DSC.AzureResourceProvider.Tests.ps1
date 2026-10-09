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
                return 'Credentials'
            }

            Mock -CommandName Get-AzContext -MockWith {
                return @{
                    Subscription = @{
                        Id = '00000000-0000-0000-0000-000000000000'
                    }
                }
            }

            Mock -CommandName Set-AzContext -MockWith {
            }

            Mock -CommandName Register-AzResourceProvider -MockWith {
            }

            Mock -CommandName Unregister-AzResourceProvider -MockWith {
            }

            Mock -CommandName Get-AzResourceProvider -MockWith {
                return $null
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        # Test contexts
        Context -Name 'The provider is not registered and it should be' -Fixture {
            BeforeAll {
                $testParams = @{
                    ProviderNamespace = 'Microsoft.DesktopVirtualization'
                    SubscriptionId    = '00000000-0000-0000-0000-000000000000'
                    Ensure            = 'Present'
                    Credential        = $Credential
                }

                # A namespace that has never been registered is simply not returned.
                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return $null
                }
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should register the provider from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Register-AzResourceProvider -ParameterFilter {
                    $ProviderNamespace -eq 'Microsoft.DesktopVirtualization'
                } -Exactly 1
                Should -Invoke -CommandName Unregister-AzResourceProvider -Exactly 0
            }
        }

        Context -Name 'The provider reports NotRegistered and it should be registered' -Fixture {
            BeforeAll {
                $testParams = @{
                    ProviderNamespace = 'Microsoft.DesktopVirtualization'
                    SubscriptionId    = '00000000-0000-0000-0000-000000000000'
                    Ensure            = 'Present'
                    Credential        = $Credential
                }

                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return @{
                        ProviderNamespace = 'Microsoft.DesktopVirtualization'
                        RegistrationState = 'NotRegistered'
                    }
                }
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should still report the state Azure returned' {
                (Get-TargetResource @testParams).RegistrationState | Should -Be 'NotRegistered'
            }

            It 'Should register the provider from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Register-AzResourceProvider -Exactly 1
            }
        }

        Context -Name 'The provider is registered and it should be' -Fixture {
            BeforeAll {
                $testParams = @{
                    ProviderNamespace = 'Microsoft.DesktopVirtualization'
                    SubscriptionId    = '00000000-0000-0000-0000-000000000000'
                    Ensure            = 'Present'
                    Credential        = $Credential
                }

                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return @{
                        ProviderNamespace = 'Microsoft.DesktopVirtualization'
                        RegistrationState = 'Registered'
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }

            It 'Should not change anything from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Register-AzResourceProvider -Exactly 0
                Should -Invoke -CommandName Unregister-AzResourceProvider -Exactly 0
            }
        }

        Context -Name 'The reported registration state is transitional' -Fixture {
            BeforeAll {
                $testParams = @{
                    ProviderNamespace = 'Microsoft.DesktopVirtualization'
                    SubscriptionId    = '00000000-0000-0000-0000-000000000000'
                    RegistrationState = 'Registered'
                    Ensure            = 'Present'
                    Credential        = $Credential
                }

                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return @{
                        ProviderNamespace = 'Microsoft.DesktopVirtualization'
                        RegistrationState = 'Registered'
                    }
                }
            }

            It 'Should not compare RegistrationState when evaluating drift' {
                (Get-CompareParameters).ExcludedProperties | Should -Contain 'RegistrationState'
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'The provider is registered and it should not be' -Fixture {
            BeforeAll {
                $testParams = @{
                    ProviderNamespace = 'Microsoft.DesktopVirtualization'
                    SubscriptionId    = '00000000-0000-0000-0000-000000000000'
                    Ensure            = 'Absent'
                    Credential        = $Credential
                }

                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return @{
                        ProviderNamespace = 'Microsoft.DesktopVirtualization'
                        RegistrationState = 'Registered'
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should unregister the provider from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Unregister-AzResourceProvider -ParameterFilter {
                    $ProviderNamespace -eq 'Microsoft.DesktopVirtualization'
                } -Exactly 1
                Should -Invoke -CommandName Register-AzResourceProvider -Exactly 0
            }
        }

        Context -Name 'The Az context points at another subscription' -Fixture {
            BeforeAll {
                $testParams = @{
                    ProviderNamespace = 'Microsoft.DesktopVirtualization'
                    SubscriptionId    = '11111111-1111-1111-1111-111111111111'
                    Ensure            = 'Present'
                    Credential        = $Credential
                }

                Mock -CommandName Get-AzContext -MockWith {
                    return @{
                        Subscription = @{
                            Id = '00000000-0000-0000-0000-000000000000'
                        }
                    }
                }

                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return @{
                        ProviderNamespace = 'Microsoft.DesktopVirtualization'
                        RegistrationState = 'Registered'
                    }
                }
            }

            It 'Should move the context to the wanted subscription before reading' {
                $null = Get-TargetResource @testParams
                Should -Invoke -CommandName Set-AzContext -ParameterFilter {
                    $Subscription -eq '11111111-1111-1111-1111-111111111111'
                } -Exactly 1
            }
        }

        Context -Name 'The Az context already points at the wanted subscription' -Fixture {
            BeforeAll {
                $testParams = @{
                    ProviderNamespace = 'Microsoft.DesktopVirtualization'
                    SubscriptionId    = '00000000-0000-0000-0000-000000000000'
                    Ensure            = 'Present'
                    Credential        = $Credential
                }

                Mock -CommandName Get-AzContext -MockWith {
                    return @{
                        Subscription = @{
                            Id = '00000000-0000-0000-0000-000000000000'
                        }
                    }
                }

                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return @{
                        ProviderNamespace = 'Microsoft.DesktopVirtualization'
                        RegistrationState = 'Registered'
                    }
                }
            }

            It 'Should leave the context alone' {
                $null = Get-TargetResource @testParams
                Should -Invoke -CommandName Set-AzContext -Exactly 0
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Get-AzSubscription -MockWith {
                    return @(
                        @{
                            Id   = '00000000-0000-0000-0000-000000000000'
                            Name = 'Test'
                        }
                    )
                }

                Mock -CommandName Get-AzResourceProvider -MockWith {
                    return @(
                        @{
                            ProviderNamespace = 'Microsoft.DesktopVirtualization'
                            RegistrationState = 'Registered'
                        },
                        @{
                            ProviderNamespace = 'Microsoft.Quantum'
                            RegistrationState = 'NotRegistered'
                        }
                    )
                }
            }

            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Should export only the registered namespaces' {
                $null = Export-TargetResource @testParams
                Should -Invoke -CommandName Write-M365DSCHost -ParameterFilter {
                    $Message -like '*Microsoft.Quantum*'
                } -Exactly 0
            }

            It 'Should narrow the export to a single subscription when one is supplied' {
                $null = Export-TargetResource @testParams -SubscriptionId '11111111-1111-1111-1111-111111111111'
                Should -Invoke -CommandName Get-AzSubscription -Exactly 0
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
