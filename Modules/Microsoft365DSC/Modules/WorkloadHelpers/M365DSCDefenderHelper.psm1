<#
.SYNOPSIS
    Returns endpoint metadata for the specified Microsoft Defender environment.

.DESCRIPTION
    Resolves authority, MDE API, Defender XDR API, and Microsoft Graph
    endpoints for a given cloud environment. Supported environments are
    Commercial and GCCHigh.

.PARAMETER Environment
    The cloud environment name. Valid values are Commercial and GCCHigh.
    Defaults to Commercial.

.OUTPUTS
    System.Collections.Hashtable

.EXAMPLE
    Get-M365DSCDefenderEnvironment -Environment 'GCCHigh'
#>
function Get-M365DSCDefenderEnvironment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter()]
        [ValidateSet('Commercial', 'GCCHigh')]
        [System.String]
        $Environment = 'Commercial'
    )

    $environmentMap = @{
        Commercial = @{
            AuthorityHost        = 'https://login.microsoftonline.com'
            MdeApiBaseUrl        = 'https://api.securitycenter.microsoft.com'
            XdrApiBaseUrl        = 'https://api.security.microsoft.com'
            GraphBaseUrl         = 'https://graph.microsoft.com'
            GraphEnvironmentName = 'Global'
            MdeResourceId        = 'https://api.securitycenter.microsoft.com'
            XdrResourceId        = 'https://security.microsoft.com'
        }
        GCCHigh    = @{
            AuthorityHost        = 'https://login.microsoftonline.us'
            MdeApiBaseUrl        = 'https://api-gov.securitycenter.microsoft.us'
            XdrApiBaseUrl        = 'https://api-gov.security.microsoft.us'
            GraphBaseUrl         = 'https://graph.microsoft.us'
            GraphEnvironmentName = 'USGov'
            MdeResourceId        = 'https://api-gov.securitycenter.microsoft.us'
            XdrResourceId        = 'https://security.microsoft.us'
        }
    }

    $selected = $environmentMap[$Environment]
    if ($null -eq $selected)
    {
        throw "Unsupported environment: $Environment. Valid values are: $($environmentMap.Keys -join ', ')"
    }

    Write-Verbose -Message "Resolved Defender environment '$Environment': MDE=$($selected.MdeApiBaseUrl), XDR=$($selected.XdrApiBaseUrl)"
    return $selected
}

<#
.SYNOPSIS
    Returns the MDE API base URL for the specified environment.

.DESCRIPTION
    Convenience wrapper around Get-M365DSCDefenderEnvironment that returns
    only the MDE API base URL string.

.PARAMETER Environment
    The cloud environment name. Defaults to Commercial.

.OUTPUTS
    System.String

.EXAMPLE
    Get-M365DSCDefenderMdeBaseUrl -Environment 'GCCHigh'
#>
function Get-M365DSCDefenderMdeBaseUrl
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [ValidateSet('Commercial', 'GCCHigh')]
        [System.String]
        $Environment = 'Commercial'
    )

    $env = Get-M365DSCDefenderEnvironment -Environment $Environment
    return $env.MdeApiBaseUrl
}

<#
.SYNOPSIS
    Returns the Defender XDR API base URL for the specified environment.

.DESCRIPTION
    Convenience wrapper around Get-M365DSCDefenderEnvironment that returns
    only the Defender XDR API base URL string.

.PARAMETER Environment
    The cloud environment name. Defaults to Commercial.

.OUTPUTS
    System.String

.EXAMPLE
    Get-M365DSCDefenderXdrBaseUrl -Environment 'GCCHigh'
#>
function Get-M365DSCDefenderXdrBaseUrl
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [ValidateSet('Commercial', 'GCCHigh')]
        [System.String]
        $Environment = 'Commercial'
    )

    $env = Get-M365DSCDefenderEnvironment -Environment $Environment
    return $env.XdrApiBaseUrl
}

<#
.SYNOPSIS
    Acquires an OAuth 2.0 access token for a Defender REST API using client credentials.

.DESCRIPTION
    Requests a token from Azure AD using either a client secret, a certificate
    thumbprint, an X509Certificate2 object, or managed identity. The token is
    returned as a bearer-ready Authorization header value.

.PARAMETER TenantId
    Azure AD tenant ID (GUID or domain).

.PARAMETER ClientId
    Application (client) ID of the Azure AD app registration.

