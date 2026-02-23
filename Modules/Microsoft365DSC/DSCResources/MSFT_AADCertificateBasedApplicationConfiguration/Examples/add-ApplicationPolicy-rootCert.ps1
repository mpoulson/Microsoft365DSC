param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$displayName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Description,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$RootCertPath,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String]$IssuerCertPath
)

Connect-MgGraph -Environment USGov -Scopes 'AppCertTrustConfiguration.ReadWrite.All' -NoWelcome
$rootcertFullPath = (Resolve-Path $RootCertPath).Path
Write-Host "RootCert path $rootcertFullPath"

if(-not (Test-Path($rootcertFullPath)))
{
    Write-Host "file at $rootcertFullPath doesn't exist"
    return
}

if (-not ([string]::IsNullOrEmpty($IssuerCertPath)))
{
    $issuerCertFullPath = (Resolve-Path $IssuerCertPath).Path
    Write-Host "IssuerCert path $issuerCertFullPath"

    if(-not (Test-Path($issuerCertFullPath)))
    {
        Write-Host "file at $issuerCertFullPath doesn't exist"
        return
    }
}

Write-Host "Getting Cert details for $rootcertFullPath"
# Load the certificate from the file
$rootCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($rootcertFullPath)
Write-Host "Checking if $($rootCert.subject) exists in Tenant"

#Get existing certs
$existingPairs = get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration
$existingPairs = $existingPairs | % {get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfigurationTrustedCertificateAuthority -CertificateBasedApplicationConfigurationId $_.id}

$existingPairs | ? {$_.IsRootAuthority} | % {$_.issuer -eq $rootCert.subject}
#get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfigurationTrustedCertificateAuthority
Write-Host "Existing Root Certs $($existingCerts.count)"


$rootcertExists = $existingCerts.trustedCertificateAuthorities | ? {$_.issuer -eq $rootCert.subject}

if ($rootcertExists -eq $null)
{
    #generate new Json payload
    $params = @{}
    $params.displayName = $displayName
    $params.Description = $Description
    $params.trustedCertificateAuthorities = @()

    $newcert = @{
        isRootAuthority = $true
        certificate = [System.Text.Encoding]::ASCII.GetBytes([Convert]::ToBase64String($rootCert.RawData))
    }

    $params.trustedCertificateAuthorities += $newcert

    if (-not [string]::IsNullOrEmpty($IssuerCertPath))
    {
        $issuerCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($issuerCertFullPath)
        Write-Host "Processing Issuer cert: $($issuerCert.Issuer)"
        Write-Host "Processing Subject cert: $($issuerCert.Subject)"
        $newcert = @{
            isRootAuthority = $false
            certificate = [System.Text.Encoding]::ASCII.GetBytes([Convert]::ToBase64String($issuerCert.RawData))
        }

        $params.trustedCertificateAuthorities += $newcert
    }

    Write-Host "Creating Certificate chain for App Protection $($certificate.Subject)"
    $response = New-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration -BodyParameter $params
    Write-Host "Added cert ID: $($response.id)"
    return $certId
}