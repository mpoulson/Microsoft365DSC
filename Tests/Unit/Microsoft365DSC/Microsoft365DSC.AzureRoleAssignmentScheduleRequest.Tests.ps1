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
    -DscResource 'AzureRoleAssignmentScheduleRequest' -GenericStubModule $GenericStubPath

Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope
        BeforeAll {
            $Global:CurrentModeIsExport = $false
            $secpasswd = ConvertTo-SecureString (New-Guid | Out-String) -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('tenantadmin@mydomain.com', $secpasswd)
            $Script:exportedInstance = $null
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
            $Script:AllAzureSchedules = $null
            $Script:AzureRoleDefinitions = $null

            Mock -CommandName Add-M365DSCTelemetryEvent -MockWith {
            }

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return 'Credentials'
            }

            Mock -CommandName Get-M365DSCAPIEndpoint -MockWith {
                return @{
                    AzureManagement = 'https://management.azure.com'
                }
            }

            Mock -CommandName Get-MgUser -MockWith {
                return @{
                    Id                = '12345678-1234-1234-1234-123456789012'
                    UserPrincipalName = 'AdeleV@contoso.onmicrosoft.com'
                }
            }

            Mock -CommandName Get-MgGroup -MockWith {
                return @{
                    Id          = '12345678-1234-1234-1234-123456789012'
                    DisplayName = 'SecurityGroup'
                }
            }

            Mock -CommandName Get-MgServicePrincipal -MockWith {
                return @{
                    Id          = '12345678-1234-1234-1234-123456789012'
                    DisplayName = 'TestServicePrincipal'
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }

            Mock -CommandName Save-M365DSCPartialExport -MockWith {
            }

            Mock -CommandName Get-M365DSCExportContentForResource -MockWith {
                return 'Export content'
            }

            $Script:exportedInstance = $null
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        # Test contexts
        Context -Name 'The instance should exist but it DOES NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    Principal             = 'AdeleV@contoso.onmicrosoft.com'
                    RoleDefinitionName    = 'Owner'
                    Scope                 = '/subscriptions/12345678-1234-1234-1234-123456789012'
                    PrincipalType         = 'User'
                    Ensure                = 'Present'
                    ApplicationId         = '12345678-1234-1234-1234-123456789012'
                    TenantId              = '12345678-1234-1234-1234-123456789012'
                    CertificateThumbprint = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    if ($Uri -match 'roleAssignmentSchedules')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": []}'
                        }
                    }
                    elseif ($Uri -match 'roleDefinitions')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"id": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635", "properties": {"roleName": "Owner"}}]}'
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = '{}'
                    }
                }
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should Create the instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRest -AtLeast 1
            }
        }

        Context -Name 'The instance exists but it SHOULD NOT' -Fixture {
            BeforeAll {
                $testParams = @{
                    Principal             = 'AdeleV@contoso.onmicrosoft.com'
                    RoleDefinitionName    = 'Owner'
                    Scope                 = '/subscriptions/12345678-1234-1234-1234-123456789012'
                    PrincipalType         = 'User'
                    Ensure                = 'Absent'
                    ApplicationId         = '12345678-1234-1234-1234-123456789012'
                    TenantId              = '12345678-1234-1234-1234-123456789012'
                    CertificateThumbprint = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
                }

                # Reset caches
                $Script:AllAzureSchedules = @()
                $Script:AzureRoleDefinitions = $null

                Mock -CommandName Invoke-AzRest -MockWith {
                    if ($Uri -match 'roleAssignmentSchedules\?')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"name": "12345", "properties": {"principalId": "12345678-1234-1234-1234-123456789012", "roleDefinitionId": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635", "scope": "/subscriptions/12345678-1234-1234-1234-123456789012", "status": "Provisioned", "startDateTime": "2024-01-15T08:00:00Z", "endDateTime": "2025-12-31T23:59:59Z"}}]}'
                        }
                    }
                    elseif ($Uri -match 'roleDefinitions')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"id": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635", "properties": {"roleName": "Owner"}}]}'
                        }
                    }
                    elseif ($Uri -match 'roleAssignmentScheduleRequests' -and $Method -eq 'PUT')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"id": "12345", "properties": {}}'
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = '{}'
                    }
                }
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should Remove the instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRest -AtLeast 1
            }
        }

        Context -Name 'The instance exists and values are already in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Principal             = 'AdeleV@contoso.onmicrosoft.com'
                    RoleDefinitionName    = 'Owner'
                    Scope                 = '/subscriptions/12345678-1234-1234-1234-123456789012'
                    PrincipalType         = 'User'
                    Ensure                = 'Present'
                    ApplicationId         = '12345678-1234-1234-1234-123456789012'
                    TenantId              = '12345678-1234-1234-1234-123456789012'
                    CertificateThumbprint = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
                }

                # Reset caches
                $Script:AllAzureSchedules = @()
                $Script:AzureRoleDefinitions = $null

                Mock -CommandName Invoke-AzRest -MockWith {
                    if ($Uri -match 'roleAssignmentSchedules')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"name": "12345", "properties": {"principalId": "12345678-1234-1234-1234-123456789012", "roleDefinitionId": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635", "scope": "/subscriptions/12345678-1234-1234-1234-123456789012", "status": "Provisioned", "startDateTime": "2024-01-15T08:00:00Z", "endDateTime": "2025-12-31T23:59:59Z"}}]}'
                        }
                    }
                    elseif ($Uri -match 'roleDefinitions')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"id": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635", "properties": {"roleName": "Owner"}}]}'
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = '{}'
                    }
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'Azure Gov endpoint handling' -Fixture {
            BeforeAll {
                $testParams = @{
                    Principal             = 'AdeleV@contoso.onmicrosoft.com'
                    RoleDefinitionName    = 'Owner'
                    Scope                 = '/subscriptions/12345678-1234-1234-1234-123456789012'
                    PrincipalType         = 'User'
                    Ensure                = 'Present'
                    ApplicationId         = '12345678-1234-1234-1234-123456789012'
                    TenantId              = '12345678-1234-1234-1234-123456789012'
                    CertificateThumbprint = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
                }

                $Script:AllAzureSchedules = $null

                Mock -CommandName Get-M365DSCAPIEndpoint -MockWith {
                    return @{
                        AzureManagement = 'https://management.usgovcloudapi.net'
                    }
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    return @{
                        StatusCode = 200
                        Content    = '{"value": []}'
                    }
                }
            }

            It 'Should use Azure Gov endpoint' {
                Get-TargetResource @testParams
                Should -Invoke -CommandName Get-M365DSCAPIEndpoint -Exactly 1
            }
        }

        Context -Name 'Management group scope handling' -Fixture {
            BeforeAll {
                $testParams = @{
                    Principal             = 'AdeleV@contoso.onmicrosoft.com'
                    RoleDefinitionName    = 'Reader'
                    Scope                 = '/providers/Microsoft.Management/managementGroups/mg-root'
                    PrincipalType         = 'User'
                    Ensure                = 'Present'
                    ApplicationId         = '12345678-1234-1234-1234-123456789012'
                    TenantId              = '12345678-1234-1234-1234-123456789012'
                    CertificateThumbprint = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
                }

                $Script:AllAzureSchedules = $null
                $Script:AzureRoleDefinitions = $null

                Mock -CommandName Invoke-AzRest -MockWith {
                    if ($Uri -match 'roleAssignmentSchedules')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"name": "mgschedule1", "properties": {"principalId": "12345678-1234-1234-1234-123456789012", "roleDefinitionId": "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7", "scope": "/providers/Microsoft.Management/managementGroups/mg-root", "status": "Provisioned", "startDateTime": "2024-01-15T08:00:00Z", "endDateTime": null}}]}'
                        }
                    }
                    elseif ($Uri -match 'roleDefinitions')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"id": "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7", "properties": {"roleName": "Reader"}}]}'
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = '{}'
                    }
                }
            }

            It 'Should return Present for management group scoped assignment' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return true from the Test method for management group scope' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    ApplicationId         = '12345678-1234-1234-1234-123456789012'
                    TenantId              = '12345678-1234-1234-1234-123456789012'
                    CertificateThumbprint = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
                }

                Mock -CommandName Invoke-AzRest -MockWith {
                    if ($Uri -match 'subscriptions\?')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"id": "/subscriptions/12345678-1234-1234-1234-123456789012", "displayName": "Test Subscription"}]}'
                        }
                    }
                    elseif ($Uri -match 'managementGroups\?')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": []}'
                        }
                    }
                    elseif ($Uri -match 'roleAssignmentSchedules')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"value": [{"name": "12345", "properties": {"principalId": "12345678-1234-1234-1234-123456789012", "roleDefinitionId": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635", "scope": "/subscriptions/12345678-1234-1234-1234-123456789012", "status": "Provisioned", "startDateTime": "2024-01-15T08:00:00Z", "endDateTime": "2025-12-31T23:59:59Z"}}]}'
                        }
                    }
                    elseif ($Uri -match 'roleDefinitions' -and $Uri -match '8e3af657')
                    {
                        return @{
                            StatusCode = 200
                            Content    = '{"id": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635", "properties": {"roleName": "Owner"}}'
                        }
                    }
                    return @{
                        StatusCode = 200
                        Content    = '{}'
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
