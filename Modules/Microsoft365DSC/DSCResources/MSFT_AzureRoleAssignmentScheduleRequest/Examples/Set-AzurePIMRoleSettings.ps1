#requires -PSEdition Core -Version 7.0
<#
.SYNOPSIS
    Configures Azure PIM (Privileged Identity Management) settings for Management Groups or Subscriptions.

.DESCRIPTION
    This script configures PIM settings including elevation duration, approval requirements,
    justification requirements, notification settings, and authentication context for specified
    Azure roles within a Management Group or Subscription scope.

.PARAMETER ResourceType
    Type of resource to configure (ManagementGroup or Subscription)

.PARAMETER ResourceName
    Name of the Management Group or Subscription

.PARAMETER TenantName
    Azure AD tenant name (e.g. contoso.com)

.PARAMETER Roles
    Array of Azure roles to configure PIM settings for

.PARAMETER ElevationDuration
    Duration for elevated access (default: PT4H - 4 hours)

.PARAMETER allowpermanentactive
    Switch to allow permanent active assignments

.PARAMETER ApprovalUsers
    Array of users who can approve PIM requests

.PARAMETER ApprovalGroups
    Array of groups who can approve PIM requests

.PARAMETER requireJustification
    Switch to require justification for elevation

.PARAMETER requireTicket
    Switch to require ticket number for elevation

.PARAMETER RequireAuthContext
    Switch to require authentication context

.PARAMETER Notification_Admin_Admin_Eligibility
    Array of notification recipients for admin eligibility events

.PARAMETER Notification_Admin_EndUser_Assignment
    Array of notification recipients for end user assignment events

.PARAMETER Notification_Admin_Admin_Assignment
    Array of notification recipients for admin assignment events

.EXAMPLE
    .\Set-AzurePIMRoleSettings.ps1 -ResourceType Subscription -ResourceName "My-Sub" -TenantName "contoso.com"

#>

param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('ManagementGroup', 'Subscription')]
        $ResourceType,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $ResourceName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $TenantName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $Roles = @(
            "Owner",
            "Contributor",
            "Reader",
            "Billing Reader",
            "User Access Administrator",
            "Support Request Contributor",
            "Microsoft Sentinel Responder",
            "Microsoft Sentinel Playbook Operator",
            "Microsoft Sentinel Reader",
            "Microsoft Sentinel Contributor"
        ),
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $ElevationDuration = "PT4H",
        [Parameter(Mandatory = $false)]
        [switch]$allowpermanentactive,
        [Parameter(Mandatory = $false)]
        $ApprovalUsers = @(),
        [Parameter(Mandatory = $false)]
        $ApprovalGroups = @(),
        [switch]$requireJustification = $true,
        [switch]$requireTicket = $true,
        [switch]$RequireAuthContext = $false,
        [Parameter(Mandatory = $false)]
        [Array]$Notification_Admin_Admin_Eligibility = @(),
        [Parameter(Mandatory = $false)]
        [Array]$Notification_Admin_EndUser_Assignment = @(),
        [Parameter(Mandatory = $false)]
        [Array]$Notification_Admin_Admin_Assignment = @()
)

# Verify Azure Context
$context = Get-AzContext

if ([String]::IsNullOrWhiteSpace($context)) {
    Write-Host "Connecting to Azure account..."
    Connect-azaccount -Environment AzureUSGovernment -ErrorAction Stop | Out-Null
    $context = Get-AzContext
    Write-Host "Connected to Azure account."
}

Write-Host "Confirm in Azure correct tenant"
if ($context.account.id -notlike "*@$TenantName") {
    Write-Host "Tenant name does not match logged in account $($context.account.id)" -foregroundcolor red
    disconnect-azaccount
    Connect-azaccount -Environment AzureUSGovernment -ErrorAction Stop | Out-Null
}

# Verify Graph Context
$mgContext = get-mgcontext

if ([String]::IsNullOrWhiteSpace($mgContext)) {
    Write-Host "Connecting to Graph account..."
    connect-mggraph -environment usgov -scope "User.Read.All","Group.Read.All" -ErrorAction Stop | Out-Null
    $mgContext = get-mgcontext
    Write-Host "Connected to Graph account."
}

