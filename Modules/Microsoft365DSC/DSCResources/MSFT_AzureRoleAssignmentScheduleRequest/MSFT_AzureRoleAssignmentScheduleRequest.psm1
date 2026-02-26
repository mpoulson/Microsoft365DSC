Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureRoleAssignmentScheduleRequest'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter(Mandatory = $true)]
        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [System.String]
        $PrincipalType,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $AppScopeId,

        [Parameter()]
        [ValidateSet('adminAssign', 'adminUpdate', 'adminRemove', 'selfActivate', 'selfDeactivate', 'adminExtend', 'adminRenew', 'selfExtend', 'selfRenew', 'unknownFutureValue')]
        [System.String]
        $Action,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [System.Boolean]
        $IsValidationOnly,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $TicketInfo,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
        $Ensure = 'Present',

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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    try
    {
        if (-not $Script:exportedInstance)
        {
            $null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
                -InboundParameters $PSBoundParameters
            $null = New-M365DSCConnection -Workload 'Azure' `
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

            # Get Azure Management endpoint
            $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
            $azureManagementEndpoint = $endpoints.AzureManagement

            # Cache role definitions via ARM API
            if ($null -eq $Script:AzureRoleDefinitions)
            {
                Write-Verbose -Message 'Retrieving all Azure role definitions'
                $Script:AzureRoleDefinitions = [System.Collections.Generic.Dictionary[System.String, System.Object]]::new()

                if ($DirectoryScopeId -match '^/providers/Microsoft.Management/managementGroups/')
                {
                    $roleDefsUri = "$azureManagementEndpoint/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01"
                }
                else
                {
                    $roleDefsUri = "$azureManagementEndpoint$DirectoryScopeId/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01"
                }

                try
                {
                    $roleDefsResponse = Invoke-AzRest -Uri $roleDefsUri -Method GET
                    $roleDefinitions = (ConvertFrom-Json $roleDefsResponse.Content).value
                    foreach ($roleDef in $roleDefinitions)
                    {
                        if (-not $Script:AzureRoleDefinitions.ContainsKey($roleDef.id))
                        {
                            $Script:AzureRoleDefinitions.Add($roleDef.id, $roleDef)
                        }
                        $roleDefName = $roleDef.properties.roleName
                        if (-not $Script:AzureRoleDefinitions.ContainsKey($roleDefName))
                        {
                            $Script:AzureRoleDefinitions.Add($roleDefName, $roleDef)
                        }
                    }
                }
                catch
                {
                    Write-Verbose -Message "Failed to retrieve role definitions: $_"
                }
            }

            # Cache schedules via ARM API
            if ($null -eq $Script:AllSchedules)
            {
                Write-Verbose -Message 'Retrieving all Azure role assignment schedules'
                $schedulesUri = "$azureManagementEndpoint$DirectoryScopeId/providers/Microsoft.Authorization/roleAssignmentSchedules?api-version=2020-10-01"
                try
                {
                    $schedulesResponse = Invoke-AzRest -Uri $schedulesUri -Method GET
                    $Script:AllSchedules = (ConvertFrom-Json $schedulesResponse.Content).value
                }
                catch
                {
                    Write-Verbose -Message "Failed to retrieve schedules: $_"
                    $Script:AllSchedules = @()
                }
            }
        }
        else
        {
            $schedule = $Script:exportedInstance
            $Script:AllSchedules = $Script:exportedInstances
        }

        Write-Verbose -Message 'Getting Role Assignment by PrincipalId and RoleDefinitionId'
        $PrincipalValue = $null
        if ($PrincipalType -eq 'User')
        {
            Write-Verbose -Message "Retrieving Principal by UserPrincipalName {$Principal}"
            $PrincipalInstance = Get-MgUser -Filter "UserPrincipalName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
            $PrincipalValue = $PrincipalInstance.UserPrincipalName
        }
        elseif ($PrincipalType -eq 'Group')
        {
            Write-Verbose -Message "Retrieving Principal by DisplayName {$Principal}"
            $PrincipalInstance = Get-MgGroup -Filter "DisplayName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
            $PrincipalValue = $PrincipalInstance.DisplayName
        }
        else
        {
            Write-Verbose -Message "Retrieving Principal by DisplayName {$Principal}"
            $PrincipalInstance = Get-MgServicePrincipal -Filter "DisplayName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
            $PrincipalValue = $PrincipalInstance.DisplayName
        }

        if ([System.String]::IsNullOrEmpty($PrincipalValue))
        {
            return $nullResult
        }

        Write-Verbose -Message 'Found Principal'
        $RoleDefinitionId = $null
        $roleDefEntry = $Script:AzureRoleDefinitions.GetEnumerator() | Where-Object -FilterScript { $_.Value.properties.roleName -eq $RoleDefinition } | Select-Object -First 1
        if ($null -ne $roleDefEntry)
        {
            $RoleDefinitionId = $roleDefEntry.Value.id
        }
        Write-Verbose -Message "Retrieved role definition {$RoleDefinition} with ID {$RoleDefinitionId}"

        if ($null -eq $schedule)
        {
            Write-Verbose -Message "Retrieving the request by PrincipalId {$($PrincipalInstance.Id)}, RoleDefinitionId {$($RoleDefinitionId)} and DirectoryScopeId {$($DirectoryScopeId)}"
            [array]$requests = $Script:AllSchedules | Where-Object -FilterScript {
                $_.properties.principalId -eq $PrincipalInstance.Id -and
                $_.properties.roleDefinitionId -eq $RoleDefinitionId -and
                $_.properties.scope -eq $DirectoryScopeId
            }
            if ($requests.Count -eq 0)
            {
                # Check for custom roles with different IDs
                [array]$schedulesForPrincipal = $Script:AllSchedules | Where-Object -FilterScript {
                    $_.properties.principalId -eq $PrincipalInstance.Id -and
                    $_.properties.scope -eq $DirectoryScopeId
                }

                $schedule = $null
                foreach ($foundSchedule in $schedulesForPrincipal)
                {
                    $scheduleRoleId = $foundSchedule.properties.roleDefinitionId
                    $roleEntry = $Script:AzureRoleDefinitions[$scheduleRoleId]
                    if ($null -eq $roleEntry)
                    {
                        $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
                        $azureManagementEndpoint = $endpoints.AzureManagement
                        $roleDefUri = "$azureManagementEndpoint$scheduleRoleId`?api-version=2022-04-01"
                        try
                        {
                            $roleDefResponse = Invoke-AzRest -Uri $roleDefUri -Method GET
                            $roleEntry = ConvertFrom-Json $roleDefResponse.Content
                        }
                        catch
                        {
                            Write-Verbose -Message "Failed to retrieve role definition: $_"
                        }
                    }
                    if ($null -ne $roleEntry -and $roleEntry.properties.roleName -eq $RoleDefinition)
                    {
                        $RoleDefinitionId = $roleEntry.id
                        if (-not $Script:AzureRoleDefinitions.ContainsKey($scheduleRoleId))
                        {
                            $Script:AzureRoleDefinitions.Add($scheduleRoleId, $roleEntry)
                        }
                        $schedule = $foundSchedule
                        break
                    }
                }

                if ($null -eq $schedule)
                {
                    return $nullResult
                }
            }
            else
            {
                $request = $requests[0]
            }
        }

        if ($null -eq $schedule)
        {
            $schedule = $Script:AllSchedules | Where-Object -FilterScript {
                $_.properties.principalId -eq $PrincipalInstance.Id -and
                $_.properties.roleDefinitionId -eq $RoleDefinitionId
            }
        }
        if ($null -eq $schedule)
        {
            foreach ($instance in $Script:AllSchedules)
            {
                $roleDefinitionInfo = $Script:AzureRoleDefinitions[$instance.properties.roleDefinitionId]
                if ($null -ne $roleDefinitionInfo -and $roleDefinitionInfo.properties.roleName -eq $RoleDefinition)
                {
                    $schedule = $instance
                    break
                }
            }
        }

        if ($null -eq $schedule)
        {
            Write-Verbose -Message "Could not retrieve the schedule for {$($PrincipalInstance.Id)} & RoleDefinitionId {$RoleDefinitionId}"
            return $nullResult
        }

        $ScheduleInfoValue = @{}

        if ($null -ne $schedule.properties.endDateTime)
        {
            $expirationValue = [ordered]@{
                type        = 'afterDateTime'
                endDateTime = $schedule.properties.endDateTime
            }
            $ScheduleInfoValue.Add('expiration', $expirationValue)
        }
        else
        {
            $expirationValue = [ordered]@{
                type = 'noExpiration'
            }
            $ScheduleInfoValue.Add('expiration', $expirationValue)
        }

        if ($null -ne $schedule.properties.startDateTime)
        {
            $ScheduleInfoValue.Add('StartDateTime', $schedule.properties.startDateTime)
        }

        $results = @{
            Principal             = $PrincipalValue
            PrincipalType         = $PrincipalType
            RoleDefinition        = $RoleDefinition
            DirectoryScopeId      = $schedule.properties.scope
            AppScopeId            = $AppScopeId
            Id                    = $schedule.name
            Justification         = "Assignment of Azure role '$RoleDefinition' to principal '$PrincipalValue' of type '$PrincipalType'."
            ScheduleInfo          = $ScheduleInfoValue
            Ensure                = 'Present'
            Credential            = $Credential
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            ApplicationSecret     = $ApplicationSecret
            CertificateThumbprint = $CertificateThumbprint
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
        $Principal,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter(Mandatory = $true)]
        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [System.String]
        $PrincipalType,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $AppScopeId,

        [Parameter()]
        [ValidateSet('adminAssign', 'adminUpdate', 'adminRemove', 'selfActivate', 'selfDeactivate', 'adminExtend', 'adminRenew', 'selfExtend', 'selfRenew', 'unknownFutureValue')]
        [System.String]
        $Action,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [System.Boolean]
        $IsValidationOnly,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $TicketInfo,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
        $Ensure = 'Present',

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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    # TODO: Remove during next breaking change
    if ($PSBoundParameters.ContainsKey('Action'))
    {
        Write-Warning -Message "The parameter 'Action' is deprecated. It will be removed in the next breaking change release."
    }

    if ($PSBoundParameters.ContainsKey('IsValidationOnly'))
    {
        Write-Warning -Message "The parameter 'IsValidationOnly' is deprecated. It will be removed in the next breaking change release."
    }

    if ($PSBoundParameters.ContainsKey('TicketInfo'))
    {
        Write-Warning -Message "The parameter 'TicketInfo' is deprecated. It will be removed in the next breaking change release."
    }

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

    # Reset caches to ensure fresh data
    $Script:AllSchedules = $null
    $Script:AzureRoleDefinitions = $null

    $currentInstance = Get-TargetResource @PSBoundParameters

    # Get Azure Management endpoint
    $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
    $azureManagementEndpoint = $endpoints.AzureManagement

    # Resolve principal using Graph cmdlets
    if ($PrincipalType -eq 'User')
    {
        Write-Verbose -Message "Retrieving Principal by UserPrincipalName {$Principal}"
        [Array]$PrincipalIdValue = (Get-MgUser -Filter "UserPrincipalName eq '$($Principal -replace "'", "''")'").Id
    }
    elseif ($PrincipalType -eq 'Group')
    {
        Write-Verbose -Message "Retrieving Principal by DisplayName {$Principal}"
        [Array]$PrincipalIdValue = (Get-MgGroup -Filter "DisplayName eq '$($Principal -replace "'", "''")'").Id
    }
    elseif ($PrincipalType -eq 'ServicePrincipal')
    {
        Write-Verbose -Message "Retrieving Principal by DisplayName {$Principal}"
        [Array]$PrincipalIdValue = (Get-MgServicePrincipal -Filter "DisplayName eq '$($Principal -replace "'", "''")'").Id
    }

    if ($null -eq $PrincipalIdValue)
    {
        throw "Couldn't find Principal {$Principal} of type {$PrincipalType}"
    }
    elseif ($PrincipalIdValue.Length -gt 1)
    {
        throw "Multiple Principal with ID {$Principal} of type {$PrincipalType} were found. Cannot create schedule."
    }

    # Resolve role definition via ARM API
    $RoleDefinitionIdValue = $null
    if ($null -ne $Script:AzureRoleDefinitions -and $Script:AzureRoleDefinitions.ContainsKey($RoleDefinition))
    {
        $RoleDefinitionIdValue = $Script:AzureRoleDefinitions[$RoleDefinition].id
    }
    else
    {
        $roleDefsUri = "$azureManagementEndpoint$DirectoryScopeId/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01&`$filter=roleName eq '$RoleDefinition'"
        $roleDefsResponse = Invoke-AzRest -Uri $roleDefsUri -Method GET
        $roleDefs = (ConvertFrom-Json $roleDefsResponse.Content).value
        if ($roleDefs.Count -gt 0)
        {
            $RoleDefinitionIdValue = $roleDefs[0].id
        }
    }

    if ($null -eq $RoleDefinitionIdValue)
    {
        throw "Couldn't find Role Definition {$RoleDefinition}"
    }

    # Build ARM API request body
    $requestBody = @{
        properties = @{
            principalId      = $PrincipalIdValue[0]
            roleDefinitionId = $RoleDefinitionIdValue
            requestType      = 'AdminAssign'
            justification    = if ($Justification) { $Justification } else { 'Managed by Microsoft365DSC' }
            scheduleInfo     = @{}
        }
    }

    if ($null -ne $ScheduleInfo)
    {
        if ($ScheduleInfo.StartDateTime)
        {
            $requestBody.properties.scheduleInfo.Add('startDateTime', $ScheduleInfo.StartDateTime)
        }

        if ($ScheduleInfo.Expiration)
        {
            $expirationValue = @{
                type = $ScheduleInfo.Expiration.type
            }
            if ($ScheduleInfo.Expiration.duration)
            {
                $expirationValue.Add('duration', $ScheduleInfo.Expiration.duration)
            }
            if ($ScheduleInfo.Expiration.endDateTime)
            {
                $expirationValue.Add('endDateTime', $ScheduleInfo.Expiration.endDateTime)
            }
            $requestBody.properties.scheduleInfo.Add('expiration', $expirationValue)
        }
    }

    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Creating a Role Assignment Schedule Request for principal {$Principal} and role {$RoleDefinition}"
        $requestBody.properties.requestType = 'AdminAssign'

        $requestId = (New-Guid).ToString()
        $uri = "$azureManagementEndpoint$DirectoryScopeId/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/$($requestId)?api-version=2020-10-01"
        $jsonBody = ConvertTo-Json $requestBody -Depth 10

        Write-Verbose -Message "Request URI: $uri"
        Write-Verbose -Message "Request Body: $jsonBody"

        $response = Invoke-AzRest -Uri $uri -Method PUT -Payload $jsonBody

        if ($response.StatusCode -notin @(200, 201))
        {
            throw "Failed to create role assignment schedule: $($response.Content)"
        }
    }
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating the Role Assignment Schedule Request for principal {$Principal} and role {$RoleDefinition}"
        $requestBody.properties.requestType = 'AdminUpdate'

        $requestId = (New-Guid).ToString()
        $uri = "$azureManagementEndpoint$DirectoryScopeId/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/$($requestId)?api-version=2020-10-01"
        $jsonBody = ConvertTo-Json $requestBody -Depth 10

        Write-Verbose -Message "Request URI: $uri"
        Write-Verbose -Message "Request Body: $jsonBody"

        $response = Invoke-AzRest -Uri $uri -Method PUT -Payload $jsonBody

        if ($response.StatusCode -notin @(200, 201))
        {
            throw "Failed to update role assignment schedule: $($response.Content)"
        }
    }
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing the Role Assignment Schedule Request for principal {$Principal} and role {$RoleDefinition}"
        $requestBody.properties.requestType = 'AdminRemove'

        $requestId = (New-Guid).ToString()
        $uri = "$azureManagementEndpoint$DirectoryScopeId/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/$($requestId)?api-version=2020-10-01"
        $jsonBody = ConvertTo-Json $requestBody -Depth 10

        Write-Verbose -Message "Request URI: $uri"
        Write-Verbose -Message "Request Body: $jsonBody"

        $response = Invoke-AzRest -Uri $uri -Method PUT -Payload $jsonBody

        if ($response.StatusCode -notin @(200, 201))
        {
            throw "Failed to remove role assignment schedule: $($response.Content)"
        }
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
        $Principal,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinition,

        [Parameter(Mandatory = $true)]
        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [System.String]
        $PrincipalType,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $AppScopeId,

        [Parameter()]
        [ValidateSet('adminAssign', 'adminUpdate', 'adminRemove', 'selfActivate', 'selfDeactivate', 'adminExtend', 'adminRenew', 'selfExtend', 'selfRenew', 'unknownFutureValue')]
        [System.String]
        $Action,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [System.Boolean]
        $IsValidationOnly,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $TicketInfo,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
        $Ensure = 'Present',

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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    # TODO: Remove during next breaking change
    if ($PSBoundParameters.ContainsKey('Action'))
    {
        Write-Warning -Message "The parameter 'Action' is deprecated. It will be removed in the next breaking change release."
    }

    if ($PSBoundParameters.ContainsKey('IsValidationOnly'))
    {
        Write-Warning -Message "The parameter 'IsValidationOnly' is deprecated. It will be removed in the next breaking change release."
    }

    if ($PSBoundParameters.ContainsKey('TicketInfo'))
    {
        Write-Warning -Message "The parameter 'TicketInfo' is deprecated. It will be removed in the next breaking change release."
    }

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
        $Filter,

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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
        -InboundParameters $PSBoundParameters
    $null = New-M365DSCConnection -Workload 'Azure' `
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
        $Script:ExportMode = $true

        # Get Azure Management endpoint
        $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
        $azureManagementEndpoint = $endpoints.AzureManagement

        [array] $Script:exportedInstances = @()

        # Get all subscriptions
        $subscriptionsUri = "$azureManagementEndpoint/subscriptions?api-version=2020-01-01"
        $subscriptionsResponse = Invoke-AzRest -Uri $subscriptionsUri -Method GET
        $subscriptions = (ConvertFrom-Json $subscriptionsResponse.Content).value

        foreach ($subscription in $subscriptions)
        {
            $scope = $subscription.id
            Write-Verbose -Message "Retrieving role assignment schedules for subscription: $($subscription.displayName)"

            $schedulesUri = "$azureManagementEndpoint$scope/providers/Microsoft.Authorization/roleAssignmentSchedules?api-version=2020-10-01"
            try
            {
                $schedulesResponse = Invoke-AzRest -Uri $schedulesUri -Method GET
                $schedules = (ConvertFrom-Json $schedulesResponse.Content).value
                $Script:exportedInstances += $schedules
            }
            catch
            {
                Write-Verbose -Message "Failed to retrieve schedules for subscription $($subscription.displayName): $_"
            }
        }

        # Get management groups
        $mgGroupsUri = "$azureManagementEndpoint/providers/Microsoft.Management/managementGroups?api-version=2020-05-01"
        try
        {
            $mgGroupsResponse = Invoke-AzRest -Uri $mgGroupsUri -Method GET
            $managementGroups = (ConvertFrom-Json $mgGroupsResponse.Content).value

            foreach ($mgGroup in $managementGroups)
            {
                $scope = $mgGroup.id
                Write-Verbose -Message "Retrieving role assignment schedules for management group: $($mgGroup.properties.displayName)"

                $schedulesUri = "$azureManagementEndpoint$scope/providers/Microsoft.Authorization/roleAssignmentSchedules?api-version=2020-10-01"
                try
                {
                    $schedulesResponse = Invoke-AzRest -Uri $schedulesUri -Method GET
                    $schedules = (ConvertFrom-Json $schedulesResponse.Content).value
                    $Script:exportedInstances += $schedules
                }
                catch
                {
                    Write-Verbose -Message "Failed to retrieve schedules for management group $($mgGroup.properties.displayName): $_"
                }
            }
        }
        catch
        {
            Write-Verbose -Message "Failed to retrieve management groups: $_"
        }

        $i = 1
        $dscContent = ''
        if ($Script:exportedInstances.Count -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }

        # Cache role definitions
        if ($null -eq $Script:AzureRoleDefinitions)
        {
            $Script:AzureRoleDefinitions = [System.Collections.Generic.Dictionary[System.String, System.Object]]::new()
        }

        foreach ($request in $Script:exportedInstances)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $displayedKey = $request.name
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -DeferWrite

            # Find the Principal Type using Get-MgBetaDirectoryObjectById (same as AAD pattern)
            $principalType = 'User'
            $userInfo = Get-MgBetaDirectoryObjectById -Ids $request.properties.principalId -ErrorAction SilentlyContinue
            $principalType = $userInfo.AdditionalProperties['@odata.type'].Split('.')[2]
            $PrincipalValue = if ($principalType -eq 'user')
            {
                $userInfo.AdditionalProperties['userPrincipalName']
            }
            else
            {
                $userInfo.AdditionalProperties['displayName']
            }

            if ($null -ne $PrincipalValue)
            {
                # Resolve role definition
                $roleDefinitionId = $request.properties.roleDefinitionId
                $roleDefinitionName = $null
                if ($Script:AzureRoleDefinitions.ContainsKey($roleDefinitionId))
                {
                    $roleDefinitionName = $Script:AzureRoleDefinitions[$roleDefinitionId].properties.roleName
                }
                else
                {
                    $roleDefUri = "$azureManagementEndpoint$roleDefinitionId`?api-version=2022-04-01"
                    try
                    {
                        $roleDefResponse = Invoke-AzRest -Uri $roleDefUri -Method GET
                        $roleDef = ConvertFrom-Json $roleDefResponse.Content
                        $roleDefinitionName = $roleDef.properties.roleName
                        $Script:AzureRoleDefinitions.Add($roleDefinitionId, $roleDef)
                    }
                    catch
                    {
                        Write-Verbose -Message "Failed to retrieve role definition: $_"
                    }
                }

                if ($null -ne $roleDefinitionName)
                {
                    $params = @{
                        Id                    = $request.name
                        Principal             = $PrincipalValue
                        PrincipalType         = $principalType
                        DirectoryScopeId      = $request.properties.scope
                        RoleDefinition        = $roleDefinitionName
                        Ensure                = 'Present'
                        Credential            = $Credential
                        ApplicationId         = $ApplicationId
                        TenantId              = $TenantId
                        ApplicationSecret     = $ApplicationSecret
                        CertificateThumbprint = $CertificateThumbprint
                        ManagedIdentity       = $ManagedIdentity.IsPresent
                        AccessTokens          = $AccessTokens
                    }
                }
            }

            $Script:exportedInstance = $request
            $Results = Get-TargetResource @Params

            if ($null -ne $Results.ScheduleInfo)
            {
                $complexMapping = @(
                    @{
                        Name            = 'ScheduleInfo'
                        CimInstanceName = 'MSFT_AzureRoleAssignmentScheduleRequestSchedule'
                        IsRequired      = $False
                    },
                    @{
                        Name            = 'expiration'
                        CimInstanceName = 'MSFT_AzureRoleAssignmentScheduleRequestScheduleExpiration'
                        IsRequired      = $False
                    },
                    @{
                        Name            = 'recurrence'
                        CimInstanceName = 'MSFT_AzureRoleAssignmentScheduleRequestScheduleRecurrence'
                        IsRequired      = $False
                    },
                    @{
                        Name            = 'pattern'
                        CimInstanceName = 'MSFT_AzureRoleAssignmentScheduleRequestScheduleRecurrencePattern'
                        IsRequired      = $False
                    },
                    @{
                        Name            = 'range'
                        CimInstanceName = 'MSFT_AzureRoleAssignmentScheduleRequestScheduleRecurrenceRange'
                        IsRequired      = $False
                    }
                )
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString `
                    -ComplexObject $Results.ScheduleInfo `
                    -CIMInstanceName 'MSFT_AzureRoleAssignmentScheduleRequestSchedule' `
                    -ComplexTypeMapping $complexMapping

                if (-Not [String]::IsNullOrWhiteSpace($complexTypeStringResult))
                {
                    $Results.ScheduleInfo = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('ScheduleInfo') | Out-Null
                }
            }
            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential `
                -NoEscape @('ScheduleInfo')

            $dscContent += $currentDSCBlock
            Save-M365DSCPartialExport -Content $currentDSCBlock `
                -FileName $Global:PartialExportFileName
            $i++
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        return $dscContent
    }
    catch
    {
        if ($_.ErrorDetails.Message -like '*The tenant needs an AAD Premium*' -or `
                $_.ErrorDetails.Message -like '*[AadPremiumLicenseRequired]*')
        {
            Write-M365DSCHost -Message "`r`n    $($Global:M365DSCEmojiYellowCircle) Tenant does not meet license requirement to extract this component."
            return ''
        }
        else
        {
            New-M365DSCLogEntry -Message 'Error during Export:' `
                -Exception $_ `
                -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $TenantId `
                -Credential $Credential

            throw
        }
    }
}

function Test-M365DSCRecurrenceIsConfigured
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $RecurrenceSettings
    )

    if ($null -eq $RecurrenceSettings.Pattern.DayOfMonth -and `
        $null -eq $RecurrenceSettings.Pattern.DayOfWeek -and `
        $null -eq $RecurrenceSettings.Pattern.FirstDayOfWeek -and `
        $null -eq $RecurrenceSettings.Pattern.Index -and `
        $null -eq $RecurrenceSettings.Pattern.Interval -and `
        $null -eq $RecurrenceSettings.Pattern.Month -and `
        $null -eq $RecurrenceSettings.Pattern.Type -and `
        $null -eq $RecurrenceSettings.Range.EndDate -and `
        $null -eq $RecurrenceSettings.Range.NumberOfOccurrences -and `
        $null -eq $RecurrenceSettings.Range.RecurrenceTimeZone -and `
        $null -eq $RecurrenceSettings.Range.StartDate -and `
        $null -eq $RecurrenceSettings.Range.Type)
    {
        return $false
    }

    return $true
}

