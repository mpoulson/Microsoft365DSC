Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureRoleEligibilityScheduleRequest'

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

        [Parameter(Mandatory = $true)]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

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
        $nullResult = $PSBoundParameters
        $nullResult.Ensure = 'Absent'

        if (-not $Script:exportedInstance)
        {
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

            if ($null -eq $Script:AllSchedules)
            {
                Write-Verbose -Message 'Retrieving all Azure role eligibility schedules'
                $uri = 'https://graph.microsoft.com/beta/roleManagement/azureResources/roleEligibilitySchedules?$filter=' + [System.Uri]::EscapeDataString("directoryScopeId eq '$DirectoryScopeId'")
                $response = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction SilentlyContinue
                $Script:AllSchedules = $response.value
            }

            if ($null -eq $Script:RoleDefinitions)
            {
                Write-Verbose -Message 'Retrieving all Azure role definitions for scope'
                $Script:RoleDefinitions = [System.Collections.Generic.Dictionary[string, object]]::new()
                $rdUri = 'https://graph.microsoft.com/beta/roleManagement/azureResources/roleDefinitions?$filter=' + [System.Uri]::EscapeDataString("scope eq '$DirectoryScopeId'")
                $rdResponse = Invoke-MgGraphRequest -Uri $rdUri -Method GET -ErrorAction SilentlyContinue
                foreach ($singleRoleDefinition in $rdResponse.value)
                {
                    if (-not $Script:RoleDefinitions.ContainsKey($singleRoleDefinition.id))
                    {
                        $Script:RoleDefinitions.Add($singleRoleDefinition.id, $singleRoleDefinition)
                    }
                }
            }
        }
        else
        {
            $schedule = $Script:exportedInstance
            $Script:AllSchedules = $Script:exportedInstance
        }

        Write-Verbose -Message 'Getting Azure Role Eligibility by PrincipalId and RoleDefinitionId'
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
            Write-Verbose -Message "Principal {$Principal} not found."
            return $nullResult
        }

        Write-Verbose -Message "Found Principal {$PrincipalValue}"

        $RoleDefinitionId = $null
        foreach ($kvp in $Script:RoleDefinitions.GetEnumerator())
        {
            if ($kvp.Value.displayName -eq $RoleDefinition)
            {
                $RoleDefinitionId = $kvp.Key
                break
            }
        }
        Write-Verbose -Message "Retrieved role definition {$RoleDefinition} with ID {$RoleDefinitionId}"

        $schedule = $null
        if ($null -ne $Script:AllSchedules)
        {
            [array]$matchingSchedules = $Script:AllSchedules | Where-Object -FilterScript {
                $_.principalId -eq $PrincipalInstance.Id -and
                $_.roleDefinitionId -eq $RoleDefinitionId -and
                $_.directoryScopeId -eq $DirectoryScopeId
            }

            if ($matchingSchedules.Count -eq 0)
            {
                [array]$schedulesForPrincipal = $Script:AllSchedules | Where-Object -FilterScript {
                    $_.principalId -eq $PrincipalInstance.Id -and
                    $_.directoryScopeId -eq $DirectoryScopeId
                }

                foreach ($foundSchedule in $schedulesForPrincipal)
                {
                    $scheduleRoleId = $foundSchedule.roleDefinitionId
                    $roleEntry = $Script:RoleDefinitions[$scheduleRoleId]
                    if ($null -ne $roleEntry -and $roleEntry.displayName -eq $RoleDefinition)
                    {
                        $RoleDefinitionId = $scheduleRoleId
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
                $schedule = $matchingSchedules[0]
            }
        }

        if ($null -eq $schedule)
        {
            return $nullResult
        }

        $ScheduleInfoValue = @{}

        if ($null -ne $schedule.scheduleInfo.expiration)
        {
            $expirationValue = [ordered]@{
                duration = $schedule.scheduleInfo.expiration.duration
                type     = $schedule.scheduleInfo.expiration.type
            }
            if ($null -ne $schedule.scheduleInfo.expiration.endDateTime)
            {
                $endDt = [System.DateTime]::Parse($schedule.scheduleInfo.expiration.endDateTime)
                $expirationValue.Add('endDateTime', $endDt.ToString('yyyy-MM-ddTHH:mm:ssZ'))
            }
            $ScheduleInfoValue.Add('expiration', $expirationValue)
        }
        if ($null -ne $schedule.scheduleInfo.recurrence)
        {
            if (Test-M365DSCAzureRoleEligibilityRecurrenceIsConfigured -RecurrenceSettings $schedule.scheduleInfo.recurrence)
            {
                $recurrenceValue = [ordered]@{
                    pattern = [ordered]@{
                        dayOfMonth     = $schedule.scheduleInfo.recurrence.pattern.dayOfMonth
                        daysOfWeek     = $schedule.scheduleInfo.recurrence.pattern.daysOfWeek
                        firstDayOfWeek = $schedule.scheduleInfo.recurrence.pattern.firstDayOfWeek
                        index          = $schedule.scheduleInfo.recurrence.pattern.index
                        interval       = $schedule.scheduleInfo.recurrence.pattern.interval
                        month          = $schedule.scheduleInfo.recurrence.pattern.month
                        type           = $schedule.scheduleInfo.recurrence.pattern.type
                    }
                    range   = [ordered]@{
                        endDate             = $schedule.scheduleInfo.recurrence.range.endDate
                        numberOfOccurrences = $schedule.scheduleInfo.recurrence.range.numberOfOccurrences
                        recurrenceTimeZone  = $schedule.scheduleInfo.recurrence.range.recurrenceTimeZone
                        startDate           = $schedule.scheduleInfo.recurrence.range.startDate
                        type                = $schedule.scheduleInfo.recurrence.range.type
                    }
                }
                $ScheduleInfoValue.Add('Recurrence', $recurrenceValue)
            }
        }
        if ($null -ne $schedule.scheduleInfo.startDateTime)
        {
            $startDt = [System.DateTime]::Parse($schedule.scheduleInfo.startDateTime)
            $ScheduleInfoValue.Add('StartDateTime', $startDt.ToString('yyyy-MM-ddTHH:mm:ssZ'))
        }

        $results = @{
            Principal             = $PrincipalValue
            PrincipalType         = $PrincipalType
            RoleDefinition        = $RoleDefinition
            DirectoryScopeId      = $schedule.directoryScopeId
            Id                    = $schedule.id
            Justification         = "Assignment of role eligibility '$RoleDefinition' to principal '$PrincipalValue' of type '$PrincipalType'."
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

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

    if ($PrincipalType -eq 'User')
    {
        Write-Verbose -Message "Retrieving Principal by UserPrincipalName {$Principal}"
        $PrincipalInstance = Get-MgUser -Filter "UserPrincipalName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
        $PrincipalId = $PrincipalInstance.Id
    }
    elseif ($PrincipalType -eq 'Group')
    {
        Write-Verbose -Message "Retrieving Principal by DisplayName {$Principal}"
        $PrincipalInstance = Get-MgGroup -Filter "DisplayName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
        $PrincipalId = $PrincipalInstance.Id
    }
    else
    {
        Write-Verbose -Message "Retrieving Principal by DisplayName {$Principal}"
        $PrincipalInstance = Get-MgServicePrincipal -Filter "DisplayName eq '$($Principal -replace "'", "''")'" -ErrorAction SilentlyContinue
        $PrincipalId = $PrincipalInstance.Id
    }

    if ([System.String]::IsNullOrEmpty($PrincipalId))
    {
        throw "Could not find Principal {$Principal} of type {$PrincipalType}"
    }

    $rdUri = 'https://graph.microsoft.com/beta/roleManagement/azureResources/roleDefinitions?$filter=' + [System.Uri]::EscapeDataString("scope eq '$DirectoryScopeId' and displayName eq '$($RoleDefinition -replace "'", "''")'")
    $rdResponse = Invoke-MgGraphRequest -Uri $rdUri -Method GET -ErrorAction SilentlyContinue
    $RoleDefinitionEntry = $rdResponse.value | Select-Object -First 1
    $RoleDefinitionId = $RoleDefinitionEntry.id

    if ([System.String]::IsNullOrEmpty($RoleDefinitionId))
    {
        throw "Could not find role definition {$RoleDefinition} for scope {$DirectoryScopeId}"
    }

    $instanceParams = @{
        principalId      = $PrincipalId
        roleDefinitionId = $RoleDefinitionId
        directoryScopeId = $DirectoryScopeId
        scheduleInfo     = @{
            expiration = @{
                type        = $ScheduleInfo.Expiration.Type
                duration    = $ScheduleInfo.Expiration.Duration
                endDateTime = $ScheduleInfo.Expiration.EndDateTime
            }
            startDateTime = $ScheduleInfo.StartDateTime
        }
    }

    if ($null -eq $instanceParams.scheduleInfo.expiration.duration)
    {
        $instanceParams.scheduleInfo.expiration.Remove('duration') | Out-Null
    }

    if ([System.String]::IsNullOrEmpty($instanceParams.scheduleInfo.expiration.endDateTime))
    {
        $instanceParams.scheduleInfo.expiration.Remove('endDateTime') | Out-Null
    }

    $RecurrenceInfo = @{}
    $foundRecurrenceItem = $false
    if ($null -ne $ScheduleInfo.Recurrence.Pattern.Type)
    {
        $Pattern = @{
            dayOfMonth     = $ScheduleInfo.Recurrence.Pattern.DayOfMonth
            daysOfWeek     = $ScheduleInfo.Recurrence.Pattern.DaysOfWeek
            firstDayOfWeek = $ScheduleInfo.Recurrence.Pattern.FirstDayOfWeek
            index          = $ScheduleInfo.Recurrence.Pattern.Index
            month          = $ScheduleInfo.Recurrence.Pattern.Month
            type           = $ScheduleInfo.Recurrence.Pattern.Type
        }
        $RecurrenceInfo.Add('pattern', $Pattern)
        $foundRecurrenceItem = $true
    }
    if ($null -ne $ScheduleInfo.Recurrence.Range.Type)
    {
        $Range = @{
            endDate             = $ScheduleInfo.Recurrence.Range.EndDate
            numberOfOccurrences = $ScheduleInfo.Recurrence.Range.NumberOfOccurrences
            recurrenceTimeZone  = $ScheduleInfo.Recurrence.Range.RecurrenceTimeZone
            startDate           = $ScheduleInfo.Recurrence.Range.StartDate
            type                = $ScheduleInfo.Recurrence.Range.Type
        }
        $RecurrenceInfo.Add('range', $Range)
        $foundRecurrenceItem = $true
    }
    if ($foundRecurrenceItem)
    {
        $instanceParams.scheduleInfo.Add('recurrence', $RecurrenceInfo)
    }

    $requestUri = 'https://graph.microsoft.com/beta/roleManagement/azureResources/roleEligibilityScheduleRequests'

    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        $instanceParams.Add('action', 'AdminAssign')
        $instanceParams.Add('justification', 'AdminAssign by Microsoft365DSC')
        Write-Verbose -Message "Creating new Azure role eligibility schedule request"
        Invoke-MgGraphRequest -Uri $requestUri -Method POST -Body ($instanceParams | ConvertTo-Json -Depth 10) -ContentType 'application/json'
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        $instanceParams.Add('action', 'AdminUpdate')
        $instanceParams.Add('justification', 'AdminUpdate by Microsoft365DSC')
        Write-Verbose -Message "Updating Azure role eligibility schedule request"
        Invoke-MgGraphRequest -Uri $requestUri -Method POST -Body ($instanceParams | ConvertTo-Json -Depth 10) -ContentType 'application/json'
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        $instanceParams.Add('action', 'AdminRemove')
        $instanceParams.Add('justification', 'AdminRemove by Microsoft365DSC')
        Write-Verbose -Message "Removing Azure role eligibility schedule request"
        Invoke-MgGraphRequest -Uri $requestUri -Method POST -Body ($instanceParams | ConvertTo-Json -Depth 10) -ContentType 'application/json'
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $DirectoryScopeId,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $Justification,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ScheduleInfo,

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
        $uri = 'https://graph.microsoft.com/beta/roleManagement/azureResources/roleEligibilitySchedules'
        if (-not [System.String]::IsNullOrEmpty($Filter))
        {
            $uri += '?$filter=' + [System.Uri]::EscapeDataString($Filter)
        }
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction SilentlyContinue
        [array]$Script:exportedInstances = $response.value

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

        if ($null -eq $Script:RoleDefinitions)
        {
            $Script:RoleDefinitions = [System.Collections.Generic.Dictionary[string, object]]::new()
            $rdUri = 'https://graph.microsoft.com/beta/roleManagement/azureResources/roleDefinitions'
            $rdResponse = Invoke-MgGraphRequest -Uri $rdUri -Method GET -ErrorAction SilentlyContinue
            foreach ($roleDefinition in $rdResponse.value)
            {
                if (-not $Script:RoleDefinitions.ContainsKey($roleDefinition.id))
                {
                    $Script:RoleDefinitions.Add($roleDefinition.id, $roleDefinition)
                }
            }
        }

        foreach ($config in $Script:exportedInstances)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $displayedKey = $config.id
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -DeferWrite

            $userInfo = Get-MgBetaDirectoryObjectById -Ids $config.principalId -ErrorAction SilentlyContinue
            $principalTypeRaw = $userInfo.AdditionalProperties['@odata.type'].Split('.')[2]
            $principalType = $principalTypeRaw.Substring(0,1).ToUpper() + $principalTypeRaw.Substring(1)
            $PrincipalValue = if ($principalTypeRaw -eq 'user')
            {
                $userInfo.AdditionalProperties['userPrincipalName']
            }
            else
            {
                $userInfo.AdditionalProperties['displayName']
            }

            if ($null -ne $PrincipalValue)
            {
                $roleDefinition = $Script:RoleDefinitions[$config.roleDefinitionId]
                if ($null -eq $roleDefinition)
                {
                    $rdLookupUri = 'https://graph.microsoft.com/beta/roleManagement/azureResources/roleDefinitions/' + $config.roleDefinitionId
                    $roleDefinition = Invoke-MgGraphRequest -Uri $rdLookupUri -Method GET -ErrorAction SilentlyContinue
                    if ($null -ne $roleDefinition)
                    {
                        $Script:RoleDefinitions.Add($config.roleDefinitionId, $roleDefinition)
                    }
                }

                $params = @{
                    Id                    = $config.id
                    Principal             = $PrincipalValue
                    PrincipalType         = $principalType
                    DirectoryScopeId      = $config.directoryScopeId
                    RoleDefinition        = $roleDefinition.displayName
                    Ensure                = 'Present'
                    Credential            = $Credential
                    ApplicationId         = $ApplicationId
                    TenantId              = $TenantId
                    ApplicationSecret     = $ApplicationSecret
                    CertificateThumbprint = $CertificateThumbprint
                    ManagedIdentity       = $ManagedIdentity.IsPresent
                    AccessTokens          = $AccessTokens
                }

                $Script:exportedInstance = $config
                $Results = Get-TargetResource @params

                if ($Results.ScheduleInfo)
                {
                    $complexMapping = @(
                        @{
                            Name            = 'expiration'
                            CimInstanceName = 'AzureRoleEligibilityScheduleRequestScheduleExpiration'
                            IsRequired      = $False
                        }
                        @{
                            Name            = 'Recurrence'
                            CimInstanceName = 'AzureRoleEligibilityScheduleRequestScheduleRecurrence'
                            IsRequired      = $False
                        }
                        @{
                            Name            = 'range'
                            CimInstanceName = 'AzureRoleEligibilityScheduleRequestScheduleRecurrenceRange'
                            IsRequired      = $False
                        }
                        @{
                            Name            = 'pattern'
                            CimInstanceName = 'AzureRoleEligibilityScheduleRequestScheduleRecurrencePattern'
                            IsRequired      = $False
                        }
                    )
                    $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject $Results.ScheduleInfo `
                            -CIMInstanceName 'AzureRoleEligibilityScheduleRequestSchedule' `
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
            }
            $i++
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
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

function Test-M365DSCAzureRoleEligibilityRecurrenceIsConfigured
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $RecurrenceSettings
    )

    if ($null -eq $RecurrenceSettings.pattern.dayOfMonth -and `
        $null -eq $RecurrenceSettings.pattern.daysOfWeek -and `
        $null -eq $RecurrenceSettings.pattern.firstDayOfWeek -and `
        $null -eq $RecurrenceSettings.pattern.index -and `
        $null -eq $RecurrenceSettings.pattern.interval -and `
        $null -eq $RecurrenceSettings.pattern.month -and `
        $null -eq $RecurrenceSettings.pattern.type -and `
        $null -eq $RecurrenceSettings.range.endDate -and `
        $null -eq $RecurrenceSettings.range.numberOfOccurrences -and `
        $null -eq $RecurrenceSettings.range.recurrenceTimeZone -and `
        $null -eq $RecurrenceSettings.range.startDate -and `
        $null -eq $RecurrenceSettings.range.type)
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
        ExcludedProperties = @('Justification')
    }
}

Export-ModuleMember -Function @('*-TargetResource', 'Get-CompareParameters')
