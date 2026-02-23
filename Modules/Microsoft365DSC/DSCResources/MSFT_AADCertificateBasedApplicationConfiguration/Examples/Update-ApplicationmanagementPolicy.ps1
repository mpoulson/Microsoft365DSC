param
    (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [switch]$policyEnabled,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('disabled', 'enabled')]
        [string]$passwordAdditionState = "disabled", #Block password by default
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('disabled', 'enabled')]
        [String]$trustedCAState = "enabled",
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $passwordLifetime = "P0D",
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $CertLifetime = "P366D",
        [Parameter(ParameterSetName = "ByName", Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $policyName
)

#Test Duration is valid
try {
    $TimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($passwordLifetime)
} catch {
    throw "Invalid passwordLifetime, format needs to be in ISO 8601 duration, example P91D (91 days)"
}

Connect-MgGraph -Environment USGov -Scopes 'Policy.ReadWrite.ApplicationConfiguration','Organization.Read.All','Policy.Read.All' -nowelcome

#Get the current Policy
Write-Host "Pulling current policy configuration"
$policies = get-mgPolicyAppManagementPolicy 

switch ($PSCmdlet.ParameterSetName) {
    'ByName' {
        Write-Host "Looking up policy $policyName"
        $policy = $policies | ? {$_.DisplayName -eq $policyName}
        if ($policy.id -eq $null)
        {
            throw "Failed to get Policy $PolicyName" 
        }
    }

    default {
        # No name provided, prompt user to choose
        Write-Host "Please choose an Policy:"
        for ($i = 0; $i -lt $policies.Count; $i++) {
            Write-Host "$($i + 1)): $($policies[$i].DisplayName)"
        }

        $selection = Read-Host "Enter the number of your selection"
        if ($selection -match '^\d+$' -and $selection -ge 1 -and $selection -le $policies.Count) {
            $selectedItem = $policies[$selection - 1]
            Write-Host "You selected: $($selectedItem.DisplayName)"
            $policyName = $($selectedItem.DisplayName)
            $policy = $policies | ? {$_.DisplayName -eq $policyName}
        } else {
            throw "Invalid selection"
        }
    }
}

if ($policy.isEnabled -ne $policyEnabled)
{
    Write-Host "Setting the Policy state to $policyEnabled"
    $policy.isEnabled = $policyEnabled
    #update-mgPolicyAppManagementPolicy -BodyParameter $policy
}


$targetConfig = @()
#Allow passwords to be used
$targetConfig += @{
            MaxLifetime = $null
            restrictionType = "passwordAddition"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = $passwordAdditionState
        }
#Set max life for Passwords
$targetConfig += @{
            MaxLifetime = $passwordLifetime
            restrictionType = "passwordLifetime"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = "enabled"
        }
#block any use of Symetric Keys
$targetConfig += @{
            MaxLifetime = $null
            restrictionType = "symmetricKeyAddition"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = $passwordAdditionEnabledState
        }
#block any use of custom passwords
$targetConfig += @{
            MaxLifetime = $null
            restrictionType = "customPasswordAddition"
            restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00Z"
            State = $passwordAdditionEnabledState
        }

#####
## AsymetricKeys
#####
$keyConfig = @()
$keyConfig += @{
            maxLifetime = $CertLifetime #Leap Year needs to be accounted for
            restrictionType = "asymmetricKeyLifetime"
            restrictForAppsCreatedAfterDateTime = "2024-11-11T00:00:00Z"
            State = "enabled"
        }

if ($trustedCAState)
{
    #Get root certs
    Write-Host "getting root certs"
    $RootCerts = get-mgDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration

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
}

#set PasswordCredentials config to policy
$policy.ApplicationRestrictions.PasswordCredentials = $targetConfig
$policy.ServicePrincipalRestrictions.PasswordCredentials = $targetConfig
#Add KeyCredentials config to Policy
$policy.ApplicationRestrictions.keyCredentials = $null
$policy.ApplicationRestrictions.keyCredentials = $keyConfig
$policy.ServicePrincipalRestrictions.keyCredentials = $keyConfig

Write-Host "Uploading Configuration"
update-mgPolicyAppManagementPolicy -BodyParameter $policy
Write-Host "Downloading latest Configuration"
return (get-mgPolicyAppManagementPolicy -AppManagementPolicyId $policy.id)
