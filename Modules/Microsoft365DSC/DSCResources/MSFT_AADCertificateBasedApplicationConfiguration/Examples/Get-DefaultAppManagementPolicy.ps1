Connect-MgGraph -Environment USGov -Scopes 'Policy.ReadWrite.ApplicationConfiguration','Organization.Read.All','Policy.Read.All' -nowelcome

Write-Host "Downloading latest Configuration"
return (get-MgPolicyDefaultAppManagementPolicy)
