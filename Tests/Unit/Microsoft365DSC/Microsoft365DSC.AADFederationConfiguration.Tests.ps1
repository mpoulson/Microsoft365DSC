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

            Mock -ModuleName M365DSCUtil -CommandName Resolve-Credentials -MockWith {
                param([string]$UserName)
                return $Credential
            }

            Mock -CommandName Get-MSCloudLoginConnectionProfile -MockWith {
            }

            Mock -CommandName Invoke-MgGraphRequest -MockWith {
                return @{
                    value = @(
                        @{
                            issuerUri                       = 'https://contoso.com/issuerUri'
                            displayName                     = 'contoso display name'
                            metadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                            passiveSignInUri                = 'https://contoso.com/signin'
                            preferredAuthenticationProtocol = 'wsFed'
                            domains                         = @(
                                @{
                                    "@odata.type" = "microsoft.graph.externalDomainName"
                                    id            = "contoso.com"
                                }
                            )
                            signingCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                            nextSigningCertificate          = 'MIIDADCCAeigAwIBAgIQEX41y8r7'
                        }
                    )
                }
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return "Credentials"
            }

            # Mock Write-M365DSCHost to hide output during the tests
            Mock -CommandName Write-M365DSCHost -MockWith {
            }
            $Script:exportedInstances =$null
            $Script:ExportMode = $false
        }
        # Test contexts
        Context -Name "The instance should exist but it DOES NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    IssuerUri                       = 'https://contoso.com/issuerUri'
                    DisplayName                     = 'contoso display name'
                    MetadataExchangeUri             ='https://contoso.com/metadataExchangeUri'
                    PassiveSignInUri                = 'https://contoso.com/signin'
                    PreferredAuthenticationProtocol = 'wsFed'
                    Domains                         = @('contoso.com')
                    SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                    Ensure                          = 'Present'
                    Credential          = $Credential;
                }

                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    return $null
                }
            }
            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should create a new instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 2
            }
        }

        Context -Name "The instance exists but it SHOULD NOT" -Fixture {
            BeforeAll {
                $testParams = @{
                    IssuerUri                       = 'https://contoso.com/issuerUri'
                    DisplayName                     = 'contoso display name'
                    MetadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                    PassiveSignInUri                = 'https://contoso.com/signin'
                    PreferredAuthenticationProtocol = 'wsFed'
                    Domains                         = @('contoso.com')
                    SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                    Ensure                          = 'Absent'
                    Credential                      = $Credential;
                }
            }
            It 'Should return Values from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }
            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should remove the instance from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 2
            }
        }

        Context -Name "The instance exists and values are already in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    IssuerUri                       = 'https://contoso.com/issuerUri'
                    DisplayName                     = 'contoso display name'
                    MetadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                    PassiveSignInUri                = 'https://contoso.com/signin'
                    PreferredAuthenticationProtocol = 'wsFed'
                    Domains                         = @('contoso.com')
                    SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                    Ensure                          = 'Present'
                    Credential                      = $Credential;
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name "The instance exists and values are NOT in the desired state" -Fixture {
            BeforeAll {
                $testParams = @{
                    IssuerUri                       = 'https://contoso.com/issuerUri'
                    DisplayName                     = 'contoso display name'
                    MetadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                    PassiveSignInUri                = 'https://contoso.com/Drift' # Drift
                    PreferredAuthenticationProtocol = 'wsFed'
                    Domains                         = @('contoso.com')
                    SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                    Ensure                          = 'Present'
                    Credential                      = $Credential;
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
                Should -Invoke -CommandName Invoke-MgGraphRequest -Exactly 2
            }
        }

        Context -Name "NextSigningCertificate should be cleared when explicitly set to empty" -Fixture {
            BeforeAll {
                $testParams = @{
                    IssuerUri                       = 'https://contoso.com/issuerUri'
                    DisplayName                     = 'contoso display name'
                    MetadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                    PassiveSignInUri                = 'https://contoso.com/signin'
                    PreferredAuthenticationProtocol = 'wsFed'
                    Domains                         = @('contoso.com')
                    SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                    NextSigningCertificate          = ''
                    Ensure                          = 'Present'
                    Credential                      = $Credential
                }
            }

            It 'Should return false from the Test method when NextSigningCertificate needs to be cleared' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should send PATCH request with nextSigningCertificate as null' {
                # Track if PATCH was called with correct body
                $script:patchCalled = $false
                $script:bodyContainsNextSigningCert = $false
                $script:nextSigningCertIsNull = $false
                
                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    param($Uri, $Method, $Body)
                    if ($Method -eq 'PATCH') {
                        $script:patchCalled = $true
                        $bodyObj = $Body | ConvertFrom-Json
                        if ($bodyObj.PSObject.Properties.Name -contains 'nextSigningCertificate') {
                            $script:bodyContainsNextSigningCert = $true
                            if ($null -eq $bodyObj.nextSigningCertificate -or $bodyObj.nextSigningCertificate -eq '') {
                                $script:nextSigningCertIsNull = $true
                            }
                        }
                    }
                    # Return empty for GET requests to allow the function to continue
                    if ($Method -eq 'Get' -or $null -eq $Method) {
                        return @{
                            value = @(
                                @{
                                    id                              = '12345'
                                    issuerUri                       = 'https://contoso.com/issuerUri'
                                    displayName                     = 'contoso display name'
                                    metadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                                    passiveSignInUri                = 'https://contoso.com/signin'
                                    preferredAuthenticationProtocol = 'wsFed'
                                    domains                         = @(
                                        @{
                                            "@odata.type" = "microsoft.graph.externalDomainName"
                                            id            = "contoso.com"
                                        }
                                    )
                                    signingCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                                    nextSigningCertificate          = 'MIIDADCCAeigAwIBAgIQEX41y8r7'
                                }
                            )
                        }
                    }
                }
                
                Set-TargetResource @testParams
                
                $script:patchCalled | Should -Be $true -Because "PATCH should be called when clearing NextSigningCertificate"
                $script:bodyContainsNextSigningCert | Should -Be $true -Because "Body should contain nextSigningCertificate property"
                $script:nextSigningCertIsNull | Should -Be $true -Because "nextSigningCertificate should be null to clear it"
            }
        }

        Context -Name "NextSigningCertificate should not be included when not provided" -Fixture {
            BeforeAll {
                $testParams = @{
                    IssuerUri                       = 'https://contoso.com/issuerUri'
                    DisplayName                     = 'contoso display name'
                    MetadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                    PassiveSignInUri                = 'https://contoso.com/signin'
                    PreferredAuthenticationProtocol = 'wsFed'
                    Domains                         = @('contoso.com')
                    SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                    Ensure                          = 'Present'
                    Credential                      = $Credential
                }
            }

            It 'Should not include nextSigningCertificate in the request body when not provided' {
                Mock -CommandName Invoke-MgGraphRequest -MockWith {
                    param($Uri, $Method, $Body)
                    if ($Method -eq 'PATCH') {
                        $bodyObj = $Body | ConvertFrom-Json
                        $bodyObj.PSObject.Properties.Name | Should -Not -Contain 'nextSigningCertificate'
                    }
                }
                
                # Mock Get-TargetResource to return a different PassiveSignInUri to trigger an update
                Mock -CommandName Get-TargetResource -MockWith {
                    return @{
                        IssuerUri                       = 'https://contoso.com/issuerUri'
                        DisplayName                     = 'contoso display name'
                        MetadataExchangeUri             = 'https://contoso.com/metadataExchangeUri'
                        PassiveSignInUri                = 'https://contoso.com/different'
                        PreferredAuthenticationProtocol = 'wsFed'
                        Domains                         = @('contoso.com')
                        SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6'
                        NextSigningCertificate          = 'MIIDADCCAeigAwIBAgIQEX41y8r7'
                        Ensure                          = 'Present'
                    }
                }
                
                Set-TargetResource @testParams
                Should -Invoke -CommandName Invoke-MgGraphRequest -ParameterFilter { $Method -eq 'PATCH' } -Exactly 1
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $Global:PartialExportFileName = "$(New-Guid).partial.ps1"
                $testParams = @{
                    Credential  = $Credential;
                }
                
                # Override the base mock to return ResourceUrl for Export operations
                Mock -CommandName Get-MSCloudLoginConnectionProfile -MockWith {
                    return @{
                        ResourceUrl = 'https://graph.microsoft.com/'
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