function Get-CompareParameters
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param()

    return @{
        ExcludedProperties = @('Action', 'IsValidationOnly', 'Justification', 'TicketInfo')
        PostProcessing = {
            param($DesiredValues, $CurrentValues, $ValuesToCheck, $ignore)
            if ($null -ne $DesiredValues.ScheduleInfo -and
                -not [System.String]::IsNullOrEmpty($DesiredValues.ScheduleInfo.StartDateTime))
            {
                $parsedDesiredDate = [System.DateTime]::MinValue
                $parseResultDesired = [System.DateTime]::TryParse($DesiredValues.ScheduleInfo.StartDateTime, [ref]$parsedDesiredDate)

                $parsedCurrentDate = [System.DateTime]::MinValue
                $parseResultCurrent = [System.DateTime]::TryParse($CurrentValues.ScheduleInfo.StartDateTime, [ref]$parsedCurrentDate)

                if ($parseResultDesired -and $parseResultCurrent)
                {
                    Write-Verbose -Message "Parsed Desired StartDateTime: $parsedDesiredDate, Parsed Current StartDateTime: $parsedCurrentDate"
                    if ($parsedDesiredDate -ne $parsedCurrentDate -and $parsedDesiredDate -lt [System.DateTime]::UtcNow)
                    {
                        Write-Verbose -Message "Ignoring StartDateTime in ScheduleInfo as it is in the past. StartDateTime cannot be set to a past date."
                        Write-Verbose -Message "Aligning the Desired and Current StartDateTime values for comparison."
                        $DesiredValues.ScheduleInfo.StartDateTime = $CurrentValues.ScheduleInfo.StartDateTime
                    }
                }
            }
            return [System.Tuple[Hashtable, Hashtable, Hashtable]]::new($DesiredValues, $CurrentValues, $ValuesToCheck)
        }
    }
}

Export-ModuleMember -Function @('*-TargetResource', 'Get-CompareParameters')
