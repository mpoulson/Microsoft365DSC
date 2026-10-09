Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureBillingAccountsRoleAssignment'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccount,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalTenantId,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $SubscriptionId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    Write-Verbose -Message "Getting configuration of Azure Billing Accounts Role Assignment for Billing Account $BillingAccount and Principal Name $PrincipalName"

    try
    {
        $null = New-M365DSCConnection -Workload 'Azure' `
            -InboundParameters $PSBoundParameters

        $null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
            -InboundParameters $PSBoundParameters

        #Ensure the proper dependencies are installed in the current environment.
        Confirm-M365DSCDependencies

        #region Telemetry
        $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
        $CommandName = $MyInvocation.MyCommand
        $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
            -CommandName $CommandName `
            -Parameters $PSBoundParameters
        Add-M365DSCTelemetryEvent -Data $data
        #endregion

        $nullResult = $PSBoundParameters
        $nullResult.Ensure = 'Absent'

        $accounts = Get-M365DSCAzureBillingAccount
        $currentAccount = $accounts.value | Where-Object -FilterScript { $_.properties.displayName -eq $BillingAccount }

        $instance = $null
        $RoleDefinitionValue = $null
        if ($null -ne $currentAccount)
        {
            $instances = Get-M365DSCAzureBillingAccountsRoleAssignment -BillingAccountId $currentAccount.Name -ErrorAction Stop
            $PrincipalIdValue = Get-M365DSCPrincipalIdFromName -PrincipalName $PrincipalName `
                -PrincipalType $PrincipalType

            # Legacy Enterprise Agreement assignments carry no principalId, identifying their principal only
            # by principalPuid and the email address the enrollment was invited with, so match on that as
            # well. Without the fallback such an assignment is always reported as Absent and every run tries
            # to create it a second time.
            $candidates = @($instances.value | Where-Object -FilterScript {
                    (-not [System.String]::IsNullOrEmpty($PrincipalIdValue) -and $_.properties.principalId -eq $PrincipalIdValue) -or
                    (-not [System.String]::IsNullOrEmpty($_.properties.userEmailAddress) -and $_.properties.userEmailAddress -eq $PrincipalName)
                })

            # A principal can hold more than one role on the same billing account, and RoleDefinition is a
            # key of this resource, so pick the assignment carrying the requested role. The export passes the
            # 'AnyRole' sentinel to mean whichever role the assignment happens to carry.
            foreach ($candidate in $candidates)
            {
                $candidateRole = Get-M365DSCAzureBillingRoleName -BillingAccountId $currentAccount.Name `
                    -RoleDefinitionResourceId $candidate.properties.roleDefinitionId

                if ($RoleDefinition -eq 'AnyRole' -or $RoleDefinition -eq $candidateRole)
                {
                    $instance = $candidate
                    $RoleDefinitionValue = $candidateRole
                    break
                }
            }
        }
        if ($null -eq $instance)
        {
            return $nullResult
        }

        $PrincipalTenantIdValue = $instance.properties.principalTenantId
        if ([System.String]::IsNullOrEmpty($PrincipalTenantIdValue))
        {
            $PrincipalTenantIdValue = $PrincipalTenantId
        }

        $results = @{
            BillingAccount        = $BillingAccount
            PrincipalName         = $PrincipalName
            PrincipalType         = $PrincipalType
            PrincipalTenantId     = $PrincipalTenantIdValue
            RoleDefinition        = $RoleDefinitionValue
            Ensure                = 'Present'
            SubscriptionId        = $SubscriptionId
            Credential            = $Credential
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
            CertificatePath       = $CertificatePath
            CertificatePassword   = $CertificatePassword
            ManagedIdentity       = $ManagedIdentity.IsPresent
            AccessTokens          = $AccessTokens
        }
        return $results
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error retrieving data:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        throw
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccount,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalTenantId,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $SubscriptionId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    Write-Verbose -Message "Setting configuration of Azure Billing Accounts Role Assignment for Billing Account {$BillingAccount} and Principal Name {$PrincipalName}"

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $currentInstance = Get-TargetResource @PSBoundParameters

    $billingAccounts = Get-M365DSCAzureBillingAccount
    $account = $billingAccounts.value | Where-Object -FilterScript { $_.properties.displayName -eq $BillingAccount }
    $PrincipalIdValue = Get-M365DSCPrincipalIdFromName -PrincipalName $PrincipalName `
        -PrincipalType $PrincipalType
    $RoleDefinitionValues = Get-M365DSCAzureBillingAccountsRoleDefinition -BillingAccountId $account.Name

    # Match the requested role, not the one already assigned, otherwise a change of role re-applies the
    # existing one. Enterprise Agreement returns some role definitions with no friendly roleName, so also
    # accept the role definition identifier.
    $roleDefinitionInstance = $RoleDefinitionValues.value | Where-Object -FilterScript {
        $_.properties.roleName -eq $RoleDefinition -or $_.name -eq $RoleDefinition
    }
    $instanceParams = @{
        principalId       = $PrincipalIdValue
        principalTenantId = $PrincipalTenantId
        roleDefinitionId  = $roleDefinitionInstance.id
    }
    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Adding new role assignment for user {$PrincipalName} for role {$RoleDefinition}"
        New-M365DSCAzureBillingAccountsRoleAssignment -BillingAccountId $account.Name `
            -Body $instanceParams
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating role assignment for user {$PrincipalName} for role {$RoleDefinition}"
        New-M365DSCAzureBillingAccountsRoleAssignment -BillingAccountId $account.Name `
            -Body $instanceParams
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        $instances = Get-M365DSCAzureBillingAccountsRoleAssignment -BillingAccountId $account.Name -ErrorAction Stop
        $instance = @($instances.value | Where-Object -FilterScript {
                (-not [System.String]::IsNullOrEmpty($PrincipalIdValue) -and $_.properties.principalId -eq $PrincipalIdValue) -or
                (-not [System.String]::IsNullOrEmpty($_.properties.userEmailAddress) -and $_.properties.userEmailAddress -eq $PrincipalName)
            })[0]
        $AssignmentId = $instance.Id.Split('/')
        $AssignmentId = $AssignmentId[$AssignmentId.Length - 1]
        Write-Verbose -Message "Removing role assignment for user {$PrincipalName} for role {$RoleDefinition}"
        Remove-M365DSCAzureBillingAccountsRoleAssignment -BillingAccountId $account.Name `
            -AssignmentId $AssignmentId
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccount,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalTenantId,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $SubscriptionId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $compareParameters = Get-CompareParameters
    $result = Test-M365DSCTargetResource -DesiredValues $PSBoundParameters `
        -ResourceName $($MyInvocation.MyCommand.Source).Replace('MSFT_', '') `
        @compareParameters
    return $result
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.String]
        $SubscriptionId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    $ConnectionMode = New-M365DSCConnection -Workload 'Azure' `
        -InboundParameters $PSBoundParameters

    $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
        -InboundParameters $PSBoundParameters

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        #Get all billing account
        $accounts = Get-M365DSCAzureBillingAccount

        $i = 1
        $dscContent = [System.Text.StringBuilder]::new()
        if ($Script:exportedInstances.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }
        foreach ($config in $accounts.value)
        {
            $displayedKey = $config.properties.displayName
            Write-M365DSCHost -Message "    |---[$i/$($accounts.Count)] $displayedKey"

            $assignments = Get-M365DSCAzureBillingAccountsRoleAssignment -BillingAccountId $config.name

            $j = 1
            foreach ($assignment in $assignments.value)
            {
                # Enterprise Agreement enrollments never populate principalType, and legacy enrollment
                # administrator entries created through the EA portal identify their principal only by
                # principalPuid and userEmailAddress, leaving principalId and principalTenantId empty. Every
                # one of those maps to a mandatory parameter of this resource, so passing the empty string
                # through aborted the whole export instead of skipping the single assignment.
                $principal = Get-M365DSCAzureBillingPrincipal -Assignment $assignment `
                    -TenantId $TenantId

                if ($null -eq $principal)
                {
                    Write-Verbose -Message "Skipping billing role assignment {$($assignment.name)} on billing account {$displayedKey}: its principal could not be identified from principalId {$($assignment.properties.principalId)}, userEmailAddress or principalDisplayName."
                    $j++
                    continue
                }

                if ($null -ne $Global:M365DSCExportResourceInstancesCount)
                {
                    $Global:M365DSCExportResourceInstancesCount++
                }

                Write-M365DSCHost -Message "        |---[$j/$($assignments.value.Length)] $($principal.Name)" -DeferWrite
                $params = @{
                    BillingAccount        = $config.properties.displayName
                    PrincipalName         = $principal.Name
                    PrincipalType         = $principal.Type
                    PrincipalTenantId     = $principal.TenantId
                    RoleDefinition        = 'AnyRole'
                    SubscriptionId        = $SubscriptionId
                    Credential            = $Credential
                    ApplicationId         = $ApplicationId
                    TenantId              = $TenantId
                    CertificateThumbprint = $CertificateThumbprint
                    ManagedIdentity       = $ManagedIdentity.IsPresent
                    AccessTokens          = $AccessTokens
                }

                $Results = Get-TargetResource @Params

                $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                    -ConnectionMode $ConnectionMode `
                    -ModulePath $PSScriptRoot `
                    -Results $Results `
                    -Credential $Credential
                [void]$dscContent.Append($currentDSCBlock)
                Save-M365DSCPartialExport -Content $currentDSCBlock `
                    -FileName $Global:PartialExportFileName
                $j++
                Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
            }
            $i++
        }
        return $dscContent.ToString()
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error during Export:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        throw
    }
}

