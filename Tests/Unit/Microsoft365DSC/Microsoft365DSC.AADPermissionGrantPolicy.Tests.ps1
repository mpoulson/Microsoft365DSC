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

            Mock -CommandName Add-M365DSCTelemetryEvent -MockWith {
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

            Mock -CommandName New-MgBetaPolicyPermissionGrantPolicyInclude -MockWith {
            }

            Mock -CommandName Remove-MgBetaPolicyPermissionGrantPolicyInclude -MockWith {
            }

            Mock -CommandName New-MgBetaPolicyPermissionGrantPolicyExclude -MockWith {
            }

            Mock -CommandName Remove-MgBetaPolicyPermissionGrantPolicyExclude -MockWith {
            }

            Mock -CommandName Get-MgServicePrincipal -MockWith {
                return @{
                    AppId                  = '00000003-0000-0000-c000-000000000000'
                    Oauth2PermissionScopes = @(
                        @{ Id = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'; Value = 'User.Read' }
                        @{ Id = '37f7f235-527c-4136-accd-4a02d197296e'; Value = 'openid' }
                        @{ Id = '14dad69e-099b-42c9-810b-d002981feec1'; Value = 'profile' }
                    )
                    AppRoles               = @(
                        @{ Id = 'df021288-bdef-4463-88db-98f22de89214'; Value = 'User.Read.All' }
                        @{ Id = '19dbc75e-c2e2-444c-a770-ec596d83d9ad'; Value = 'Directory.Read.All' }
                    )
                }
            }

            Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                if ($All)
                {
                    return @(
                        @{
                            Id          = 'test-policy'
                            DisplayName = 'Test Permission Grant Policy'
                            Description = 'Test policy description'
                            Includes    = @()
                            Excludes    = @()
                        }
                    )
                }
                elseif ($PermissionGrantPolicyId)
                {
                    return @{
                        Id          = $PermissionGrantPolicyId
                        DisplayName = 'Test Permission Grant Policy'
                        Description = 'Test policy description'
                        Includes    = @()
                        Excludes    = @()
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
                return "AADPermissionGrantPolicy 'TestPolicy' {}`r`n"
            }

            Mock -CommandName New-M365DSCLogEntry -MockWith {
            }

            $Script:exportedInstance = $null
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
                        Includes    = @()
                        Excludes    = @()
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
                        Includes    = @()
                        Excludes    = @()
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
                        Includes    = @()
                        Excludes    = @()
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

        Context -Name 'Complex Scenario - Policy with multiple includes and excludes' -Fixture {
            BeforeAll {
                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    return @{
                        Id          = 'complex-policy'
                        DisplayName = 'Complex Policy'
                        Description = 'Policy with complex conditions'
                        Includes    = @(
                            @{
                                Id                       = 'include-1'
                                PermissionType           = 'delegated'
                                PermissionClassification = 'low'
                                ClientApplicationIds     = @('all')
                                ResourceApplication      = '00000003-0000-0000-c000-000000000000'
                                Permissions              = @('User.Read', 'openid', 'profile')
                            },
                            @{
                                Id                              = 'include-2'
                                PermissionType                  = 'delegated'
                                ClientApplicationIds            = @('app-id-1', 'app-id-2')
                                ClientApplicationsFromVerifiedPublisherOnly = $true
                                ResourceApplication             = 'any'
                                Permissions                     = @('all')
                            }
                        )
                        Excludes    = @(
                            @{
                                Id                       = 'exclude-1'
                                PermissionType           = 'application'
                                ClientApplicationIds     = @('all')
                                ResourceApplication      = 'any'
                                Permissions              = @('all')
                            }
                        )
                    }
                }
            }

            It 'Should correctly retrieve policy with multiple condition sets' {
                $result = Get-TargetResource -Id 'complex-policy' -Credential $Credential
                $result.Ensure | Should -Be 'Present'
                $result.Includes.Count | Should -Be 2
                $result.Excludes.Count | Should -Be 1
                $result.Includes[0].Id | Should -Be 'include-1'
                $result.Includes[1].Id | Should -Be 'include-2'
                $result.Excludes[0].Id | Should -Be 'exclude-1'
            }
        }

        Context -Name 'Complex Scenario - Condition set with arrays' -Fixture {
            BeforeAll {
                Mock -CommandName Get-MgBetaPolicyPermissionGrantPolicy -MockWith {
                    return @{
                        Id          = 'array-policy'
                        DisplayName = 'Array Test Policy'
                        Description = 'Tests array properties'
                        Includes    = @(
                            @{
                                Id                            = 'array-include'
                                PermissionType                = 'delegated'
                                ClientApplicationIds          = @('id1', 'id2', 'id3')
                                ClientApplicationPublisherIds = @('pub1', 'pub2')
                                ClientApplicationTenantIds    = @('tenant1')
                                Permissions                   = @('Permission1', 'Permission2', 'Permission3')
                                ResourceApplication           = '00000003-0000-0000-c000-000000000000'
                            }
                        )
                        Excludes    = @()
                    }
                }
            }

            It 'Should correctly handle array properties' {
                $result = Get-TargetResource -Id 'array-policy' -Credential $Credential
                $result.Includes[0].ClientApplicationIds.Count | Should -Be 3
                $result.Includes[0].ClientApplicationPublisherIds.Count | Should -Be 2
                $result.Includes[0].Permissions.Count | Should -Be 3
            }
        }

        Context -Name 'Complex Scenario - Helper function Test-ConditionSetsEqual' -Fixture {
            It 'Should return true for identical condition sets' {
                $set1 = @{
                    Id                       = 'test-id'
                    PermissionType           = 'delegated'
                    PermissionClassification = 'low'
                    ClientApplicationIds     = @('all')
                    Permissions              = @('User.Read')
                }

                $set2 = @{
                    Id                       = 'test-id'
                    PermissionType           = 'delegated'
                    PermissionClassification = 'low'
                    ClientApplicationIds     = @('all')
                    Permissions              = @('User.Read')
                }

                Test-ConditionSetsEqual -ConditionSet1 $set1 -ConditionSet2 $set2 | Should -Be $true
            }

            It 'Should return false for different permission types' {
                $set1 = @{
                    Id             = 'test-id'
                    PermissionType = 'delegated'
                }

                $set2 = @{
                    Id             = 'test-id'
                    PermissionType = 'application'
                }

                Test-ConditionSetsEqual -ConditionSet1 $set1 -ConditionSet2 $set2 | Should -Be $false
            }

            It 'Should return false for different array values' {
                $set1 = @{
                    Id          = 'test-id'
                    Permissions = @('User.Read', 'User.Write')
                }

                $set2 = @{
                    Id          = 'test-id'
                    Permissions = @('User.Read')
                }

                Test-ConditionSetsEqual -ConditionSet1 $set1 -ConditionSet2 $set2 | Should -Be $false
            }

            It 'Should return true for arrays in different order' {
                $set1 = @{
                    Id                   = 'test-id'
                    ClientApplicationIds = @('id1', 'id2', 'id3')
                }

                $set2 = @{
                    Id                   = 'test-id'
                    ClientApplicationIds = @('id3', 'id1', 'id2')
                }

                Test-ConditionSetsEqual -ConditionSet1 $set1 -ConditionSet2 $set2 | Should -Be $true
            }

            It 'Should return false when properties are missing' {
                $set1 = @{
                    Id             = 'test-id'
                    PermissionType = 'delegated'
                    Permissions    = @('User.Read')
                }

                $set2 = @{
                    Id             = 'test-id'
                    PermissionType = 'delegated'
                }

                Test-ConditionSetsEqual -ConditionSet1 $set1 -ConditionSet2 $set2 | Should -Be $false
            }
        }

        Context -Name 'Complex Scenario - Helper function Get-PermissionGrantConditionSetAsHashtable' -Fixture {
            It 'Should convert all properties correctly' {
                $conditionSet = [PSCustomObject]@{
                    Id                                          = 'test-id'
                    PermissionType                              = 'delegated'
                    PermissionClassification                    = 'low'
                    ClientApplicationIds                        = @('all')
                    ClientApplicationPublisherIds               = @('publisher1')
                    ClientApplicationTenantIds                  = @('tenant1')
                    CertifiedClientApplicationsOnly             = $false
                    ClientApplicationsFromVerifiedPublisherOnly = $true
                    Permissions                                 = @('User.Read')
                    ResourceApplication                         = '00000003-0000-0000-c000-000000000000'
                }

                $result = Get-PermissionGrantConditionSetAsHashtable -ConditionSet $conditionSet

                $result.Id | Should -Be 'test-id'
                $result.PermissionType | Should -Be 'delegated'
                $result.PermissionClassification | Should -Be 'low'
                $result.ClientApplicationIds.Count | Should -Be 1
                $result.ClientApplicationsFromVerifiedPublisherOnly | Should -Be $true
            }

            It 'Should handle null properties' {
                $conditionSet = [PSCustomObject]@{
                    Id             = 'test-id'
                    PermissionType = 'delegated'
                }

                $result = Get-PermissionGrantConditionSetAsHashtable -ConditionSet $conditionSet

                $result.ContainsKey('Id') | Should -Be $true
                $result.ContainsKey('PermissionType') | Should -Be $true
                $result.ContainsKey('PermissionClassification') | Should -Be $false
            }
        }

        Context -Name 'Complex Scenario - Helper function Get-PermissionGrantConditionSetAsParameters' -Fixture {
            It 'Should convert to API parameters correctly' {
                $conditionSet = [PSCustomObject]@{
                    Id                   = 'test-id'
                    PermissionType       = 'delegated'
                    ClientApplicationIds = @('all')
                    Permissions          = @('all')
                    ResourceApplication  = 'any'
                }

                $result = Get-PermissionGrantConditionSetAsParameters -ConditionSet $conditionSet

                $result.ContainsKey('PermissionGrantConditionSetId') | Should -Be $false
                $result.PermissionType | Should -Be 'delegated'
                $result.ClientApplicationIds | Should -Be @('all')
            }

            It 'Should skip empty arrays' {
                $conditionSet = [PSCustomObject]@{
                    Id                   = 'test-id'
                    PermissionType       = 'delegated'
                    ClientApplicationIds = @()
                }

                $result = Get-PermissionGrantConditionSetAsParameters -ConditionSet $conditionSet

                $result.ContainsKey('ClientApplicationIds') | Should -Be $false
            }

            It 'Should normalize asterisk wildcard to all for array properties' {
                $conditionSet = [PSCustomObject]@{
                    Id                            = 'test-id'
                    PermissionType                = 'delegated'
                    ClientApplicationIds          = @('*')
                    ClientApplicationPublisherIds = @('*')
                    ClientApplicationTenantIds    = @('*')
                    Permissions                   = @('*')
                    ResourceApplication           = 'any'
                }

                $result = Get-PermissionGrantConditionSetAsParameters -ConditionSet $conditionSet

                $result.ClientApplicationIds | Should -Be @('all')
                $result.ClientApplicationPublisherIds | Should -Be @('all')
                $result.ClientApplicationTenantIds | Should -Be @('all')
                $result.Permissions | Should -Be @('all')
            }

            It 'Should normalize asterisk to any for ResourceApplication' {
                $conditionSet = [PSCustomObject]@{
                    Id                  = 'test-id'
                    PermissionType      = 'delegated'
                    Permissions         = @('all')
                    ResourceApplication = '*'
                }

                $result = Get-PermissionGrantConditionSetAsParameters -ConditionSet $conditionSet

                $result.ResourceApplication | Should -Be 'any'
            }
        }

        Context -Name 'Complex Scenario - Helper function ConvertTo-PermissionGuid' -Fixture {
            It 'Should pass through wildcard all as all' {
                $result = ConvertTo-PermissionGuid -PermissionName 'all'
                $result | Should -Be 'all'
            }

            It 'Should convert asterisk wildcard to all' {
                $result = ConvertTo-PermissionGuid -PermissionName '*'
                $result | Should -Be 'all'
            }

            It 'Should convert any wildcard to all' {
                $result = ConvertTo-PermissionGuid -PermissionName 'any'
                $result | Should -Be 'all'
            }

            It 'Should pass through existing GUIDs unchanged' {
                $guid = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
                $result = ConvertTo-PermissionGuid -PermissionName $guid
                $result | Should -Be $guid
            }

            It 'Should resolve delegated permission name to GUID' {
                $result = ConvertTo-PermissionGuid -PermissionName 'User.Read' `
                    -ResourceApplicationId '00000003-0000-0000-c000-000000000000' `
                    -PermissionType 'delegated'
                $result | Should -Be 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
            }

            It 'Should resolve application permission name to GUID' {
                $result = ConvertTo-PermissionGuid -PermissionName 'User.Read.All' `
                    -ResourceApplicationId '00000003-0000-0000-c000-000000000000' `
                    -PermissionType 'application'
                $result | Should -Be 'df021288-bdef-4463-88db-98f22de89214'
            }

            It 'Should return name when ResourceApplication is any' {
                $result = ConvertTo-PermissionGuid -PermissionName 'User.Read' `
                    -ResourceApplicationId 'any' `
                    -PermissionType 'delegated'
                $result | Should -Be 'User.Read'
            }

            It 'Should return name when ResourceApplication is not specified' {
                $result = ConvertTo-PermissionGuid -PermissionName 'User.Read'
                $result | Should -Be 'User.Read'
            }

            It 'Should cache service principal and only call Get-MgServicePrincipal once for same ResourceApplication' {
                $Script:ServicePrincipalCache = @{}

                $result1 = ConvertTo-PermissionGuid -PermissionName 'User.Read' `
                    -ResourceApplicationId '00000003-0000-0000-c000-000000000000' `
                    -PermissionType 'delegated'
                $result2 = ConvertTo-PermissionGuid -PermissionName 'openid' `
                    -ResourceApplicationId '00000003-0000-0000-c000-000000000000' `
                    -PermissionType 'delegated'
                $result3 = ConvertTo-PermissionGuid -PermissionName 'User.Read.All' `
                    -ResourceApplicationId '00000003-0000-0000-c000-000000000000' `
                    -PermissionType 'application'

                $result1 | Should -Be 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
                $result2 | Should -Be '37f7f235-527c-4136-accd-4a02d197296e'
                $result3 | Should -Be 'df021288-bdef-4463-88db-98f22de89214'

                Should -Invoke -CommandName 'Get-MgServicePrincipal' -Exactly 1
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
                                Includes    = @()
                                Excludes    = @()
                            },
                            @{
                                Id          = 'test-policy-2'
                                DisplayName = 'Test Policy 2'
                                Description = 'Second test policy'
                                Includes    = @()
                                Excludes    = @()
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

        Context -Name 'ReverseDSC Tests - Export with Condition Sets' -Fixture {
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
                                Id          = 'microsoft-all-application-permissions'
                                DisplayName = 'All application permissions, for any client app'
                                Description = 'Includes all application permissions for all APIs.'
                                Includes    = @(
                                    @{
                                        Id                                          = 'include-1'
                                        PermissionType                              = 'application'
                                        PermissionClassification                    = 'all'
                                        ClientApplicationIds                        = @('all')
                                        ClientApplicationPublisherIds               = @('all')
                                        ClientApplicationTenantIds                  = @('all')
                                        ClientApplicationsFromVerifiedPublisherOnly = $false
                                        ResourceApplication                         = 'any'
                                        Permissions                                 = @('all')
                                    }
                                )
                                Excludes    = @(
                                    @{
                                        Id                   = 'exclude-1'
                                        PermissionType       = 'application'
                                        ClientApplicationIds = @('all')
                                        ResourceApplication  = 'any'
                                        Permissions          = @('all')
                                    }
                                )
                            }
                        )
                    }
                    return $null
                }
            }

            It 'Should Reverse Engineer resource with condition sets from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
