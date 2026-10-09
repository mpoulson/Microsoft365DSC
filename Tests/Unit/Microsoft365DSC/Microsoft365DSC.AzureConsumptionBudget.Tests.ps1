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
                    Name       = 'MonthlyPlatformBudget'
                    Scope      = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Category   = 'Cost'
                    Amount     = 5000
                    TimeGrain  = 'Monthly'
                    Ensure     = 'Present'
                    Credential = $Credential
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

            It 'Should create the budget with a PUT from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Method -eq 'PUT' } -Exactly 1
            }
        }

        Context -Name 'The instance exists and values are already in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Name       = 'MonthlyPlatformBudget'
                    Scope      = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Category   = 'Cost'
                    Amount     = 5000
                    TimeGrain  = 'Monthly'
                    Ensure     = 'Present'
                    Credential = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "MonthlyPlatformBudget",
    "properties": {
        "category": "Cost",
        "amount": 5000,
        "timeGrain": "Monthly"
    }
}
'@)
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return the amount from the Get method' {
                (Get-TargetResource @testParams).Amount | Should -Be 5000
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'The instance exists and values are NOT in the desired state' -Fixture {
            BeforeAll {
                $testParams = @{
                    Name       = 'MonthlyPlatformBudget'
                    Scope      = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Category   = 'Cost'
                    Amount     = 7500
                    TimeGrain  = 'Monthly'
                    Ensure     = 'Present'
                    Credential = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "MonthlyPlatformBudget",
    "properties": {
        "category": "Cost",
        "amount": 5000,
        "timeGrain": "Monthly"
    }
}
'@)
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should update the budget with a PUT from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Method -eq 'PUT' } -Exactly 1
            }
        }

        Context -Name 'The instance exists and it should not' -Fixture {
            BeforeAll {
                $testParams = @{
                    Name       = 'MonthlyPlatformBudget'
                    Scope      = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Ensure     = 'Absent'
                    Credential = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "MonthlyPlatformBudget",
    "properties": {
        "category": "Cost",
        "amount": 5000,
        "timeGrain": "Monthly"
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

            It 'Should remove the budget with a DELETE from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter { $Method -eq 'DELETE' } -Exactly 1
            }
        }

        Context -Name 'The notifications dictionary is flattened by the Get method' -Fixture {
            BeforeAll {
                $testParams = @{
                    Name       = 'MonthlyPlatformBudget'
                    Scope      = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Credential = $Credential
                }

                # The api keys notifications by name rather than returning an array, and the key is carried as the
                # {Name} property of each entry.
                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "MonthlyPlatformBudget",
    "properties": {
        "category": "Cost",
        "amount": 5000,
        "timeGrain": "Monthly",
        "notifications": {
            "Actual_GreaterThan_80_Percent": {
                "enabled": true,
                "operator": "GreaterThan",
                "threshold": 80,
                "thresholdType": "Actual",
                "contactEmails": [ "finops@contoso.com" ],
                "contactRoles": [ "Owner" ],
                "locale": "en-us"
            }
        }
    }
}
'@)
                }
            }

            It 'Should return one notification carrying the dictionary key as its name' {
                $result = Get-TargetResource @testParams
                $result.Notifications.Length | Should -Be 1
                $result.Notifications[0].Name | Should -Be 'Actual_GreaterThan_80_Percent'
                $result.Notifications[0].Threshold | Should -Be 80
                $result.Notifications[0].ContactEmails | Should -Be @('finops@contoso.com')
            }
        }

        Context -Name 'The filter is flattened by the Get method' -Fixture {
            BeforeAll {
                $testParams = @{
                    Name       = 'MonthlyPlatformBudget'
                    Scope      = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Credential = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "MonthlyPlatformBudget",
    "properties": {
        "category": "Cost",
        "amount": 5000,
        "timeGrain": "Monthly",
        "filter": {
            "and": [
                { "dimensions": { "name": "ResourceGroupName", "operator": "In", "values": [ "rg-platform-prod" ] } },
                { "tags": { "name": "CostCenter", "operator": "In", "values": [ "1234" ] } }
            ]
        }
    }
}
'@)
                }
            }

            It 'Should split the and clause into dimensions and tags' {
                $result = Get-TargetResource @testParams
                $result.FilterDimensions.Length | Should -Be 1
                $result.FilterDimensions[0].Name | Should -Be 'ResourceGroupName'
                $result.FilterTags.Length | Should -Be 1
                $result.FilterTags[0].Name | Should -Be 'CostCenter'
            }
        }

        Context -Name 'A single filter criterion is sent without an and wrapper' -Fixture {
            BeforeAll {
                $testParams = @{
                    Name             = 'MonthlyPlatformBudget'
                    Scope            = '/subscriptions/00000000-0000-0000-0000-000000000000'
                    Category         = 'Cost'
                    Amount           = 5000
                    TimeGrain        = 'Monthly'
                    FilterDimensions = [CimInstance[]]@(
                        (New-CimInstance -ClassName MSFT_AzureConsumptionBudgetFilterDimension -Property @{
                            Name     = 'ResourceGroupName'
                            Operator = 'In'
                            Values   = [String[]]@('rg-platform-prod')
                        } -ClientOnly)
                    )
                    Ensure           = 'Present'
                    Credential       = $Credential
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return $null
                }
            }

            It 'Should not wrap the single criterion in an and array' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -ParameterFilter {
                    $Method -eq 'PUT' -and $Payload -notlike '*"and"*' -and $Payload -like '*ResourceGroupName*'
                } -Exactly 1
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Get-M365DSCAzureBillingAccount -MockWith {
                    return @{
                        value = @()
                    }
                }

                Mock -CommandName Get-AzSubscription -MockWith {
                    return @(
                        @{
                            Id   = '00000000-0000-0000-0000-000000000000'
                            Name = 'Test'
                        }
                    )
                }

                Mock -CommandName Invoke-M365DSCAzureRestList -MockWith {
                    return @(
                        @{
                            name = 'MonthlyPlatformBudget'
                        }
                    )
                }

                Mock -CommandName Invoke-M365DSCAzureRestGet -MockWith {
                    return (ConvertFrom-Json @'
{
    "name": "MonthlyPlatformBudget",
    "properties": {
        "category": "Cost",
        "amount": 5000,
        "timeGrain": "Monthly"
    }
}
'@)
                }
            }

            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Should discover budgets on the subscriptions the caller can see' {
                $null = Export-TargetResource @testParams
                Should -Invoke -CommandName Get-AzSubscription
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