function Get-M365DSCAzureBillingPrincipal
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Object]
        $Assignment,

        [Parameter()]
        [System.String]
        $TenantId
    )

    $principalId = $Assignment.properties.principalId
    $principalType = $Assignment.properties.principalType
    $principalTenantId = $Assignment.properties.principalTenantId
    $principalName = $null

    if (-not [System.String]::IsNullOrEmpty($principalId))
    {
        # Enterprise Agreement omits principalType, so probe the directory by identifier to establish both
        # the type and the name that the Get method has to resolve back into that same identifier.
        $candidateTypes = @($principalType)
        if ([System.String]::IsNullOrEmpty($principalType))
        {
            $candidateTypes = @('User', 'ServicePrincipal', 'Group')
        }

        foreach ($candidateType in $candidateTypes)
        {
            try
            {
                $principalName = Get-M365DSCPrincipalNameFromId -PrincipalId $principalId `
                    -PrincipalType $candidateType
            }
            catch
            {
                $principalName = $null
            }

            if (-not [System.String]::IsNullOrEmpty($principalName))
            {
                $principalType = $candidateType
                break
            }
        }
    }

    # Legacy Enterprise Agreement entries carry no identifier at all. They are always users, invited by
    # email address, and that address is what the Get method matches them on.
    if ([System.String]::IsNullOrEmpty($principalName) -and
        -not [System.String]::IsNullOrEmpty($Assignment.properties.userEmailAddress))
    {
        $principalName = $Assignment.properties.userEmailAddress
        $principalType = 'User'
    }

    if ([System.String]::IsNullOrEmpty($principalName))
    {
        $principalName = $Assignment.properties.principalDisplayName
    }

    if ([System.String]::IsNullOrEmpty($principalName) -or [System.String]::IsNullOrEmpty($principalType))
    {
        return $null
    }

    # A principal resolved through the directory currently connected to belongs to that tenant, so use the
    # tenant identifier the caller was already given when the billing plane does not report one.
    if ([System.String]::IsNullOrEmpty($principalTenantId))
    {
        $principalTenantId = $TenantId
    }

    if ([System.String]::IsNullOrEmpty($principalTenantId))
    {
        return $null
    }

    return @{
        Name     = $principalName
        Type     = $principalType
        TenantId = $principalTenantId
    }
}

function Get-M365DSCAzureBillingRoleName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId,

        [Parameter()]
        [System.String]
        $RoleDefinitionResourceId
    )

    if ([System.String]::IsNullOrEmpty($RoleDefinitionResourceId))
    {
        return $null
    }

    $segments = $RoleDefinitionResourceId.Split('/')
    $roleDefinitionId = $segments[$segments.Length - 1]

    if ([System.String]::IsNullOrEmpty($roleDefinitionId))
    {
        return $null
    }

    $roleDefinition = Get-M365DSCAzureBillingAccountsRoleDefinition -BillingAccountId $BillingAccountId `
        -RoleDefinitionId $roleDefinitionId

    # Enterprise Agreement returns some role definitions with no friendly roleName, reporting them as
    # EaRoleId_<guid>. RoleDefinition is a key of this resource, so it can never be left empty.
    $result = $roleDefinition.properties.roleName
    if ([System.String]::IsNullOrEmpty($result))
    {
        $result = $roleDefinition.name
    }
    if ([System.String]::IsNullOrEmpty($result))
    {
        $result = $roleDefinitionId
    }
    return $result
}

function Get-M365DSCPrincipalNameFromId
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalType
    )

    $result = $null
    if ($PrincipalType -eq 'User')
    {
        $userInfo = Get-MgUser -UserId $PrincipalId
        if ($null -ne $userInfo)
        {
            $result = $userInfo.UserPrincipalName
        }
    }
    elseif ($PrincipalType -eq 'ServicePrincipal')
    {
        $spnInfo = Get-MgServicePrincipal -ServicePrincipalId $PrincipalId
        if ($null -ne $spnInfo)
        {
            $result = $spnInfo.DisplayName
        }
    }
    elseif ($PrincipalType -eq 'Group')
    {
        $groupInfo = Get-MgGroup -GroupId $PrincipalId
        if ($null -ne $groupInfo)
        {
            $result = $groupInfo.DisplayName
        }
    }
    return $result
}

function Get-M365DSCPrincipalIdFromName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalType
    )

    $result = $null
    if ($PrincipalType -eq 'User')
    {
        $userInfo = Get-MgUser -Filter "UserPrincipalName eq '$($PrincipalName -replace "'", "''")'"
        if ($null -ne $userInfo)
        {
            $result = $userInfo.Id
        }
    }
    elseif ($PrincipalType -eq 'ServicePrincipal')
    {
        $spnInfo = Get-MgServicePrincipal -Filter "DisplayName eq '$($PrincipalName -replace "'", "''")'"
        if ($null -ne $spnInfo)
        {
            $result = $spnInfo.Id
        }
    }
    elseif ($PrincipalType -eq 'Group')
    {
        $groupInfo = Get-MgGroup -Filter "DisplayName eq '$($PrincipalName -replace "'", "''")'"
        if ($null -ne $groupInfo)
        {
            $result = $groupInfo.Id
        }
    }
    return $result
}

function Get-CompareParameters
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param()

    return @{
        ExcludedProperties = @('SubscriptionId')
    }
}

Export-ModuleMember -Function @('*-TargetResource', 'Get-CompareParameters')
