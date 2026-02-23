param(
    [Parameter(Mandatory=$true)]
    [string]$AppId,                    # The App (client) ID of the Entra application

    [Parameter(Mandatory=$true)]
    [string]$CertPath,                 # Path to the .cer file

    [Parameter(Mandatory=$false)]
    [string]$DisplayName = "New Certificate"  # Optional display name for the key
)

# Connect to Microsoft Graph in US Government cloud
Connect-MgGraph -Environment "USGov" -Scopes "Application.ReadWrite.All"

# Validate certificate file
if (-Not (Test-Path $CertPath)) {
    Write-Error "Certificate file not found at path: $CertPath"
    exit 1
}

# Load the certificate
$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)

# Extract certificate dates
$CertStartDate = $Cert.NotBefore
$CertEndDate = $Cert.NotAfter

# Convert certificate to Base64
$CertBase64 = [System.Convert]::ToBase64String($Cert.RawData)

# Create a Key Credential object
$KeyCredential = @{
    type = "AsymmetricX509Cert"
    usage = "Verify"
    key = $CertBase64
    displayName = $DisplayName
    startDateTime = $CertStartDate
    endDateTime = $CertEndDate
}

# Upload certificate to the application
try {
    New-MgApplicationKeyCredential -ApplicationId $AppId -BodyParameter $KeyCredential
    Write-Host "Certificate uploaded successfully to USGov (GCC High). Valid from $CertStartDate to $CertEndDate."
} catch {
    Write-Error "Failed to upload certificate: $_"
}
