param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('ManagementGroup', 'Subscription')]
        $ResourceType,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $RoleName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $ResourceName,
        [Parameter(Mandatory = $true,
            ParameterSetName = 'User')]
        [string]$UserUPN,
        [Parameter(Mandatory = $true,
            ParameterSetName = 'Group')]
        [string]$GroupName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $TenantName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $ElevationDuration = "PT4H", #Default to 4 hours
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Int]$ExpirationDays = -1
)
#Example
#
#.\Add-AzureRole-PIMElegibility.ps1 -ResourceType ManagementGroup -RoleName "Owner" -ResourceName "security" -TenantName tucson.onmicrosoft.us -GroupName "sg-azure-users-kcsls-owner" -ExpirationDays -1
#

#Test Duration is valid
try {
    $TimeSpan = [System.Xml.XmlConvert]::ToTimeSpan($ElevationDuration)
} catch {
    throw "Invalid ElevationDuration, format needs to be in ISO 8601 duration, example P91D (91 days)"
}
#Process Expiration that isn't permanent
if ($ExpirationDays -ne -1)
{
    $Expiration = ("$(((Get-Date).ToUniversalTime()).AddDays($ExpirationDays))"+"Z") `   
}

#Get Current context
$context = Get-AzContext
$mgContext = get-mgcontext

if ([String]::IsNullOrWhiteSpace($context))
{
    Write-Host "Connecting to Azure account..."
    Connect-azaccount -Environment AzureUSGovernment -ErrorAction Stop | Out-Null
    $context = Get-AzContext
    Write-Host "Connected to Azure account."
}

if ([String]::IsNullOrWhiteSpace($mgContext))
{
    Write-Host "Connecting to Graph account..."
    connect-mggraph -environment usgov -scope "Group.Read.All" -ErrorAction Stop | Out-Null
    $mgContext = get-mgcontext
    Write-Host "Connected to Graph account."
}
Write-Host "Confirm in correct tenant"
if ($context.account.id -notlike "*@$TenantName")
{
    Write-Host "Azure - Tenant name does not match logged in account $($context.account.id)" -foregroundcolor red
    Disconnect-azaccount
    Connect-azaccount -Environment AzureUSGovernment -ErrorAction Stop | Out-Null
    #return
}

if ($mgContext.account -notlike "*@$TenantName")
{
    Write-Host "Graph - Tenant name does not match logged in account $($mgContext.account)" -foregroundcolor red
    Disconnect-MgGraph
    connect-mggraph -environment usgov -scope "Group.Read.All" -ErrorAction Stop | Out-Null
    #return
}

Write-Host "Getting Role $roleName"
$role = Get-AzRoleDefinition -Name $roleName
if ($role -eq $null)
{
   Write-Host "Failed to lookup Role $roleName"
   return
}

if ($ResourceType -eq "Subscription")
{
    $subscription = Get-AzSubscription -SubscriptionName $ResourceName
    $SubscriptionId = $subscription.id
    $scope = "subscriptions/$($subscriptionid)"
    $resourceId = $SubscriptionId
}
elseif ($ResourceType -eq "ManagementGroup")
{
    $scope = "/providers/Microsoft.Management/managementGroups/$ResourceName"
    $mgmtgroup = Get-AzManagementGroup -GroupName $ResourceName -ErrorAction silent
    if ($mgmtgroup -eq $null)
    {
        #the initial query wasn't found, seeing if we can find via DisplayName
        Write-Host "Management Group $ResourceName was not found, checking for DisplayName by name $ResourceName" -foregroundcolor yellow
        $mgmtgroup = Get-AzManagementGroup | ? {$_.DisplayName -eq $ResourceName}
        $scope = "/providers/Microsoft.Management/managementGroups/$($mgmtgroup.name)"
        if ($mgmtgroup -eq $null)
        {
            Write-Host "Management Group $ResourceName was not found" -foregroundcolor red
            return
        }
    }
    $resourceId = $mgmtgroup.id
}

if ($PSCmdlet.ParameterSetName -eq 'User')
{
    Write-Host "Performing User Lookup for $UserUPN"
    $user = get-mguser -UserId $UserUPN
    if ($user -eq $null)
    {
        Write-Host "Failed to find user $UserUPN" -foregroundcolor Red
        return
    }
    $targetId = $user.id
}
elseif ($PSCmdlet.ParameterSetName -eq 'Group')
{
    Write-Host "Performing Group Lookup for $groupName"
    $group = Get-mgGroup  -Filter "DisplayName eq '$groupName'"
    if ($group -eq $null)
    {
        Write-Host "Failed to find group $groupName" -foregroundcolor Red
        return
    }

    $targetId = $group.id
}

$docLink = "https://docs.microsoft.com/en-us/azure/active-directory/privileged-identity-management/pim-resource-roles-discover-resources#discover-resources"

Write-Host "Checking if $ResourceType [$($ResourceName)] is onboarded to PIM or not..."
try
{    
    $pimEligibleRoleAssignments = Get-AzRoleEligibilityScheduleInstance -Scope $scope -ErrorAction stop
}
catch
{
    Write-Host "$($_)"
    return
}

if (-not $pimEligibleRoleAssignments)
{
    Write-Host "$ResourceType is not onboarded to PIM. Please onboard the $ResourceType to PIM and again run the script."
    Write-Host "*** To onboard the $ResourceType to PIM please follow the steps mentioned here $($docLink). ***"
    #return
}
else
{
    Write-Host "$ResourceType [$resourceId] is onboarded to PIM." 
}
"Assigning Eligibile entry created, TargetID: $targetId, Role: $roleName, $ResourceType $ResourceName, Tenant $TenantName"
$RoleDefinitionId = "$scope/providers/Microsoft.Authorization/roleDefinitions/$($role.id)"

$params = @{
    Name = (new-guid)
    RoleDefinitionId = $RoleDefinitionId
    Scope = $Scope
    PrincipalId = $targetId 
    ScheduleInfoStartDateTime = Get-Date -Format o #("$((Get-Date).ToUniversalTime())" +"Z")
    RequestType = 'AdminAssign'
    ExpirationDuration = $ElevationDuration
}
#Handle permanent elegible assignements
if ($ExpirationDays -eq -1)
{
    $params.Add( 'ExpirationType', 'NoExpiration')
}
else
{
    $params.Add( 'ExpirationEndDateTime', $Expiration)
}

$PIMAssignment = New-AzRoleEligibilityScheduleRequest @params

if ($PIMAssignment -eq $null)
{
    if ($PSCmdlet.ParameterSetName -eq 'User')
    {
        Write-Host "Eligibile entry created, User: $UserUPN, Role: $roleName, $ResourceType $ResourceName, Tenant $TenantName"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Group')
    {
        Write-Host "Eligibile entry created, Group: $GroupName, Role: $roleName, $ResourceType $ResourceName, Tenant $TenantName"
    }
    return $PIMAssignment                  
}