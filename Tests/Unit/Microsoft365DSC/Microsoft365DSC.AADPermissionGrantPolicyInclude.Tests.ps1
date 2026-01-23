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

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return 'Credentials'
            }

            Mock -CommandName Get-PSSession -MockWith {
            }

            Mock -CommandName Remove-PSSession -MockWith {
            }

            Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                return @{
                    Id          = 'test-policy'
                    DisplayName = 'Test Permission Grant Policy'
                }
            }

            Mock -CommandName Invoke-MgGraphRequest -MockWith {
                param($Method, $Uri, $Body, $ContentType)
                
                if ($Method -eq 'GET' -and $Uri -like '*includes/test-include*')
                {
                    return @{
                        id                                          = 'test-include'
                        permissionType                              = 'delegated'
                        resourceApplication                         = 'any'
                        permissions                                 = @('User.Read.All')
                        permissionClassification                    = 'low'
                        clientApplicationIds                        = @('all')
                        clientApplicationTenantIds                  = @('all')
                        clientApplicationPublisherIds               = @('all')
                        clientApplicationsFromVerifiedPublisherOnly = $false
                    }
                }
                elseif ($Method -eq 'GET' -and $Uri -like '*includes')
                {
                    return @{
                        value = @(
                            @{
                                id                 = 'test-include-1'
                                permissionType     = 'delegated'
                                resourceApplication = 'any'
                            },
                            @{
                                id                 = 'test-include-2'
                                permissionType     = 'application'
                                resourceApplication = 'any'
                            }
                        )
                    }
                }
                return $null
            }

            Mock -CommandName Write-M365DSCHost -MockWith {
            }

            Mock -CommandName Save-M365DSCPartialExport -MockWith {
            }

            Mock -CommandName Update-M365DSCExportAuthenticationResults -MockWith {
                return @{}
            }

            Mock -CommandName Get-M365DSCExportContentForResource -MockWith {
                return "AADPermissionGrantPolicyInclude 'TestInclude' {}`r`n"
            }

            Mock -CommandName New-M365DSCLogEntry -MockWith {
            }

            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        # Test contexts
        Context -Name 'The Include condition should exist but it DOES NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                                          = 'test-include'
                    PermissionGrantPolicyId                     = 'test-policy'
                    PermissionType                              = 'delegated'
                    ResourceApplication                         = 'any'
                    Permissions                                 = @('User.Read.All')
                    PermissionClassification                    = 'low'
                    ClientApplicationIds                        = @('all')
                    ClientApplicationTenantIds                  = @('all')
                    ClientApplicationPublisherIds               = @('all')
                    ClientApplicationsFromVerifiedPublisherOnly = $false
                    Ensure                                      = 'Present'
                    Credential                                  = $Credential
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    param($Method, $Uri)
                    
                    if ($Method -eq 'GET' -and $Uri -like '*includes/test-include*')
                    {
                        return $null
                    }
                    return $null
                }
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should create the Include condition from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Invoke-MgGraphRequest' -ParameterFilter { $Method -eq 'POST' } -Exactly 1
            }
        }

        Context -Name 'The Include condition exists but it SHOULD NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                      = 'test-include'
                    PermissionGrantPolicyId = 'test-policy'
                    Ensure                  = 'Absent'
                    Credential              = $Credential
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    param($Method, $Uri)
                    
                    if ($Method -eq 'GET' -and $Uri -like '*includes/test-include*')
                    {
                        return @{
                            id                 = 'test-include'
                            permissionType     = 'delegated'
                            resourceApplication = 'any'
                        }
                    }
                    return $null
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should remove the Include condition from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Invoke-MgGraphRequest' -ParameterFilter { $Method -eq 'DELETE' } -Exactly 1
            }
        }

        Context -Name 'The Include condition Exists and Values are already in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                                          = 'test-include'
                    PermissionGrantPolicyId                     = 'test-policy'
                    PermissionType                              = 'delegated'
                    ResourceApplication                         = 'any'
                    Permissions                                 = @('User.Read.All')
                    PermissionClassification                    = 'low'
                    ClientApplicationIds                        = @('all')
                    ClientApplicationTenantIds                  = @('all')
                    ClientApplicationPublisherIds               = @('all')
                    ClientApplicationsFromVerifiedPublisherOnly = $false
                    Ensure                                      = 'Present'
                    Credential                                  = $Credential
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    param($Method, $Uri)
                    
                    if ($Method -eq 'GET' -and $Uri -like '*includes/test-include*')
                    {
                        return @{
                            id                                          = 'test-include'
                            permissionType                              = 'delegated'
                            resourceApplication                         = 'any'
                            permissions                                 = @('User.Read.All')
                            permissionClassification                    = 'low'
                            clientApplicationIds                        = @('all')
                            clientApplicationTenantIds                  = @('all')
                            clientApplicationPublisherIds               = @('all')
                            clientApplicationsFromVerifiedPublisherOnly = $false
                        }
                    }
                    return $null
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'Values are NOT in the desired state (Include condition needs recreation)' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                                          = 'test-include'
                    PermissionGrantPolicyId                     = 'test-policy'
                    PermissionType                              = 'application'
                    ResourceApplication                         = 'any'
                    Permissions                                 = @('User.Read.All', 'Mail.Read')
                    PermissionClassification                    = 'medium'
                    ClientApplicationIds                        = @('all')
                    ClientApplicationTenantIds                  = @('all')
                    ClientApplicationPublisherIds               = @('all')
                    ClientApplicationsFromVerifiedPublisherOnly = $true
                    Ensure                                      = 'Present'
                    Credential                                  = $Credential
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    param($Method, $Uri)
                    
                    if ($Method -eq 'GET' -and $Uri -like '*includes/test-include*')
                    {
                        return @{
                            id                                          = 'test-include'
                            permissionType                              = 'delegated'
                            resourceApplication                         = 'any'
                            permissions                                 = @('User.Read.All')
                            permissionClassification                    = 'low'
                            clientApplicationIds                        = @('all')
                            clientApplicationTenantIds                  = @('all')
                            clientApplicationPublisherIds               = @('all')
                            clientApplicationsFromVerifiedPublisherOnly = $false
                        }
                    }
                    return $null
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should recreate the Include condition in the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName 'Invoke-MgGraphRequest' -ParameterFilter { $Method -eq 'DELETE' } -Exactly 1
                Should -Invoke -CommandName 'Invoke-MgGraphRequest' -ParameterFilter { $Method -eq 'POST' } -Exactly 1
            }
        }

        Context -Name 'Parent policy does not exist' -Fixture {
            BeforeAll {
                $testParams = @{
                    Id                      = 'test-include'
                    PermissionGrantPolicyId = 'nonexistent-policy'
                    PermissionType          = 'delegated'
                    ResourceApplication     = 'any'
                    Ensure                  = 'Present'
                    Credential              = $Credential
                }

                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    return $null
                }
            }

            It 'Should return Absent from the Get method when parent policy does not exist' {
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

                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    if ($All)
                    {
                        return @(
                            @{
                                Id          = 'test-policy-1'
                                DisplayName = 'Test Policy 1'
                            }
                        )
                    }
                    return $null
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    param($Method, $Uri)
                    
                    if ($Method -eq 'GET' -and $Uri -like '*includes' -and $Uri -notlike '*includes/*')
                    {
                        return @{
                            value = @(
                                @{
                                    id                 = 'test-include-1'
                                    permissionType     = 'delegated'
                                    resourceApplication = 'any'
                                },
                                @{
                                    id                 = 'test-include-2'
                                    permissionType     = 'application'
                                    resourceApplication = 'any'
                                }
                            )
                        }
                    }
                    elseif ($Method -eq 'GET' -and $Uri -like '*includes/*')
                    {
                        $includeId = $Uri.Split('/')[-1]
                        return @{
                            id                 = $includeId
                            permissionType     = 'delegated'
                            resourceApplication = 'any'
                        }
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