.PARAMETER ClientSecret
    Client secret credential. Mutually exclusive with certificate parameters.

.PARAMETER CertificateThumbprint
    Thumbprint of a certificate in the local certificate store. Mutually
    exclusive with ClientSecret.

.PARAMETER Certificate
    An X509Certificate2 object for certificate-based auth. Mutually exclusive
    with ClientSecret.

.PARAMETER ResourceUrl
    The resource identifier / audience for the token request.

.PARAMETER AuthorityHost
    The authority host URL. Defaults to Commercial.

.PARAMETER UseManagedIdentity
    When specified, acquires a token using the Azure managed identity endpoint.

.OUTPUTS
    System.String

.EXAMPLE
    $token = Get-M365DSCDefenderToken -TenantId $tid -ClientId $cid -ClientSecret $sec `
        -ResourceUrl 'https://api.securitycenter.microsoft.com'
#>
function Get-M365DSCDefenderToken
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $ClientId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ClientSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceUrl,

        [Parameter()]
        [System.String]
        $AuthorityHost = 'https://login.microsoftonline.com',

        [Parameter()]
        [System.Boolean]
        $UseManagedIdentity = $false
    )

    # Managed Identity path
    if ($UseManagedIdentity)
    {
        Write-Verbose -Message 'Acquiring token via managed identity.'
        $tokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$ResourceUrl"
        try
        {
            $tokenResponse = Invoke-WebRequest -Uri $tokenUri `
                -Headers @{ 'Metadata' = 'true' } `
                -Method GET `
                -UseBasicParsing
            $tokenContent = ConvertFrom-Json $tokenResponse.Content
            return "Bearer $($tokenContent.access_token)"
        }
        catch
        {
            throw "Failed to acquire managed identity token for resource '$ResourceUrl': $($_.Exception.Message)"
        }
    }

    # Certificate-based auth path
    if (-not [System.String]::IsNullOrEmpty($CertificateThumbprint) -or $null -ne $Certificate)
    {
        Write-Verbose -Message 'Acquiring token via certificate credentials.'

        if ($null -eq $Certificate)
        {
            $Certificate = Get-ChildItem -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
            if ($null -eq $Certificate)
            {
                $Certificate = Get-ChildItem -Path "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
            }

            if ($null -eq $Certificate)
            {
                throw "Certificate with thumbprint '$CertificateThumbprint' not found in LocalMachine or CurrentUser stores."
            }
        }

        # Build JWT assertion for certificate auth
        $tokenEndpoint = "$AuthorityHost/$TenantId/oauth2/v2.0/token"
        $now = [System.DateTimeOffset]::UtcNow
        $headerHash = @{
            alg = 'RS256'
            typ = 'JWT'
            x5t = [System.Convert]::ToBase64String($Certificate.GetCertHash([System.Security.Cryptography.HashAlgorithmName]::SHA1)) -replace '\+', '-' -replace '/', '_' -replace '='
        }
        $payloadHash = @{
            aud = $tokenEndpoint
            exp = ($now.AddMinutes(10)).ToUnixTimeSeconds()
            iss = $ClientId
            jti = [System.Guid]::NewGuid().ToString()
            nbf = $now.ToUnixTimeSeconds()
            sub = $ClientId
        }

        $headerJson = ConvertTo-Json $headerHash -Compress
        $payloadJson = ConvertTo-Json $payloadHash -Compress

        $headerB64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($headerJson)) -replace '\+', '-' -replace '/', '_' -replace '='
        $payloadB64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadJson)) -replace '\+', '-' -replace '/', '_' -replace '='

        $dataToSign = [System.Text.Encoding]::UTF8.GetBytes("$headerB64.$payloadB64")
        $rsaPrivateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
        $signatureBytes = $rsaPrivateKey.SignData($dataToSign, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $signatureB64 = [System.Convert]::ToBase64String($signatureBytes) -replace '\+', '-' -replace '/', '_' -replace '='

        $clientAssertion = "$headerB64.$payloadB64.$signatureB64"

        $body = @{
            client_id             = $ClientId
            client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
            client_assertion      = $clientAssertion
            scope                 = "$ResourceUrl/.default"
            grant_type            = 'client_credentials'
        }

        try
        {
            $tokenResponse = Invoke-WebRequest -Uri $tokenEndpoint `
                -Method POST `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body $body `
                -UseBasicParsing
            $tokenContent = ConvertFrom-Json $tokenResponse.Content
            return "Bearer $($tokenContent.access_token)"
        }
        catch
        {
            throw "Failed to acquire certificate-based token for resource '$ResourceUrl': $($_.Exception.Message)"
        }
    }

    # Client secret path
    if ($null -ne $ClientSecret)
    {
        Write-Verbose -Message 'Acquiring token via client secret.'
        $tokenEndpoint = "$AuthorityHost/$TenantId/oauth2/v2.0/token"
        $body = @{
            client_id     = $ClientId
            client_secret = $ClientSecret.GetNetworkCredential().Password
            scope         = "$ResourceUrl/.default"
            grant_type    = 'client_credentials'
        }

        try
        {
            $tokenResponse = Invoke-WebRequest -Uri $tokenEndpoint `
                -Method POST `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body $body `
                -UseBasicParsing
            $tokenContent = ConvertFrom-Json $tokenResponse.Content
            return "Bearer $($tokenContent.access_token)"
        }
        catch
        {
            throw "Failed to acquire client secret token for resource '$ResourceUrl': $($_.Exception.Message)"
        }
    }

    throw 'No valid authentication method provided. Supply ClientSecret, CertificateThumbprint, Certificate, or set UseManagedIdentity to $true.'
}

