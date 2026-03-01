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
        $TenantName
)

#Get Current context
$context = Get-AzContext
$mgContext = get-mgcontext
#connect-mggraph -environment usgov
#Connect-azaccount -Environment AzureUSGovernment

if ([String]::IsNullOrWhiteSpace($context.account.id))
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
    Write-Host "Graph - Tenant name does not match logged in account $($mgContext.account.id)" -foregroundcolor red
    Disconnect-MgGraph
    connect-mggraph -environment usgov -scope "Group.Read.All" -ErrorAction Stop | Out-Null
    #return
}
Write-Host "Getting Role $roleName"
$role = Get-AzRoleDefinition -Name $roleName
if ($role -eq $null)
{
    Connect-azaccount -Environment AzureUSGovernment -ErrorAction Stop | Out-Null
    $role = Get-AzRoleDefinition -Name $roleName
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
    Write-Host "Found user with id $($user.id)"
    $targetId = $user.id
}
elseif ($PSCmdlet.ParameterSetName -eq 'Group')
{
    Write-Host "Performing Group Lookup for $groupName"
    $group = Get-AzADGroup -DisplayName $groupName
    if ($group -eq $null)
    {
        Write-Host "Failed to find group $groupName" -foregroundcolor Red
        return
    }
    Write-Host "Found group with id $($group.id)"
    $targetId = $group.id
}

if ($PSCmdlet.ParameterSetName -eq 'User')
{
    Write-Host "Assigning User $UserUPN to Role $roleName on scope $scope"
    $assignment = New-AzRoleAssignment -ObjectId $targetId -RoleDefinitionName $roleName -Scope $scope
    Write-Host "Active Assignment created, User: $UserUPN, Role: $roleName, $ResourceType $ResourceName, Tenant $TenantName"
}
elseif ($PSCmdlet.ParameterSetName -eq 'Group')
{
    Write-Host "Assigning Group $GroupName to Role $roleName on scope $scope"
    $assignment = New-AzRoleAssignment -ObjectId $targetId -RoleDefinitionName $roleName -Scope $scope
    Write-Host "Eligibile entry created, Group: $GroupName, Role: $roleName, $ResourceType $ResourceName, Tenant $TenantName"
}