param
    (

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ResourceGroup,
        [Parameter(Mandatory)]
	      [ValidateSet('WindowsFirewallEventsAMA', 'WindowsSecurityEventsAMA')]
        [String]$DCRName
)

$cloudEnv = "AzureUSGovernment"

Write-Host "Logging in to $cloudEnv"
Connect-AzAccount -Environment $cloudEnv

$tenantInfo = (Get-AzTenant)[0]
$TenantID = $tenantInfo.TenantId
$TenantName = $tenantInfo.name
$SubscriptionID = (Get-AzSubscription)[0].SubscriptionId
$context = Get-AzContext
$resourceUrl = $context.Environment.ResourceManagerUrl
Write-Host "Got ResourceUrl $resourceUrl"

#Create Auth Token
write-Host "getting Access Token"
$auth = Get-AzAccessToken
$token = ConvertFrom-SecureString($auth.Token) -AsPlainText

$AuthenticationHeader = @{
  "Content-Type" = "application/json"
  "Authorization" = "Bearer $token"
}

Write-Host "Confirming the DCR $DCRName exists in Resource Group $ResourceGroup"
$requestURL = "$($resourceUrl)subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$DCRName`?api-version=2022-06-01"
$Respond = Invoke-RestMethod -Uri $requestURL -Headers $AuthenticationHeader -Method GET -Verbose
if ($Respond -eq $null) {
  Write-Host "Data Collection Rule $DCRName does not exist. Create DCR before proceeding, exiting script." -ForegroundColor Red
  throw
}

Write-Host "Confirm Azure Subscription is set"
$out = Select-AzSubscription -TenantId $TenantID -SubscriptionId $SubscriptionID | out-null

$newguid = (New-Guid).Guid
$user = Get-AzADUser -UserPrincipalName $context.Account
$UserObjectID = $user.Id

Write-Host "Assigning the Role required to $($context.Account) set for $userObjectID"
if ($UserObjectID -eq $null)
{
	throw "Failed too lookup user, try again"
}

$body = @"
  {
      "properties": {
          "roleDefinitionId":"/providers/Microsoft.Authorization/roleDefinitions/56be40e24db14ccf93c37e44c597135b",
          "principalId": `"$UserObjectID`"
      }
  }
"@

$requestURL = "$($resourceUrl)providers/microsoft.insights/providers/microsoft.authorization/roleassignments/$newguid`?api-version=2021-04-01-preview"
Write-host "Assigning Role"
Invoke-RestMethod -Uri $requestURL -Headers $AuthenticationHeader -Method PUT -Body $body

Write-Host "Creating new Monitored Object"
$requestURL = "$($resourceUrl)providers/Microsoft.Insights/monitoredObjects/$TenantID`?api-version=2021-09-01-preview"
$Location   = (Get-AzDataCollectionRule -Name $DCRName -ResourceGroupName $ResourceGroup -WarningAction SilentlyContinue).Location

$body = @"
  {
      "properties":{
          "location":`"$Location`"
      }
  }
"@

$Respond = Invoke-RestMethod -Uri $requestURL -Headers $AuthenticationHeader -Method PUT -Body $body -Verbose
$RespondID = $($Respond.id).Substring(1)

Write-Host "associating DCR $DCRName to Monitored Object"
# See reference documentation https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rule-associations/create?tabs=HTTP
$associationName = "$TenantName-$DCRName"

#Read
#$requestURL = "$($resourceUrl)$RespondId/providers/microsoft.insights/datacollectionruleassociations/`?api-version=2022-06-01"
$requestURL = "$($resourceUrl)$RespondId/providers/microsoft.insights/datacollectionruleassociations/$associationName`?api-version=2022-06-01"
$body = @"
  {
      "properties": {
          "dataCollectionRuleId": "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$DCRName"
      }
  }
"@
#Read
#Invoke-RestMethod -Uri $requestURL -Headers $AuthenticationHeader -Method Get

Invoke-RestMethod -Uri $requestURL -Headers $AuthenticationHeader -Method PUT -Body $body
