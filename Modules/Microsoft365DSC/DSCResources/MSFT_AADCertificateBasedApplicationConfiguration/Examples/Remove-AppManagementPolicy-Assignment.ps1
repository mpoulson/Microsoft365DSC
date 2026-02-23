param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $policyName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Array]$ApplicationNameList = @(),
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Array]$ServicePrincipalNameList = @()
)
Write-Host "Looking up policy $policyName"
$policy= get-MgBetaPolicyAppManagementPolicy | ? {$_.DisplayName -eq $policyName}
if ($policy.id -eq $null)
{
	throw "Failed to get Policy $PolicyName" 
}

$policyPath = "https://graph.microsoft.com/beta/policies/appManagementPolicies/$($policy.id)"
Write-Host "Processing Entra Applications"
foreach($applicationname in $ApplicationNameList)
{
	Write-Host "Getting application $applicationname"
	$app = get-mgapplication -Filter "DisplayName eq '$applicationName'"
	
	if ($app -eq $null)
	{
		Write-Host "Failed to find Application $applicationName"
	}
	
	Write-Host "Removing policy $policyName to $applicationname"
	#Remove-MgApplicationAppManagementPolicyByRef -ApplicationId $app.id -OdataId $policyPath
	Remove-MgApplicationAppManagementPolicyByRef -ApplicationId $app.id -AppManagementPolicyId $policy.id
}

foreach($spName in $ServicePrincipalNameList)
{
	Write-Host "Getting Service Principal $spName"
	$sp = get-mgServicePrincipal -Filter "DisplayName eq '$spName'"
	
	if ($sp -eq $null)
	{
		Write-Host "Failed to find Service Principal $spName"
	}
	$param = @{
	  "@odata.id" = $policyPath
	}
	
	Write-Host "Removing policy $policyName to $spName"
	#Remove-MgApplicationAppManagementPolicyByRef -ApplicationId $sp.id -AppManagementPolicyId $policy.id
	invoke-mggraphrequest -method Delete -uri "v1.0/serviceprincipals/$($sp.id)/appManagementPolicies/$($policy.id)/`$ref" -body $param
}