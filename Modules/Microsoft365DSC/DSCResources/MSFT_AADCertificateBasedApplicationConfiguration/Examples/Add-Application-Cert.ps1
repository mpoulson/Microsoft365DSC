param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ApplicationName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$CertFilePath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$expectedThumbprint
)

$certFullPath = (Resolve-Path $CertFilePath).Path

Write-Host "Getting Cert details for $certFullPath"
# Load the certificate from the file
$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certFullPath)

if (($certificate.thummbprint) -like $expectedThumbprint)
{
	Write-Host "Failed to confirm thummbprint match!" -foregroundcolor red
	Write-Host " Cert File Thumbrint = $($certificate.Thumbprint)"
	Write-Host " Expected Thumbrint  = $expectedThumbprint"
	return
}

Write-Host "Getting Application $ApplicationName"
Connect-MgGraph -Scopes 'Application.ReadWrite.All' -environment usgov -nowelcome

$app = Get-MgApplication -Filter "DisplayName eq `'$ApplicationName`'"
if ($app -eq $null)
{
	Write-Host "Failed to find application $ApplicationName"
	return 
}

Write-Host "Cert Data:"
Write-Host " Expires: $($certificate.NotAfter)"
Write-Host " Thumbrint: $($certificate.Thumbprint)"
Write-Host " Issued By: $($certificate.Issuer)"
Write-Host " Subject: $($certificate.Subject)"

# Export the raw certificate data and convert to Base64 string
$base64Certificate = [Convert]::ToBase64String($certificate.RawData)

$newCert = @{
			endDateTime = [System.DateTime]::Parse($certificate.NotAfter)
			startDateTime = [System.DateTime]::Parse($certificate.NotBefore)
			type = "AsymmetricX509Cert"
			usage = "Verify"
			key = [System.Text.Encoding]::ASCII.GetBytes("$base64Certificate")
			displayName = $certificate.subject
		}
$app.KeyCredentials += $newCert
Write-Host "Updating $ApplicationName adding cert $($certificate.subject) Thumbrint: $($certificate.Thumbprint)"
Update-MgApplication -ApplicationId $app.id -KeyCredentials $app.KeyCredentials