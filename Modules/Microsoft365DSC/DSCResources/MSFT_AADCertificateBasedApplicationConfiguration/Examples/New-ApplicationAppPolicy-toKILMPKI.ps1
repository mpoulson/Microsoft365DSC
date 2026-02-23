param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$PolicyName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$PolicyDescription,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$CertificateMaxLifeTime = "P366D",
        [Parameter(Mandatory =$false)]
        [ValidateNotNullOrEmpty()]
        [Array]$CertificateApplicationIds = @(),
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('disabled', 'enabled')]
        [String]$BlockPasswords,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$PasswordMaxLifeTime = "P90D",
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('disabled', 'enabled')]
        [String]$trustedCAState = "enabled"
)

disconnect-mggraph | out-null
Connect-MgGraph -Environment USGov -Scopes ("Policy.ReadWrite.ApplicationConfiguration","Policy.Read.All")  -nowelcome

Write-Host  "checking if policy already exists"
$policy= get-MgBetaPolicyAppManagementPolicy | ? {$_.DisplayName -eq $policyName}
if ($policy -ne $null)
{
    throw "Policy with name $policyName already exists"
}

if ($CertificateApplicationIds.count -eq 0)
{
	Write-Host "CertificateApplicationIds.count -eq 0 so marking trustedCAState = 'disabled'"
	$trustedCAState = 'disabled'
}

$params = @{
    displayName = $PolicyName
    description = $PolicyDescription
    isEnabled = $true
    restrictions = @{
        keyCredentials = @(
            @{
                
                maxLifetime = $CertificateMaxLifeTime
                restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2020-11-01T00:00:00Z")
                restrictionType = "asymmetricKeyLifetime"
                state = "enabled"
		        excludeActors = $null
		        certificateBasedApplicationConfigurationIds = @()
            }
            if ($CertificateApplicationIds.count -ne 0)
            {
                @{
                    certificateBasedApplicationConfigurationIds = $CertificateApplicationIds
                    maxLifetime = $null
                    restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2020-11-01T00:00:00Z")
                    restrictionType = "trustedCertificateAuthority"
                    state = $trustedCAState
		            excludeActors = $null
                }
            }
        )
        passwordCredentials = @(
            @{
                maxLifetime = $null
                restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2020-11-01T00:00:00Z")
                restrictionType = "passwordAddition"
                state = $BlockPasswords
		        excludeActors = $null
            }
            @{
                maxLifetime = $PasswordMaxLifeTime
                restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2020-11-01T00:00:00Z")
                restrictionType = "passwordLifetime"
                state = "enabled" #Always have a password timeout
		        excludeActors = $null
            }
            @{
                maxLifetime = $null
                restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2020-11-01T00:00:00Z")
                restrictionType = "customPasswordAddition"
                state = $BlockPasswords
		        excludeActors = $null
            }
            @{
                maxLifetime = $null
                restrictForAppsCreatedAfterDateTime = [System.DateTime]::Parse("2020-11-01T00:00:00Z")
                restrictionType = "symmetricKeyAddition"
                state = $BlockPasswords
		        excludeActors = $null
            }
        )
    }
}
Write-Host "Creating new Policy"
$policy = invoke-mggraphrequest -method post -uri "https://graph.microsoft.us/beta/policies/appManagementPolicies" -body $params
#$policy = new-MgBetaPolicyAppManagementPolicy -BodyParameter $params
if ($policy -eq $null)
{
    throw "Failed to create policy"
}
return ($policy)
