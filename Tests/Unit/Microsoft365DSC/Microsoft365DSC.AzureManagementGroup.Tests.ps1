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

            Mock -CommandName Get-MSCloudLoginConnectionProfile -MockWith {
                return @{
                    ManagementUrl = 'https://management.usgovcloudapi.net/'
                }
            }

            # The reads go through the shared Azure helpers rather than through Invoke-AzRestMethod directly, so the
            # helpers are what the tests replace. The writes are issued by the resource itself.
            Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                return $null
            }

            Mock -CommandName Invoke-M365DSCAzureRestList -MockWith {
                return @()
            }

            Mock -CommandName Invoke-AzRestMethod -MockWith {
                return @{
                    StatusCode = 200
                    Content    = '{}'
                }
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances = $null
            $Script:ExportMode = $false
        }

        # Test contexts
        Context -Name "The instance doesn't exist and it should" -Fixture {
            BeforeAll {
                $testParams = @{
                    GroupId       = 'mg-platform'
                    DisplayName   = 'Platform'
                    ParentGroupId = 'mg-contoso-root'
                    Subscriptions = @('00000000-0000-0000-0000-000000000000')
                    Ensure        = 'Present'
                    Credential    = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return $null
                }
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should create the group with a PUT and then assign the subscription' {
                Set-TargetResource @testParams

                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PUT' -and $Uri -notlike '*/subscriptions/*'
                } -Exactly 1

                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PUT' -and $Uri -like '*managementGroups/mg-platform/subscriptions/00000000-0000-0000-0000-000000000000*'
                } -Exactly 1
            }
        }

        Context -Name 'The instance exists and values are already in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    GroupId       = 'mg-platform'
                    DisplayName   = 'Platform'
                    ParentGroupId = 'mg-contoso-root'
                    Subscriptions = @('00000000-0000-0000-0000-000000000000')
                    Ensure        = 'Present'
                    Credential    = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "mg-platform",
    "properties": {
        "displayName": "Platform",
        "details": { "parent": { "name": "mg-contoso-root" } },
        "children": [
            { "type": "/subscriptions", "name": "00000000-0000-0000-0000-000000000000" }
        ]
    }
}
'@)
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should report the parent group and the assigned subscriptions' {
                $result = Get-TargetResource @testParams
                $result.ParentGroupId | Should -Be 'mg-contoso-root'
                $result.Subscriptions | Should -Be @('00000000-0000-0000-0000-000000000000')
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }

            It 'Should not issue any write from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -Exactly 0
            }
        }

        Context -Name 'The display name is NOT in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    GroupId     = 'mg-platform'
                    DisplayName = 'Platform and Shared Services'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "mg-platform",
    "properties": {
        "displayName": "Platform",
        "children": []
    }
}
'@)
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should update the group with a PATCH rather than a PUT' {
                Set-TargetResource @testParams

                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Method -eq 'PATCH' } -Exactly 1
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Method -eq 'PUT' } -Exactly 0
            }
        }

        Context -Name 'A subscription has to be added and another removed' -Fixture {
            BeforeAll {
                $testParams = @{
                    GroupId       = 'mg-platform'
                    DisplayName   = 'Platform'
                    Subscriptions = @('11111111-1111-1111-1111-111111111111')
                    Ensure        = 'Present'
                    Credential    = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "mg-platform",
    "properties": {
        "displayName": "Platform",
        "children": [
            { "type": "/subscriptions", "name": "00000000-0000-0000-0000-000000000000" }
        ]
    }
}
'@)
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should add the wanted subscription and remove the unwanted one' {
                Set-TargetResource @testParams

                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PUT' -and $Uri -like '*subscriptions/11111111-1111-1111-1111-111111111111*'
                } -Exactly 1

                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'DELETE' -and $Uri -like '*subscriptions/00000000-0000-0000-0000-000000000000*'
                } -Exactly 1
            }
        }

        Context -Name 'Subscriptions is left out of the configuration' -Fixture {
            BeforeAll {
                $testParams = @{
                    GroupId     = 'mg-platform'
                    DisplayName = 'Platform'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "mg-platform",
    "properties": {
        "displayName": "Platform",
        "children": [
            { "type": "/subscriptions", "name": "00000000-0000-0000-0000-000000000000" }
        ]
    }
}
'@)
                }
            }

            It 'Should leave the existing assignments untouched' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Uri -like '*/subscriptions/*' } -Exactly 0
            }
        }

        Context -Name 'The instance exists and it should not' -Fixture {
            BeforeAll {
                $testParams = @{
                    GroupId    = 'mg-platform'
                    Ensure     = 'Absent'
                    Credential = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "mg-platform",
    "properties": {
        "displayName": "Platform",
        "children": [
            { "type": "/subscriptions", "name": "00000000-0000-0000-0000-000000000000" }
        ]
    }
}
'@)
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should move the subscriptions out before deleting the group' {
                Set-TargetResource @testParams

                # Azure refuses to delete a management group that still holds children.
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'DELETE' -and $Uri -like '*subscriptions/00000000-0000-0000-0000-000000000000*'
                } -Exactly 1

                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'DELETE' -and $Uri -notlike '*/subscriptions/*'
                } -Exactly 1
            }
        }

        Context -Name 'Azure returns an unsuccessful status code' -Fixture {
            BeforeAll {
                $testParams = @{
                    GroupId     = 'mg-platform'
                    DisplayName = 'Platform'
                    Ensure      = 'Present'
                    Credential  = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return $null
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith {
                    return @{
                        StatusCode = 403
                        Content    = '{"error":{"code":"AuthorizationFailed"}}'
                    }
                }
            }

            It 'Should throw rather than report success' {
                { Set-TargetResource @testParams } | Should -Throw
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestList -MockWith {
                    return @(
                        @{
                            name = 'mg-platform'
                        }
                    )
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "mg-platform",
    "properties": {
        "displayName": "Platform",
        "children": []
    }
}
'@)
                }
            }

            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Should read each group with its children expanded' {
                $null = Export-TargetResource @testParams
                Should -Invoke -CommandName Invoke-M365DSCAzureRestGet -ParameterFilter { $Uri -like '*expand=children*' }
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