Write-Host "Confirm in Graph correct tenant"
if ($mgContext.account -notlike "*@$TenantName") {
    Write-Host "Graph - Tenant name does not match logged in account $($mgContext.account)" -foregroundcolor red
    Disconnect-MgGraph
    connect-mggraph -environment usgov -scope "User.Read.All","Group.Read.All" -ErrorAction Stop | Out-Null
}

# Get Resource Scope
if ($ResourceType -eq "Subscription") {
    $subscription = Get-AzSubscription -SubscriptionName $ResourceName
    $SubscriptionId = $subscription.id
    $scope = "subscriptions/$($subscriptionid)"
    $resourceId = $SubscriptionId
}
elseif ($ResourceType -eq "ManagementGroup")
{
    $mgmtgroup = Get-AzManagementGroup -GroupName $ResourceName -ErrorAction silent
    if ($mgmtgroup -eq $null)
    {
        #the initial query wasn't found, seeing if we can find via DisplayName
        Write-Host "Management Group $ResourceName was not found, checking for DisplayName by name $ResourceName" -foregroundcolor yellow
        $mgmtgroup = Get-AzManagementGroup | ? {$_.DisplayName -eq $ResourceName}
        if ($mgmtgroup -eq $null)
        {
            Write-Host "Management Group $ResourceName was not found" -foregroundcolor red
            return
        }
    }
    $resourceId = $mgmtgroup.id
    $scope = $mgmtgroup.id
}

Write-Host "Getting all the Roles and assignments in scope $scope"
$allRoles = Get-AzRoleManagementPolicyAssignment -Scope $scope

