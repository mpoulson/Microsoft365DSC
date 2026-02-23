#Tucson 90D passwords 366D Tucson CA
param
    (
        [Parameter(ParameterSetName="ByName")]
        [ValidateNotNullOrEmpty()]
        $policyName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Array]$ApplicationNameList = @(),
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Array]$ServicePrincipalNameList = @()
)
Connect-MgGraph -Environment USGov -Scopes  "Application.Readwrite.All", "Policy.ReadWrite.ApplicationConfiguration"  -nowelcome
$policies = get-MgBetaPolicyAppManagementPolicy 

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
	
	Write-Host "Applying policy $policyName to $applicationname"
	New-MgApplicationAppManagementPolicyByRef -ApplicationId $app.id -OdataId $policyPath
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
	
	Write-Host "Applying policy $policyName to $spName"
	invoke-mggraphrequest -method post -uri "v1.0/serviceprincipals/$($sp.id)/appManagementPolicies/`$ref" -body $param
}
