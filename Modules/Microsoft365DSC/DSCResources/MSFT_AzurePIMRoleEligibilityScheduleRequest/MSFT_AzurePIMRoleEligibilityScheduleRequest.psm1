Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzurePIMRoleEligibilityScheduleRequest'

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
        $RoleDefinitionName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [System.String]
        $PrincipalType = 'User',

        [Parameter()]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [ValidateSet('adminAssign', 'adminUpdate', 'adminRemove', 'selfActivate', 'selfDeactivate', 'adminExtend', 'adminRenew', 'selfExtend', 'selfRenew')]
        [System.String]
        $RequestType,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $Id,

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

            # Get Azure Management endpoint based on tenant region
            $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
            $azureManagementEndpoint = $endpoints.AzureManagement

            # Cache role definitions if not already cached
            if ($null -eq $Script:AzureRoleDefinitions)
            {
                Write-Verbose -Message 'Retrieving all Azure role definitions'
                $Script:AzureRoleDefinitions = [System.Collections.Generic.Dictionary[string, object]]::new()
                
                # Get role definitions at the scope level
                $scopeForRoleDefinitions = $Scope
                if ($Scope -notmatch '^/providers/Microsoft.Management/managementGroups/')
                {
                    # For non-management group scopes, we can list role definitions
                    $roleDefsUri = "$azureManagementEndpoint$scopeForRoleDefinitions/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01"
                }
                else
                {
                    # For management groups, use subscription or tenant scope
                    $roleDefsUri = "$azureManagementEndpoint/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01"
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
                        # Also add by name for easier lookup
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

            # Cache existing schedules if not already cached
            if ($null -eq $Script:AllAzureSchedules)
            {
                Write-Verbose -Message 'Retrieving all Azure role eligibility schedules for scope'
                $schedulesUri = "$azureManagementEndpoint$Scope/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01"
                try
                {
                    $schedulesResponse = Invoke-AzRest -Uri $schedulesUri -Method GET
                    $Script:AllAzureSchedules = (ConvertFrom-Json $schedulesResponse.Content).value
                }
                catch
                {
                    Write-Verbose -Message "Failed to retrieve schedules: $_"
                    $Script:AllAzureSchedules = @()
                }
            }
        }
        else
        {
            $schedule = $Script:exportedInstance
            $Script:AllAzureSchedules = @($Script:exportedInstance)
        }

        # Resolve principal ID
        Write-Verbose -Message "Resolving principal: $Principal of type: $PrincipalType"
        $principalId = Get-AzurePIMPrincipalId -Principal $Principal -PrincipalType $PrincipalType
        
        if ($null -eq $principalId)
        {
            Write-Verbose -Message "Could not resolve principal: $Principal"
            return $nullResult
        }

        # Resolve role definition ID
        Write-Verbose -Message "Resolving role definition: $RoleDefinitionName"
        $roleDefinitionId = Get-AzurePIMRoleDefinitionId -RoleDefinitionName $RoleDefinitionName -Scope $Scope
        
        if ($null -eq $roleDefinitionId)
        {
            Write-Verbose -Message "Could not resolve role definition: $RoleDefinitionName"
            return $nullResult
        }

        # Find matching schedule
        if ($null -eq $schedule)
        {
            Write-Verbose -Message "Looking for schedule with PrincipalId: $principalId, RoleDefinitionId: $roleDefinitionId, Scope: $Scope"
            [array]$matchingSchedules = $Script:AllAzureSchedules | Where-Object -FilterScript {
                $_.properties.principalId -eq $principalId -and
                $_.properties.roleDefinitionId -eq $roleDefinitionId -and
                $_.properties.scope -eq $Scope
            }

            if ($matchingSchedules.Count -gt 0)
            {
                $schedule = $matchingSchedules[0]
            }
        }

        if ($null -eq $schedule)
        {
            Write-Verbose -Message "No matching schedule found"
            return $nullResult
        }

        # Build ScheduleInfo
        $ScheduleInfoValue = @{}
        
        if ($null -ne $schedule.properties.endDateTime)
        {
            $expirationValue = [ordered]@{
                type = 'afterDateTime'
                endDateTime = $schedule.properties.endDateTime
            }
            $ScheduleInfoValue.Add('expiration', $expirationValue)
        }
        elseif ($null -eq $schedule.properties.endDateTime)
        {
            $expirationValue = [ordered]@{
                type = 'noExpiration'
            }
            $ScheduleInfoValue.Add('expiration', $expirationValue)
        }
        
        if ($null -ne $schedule.properties.startDateTime)
        {
            $ScheduleInfoValue.Add('startDateTime', $schedule.properties.startDateTime)
        }

        $results = @{
            Principal             = $Principal
            RoleDefinitionName    = $RoleDefinitionName
            Scope                 = $Scope
            PrincipalType         = $PrincipalType
            DirectoryScopeId      = $DirectoryScopeId
            RequestType           = $RequestType
            Justification         = "Assignment of Azure role '$RoleDefinitionName' eligibility to principal '$Principal'"
            ScheduleInfo          = $ScheduleInfoValue
            Status                = $schedule.properties.status
            Id                    = $schedule.name
            Ensure                = 'Present'
            Credential            = $Credential
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
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

        return $nullResult
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
        $RoleDefinitionName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [System.String]
        $PrincipalType = 'User',

        [Parameter()]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [ValidateSet('adminAssign', 'adminUpdate', 'adminRemove', 'selfActivate', 'selfDeactivate', 'adminExtend', 'adminRenew', 'selfExtend', 'selfRenew')]
        [System.String]
        $RequestType,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $Id,

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
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

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

    # Get Azure Management endpoint
    $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
    $azureManagementEndpoint = $endpoints.AzureManagement

    # Resolve principal ID
    Write-Verbose -Message "Resolving principal: $Principal"
    $principalId = Get-AzurePIMPrincipalId -Principal $Principal -PrincipalType $PrincipalType
    
    if ($null -eq $principalId)
    {
        throw "Could not resolve principal: $Principal"
    }

    # Resolve role definition ID
    Write-Verbose -Message "Resolving role definition: $RoleDefinitionName"
    $roleDefinitionId = Get-AzurePIMRoleDefinitionId -RoleDefinitionName $RoleDefinitionName -Scope $Scope
    
    if ($null -eq $roleDefinitionId)
    {
        throw "Could not resolve role definition: $RoleDefinitionName"
    }

    # Build request body
    $requestBody = @{
        properties = @{
            principalId      = $principalId
            roleDefinitionId = $roleDefinitionId
            requestType      = 'AdminAssign'
            justification    = if ($Justification) { $Justification } else { "Managed by Microsoft365DSC" }
            scheduleInfo     = @{}
        }
    }

    # Add schedule information
    if ($null -ne $ScheduleInfo)
    {
        if ($null -ne $ScheduleInfo.startDateTime)
        {
            $requestBody.properties.scheduleInfo.Add('startDateTime', $ScheduleInfo.startDateTime)
        }
        
        if ($null -ne $ScheduleInfo.expiration)
        {
            $expiration = @{
                type = $ScheduleInfo.expiration.type
            }
            
            if ($null -ne $ScheduleInfo.expiration.duration)
            {
                $expiration.Add('duration', $ScheduleInfo.expiration.duration)
            }
            
            if ($null -ne $ScheduleInfo.expiration.endDateTime)
            {
                $expiration.Add('endDateTime', $ScheduleInfo.expiration.endDateTime)
            }
            
            $requestBody.properties.scheduleInfo.Add('expiration', $expiration)
        }
    }

    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Creating new Azure PIM role eligibility schedule"
        $requestBody.properties.requestType = 'AdminAssign'
        
        $requestId = (New-Guid).ToString()
        $uri = "$azureManagementEndpoint$Scope/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/$($requestId)?api-version=2020-10-01"
        $jsonBody = ConvertTo-Json $requestBody -Depth 10
        
        Write-Verbose -Message "Request URI: $uri"
        Write-Verbose -Message "Request Body: $jsonBody"
        
        $response = Invoke-AzRest -Uri $uri -Method PUT -Payload $jsonBody
        
        if ($response.StatusCode -notin @(200, 201))
        {
            throw "Failed to create role eligibility schedule: $($response.Content)"
        }
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating Azure PIM role eligibility schedule"
        $requestBody.properties.requestType = 'AdminUpdate'
        
        $requestId = (New-Guid).ToString()
        $uri = "$azureManagementEndpoint$Scope/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/$($requestId)?api-version=2020-10-01"
        $jsonBody = ConvertTo-Json $requestBody -Depth 10
        
        Write-Verbose -Message "Request URI: $uri"
        Write-Verbose -Message "Request Body: $jsonBody"
        
        $response = Invoke-AzRest -Uri $uri -Method PUT -Payload $jsonBody
        
        if ($response.StatusCode -notin @(200, 201))
        {
            throw "Failed to update role eligibility schedule: $($response.Content)"
        }
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing Azure PIM role eligibility schedule"
        $requestBody.properties.requestType = 'AdminRemove'
        
        $requestId = (New-Guid).ToString()
        $uri = "$azureManagementEndpoint$Scope/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/$($requestId)?api-version=2020-10-01"
        $jsonBody = ConvertTo-Json $requestBody -Depth 10
        
        Write-Verbose -Message "Request URI: $uri"
        Write-Verbose -Message "Request Body: $jsonBody"
        
        $response = Invoke-AzRest -Uri $uri -Method PUT -Payload $jsonBody
        
        if ($response.StatusCode -notin @(200, 201))
        {
            throw "Failed to remove role eligibility schedule: $($response.Content)"
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
        $RoleDefinitionName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [System.String]
        $PrincipalType = 'User',

        [Parameter()]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [ValidateSet('adminAssign', 'adminUpdate', 'adminRemove', 'selfActivate', 'selfDeactivate', 'adminExtend', 'adminRenew', 'selfExtend', 'selfRenew')]
        [System.String]
        $RequestType,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

        [Parameter()]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $Id,

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
        [System.String]
        $CertificateThumbprint,

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

    $result = Test-M365DSCTargetResource -DesiredValues $PSBoundParameters `
                                             -ResourceName $($MyInvocation.MyCommand.Source).Replace('MSFT_', '')
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
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    $ConnectionMode = New-M365DSCConnection -Workload 'Azure' `
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

        # Get all subscriptions to export from
        $subscriptionsUri = "$azureManagementEndpoint/subscriptions?api-version=2020-01-01"
        $subscriptionsResponse = Invoke-AzRest -Uri $subscriptionsUri -Method GET
        $subscriptions = (ConvertFrom-Json $subscriptionsResponse.Content).value

        [array] $Script:exportedInstances = @()
        
        foreach ($subscription in $subscriptions)
        {
            $scope = $subscription.id
            Write-Verbose -Message "Retrieving role eligibility schedules for subscription: $($subscription.displayName)"
            
            $schedulesUri = "$azureManagementEndpoint$scope/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01"
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

        $i = 1
        $dscContent = ''
        if ($Script:exportedInstances.Count -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark
        }
        else
        {
            Write-M365DSCHost -Message "`r`n"
        }

        foreach ($config in $Script:exportedInstances)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $displayedKey = $config.name
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey"

            # Resolve principal
            $principalId = $config.properties.principalId
            $principalInfo = Get-AzurePIMPrincipalInfo -PrincipalId $principalId
            
            if ($null -eq $principalInfo)
            {
                Write-Verbose -Message "Could not resolve principal ID: $principalId"
                continue
            }

            # Resolve role definition
            $roleDefinitionId = $config.properties.roleDefinitionId
            $roleDefinitionName = Get-AzurePIMRoleDefinitionName -RoleDefinitionId $roleDefinitionId
            
            if ($null -eq $roleDefinitionName)
            {
                Write-Verbose -Message "Could not resolve role definition ID: $roleDefinitionId"
                continue
            }

            $params = @{
                Principal             = $principalInfo.Principal
                PrincipalType         = $principalInfo.PrincipalType
                RoleDefinitionName    = $roleDefinitionName
                Scope                 = $config.properties.scope
                Id                    = $config.name
                Ensure                = 'Present'
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $Script:exportedInstance = $config
            $Results = Get-TargetResource @Params

            if ($Results.ScheduleInfo)
            {
                $complexMapping = @(
                    @{
                        Name            = 'expiration'
                        CimInstanceName = 'AzurePIMRoleEligibilityScheduleRequestScheduleExpiration'
                        IsRequired      = $False
                    }
                )
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject $Results.ScheduleInfo `
                        -CIMInstanceName 'AzurePIMRoleEligibilityScheduleRequestSchedule' `
                        -ComplexTypeMapping $complexMapping
                if ($complexTypeStringResult)
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
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark
        }
        return $dscContent
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

# Helper function to resolve principal ID
function Get-AzurePIMPrincipalId
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalType
    )

    try
    {
        # Check if Principal is already a GUID (Object ID)
        $guid = $null
        if ([System.Guid]::TryParse($Principal, [ref]$guid))
        {
            return $Principal
        }

        # Connect to Microsoft Graph to resolve principal
        $null = New-M365DSCConnection -Workload 'MicrosoftGraph' -InboundParameters $PSBoundParameters

        if ($PrincipalType -eq 'User')
        {
            $user = Get-MgUser -Filter "UserPrincipalName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
            return $user.Id
        }
        elseif ($PrincipalType -eq 'Group')
        {
            $group = Get-MgGroup -Filter "DisplayName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
            return $group.Id
        }
        elseif ($PrincipalType -eq 'ServicePrincipal')
        {
            $sp = Get-MgServicePrincipal -Filter "DisplayName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
            return $sp.Id
        }

        return $null
    }
    catch
    {
        Write-Verbose -Message "Failed to resolve principal: $_"
        return $null
    }
}

# Helper function to resolve principal info from ID
function Get-AzurePIMPrincipalInfo
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $PrincipalId
    )

    try
    {
        # Connect to Microsoft Graph to resolve principal
        $null = New-M365DSCConnection -Workload 'MicrosoftGraph' -InboundParameters $PSBoundParameters

        # Try to get as user
        $user = Get-MgUser -UserId $PrincipalId -ErrorAction SilentlyContinue
        if ($null -ne $user)
        {
            return @{
                Principal = $user.UserPrincipalName
                PrincipalType = 'User'
            }
        }

        # Try to get as group
        $group = Get-MgGroup -GroupId $PrincipalId -ErrorAction SilentlyContinue
        if ($null -ne $group)
        {
            return @{
                Principal = $group.DisplayName
                PrincipalType = 'Group'
            }
        }

        # Try to get as service principal
        $sp = Get-MgServicePrincipal -ServicePrincipalId $PrincipalId -ErrorAction SilentlyContinue
        if ($null -ne $sp)
        {
            return @{
                Principal = $sp.DisplayName
                PrincipalType = 'ServicePrincipal'
            }
        }

        return $null
    }
    catch
    {
        Write-Verbose -Message "Failed to resolve principal info: $_"
        return $null
    }
}

# Helper function to resolve role definition ID
function Get-AzurePIMRoleDefinitionId
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinitionName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope
    )

    try
    {
        # Check if cached
        if ($null -ne $Script:AzureRoleDefinitions -and $Script:AzureRoleDefinitions.ContainsKey($RoleDefinitionName))
        {
            return $Script:AzureRoleDefinitions[$RoleDefinitionName].id
        }

        # Get endpoints
        $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
        $azureManagementEndpoint = $endpoints.AzureManagement

        # Query for role definition
        $roleDefsUri = "$azureManagementEndpoint$Scope/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01&`$filter=roleName eq '$RoleDefinitionName'"
        $roleDefsResponse = Invoke-AzRest -Uri $roleDefsUri -Method GET
        $roleDefinitions = (ConvertFrom-Json $roleDefsResponse.Content).value

        if ($roleDefinitions.Count -gt 0)
        {
            return $roleDefinitions[0].id
        }

        return $null
    }
    catch
    {
        Write-Verbose -Message "Failed to resolve role definition: $_"
        return $null
    }
}

# Helper function to resolve role definition name from ID
function Get-AzurePIMRoleDefinitionName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinitionId
    )

    try
    {
        # Check if cached
        if ($null -ne $Script:AzureRoleDefinitions -and $Script:AzureRoleDefinitions.ContainsKey($RoleDefinitionId))
        {
            return $Script:AzureRoleDefinitions[$RoleDefinitionId].properties.roleName
        }

        # Get endpoints
        $endpoints = Get-M365DSCAPIEndpoint -TenantId $TenantId
        $azureManagementEndpoint = $endpoints.AzureManagement

        # Query for role definition
        $roleDefUri = "$azureManagementEndpoint$RoleDefinitionId`?api-version=2022-04-01"
        $roleDefResponse = Invoke-AzRest -Uri $roleDefUri -Method GET
        $roleDefinition = ConvertFrom-Json $roleDefResponse.Content

        if ($null -ne $roleDefinition)
        {
            return $roleDefinition.properties.roleName
        }

        return $null
    }
    catch
    {
        Write-Verbose -Message "Failed to resolve role definition name: $_"
        return $null
    }
}

Export-ModuleMember -Function @('*-TargetResource')