<#
.SYNOPSIS
    Establishes a Microsoft Graph connection with environment-aware settings.

.DESCRIPTION
    Connects to Microsoft Graph using Connect-MgGraph, selecting the
    appropriate environment (Global or USGov) based on the Defender
    environment configuration.

.PARAMETER TenantId
    Azure AD tenant ID.

.PARAMETER ClientId
    Application (client) ID.

.PARAMETER CertificateThumbprint
    Certificate thumbprint for app-only Graph auth.

.PARAMETER Environment
    The cloud environment name. Defaults to Commercial.

.OUTPUTS
    None

.EXAMPLE
    Connect-M365DSCDefenderGraph -TenantId $tid -ClientId $cid `
        -CertificateThumbprint $thumb -Environment 'GCCHigh'
#>
function Connect-M365DSCDefenderGraph
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $TenantId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ClientId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [ValidateSet('Commercial', 'GCCHigh')]
        [System.String]
        $Environment = 'Commercial'
    )

    $envConfig = Get-M365DSCDefenderEnvironment -Environment $Environment
    Write-Verbose -Message "Connecting to Microsoft Graph environment '$($envConfig.GraphEnvironmentName)'."

    $connectParams = @{
        TenantId              = $TenantId
        ClientId              = $ClientId
        CertificateThumbprint = $CertificateThumbprint
        Environment           = $envConfig.GraphEnvironmentName
    }

    Connect-MgGraph @connectParams | Out-Null
    Write-Verbose -Message 'Microsoft Graph connection established.'
}

<#
.SYNOPSIS
    Invokes a Microsoft Defender REST API call with proper authentication.

.DESCRIPTION
    Sends an HTTP request to a Defender REST API endpoint. The access token
    is retrieved from the MSCloudLogin connection profile for the
    DefenderForEndpoint workload. Supports GET, POST, PATCH, and DELETE.

.PARAMETER Uri
    The full URI of the API endpoint.

.PARAMETER Method
    HTTP method. Defaults to GET.

.PARAMETER Body
    Optional hashtable that will be serialized to JSON for the request body.

.OUTPUTS
    System.Collections.Hashtable

.EXAMPLE
    $result = Invoke-M365DSCDefenderREST -Uri 'https://api.securitycenter.microsoft.com/api/Software'
#>
function Invoke-M365DSCDefenderREST
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Uri,

        [Parameter()]
        [System.String]
        $Method = 'GET',

        [Parameter()]
        [System.Collections.Hashtable]
        $Body
    )

    $bodyJSON = ConvertTo-Json $Body -Depth 10 -Compress
    $headers = @{
        Authorization  = (Get-MSCloudLoginConnectionProfile -Workload DefenderForEndpoint).AccessToken
        'Content-Type' = 'application/json'
    }
    $response = Invoke-WebRequest -Method $Method `
        -Uri $Uri `
        -Headers $headers `
        -Body $bodyJSON `
        -UseBasicParsing
    $result = ConvertFrom-Json $response.Content
    return $result
}
