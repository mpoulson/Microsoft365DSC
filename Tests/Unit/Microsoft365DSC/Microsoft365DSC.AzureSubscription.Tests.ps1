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

            $invoiceSectionId = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"

            Mock -ModuleName M365DSCUtil -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return "Credentials"
            }

            Mock -CommandName Enable-AzSubscription -MockWith {
            }

            Mock -CommandName Disable-AzSubscription -MockWith {
            }

            Mock -CommandName Start-Sleep -MockWith {
            }

            # Billing collection endpoints answer with a {value} envelope. A single instance GET answers with the
            # resource itself, so the resource only ever issues collection requests.
            $billingSubscriptionResponse = {
                return @{
                    StatusCode = 200
                    Content = ConvertTo-Json (@{
                        value = @(
                            @{
                                name = (New-Guid).ToString()
                                properties = @{
                                    displayName = 'Test'
                                    status      = 'Active'
                                    invoiceSectionId = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"
                                }
                            }
                        )
                    }) -Depth 10
                }
            }

            Mock -CommandName Invoke-AzRestMethod -MockWith $billingSubscriptionResponse

            # Paging now happens inside Invoke-M365DSCAzureRestList, which lives in the Microsoft365DSC module
            # rather than in this resource, so the collection reads have to be mocked in that scope as well.
            Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -MockWith $billingSubscriptionResponse

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances =$null
            $Script:ExportMode = $false
        }
        # Test contexts
        Context -Name "The instance doesn't exists and it should" -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName         = "Test"
                    InvoiceSectionId    = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"
                    Status              = "Active"
                    Ensure              = 'Present'
                    Credential          = $Credential;
                }

                $emptyResponse = {
                    return @{
                        StatusCode = 200
                        Content = "{}"
                    }
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $emptyResponse
                Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -MockWith $emptyResponse
            }

            It 'Should return Absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }
        }

        Context -Name "The instance exists and values are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName         = "Test"
                    InvoiceSectionId    = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"
                    Status              = "Active"
                    Ensure              = 'Present'
                    Credential          = $Credential;
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return the identifier assigned by the billing platform from the Get method' {
                (Get-TargetResource @testParams).Id | Should -Not -BeNullOrEmpty
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }

            It 'Should call the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-AzRestMethod -Exactly 1
            }

            It 'Should not change the status of a subscription that is already in the desired state' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Enable-AzSubscription -Exactly 0
                Should -Invoke -CommandName Disable-AzSubscription -Exactly 0
            }
        }

        Context -Name "The instance exists and values are NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName         = "Test"
                    Status              = "Disabled" # Drift
                    InvoiceSectionId    = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"
                    Ensure              = 'Present'
                    Credential          = $Credential;
                }
            }

            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Disable-AzSubscription -Exactly 1
            }

            It 'Should not enable a subscription that should be disabled' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Enable-AzSubscription -Exactly 0
            }
        }

        Context -Name 'The subscription is disabled and should be active' -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName         = "Test"
                    Status              = "Active"
                    InvoiceSectionId    = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"
                    Ensure              = 'Present'
                    Credential          = $Credential;
                }

                $disabledResponse = {
                    return @{
                        StatusCode = 200
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    name = (New-Guid).ToString()
                                    properties = @{
                                        displayName = 'Test'
                                        status      = 'Disabled'
                                    }
                                }
                            )
                        }) -Depth 10
                    }
                }

                Mock -CommandName Invoke-AzRestMethod -MockWith $disabledResponse
                Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -MockWith $disabledResponse
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should enable the subscription from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Enable-AzSubscription -Exactly 1
            }
        }

        Context -Name 'The reported status is not one that can be set' -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName         = "Test"
                    Status              = "Expired"
                    InvoiceSectionId    = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"
                    Ensure              = 'Present'
                    Credential          = $Credential;
                }
            }

            It 'Should not attempt to enable or disable the subscription' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Enable-AzSubscription -Exactly 0
                Should -Invoke -CommandName Disable-AzSubscription -Exactly 0
            }
        }

        Context -Name 'The instance is spread across multiple pages of results' -Fixture {
            BeforeAll {
                $testParams = @{
                    DisplayName         = "Second Page Subscription"
                    InvoiceSectionId    = "/providers/Microsoft.Billing/billingAccounts/0b32abd9-f0e6-4fc9-8b2f-404350313179:0b32abd9-f0e6-4fc9-8b2f-404350313179_2019-05-31/billingProfiles/OHZY-JSSA-BG7-M77W-XXX/invoiceSections/E6RO-KYS7-P2D-MAOR-SGB"
                    Status              = "Active"
                    Ensure              = 'Present'
                    Credential          = $Credential;
                }

                $firstPageResponse = {
                    return @{
                        StatusCode = 200
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    name = (New-Guid).ToString()
                                    properties = @{
                                        displayName = 'First Page Subscription'
                                        status      = 'Active'
                                    }
                                }
                            )
                            nextLink = 'https://management.usgovcloudapi.net/providers/Microsoft.Billing/billingSubscriptions?api-version=2024-04-01&$skiptoken=page2'
                        }) -Depth 10
                    }
                }

                $secondPageResponse = {
                    return @{
                        StatusCode = 200
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    name = (New-Guid).ToString()
                                    properties = @{
                                        displayName = 'Second Page Subscription'
                                        status      = 'Active'
                                    }
                                }
                            )
                        }) -Depth 10
                    }
                }

                Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -ParameterFilter { $Uri -notlike '*$skiptoken*' } -MockWith $firstPageResponse
                Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -ParameterFilter { $Uri -like '*$skiptoken*' } -MockWith $secondPageResponse
            }

            It 'Should follow the nextLink and find the instance on the second page' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should request every page of results' {
                $null = Get-TargetResource @testParams
                Should -Invoke -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -Exactly 2
            }
        }

        Context -Name 'Azure returns an unsuccessful status code' -Fixture {
            It 'Should throw rather than report an empty result' {
                {
                    Assert-M365DSCAzureResponse -Response @{
                        StatusCode = 403
                        Content    = '{"error":{"code":"AuthorizationFailed"}}'
                    } -Operation 'retrieving billing subscriptions'
                } | Should -Throw -ExpectedMessage '*403*'
            }

            It 'Should not throw on a successful status code' {
                {
                    Assert-M365DSCAzureResponse -Response @{
                        StatusCode = 200
                        Content    = '{}'
                    } -Operation 'retrieving billing subscriptions'
                } | Should -Not -Throw
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential  = $Credential;
                }
            }
            It 'Should Reverse Engineer resource from the Export method' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }
        }

        Context -Name 'ReverseDSC Tests against an Enterprise Agreement billing account' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential  = $Credential;
                }

                $eaAccountResponse = {
                    return @{
                        StatusCode = 200
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    name = '5538726'
                                    properties = @{
                                        displayName   = 'Contoso EA Enrollment'
                                        agreementType = 'EnterpriseAgreement'
                                    }
                                }
                            )
                        }) -Depth 10
                    }
                }

                $eaSubscriptionResponse = {
                    return @{
                        StatusCode = 200
                        Content = ConvertTo-Json (@{
                            value = @(
                                @{
                                    name = (New-Guid).ToString()
                                    properties = @{
                                        displayName = 'EA Subscription'
                                        status      = 'Active'
                                    }
                                }
                            )
                        }) -Depth 10
                    }
                }

                # Enterprise Agreement enrollments have no billing profiles at all and answer this request with
                # HTTP 400 InvoiceBillingAccountName.
                $billingProfileResponse = {
                    return @{
                        StatusCode = 400
                        Content = '{"code":"InvalidBillingAccountName","message":"Invalid billing account name. Billing profiles is not supported on EA enrollment billing accounts."}'
                    }
                }

                Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -ParameterFilter { $Uri -like '*billingaccounts/?api-version*' } -MockWith $eaAccountResponse
                Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -ParameterFilter { $Uri -like '*billingAccounts/5538726/billingSubscriptions*' } -MockWith $eaSubscriptionResponse
                Mock -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -ParameterFilter { $Uri -like '*billingprofiles*' } -MockWith $billingProfileResponse
            }

            It 'Should Reverse Engineer subscriptions from an Enterprise Agreement billing account' {
                $result = Export-TargetResource @testParams
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Should never request billing profiles' {
                $null = Export-TargetResource @testParams
                Should -Invoke -ModuleName Microsoft365DSC -CommandName Invoke-AzRestMethod -ParameterFilter { $Uri -like '*billingprofiles*' } -Exactly 0
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
