[CmdletBinding()]
param(
)

$M365DSCTestFolder = Join-Path -Path $PSScriptRoot `
    -ChildPath '..\..\Unit' `
    -Resolve

$helperModulePath = Join-Path -Path $M365DSCTestFolder `
    -ChildPath '..\..\Modules\Microsoft365DSC\Modules\WorkloadHelpers\M365DSCDefenderHelper.psm1' `
    -Resolve

Import-Module -Name $helperModulePath -Force

Describe 'M365DSCDefenderHelper' {

    Context 'Get-M365DSCDefenderEnvironment' {

        It 'Should return Commercial endpoints by default' {
            $result = Get-M365DSCDefenderEnvironment
            $result.AuthorityHost | Should -Be 'https://login.microsoftonline.com'
            $result.MdeApiBaseUrl | Should -Be 'https://api.securitycenter.microsoft.com'
            $result.XdrApiBaseUrl | Should -Be 'https://api.security.microsoft.com'
            $result.GraphBaseUrl | Should -Be 'https://graph.microsoft.com'
            $result.GraphEnvironmentName | Should -Be 'Global'
        }

        It 'Should return Commercial endpoints when Commercial is specified' {
            $result = Get-M365DSCDefenderEnvironment -Environment 'Commercial'
            $result.AuthorityHost | Should -Be 'https://login.microsoftonline.com'
            $result.MdeApiBaseUrl | Should -Be 'https://api.securitycenter.microsoft.com'
            $result.XdrApiBaseUrl | Should -Be 'https://api.security.microsoft.com'
            $result.GraphBaseUrl | Should -Be 'https://graph.microsoft.com'
            $result.GraphEnvironmentName | Should -Be 'Global'
        }

        It 'Should return GCC High endpoints when GCCHigh is specified' {
            $result = Get-M365DSCDefenderEnvironment -Environment 'GCCHigh'
            $result.AuthorityHost | Should -Be 'https://login.microsoftonline.us'
            $result.MdeApiBaseUrl | Should -Be 'https://api-gov.securitycenter.microsoft.us'
            $result.XdrApiBaseUrl | Should -Be 'https://api-gov.security.microsoft.us'
            $result.GraphBaseUrl | Should -Be 'https://graph.microsoft.us'
            $result.GraphEnvironmentName | Should -Be 'USGov'
        }

        It 'Should return the MDE resource ID for GCC High' {
            $result = Get-M365DSCDefenderEnvironment -Environment 'GCCHigh'
            $result.MdeResourceId | Should -Be 'https://api-gov.securitycenter.microsoft.us'
        }

        It 'Should return the XDR resource ID for GCC High' {
            $result = Get-M365DSCDefenderEnvironment -Environment 'GCCHigh'
            $result.XdrResourceId | Should -Be 'https://security.microsoft.us'
        }

        It 'Should contain all expected keys' {
            $result = Get-M365DSCDefenderEnvironment -Environment 'Commercial'
            $result.Keys | Should -Contain 'AuthorityHost'
            $result.Keys | Should -Contain 'MdeApiBaseUrl'
            $result.Keys | Should -Contain 'XdrApiBaseUrl'
            $result.Keys | Should -Contain 'GraphBaseUrl'
            $result.Keys | Should -Contain 'GraphEnvironmentName'
            $result.Keys | Should -Contain 'MdeResourceId'
            $result.Keys | Should -Contain 'XdrResourceId'
        }
    }

    Context 'Get-M365DSCDefenderMdeBaseUrl' {

        It 'Should return Commercial MDE URL by default' {
            $result = Get-M365DSCDefenderMdeBaseUrl
            $result | Should -Be 'https://api.securitycenter.microsoft.com'
        }

        It 'Should return GCC High MDE URL when GCCHigh is specified' {
            $result = Get-M365DSCDefenderMdeBaseUrl -Environment 'GCCHigh'
            $result | Should -Be 'https://api-gov.securitycenter.microsoft.us'
        }

        It 'Should not contain trailing slash' {
            $result = Get-M365DSCDefenderMdeBaseUrl -Environment 'Commercial'
            $result | Should -Not -Match '/$'
        }
    }

    Context 'Get-M365DSCDefenderXdrBaseUrl' {

        It 'Should return Commercial XDR URL by default' {
            $result = Get-M365DSCDefenderXdrBaseUrl
            $result | Should -Be 'https://api.security.microsoft.com'
        }

        It 'Should return GCC High XDR URL when GCCHigh is specified' {
            $result = Get-M365DSCDefenderXdrBaseUrl -Environment 'GCCHigh'
            $result | Should -Be 'https://api-gov.security.microsoft.us'
        }

        It 'Should not contain trailing slash' {
            $result = Get-M365DSCDefenderXdrBaseUrl -Environment 'Commercial'
            $result | Should -Not -Match '/$'
        }
    }

    Context 'Get-M365DSCDefenderToken' {

        It 'Should throw when no authentication method is provided' {
            { Get-M365DSCDefenderToken -ResourceUrl 'https://api.securitycenter.microsoft.com' } | Should -Throw '*No valid authentication method*'
        }

        It 'Should throw with a clear message when managed identity endpoint is unreachable' {
            Mock -ModuleName M365DSCDefenderHelper -CommandName Invoke-WebRequest -MockWith {
                throw 'Connection refused'
            }

            { Get-M365DSCDefenderToken -ResourceUrl 'https://api.securitycenter.microsoft.com' `
                    -UseManagedIdentity $true } | Should -Throw '*managed identity*'
        }

        It 'Should throw with a clear message when client secret auth fails' {
            $secSecret = ConvertTo-SecureString 'TestSecret' -AsPlainText -Force
            $clientSecretCred = New-Object System.Management.Automation.PSCredential ('clientid', $secSecret)

            Mock -ModuleName M365DSCDefenderHelper -CommandName Invoke-WebRequest -MockWith {
                throw 'Unauthorized'
            }

            { Get-M365DSCDefenderToken -TenantId 'test-tenant' `
                    -ClientId 'test-client' `
                    -ClientSecret $clientSecretCred `
                    -ResourceUrl 'https://api.securitycenter.microsoft.com' } | Should -Throw '*client secret*'
        }

        It 'Should return a bearer token when client secret auth succeeds' {
            $secSecret = ConvertTo-SecureString 'TestSecret' -AsPlainText -Force
            $clientSecretCred = New-Object System.Management.Automation.PSCredential ('clientid', $secSecret)

            Mock -ModuleName M365DSCDefenderHelper -CommandName Invoke-WebRequest -MockWith {
                $mockResponse = [PSCustomObject]@{
                    Content = '{"access_token": "mock-token-12345", "token_type": "Bearer", "expires_in": 3600}'
                }
                return $mockResponse
            }

            $result = Get-M365DSCDefenderToken -TenantId 'test-tenant' `
                -ClientId 'test-client' `
                -ClientSecret $clientSecretCred `
                -ResourceUrl 'https://api.securitycenter.microsoft.com'

            $result | Should -Be 'Bearer mock-token-12345'
        }

        It 'Should use the correct authority host for GCC High' {
            $secSecret = ConvertTo-SecureString 'TestSecret' -AsPlainText -Force
            $clientSecretCred = New-Object System.Management.Automation.PSCredential ('clientid', $secSecret)

            Mock -ModuleName M365DSCDefenderHelper -CommandName Invoke-WebRequest -MockWith {
                param($Uri)
                if ($Uri -notlike '*login.microsoftonline.us*')
                {
                    throw "Expected GCC High authority URL but got $Uri"
                }
                $mockResponse = [PSCustomObject]@{
                    Content = '{"access_token": "gcc-token", "token_type": "Bearer", "expires_in": 3600}'
                }
                return $mockResponse
            }

            $result = Get-M365DSCDefenderToken -TenantId 'test-tenant' `
                -ClientId 'test-client' `
                -ClientSecret $clientSecretCred `
                -ResourceUrl 'https://api-gov.securitycenter.microsoft.us' `
                -AuthorityHost 'https://login.microsoftonline.us'

            $result | Should -Be 'Bearer gcc-token'
        }

        It 'Should return a bearer token when managed identity auth succeeds' {
            Mock -ModuleName M365DSCDefenderHelper -CommandName Invoke-WebRequest -MockWith {
                $mockResponse = [PSCustomObject]@{
                    Content = '{"access_token": "mi-token-67890", "token_type": "Bearer"}'
                }
                return $mockResponse
            }

            $result = Get-M365DSCDefenderToken -ResourceUrl 'https://api.securitycenter.microsoft.com' `
                -UseManagedIdentity $true

            $result | Should -Be 'Bearer mi-token-67890'
        }
    }

    Context 'URL Construction Patterns' {

        It 'Should build correct MDE Software URL for Commercial' {
            $baseUrl = Get-M365DSCDefenderMdeBaseUrl -Environment 'Commercial'
            $fullUrl = "$baseUrl/api/Software"
            $fullUrl | Should -Be 'https://api.securitycenter.microsoft.com/api/Software'
        }

        It 'Should build correct MDE Software URL for GCC High' {
            $baseUrl = Get-M365DSCDefenderMdeBaseUrl -Environment 'GCCHigh'
            $fullUrl = "$baseUrl/api/Software"
            $fullUrl | Should -Be 'https://api-gov.securitycenter.microsoft.us/api/Software'
        }

        It 'Should build correct XDR Incidents URL for Commercial' {
            $baseUrl = Get-M365DSCDefenderXdrBaseUrl -Environment 'Commercial'
            $fullUrl = "$baseUrl/api/incidents"
            $fullUrl | Should -Be 'https://api.security.microsoft.com/api/incidents'
        }

        It 'Should build correct XDR Incidents URL for GCC High' {
            $baseUrl = Get-M365DSCDefenderXdrBaseUrl -Environment 'GCCHigh'
            $fullUrl = "$baseUrl/api/incidents"
            $fullUrl | Should -Be 'https://api-gov.security.microsoft.us/api/incidents'
        }

        It 'Should build correct MDE DeviceAuthenticatedScanDefinitions URL for GCC High' {
            $baseUrl = Get-M365DSCDefenderMdeBaseUrl -Environment 'GCCHigh'
            $fullUrl = "$baseUrl/api/DeviceAuthenticatedScanDefinitions"
            $fullUrl | Should -Be 'https://api-gov.securitycenter.microsoft.us/api/DeviceAuthenticatedScanDefinitions'
        }
    }
}
