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
    -DscResource 'AzureRoleEligibilityScheduleRequest' -GenericStubModule $GenericStubPath

Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope
        BeforeAll {
            $Global:CurrentModeIsExport = $false
            $secpasswd = ConvertTo-SecureString (New-Guid | Out-String) -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('tenantadmin@mydomain.com', $secpasswd)
            $Script:exportedInstances = $null
            $Script:ExportMode = $null

            Mock -CommandName Add-M365DSCTelemetryEvent -MockWith {
            }

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return 'Credentials'
            }

            Mock -CommandName Invoke-MgGraphRequest -MockWith {
                if ($Uri -like '*roleEligibilitySchedules*')
                {
                    return @{
                        value = @(
                            @{
                                id               = '12345-12345-12345-12345-12345'
                                roleDefinitionId = 'roledef-12345'
                                directoryScopeId = '/subscriptions/00000000-0000-0000-0000-000000000000'
                                principalId      = '123456'
                                scheduleInfo     = @{
                                    startDateTime = '2021-09-01T02:40:44Z'
                                    expiration    = @{
                                        endDateTime = '2025-10-31T02:40:09Z'
                                        type        = 'afterDateTime'
                                    }
                                }
                            }
                        )
                    }
                }
                elseif ($Uri -like '*roleDefinitions*')
                {
                    return @{
                        value = @(
                            @{
                                id          = 'roledef-12345'
                                displayName = 'Contributor'
                                scope       = '/subscriptions/00000000-0000-0000-0000-000000000000'
                            }
                        )
                    }
                }
                else
                {
                    return @{ value = @() }
                }
            }

            Mock -CommandName Get-MgUser -MockWith {
                return @{
                    Id                = '123456'
                    UserPrincipalName = 'John.Smith@contoso.com'
                }
            }

            Mock -CommandName Get-MgBetaDirectoryObjectById -MockWith {
                return @{
                    Id                   = '123456'
                    AdditionalProperties = @{
                        '@odata.type'     = '#microsoft.graph.user'
                        userPrincipalName = 'John.Smith@contoso.com'
                    }
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstance = $null
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
            $Script:AllSchedules = $null
            $Script:RoleDefinitions = $null
        }
        # Test contexts
        Context -Name 'The instance should exist but it DOES NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    DirectoryScopeId = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Ensure           = 'Present'
                    Principal        = 'John.Smith@contoso.com'
                    PrincipalType    = 'User'
                    RoleDefinition   = 'Contributor'
                    ScheduleInfo     = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestSchedule -Property @{
                        startDateTime = '2023-09-01T02:40:44Z'
                        expiration    = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestScheduleExpiration -Property @{
                            endDateTime = '2025-10-31T02:40:09Z'
                            type        = 'afterDateTime'
                        } -ClientOnly
                    } -ClientOnly
                    Credential       = $Credential
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    if ($Uri -like '*roleDefinitions*')
                    {
                        return @{
                            value = @(
                                @{
                                    id          = 'roledef-12345'
                                    displayName = 'Contributor'
                                    scope       = '/subscriptions/00000000-0000-0000-0000-000000000000'
                                }
                            )
                        }
                    }
                    return @{
                        value = @()
                    }
                }
                $Script:AllSchedules = $null
                $Script:RoleDefinitions = $null
            }
            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }
            It 'Should Create the instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 1 -ParameterFilter { $Method -eq 'POST' }
            }
        }

        Context -Name 'The instance exists but it SHOULD NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    DirectoryScopeId = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Ensure           = 'Absent'
                    PrincipalType    = 'User'
                    Principal        = 'John.Smith@contoso.com'
                    RoleDefinition   = 'Contributor'
                    ScheduleInfo     = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestSchedule -Property @{
                        expiration = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestScheduleExpiration -Property @{
                            type = 'afterDateTime'
                        } -ClientOnly
                    } -ClientOnly
                    Credential       = $Credential
                }

                $Script:AllSchedules = $null
                $Script:RoleDefinitions = $null
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should Remove the instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 1 -ParameterFilter { $Method -eq 'POST' }
            }
        }

        Context -Name 'The instance Exists and Values are already in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    DirectoryScopeId = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Ensure           = 'Present'
                    PrincipalType    = 'User'
                    Principal        = 'John.Smith@contoso.com'
                    RoleDefinition   = 'Contributor'
                    ScheduleInfo     = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestSchedule -Property @{
                        expiration = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestScheduleExpiration -Property @{
                            type = 'afterDateTime'
                        } -ClientOnly
                    } -ClientOnly
                    Credential       = $Credential
                }

                $Script:AllSchedules = $null
                $Script:RoleDefinitions = $null
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'The instance Exists and specified Values are NOT in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    DirectoryScopeId = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Ensure           = 'Present'
                    PrincipalType    = 'User'
                    Principal        = 'John.Smith@contoso.com'
                    RoleDefinition   = 'Contributor'
                    ScheduleInfo     = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestSchedule -Property @{
                        startDateTime = '2023-01-01T02:40:44Z' # Drift
                        expiration    = New-CimInstance -ClassName MSFT_AzureRoleEligibilityScheduleRequestScheduleExpiration -Property @{
                            endDateTime = '2025-10-31T02:40:09Z'
                            type        = 'afterDateTime'
                        } -ClientOnly
                    } -ClientOnly
                    Credential       = $Credential
                }

                $Script:AllSchedules = $null
                $Script:RoleDefinitions = $null
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set to Update the instance' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 1 -ParameterFilter { $Method -eq 'POST' }
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }
                $Script:AllSchedules = $null
                $Script:RoleDefinitions = $null
            }

            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
