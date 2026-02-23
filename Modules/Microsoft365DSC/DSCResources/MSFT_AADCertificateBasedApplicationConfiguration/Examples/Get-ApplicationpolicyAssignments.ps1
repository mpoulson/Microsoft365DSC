

Connect-MgGraph -Environment USGov -Scopes "Policy.ReadWrite.ApplicationConfiguration", "Policy.Read.All"  -nowelcome

Write-Host  "Getting existing Policies"
$Policies = get-MgPolicyAppManagementPolicy
$manifest = @()
foreach($policy in $policies)
{
	Write-Host "Getting Assigned Apps to $($policy.DisplayName)"
	$appliedTo = Get-MgPolicyAppManagementPolicyApplyTo -AppManagementPolicyId $policy.id
	$appliedToDetails = @()
	foreach($app in $AppliedTo)
	{
		Write-Host "Getting Object Details for ID $($app.id)"
		$object = Get-MgDirectoryObjectById -Ids $app.id
		
		$appliedToDetails += @{
			resourcetype = $object.AdditionalProperties."@odata.type" -replace "#microsoft.graph.", ""
			name = $object.AdditionalProperties.displayName
			id = $object.id
		}
	}

	$manifest += @{
		name = $policy.DisplayName
		id = $policy.id
		assigned = $appliedToDetails
		IsEnabled = $policy.IsEnabled
	}
}

return $manifest | convertto-json -depth 10