# Process each role
foreach ($role in $roles)
{
    Write-Host "Processing Role: $role"
    Write-Host "Getting current assignments on Role: $role"
    $assignment = $allRoles | Where-Object { $_.roleDefinitionDisplayName -eq $role}
    if ($assignment -eq $null)
    {
        Write-Host "Failed to find Role $role in Scope $scope"
        break
    }

    $PolicyId = $assignment.PolicyId.split('/')[-1]
    Write-Host "Looking up Policy $PolicyId"
    $Policy = get-AzRoleManagementPolicy -scope $scope -name $policyId

    # Configure elevation duration
    Write-Host "Setting max Elevation to $ElevationDuration"
    ($policy.rule | ? {$_.id -eq "Expiration_EndUser_Assignment"}).MaximumDuration = $ElevationDuration

    #Allow perm elevation assignement
    ##Expiration_Admin_Eligibility
    ###IsExpirationRequired = $false
    Write-Host "Allowing permanent elevation Eligibility Assignment"
    ($policy.rule | ? {$_.id -eq "Expiration_Admin_Eligibility"}).IsExpirationRequired = $false
    Write-Host "Allowing permanent elevation Active Assignment"
    ($policy.rule | ? {$_.id -eq "Expiration_Admin_Assignment"}).IsExpirationRequired = (-not $allowpermanentactive)

    # Configure approvals
    $approval = $policy.rule | ? {$_.id -eq "Approval_EndUser_Assignment"}
    $primaryApprovers = @()
    #Add Users for Approvals
    foreach ($user in $ApprovalUsers)
    {
        Write-Host "Adding Approval User $user"
        $PrincipalId = (Get-MgBetaUser -Filter "UserPrincipalName eq '$user'" -ErrorAction SilentlyContinue).id
        if ([string]::IsNullOrEmpty($PrincipalId))
        {
            Write-Host "Failed to lookup User $user"
            continue
        }
        $approvalObject = @{
            UserType = [Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Support.UserType]("User")
            Id = $PrincipalId
        }
        $primaryApprovers += $approvalObject
    }
    #Add Groups for Approvals
    foreach ($group in $ApprovalGroups)
    {
        Write-Host "Adding Approval Group $group"
        $PrincipalId = (Get-MgBetaGroup -Filter "DisplayName eq '$group'" -ErrorAction SilentlyContinue).id
        if ([string]::IsNullOrEmpty($PrincipalId))
        {
            Write-Host "Failed to lookup Group $group" -foregroundcolor red
            return false
        }

        $approvalObject = @{
            UserType = [Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Support.UserType]("Group")
            Id = $PrincipalId
        }
        $primaryApprovers += $approvalObject
    }
    #Require approval if there is an approval Group or Approval User
    $approval.settingIsApprovalRequired = ($ApprovalGroups.length -gt 0 -or $ApprovalUsers.length -gt 0)
    $approval.settingIsRequestorJustificationRequired = $true

    $approval.SettingApprovalStage = @(
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models.Api20201001Preview.ApprovalStage]@{
            EscalationApprover = $null
            EscalationTimeInMinute = 0
            IsApproverJustificationRequired = $true
            IsEscalationEnabled = $false
            TimeOutInDay = 1
            PrimaryApprover = $primaryApprovers
        }
    )

    # Configure enablement rules
    $assignment_EnabledRule = @() # MultiFactorAuthentication, Justification, Ticketing
    if ($requireJustification)
    {
        Write-Host "Enabling Rule 'Justification'"
        $assignment_EnabledRule += 'Justification'
    }
    if ($requireTicket)
    {
        Write-Host "Enabling Rule 'Ticketing'"
        $assignment_EnabledRule += 'Ticketing'
    }

    ($policy.Rule | ? {$_.id -eq "Enablement_EndUser_Assignment"}).EnabledRule = $assignment_EnabledRule

    #Require Justifcation and MultiFactorAuthentication when permanent assignment is made
    ($policy.Rule | ? {$_.id -eq "Enablement_Admin_Assignment"}).EnabledRule = @('Justification','MultiFactorAuthentication')

    ## Use Authentication Context
    ## AuthenticationContext_EndUser_Assignment
    ($policy.Rule | ? {$_.id -eq "AuthenticationContext_EndUser_Assignment"}).isEnabled = $RequireAuthContext
    if ($RequireAuthContext)
    {
        Write-Host "Enabling Authentication Context"
        ($policy.Rule | ? {$_.id -eq "AuthenticationContext_EndUser_Assignment"}).ClaimValue = "c1" # C1 = Strong Auth, C2 = Cert Auth
    }

    ##################
    # Notification_Requestor_Admin_Eligibility = email to elevated user that was assigned as eligible
    # Notification_Admin_Admin_Eligibility = email when someone has been assigned as eligible to DL
    # Notification_Admin_EndUser_Assignment = email when role activated sent to DL
    # Notification_Requestor_EndUser_Assignment = email when role activated sent to elevated user
    # https://wiki.kbobjects.com/spaces/~mikepo/pages/560432552/Entra+PIM+Group+Rule+Names+and+Settings
    ##################

    #Notification_Admin_Admin_Eligibility # When Active assigned
    Write-Host "Setting Notification_Admin_Admin_Assignment $Notification_Admin_Admin_Assignment"
    ($policy.Rule | ? {$_.id -eq "Notification_Admin_Admin_Assignment"}).NotificationRecipient = $Notification_Admin_Admin_Assignment

    #Notification_Admin_Admin_Eligibility # When role elevated\activated
    #email when someone has been assigned as eligible to DL
    Write-Host "Setting Notification_Admin_Admin_Eligibility $Notification_Admin_Admin_Eligibility"
    ($policy.Rule | ? {$_.id -eq "Notification_Admin_Admin_Eligibility"}).NotificationRecipient = $Notification_Admin_Admin_Eligibility

    #Notification_Requestor_Admin_Assignment # to the user when role elevated\activated

    #Notification_Admin_EndUser_Assignment
    #email when role activated sent to DL
    Write-Host "Setting Notification_Admin_EndUser_Assignment $Notification_Admin_EndUser_Assignment"
    ($policy.Rule | ? {$_.id -eq "Notification_Admin_EndUser_Assignment"}).NotificationRecipient = $Notification_Admin_EndUser_Assignment

    # Update policy
    Write-Host "Updating Policy $PolicyId in scope $scope"
    $out = Update-AzRoleManagementPolicy -scope $Scope -name $PolicyId -Rule $Policy.rule
}
