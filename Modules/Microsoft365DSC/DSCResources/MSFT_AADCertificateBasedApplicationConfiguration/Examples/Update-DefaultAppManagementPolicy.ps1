param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'DefaultDisable')]
        [ValidateNotNullOrEmpty()]
        [switch]$defaultPolicyDisabled,
        [Parameter(Mandatory = $false, ParameterSetName = 'DefaultEnable')]
        [ValidateNotNullOrEmpty()]
        [switch]$passwordAdditionEnabled,
        [Parameter(Mandatory = $false, ParameterSetName = 'DefaultEnable')]
        [ValidateNotNullOrEmpty()]
        $passwordLifetime = "P0D",
        [Parameter(Mandatory = $false, ParameterSetName = 'DefaultEnable')]
        [ValidateNotNullOrEmpty()]
        $CertLifetime = "P366D",
        [Parameter(Mandatory = $false)]
        [String]$RootCertChainName
)

#Test Duration is valid
try {
    $passwordTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($passwordLifetime)
} catch {
    throw "Invalid passwordLifetime, format needs to be in ISO 8601 duration, example P91D (91 days)"
}

try {
    $certificateTimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($CertLifetime)
} catch {
    throw "Invalid CertLifetime, format needs to be in ISO 8601 duration, example P366D (366 days)"
}

if ($PSCmdlet.ParameterSetName -eq 'DefaultDisable')
{
    Write-Host "setting policy to Disabled"
    #Disable the default policy
    $defaultIsEnabled = $false
}
else
{
    Write-Host "setting policy to Enabled"
    #Disable the default policy
    $defaultIsEnabled = $true   
}

if ($passwordTimeSpan.days -gt 1)
{
    $passwordStatus = "enabled"
}
else
{
    $passwordStatus = "disabled"
}

if ($certificateTimeSpan.days -gt 1)
{
    $certificateStatus = "enabled"
}
else
{
    $certificateStatus = "disabled"
}

Connect-MgGraph -Environment USGov -Scopes 'Policy.ReadWrite.ApplicationConfiguration','Organization.Read.All','Policy.Read.All','AppCertTrustConfiguration.Read.All' -nowelcome

#Get the current Policy
Write-Host "Pulling current policy configuration"
$policy = get-mgbetaPolicyDefaultAppManagementPolicy
if ($policy.isEnabled -ne $defaultIsEnabled)
{
    Write-Host "Setting the Policy state to $defaultIsEnabled"
    $policy.isEnabled = $defaultIsEnabled
    update-mgPolicyDefaultAppManagementPolicy -BodyParameter $policy
}

Write-Host "Getting updates policy configuration"
$policy = get-mgbetaPolicyDefaultAppManagementPolicy

if ($defaultIsEnabled -eq $false) #policy was disabled
{
    Write-Host "Policy marked as disabled, returning"
    return $policy
}
#Add Tenant wide Default settings for Password configs
$params = @{
    displayName = $Policy.Displayname
    description = $Policy.Description
    isEnabled = $defaultIsEnabled
    applicationRestrictions = @{
        keyCredentials = @()
        passwordCredentials = @()
    }
    servicePrincipalRestrictions = @{
        keyCredentials = @()
        passwordCredentials = @()
    }
}

$targetConfig = @()
#Allow passwords to be used
$targetConfig += @{
            MaxLifetime = $null
            restrictionType = "passwordAddition"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = $passwordStatus
        }
#Set max life for Passwords
$targetConfig += @{
            MaxLifetime = $passwordLifetime
            restrictionType = "passwordLifetime"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = $passwordStatus
        }
#block any use of Symetric Keys
$targetConfig += @{
            MaxLifetime = $null
            restrictionType = "symmetricKeyAddition"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = "enabled"
        }
#block any use of custom passwords
$targetConfig += @{
            MaxLifetime = $null
            restrictionType = "customPasswordAddition"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = "enabled"
        }
# This isn't required because symmetricKeyAddition is disabled        
#$targetConfig += @{
#            MaxLifetime = "P0D"
#            restrictionType = "symmetricKeyLifetime"
#            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
#            State = "disabled"
#        }

#####
## AsymetricKeys
#####
$keyConfig = @()
$keyConfig += @{
            maxLifetime = $CertLifetime #Leap Year needs to be accounted for
            restrictionType = "asymmetricKeyLifetime"
            restrictForAppsCreatedAfterDateTime = "2024-11-11T00:00:00Z"
            State = $certificateStatus
        }

#Get root certs
Write-Host "getting root certs"
$RootCerts = get-mgbetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration 
if (-not [string]::IsNullOrEmpty($RootCertChainName))
{
    Write-Host "Mapping to Root Chain '$RootCertChainName'"
    $RootCerts = $RootCerts | ? {$_.DisplayName -eq $RootCertChainName}
}

if ($RootCerts.count -gt 0)
{
    #Define the Trusted CA items
    $trustedCertificateAuthority = @{}
    $trustedCertificateAuthority.State = "enabled"
    $trustedCertificateAuthority.MaxLifetime = $null
    $trustedCertificateAuthority.restrictionType = "trustedCertificateAuthority"
    $trustedCertificateAuthority.restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"


    $certificateBasedApplicationConfigurationIds = @()
    $certificateBasedApplicationConfigurationIds += $RootCerts.id
    $trustedCertificateAuthority.certificateBasedApplicationConfigurationIds = $certificateBasedApplicationConfigurationIds

    $keyConfig +=$trustedCertificateAuthority
}
else
{
    Write-Host "No root Certs found"  -foregroundcolor red   
}

#set PasswordCredentials config to policy
$params.ApplicationRestrictions.PasswordCredentials = $targetConfig
$params.ServicePrincipalRestrictions.PasswordCredentials = $targetConfig
#Add KeyCredentials config to Policy
#$policy.ApplicationRestrictions.keyCredentials = $null
$params.ApplicationRestrictions.keyCredentials = $keyConfig
$params.ServicePrincipalRestrictions.keyCredentials = $keyConfig

Write-Host "Uploading Configuration"
update-mgbetaPolicyDefaultAppManagementPolicy -BodyParameter $params
Write-Host "Downloading latest Configuration"
return (get-mgbetaPolicyDefaultAppManagementPolicy)
