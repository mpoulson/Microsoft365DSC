function ConvertFrom-IntunePolicyAssignment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param (
        [Parameter(Mandatory = $true)]
        [Array]
        $Assignments,

        [Parameter()]
        [System.Boolean]
        $IncludeDeviceFilter = $true
    )

    if ($null -eq $Script:IntuneAssignmentFilters)
    {
        $Script:IntuneAssignmentFilters = Get-MgBetaDeviceManagementAssignmentFilter -All -ErrorAction SilentlyContinue | ForEach-Object {
            @{
                FilterId    = $_.Id
                DisplayName = $_.DisplayName
            }
        }
    }

    $assignmentResult = @()
    foreach ($assignment in $Assignments)
    {
        $hashAssignment = [ordered]@{}
        if ($null -ne $assignment.Target.'@odata.type')
        {
            $dataType = $assignment.Target.'@odata.type'
        }
        else
        {
            $dataType = $assignment.Target.AdditionalProperties.'@odata.type'
        }

        if ($null -ne $assignment.Target.groupId)
        {
            $groupId = $assignment.Target.groupId
        }
        else
        {
            $groupId = $assignment.Target.AdditionalProperties.groupId
        }

        if ($null -ne $assignment.Target.collectionId)
        {
            $collectionId = $assignment.Target.collectionId
        }
        else
        {
            $collectionId = $assignment.Target.AdditionalProperties.collectionId
        }

        $hashAssignment.Add('dataType', $dataType)
        if (-not [string]::IsNullOrEmpty($groupId))
        {
            $hashAssignment.Add('groupId', $groupId)

            $group = Get-MgGroup -GroupId ($groupId) -ErrorAction SilentlyContinue
            if ($null -ne $group)
            {
                $groupDisplayName = $group.DisplayName
            }
        }
        if ($dataType -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')
        {
            $groupDisplayName = 'All users'
        }
        if ($dataType -eq '#microsoft.graph.allDevicesAssignmentTarget')
        {
            $groupDisplayName = 'All devices'
        }
        if ($null -ne $groupDisplayName)
        {
            $hashAssignment.Add('groupDisplayName', $groupDisplayName)
        }
        if (-not [string]::IsNullOrEmpty($collectionId))
        {
            $hashAssignment.Add('collectionId', $collectionId)
        }
        if ($IncludeDeviceFilter)
        {
            if ($null -ne $assignment.Target.DeviceAndAppManagementAssignmentFilterType)
            {
                $hashAssignment.Add('deviceAndAppManagementAssignmentFilterType', $assignment.Target.DeviceAndAppManagementAssignmentFilterType.ToString())
            }
            if ($null -ne $assignment.Target.DeviceAndAppManagementAssignmentFilterId)
            {
                $filterId = $assignment.Target.DeviceAndAppManagementAssignmentFilterId
                $hashAssignment.Add('deviceAndAppManagementAssignmentFilterId', $filterId)
                $hashAssignment.Add('deviceAndAppManagementAssignmentFilterDisplayName', (($Script:IntuneAssignmentFilters | Where-Object -FilterScript { $_.FilterId -eq $filterId }).DisplayName))
            }
        }

        $assignmentResult += $hashAssignment
    }

    return ,$assignmentResult
}

function ConvertTo-IntunePolicyAssignment
{
    [CmdletBinding()]
    [OutputType([Hashtable[]])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Assignments,

        [Parameter()]
        [System.Boolean]
        $IncludeDeviceFilter = $true
    )

    if ($null -eq $Script:IntuneAssignmentFilters)
    {
        $Script:IntuneAssignmentFilters = Get-MgBetaDeviceManagementAssignmentFilter -All -ErrorAction SilentlyContinue | ForEach-Object {
            @{
                FilterId    = $_.Id
                DisplayName = $_.DisplayName
            }
        }
    }

    if ($null -eq $Assignments)
    {
        return ,@()
    }

    $assignmentResult = @()
    foreach ($assignment in $Assignments)
    {
        $target = @{
            '@odata.type' = $assignment.dataType
        }
        if ($IncludeDeviceFilter)
        {
            if ($null -ne $assignment.DeviceAndAppManagementAssignmentFilterType -and $assignment.DeviceAndAppManagementAssignmentFilterType -ne 'none')
            {
                $filter = $Script:IntuneAssignmentFilters | Where-Object -FilterScript { $_.FilterId -eq $assignment.DeviceAndAppManagementAssignmentFilterId }
                if ($null -eq $filter)
                {
                    $filter = $Script:IntuneAssignmentFilters | Where-Object -FilterScript { $_.DisplayName -eq $assignment.DeviceAndAppManagementAssignmentFilterDisplayName }
                    if ($null -eq $filter)
                    {
                        Write-Warning -Message "Assignment filter with DisplayName {$($assignment.DeviceAndAppManagementAssignmentFilterDisplayName)} not found in the directory. Please update your DSC resource extract with the correct filterId or filterDisplayName."
                    }
                }

                if ($null -ne $filter)
                {
                    $target.Add('deviceAndAppManagementAssignmentFilterType', $assignment.DeviceAndAppManagementAssignmentFilterType)
                    $target.Add('deviceAndAppManagementAssignmentFilterId', $filter.FilterId)
                }
            }
        }
        if ($assignment.dataType -like '*CollectionAssignmentTarget')
        {
            $target.Add('collectionId', $assignment.collectionId)
        }
        elseif ($assignment.dataType -like '*GroupAssignmentTarget')
        {
            $group = $null
            if (-not [System.String]::IsNullOrEmpty($assignment.groupId))
            {
                $group = Get-MgGroup -GroupId ($assignment.groupId) -ErrorAction SilentlyContinue
            }
            if ($null -eq $group -and -not [System.String]::IsNullOrEmpty($assignment.groupDisplayName))
            {
                $escapedName = $assignment.groupDisplayName -replace "'", "''"
                $group = Get-MgGroup -Filter "DisplayName eq '$escapedName'" -All -ErrorAction SilentlyContinue
                if ($null -eq $group)
                {
                    Write-Warning "Skipping assignment: groupDisplayName '{$($assignment.groupDisplayName)}' not found."
                    $target = $null
                }
                elseif ($group.Count -gt 1)
                {
                    Write-Warning "Skipping assignment: groupDisplayName '{$($assignment.groupDisplayName)}' is not unique."
                    $target = $null
                }
            }
            # If group found, add its ID
            if ($null -ne $group)
            {
                $target.Add('groupId', $group.Id)
            }
            elseif ($null -eq $group -and [System.String]::IsNullOrEmpty($assignment.groupDisplayName))
            {
                Write-Warning 'Skipping assignment: missing both groupId and groupDisplayName.'
                $target = $null
            }
        }

        if ($target)
        {
            $assignmentResult += @{ target = $target }
        }
    }

    return ,$assignmentResult
}

function ConvertFrom-IntuneMobileAppAssignment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param (
        [Parameter(Mandatory = $true)]
        [Array]
        $Assignments,

        [Parameter()]
        [System.Boolean]
        $IncludeDeviceFilter = $true
    )

    if ($null -eq $Script:IntuneAssignmentFilters)
    {
        $Script:IntuneAssignmentFilters = Get-MgBetaDeviceManagementAssignmentFilter -All -ErrorAction SilentlyContinue | ForEach-Object {
            @{
                FilterId    = $_.Id
                DisplayName = $_.DisplayName
            }
        }
    }

    $assignmentResult = @()
    foreach ($assignment in $Assignments)
    {
        $hashAssignment = @{}
        if ($null -ne $assignment.Target.'@odata.type')
        {
            $dataType = $assignment.Target.'@odata.type'
        }
        else
        {
            $dataType = $assignment.Target.AdditionalProperties.'@odata.type'
        }

        if ($null -ne $assignment.Target.groupId)
        {
            $groupId = $assignment.Target.groupId
        }
        else
        {
            $groupId = $assignment.Target.AdditionalProperties.groupId
        }

        $hashAssignment.Add('dataType', $dataType)
        if (-not [string]::IsNullOrEmpty($groupId))
        {
            $hashAssignment.Add('groupId', $groupId)

            $group = Get-MgGroup -GroupId ($groupId) -ErrorAction SilentlyContinue
            if ($null -ne $group)
            {
                $groupDisplayName = $group.DisplayName
            }
        }

        if ($dataType -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')
        {
            $groupDisplayName = 'All users'
        }
        if ($dataType -eq '#microsoft.graph.allDevicesAssignmentTarget')
        {
            $groupDisplayName = 'All devices'
        }
        if ($null -ne $groupDisplayName)
        {
            $hashAssignment.Add('groupDisplayName', $groupDisplayName)
        }

        $hashAssignment.Add('intent', $assignment.intent.ToString())

        if ($IncludeDeviceFilter)
        {
            if ($null -ne $assignment.Target.DeviceAndAppManagementAssignmentFilterType)
            {
                $hashAssignment.Add('deviceAndAppManagementAssignmentFilterType', $assignment.Target.DeviceAndAppManagementAssignmentFilterType.ToString())
            }
            if ($null -ne $assignment.Target.DeviceAndAppManagementAssignmentFilterId)
            {
                $filterId = $assignment.Target.DeviceAndAppManagementAssignmentFilterId
                $hashAssignment.Add('deviceAndAppManagementAssignmentFilterId', $filterId)
                $hashAssignment.Add('deviceAndAppManagementAssignmentFilterDisplayName', (($Script:IntuneAssignmentFilters | Where-Object -FilterScript { $_.FilterId -eq $filterId }).DisplayName))
            }
        }

        if ($null -ne $assignment.settings -and $assignment.settings.AdditionalProperties.Count -gt 0)
        {
            $settings = (Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $assignment.settings.AdditionalProperties)
            $hashAssignment.Add('assignmentSettings', $settings)
        }

        $assignmentResult += $hashAssignment
    }

    return ,$assignmentResult
}

function ConvertTo-IntuneMobileAppAssignment
{
    [CmdletBinding()]
    [OutputType([Hashtable[]])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Assignments,

        [Parameter()]
        [System.Boolean]
        $IncludeDeviceFilter = $true
    )

    if ($null -eq $Script:IntuneAssignmentFilters)
    {
        $Script:IntuneAssignmentFilters = Get-MgBetaDeviceManagementAssignmentFilter -All -ErrorAction SilentlyContinue | ForEach-Object {
            @{
                FilterId    = $_.Id
                DisplayName = $_.DisplayName
            }
        }
    }

    if ($null -eq $Assignments)
    {
        return ,@()
    }

    $assignmentResult = @()
    foreach ($assignment in $Assignments)
    {
        $formattedAssignment = @{}
        $target = @{
            '@odata.type' = $assignment.dataType
        }

        # Handle Device Filters
        if ($IncludeDeviceFilter)
        {
            if ($null -ne $assignment.DeviceAndAppManagementAssignmentFilterType -and
                $assignment.DeviceAndAppManagementAssignmentFilterType -ne 'none')
            {
                $filter = $Script:IntuneAssignmentFilters | Where-Object {
                    $_.FilterId -eq $assignment.DeviceAndAppManagementAssignmentFilterId
                }

                if ($null -eq $filter)
                {
                    $filter = $Script:IntuneAssignmentFilters | Where-Object {
                        $_.DisplayName -eq $assignment.DeviceAndAppManagementAssignmentFilterDisplayName
                    }
                }

                if ($null -ne $filter)
                {
                    $target.Add('deviceAndAppManagementAssignmentFilterType', $assignment.DeviceAndAppManagementAssignmentFilterType)
                    $target.Add('deviceAndAppManagementAssignmentFilterId', $filter.FilterId)
                }
                else
                {
                    Write-Warning "Assignment filter with DisplayName {$($assignment.DeviceAndAppManagementAssignmentFilterDisplayName)} not found."
                }
            }
        }

        # Add intent (required for app assignments)
        $formattedAssignment.Add('intent', $assignment.intent)

        if ($assignment.dataType -like '*groupAssignmentTarget')
        {
            $group = $null
            if (-not [System.String]::IsNullOrEmpty($assignment.groupId))
            {
                $group = Get-MgGroup -GroupId $assignment.groupId -ErrorAction SilentlyContinue
            }
            # If groupId lookup failed, try by display name
            if ($null -eq $group -and -not [System.String]::IsNullOrEmpty($assignment.groupDisplayName))
            {
                $escapedName = $assignment.groupDisplayName -replace "'", "''"
                $group = Get-MgGroup -Filter "DisplayName eq '$escapedName'" -All -ErrorAction SilentlyContinue
                if ($null -eq $group)
                {
                    Write-Warning "Skipping assignment: groupDisplayName '{$($assignment.groupDisplayName)}' not found."
                    $target = $null
                }
                elseif ($group.Count -gt 1)
                {
                    Write-Warning "Skipping assignment: groupDisplayName '{$($assignment.groupDisplayName)}' is not unique."
                    $target = $null
                }
            }
            # If group found, add its ID
            if ($null -ne $group)
            {
                $target.Add('groupId', $group.Id)
            }
            elseif ($null -eq $group -and [System.String]::IsNullOrEmpty($assignment.groupDisplayName))
            {
                Write-Warning 'Skipping assignment: missing both groupId and groupDisplayName.'
                $target = $null
            }
        }
        # Add target if valid
        if ($target)
        {
            $formattedAssignment.Add('target', $target)
        }
        # Add assignment settings if present
        if ($null -ne $assignment.assignmentSettings)
        {
            $settings = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $assignment.assignmentSettings
            $formattedAssignment.Add('settings', $settings)
            $formattedAssignment.settings.Add('@odata.type', $formattedAssignment.settings.odataType)
            $formattedAssignment.settings.Remove('odataType') | Out-Null
        }
        $assignmentResult += $formattedAssignment
    }
    return ,$assignmentResult
}

function Compare-M365DSCIntunePolicyAssignment
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter()]
        [array]$Source,
        [Parameter()]
        [array]$Target
    )
    $DriftObject = @{
        DriftInfo     = @{}
        CurrentValues = @{}
        DesiredValues = @{}
    }
    $testResult = $Source.Count -eq $Target.Count
    if (-not $testResult)
    {
        $DriftObject.DriftInfo.Add('Assignments.Count', @{
            PropertyName = 'Assignments.Count'
            CurrentValue = $Source.Count
            DesiredValue = $Target.Count
        })
    }
    Write-Verbose "Count: $($Source.Count) - $($Target.Count)"
    if ($testResult)
    {
        foreach ($assignment in $Source)
        {
            if ($assignment.dataType -like '*AssignmentTarget')
            {
                $assignmentTarget = $Target | Where-Object -FilterScript { $_.dataType -eq $assignment.DataType -and $_.groupId -eq $assignment.groupId }
                $testResult = $null -ne $assignmentTarget
                # Check for mobile app assignments with intent
                $testResult = $assignment.intent -eq $assignmentTarget.intent
                # Using assignment groupDisplayName only if the groupId is not found in the directory otherwise groupId should be the key
                if (-not $testResult)
                {
                    Write-Verbose 'Group not found by groupId, looking for group by groupDisplayName'
                    $assignmentTarget = $Target | Where-Object -FilterScript { $_.dataType -eq $assignment.DataType -and $_.groupDisplayName -eq $assignment.groupDisplayName }
                    $testResult = $null -ne $assignmentTarget

                    if (-not $testResult)
                    {
                        $DriftObject.DriftInfo.Add('Assignments.GroupDisplayName', @{
                            PropertyName = 'Assignments.GroupDisplayName'
                            CurrentValue = $assignment.groupDisplayName
                            DesiredValue = $null
                        })
                    }
                }

                if ($testResult)
                {
                    Write-Verbose 'Group found by groupId or groupDisplayName, checking filters'
                    $isFilterTypeSpecified = ($null -ne $assignment.deviceAndAppManagementAssignmentFilterType -and $assignment.deviceAndAppManagementAssignmentFilterType -ne 'none') -or `
                    ($null -ne $assignmentTarget.deviceAndAppManagementAssignmentFilterType -and $assignmentTarget.deviceAndAppManagementAssignmentFilterType -ne 'none')
                    $isFilterIdSpecified = ($null -ne $assignment.deviceAndAppManagementAssignmentFilterId -and $assignment.deviceAndAppManagementAssignmentFilterId -ne '00000000-0000-0000-0000-000000000000') -or `
                    ($null -ne $assignmentTarget.deviceAndAppManagementAssignmentFilterId -and $assignmentTarget.deviceAndAppManagementAssignmentFilterId -ne '00000000-0000-0000-0000-000000000000')
                    if ($isFilterTypeSpecified)
                    {
                        Write-Verbose 'FilterType specified, checking filterType'
                        $testResult = $assignment.deviceAndAppManagementAssignmentFilterType -eq $assignmentTarget.deviceAndAppManagementAssignmentFilterType
                    }
                    if ($testResult -and $isFilterTypeSpecified -and $isFilterIdSpecified)
                    {
                        Write-Verbose 'FilterId specified, checking filterId'
                        $testResult = $assignment.deviceAndAppManagementAssignmentFilterId -eq $assignmentTarget.deviceAndAppManagementAssignmentFilterId

                        if (-not $testResult)
                        {
                            Write-Verbose 'FilterId does not match, checking filterDisplayName'
                            $testResult = $assignment.deviceAndAppManagementAssignmentFilterDisplayName -eq $assignmentTarget.deviceAndAppManagementAssignmentFilterDisplayName
                        }
                    }
                    if (-not $testResult)
                    {
                        $DriftObject.DriftInfo.Add('Assignments.Filters', @{
                            PropertyName = 'Assignments.Filters'
                            CurrentValue = $assignment.deviceAndAppManagementAssignmentFilterType
                            DesiredValue = $assignmentTarget.deviceAndAppManagementAssignmentFilterType
                        })
                    }
                }

                if ($testResult)
                {
                    Write-Verbose 'Group and filters match, checking collectionId'
                    $testResult = $assignment.collectionId -eq $assignmentTarget.collectionId
                    if (-not $testResult)
                    {
                        $DriftObject.DriftInfo.Add('Assignments.collectionId', @{
                            PropertyName = 'Assignments.collectionId'
                            CurrentValue = $assignment.collectionId
                            DesiredValue = $assignmentTarget.collectionId
                        })
                    }
                }
            }
            else
            {
                $testResult = $null -ne ($Target | Where-Object -FilterScript { $_.dataType -eq $assignment.DataType })
                if (-not $testResult)
                {
                    $DriftObject.DriftInfo.Add('Assignments.collectionId', @{
                        PropertyName = 'Assignments.DataType'
                        CurrentValue = $assignment.DataType
                        DesiredValue = $null
                    })
                }
            }
            $Global:CCMCurrentDriftInfo = $DriftObject
            if (-not $testResult)
            {
                break
            }
        }
    }

    $Global:CCMCurrentDriftInfo = $DriftObject
    return $testResult
}

function Update-DeviceConfigurationPolicyAssignment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DeviceConfigurationPolicyId,

        [Parameter()]
        [Array]
        $Targets,

        [Parameter()]
        [System.String]
        $Repository = 'deviceManagement/configurationPolicies',

        [Parameter()]
        [ValidateSet('v1.0', 'beta')]
        [System.String]
        $APIVersion = 'beta',

        [Parameter()]
        [System.String]
        $RootIdentifier = 'assignments'
    )

    try
    {
        $deviceManagementPolicyAssignments = @()
        $Uri = "/$APIVersion/$Repository/$DeviceConfigurationPolicyId/assign"

        foreach ($target in $targets)
        {
            $targetAssignment = @{}
            $formattedTarget = @{'@odata.type' = $target.dataType }
            if ($null -ne $target.runRemediationScript)
            {
                $targetAssignment.Add('runRemediationScript', $target.runRemediationScript)
            }
            if ($null -ne $target.runSchedule)
            {
                $targetAssignment.Add('runSchedule', $target.runSchedule)
            }
            if ($target.target -is [hashtable])
            {
                $target = $target.target
            }
            if (-not $formattedTarget.'@odata.type' -and $target.'@odata.type')
            {
                $formattedTarget.'@odata.type' = $target.'@odata.type'
            }
            if ($target.groupId)
            {
                $group = Get-MgGroup -GroupId ($target.groupId) -ErrorAction SilentlyContinue
                if ($null -eq $group)
                {
                    if ($target.groupDisplayName)
                    {
                        $group = Get-MgGroup -Filter "DisplayName eq '$($target.groupDisplayName -replace "'", "''")'" -All -ErrorAction SilentlyContinue
                        if ($null -eq $group)
                        {
                            $message = "Skipping assignment for the group with DisplayName {$($target.groupDisplayName)} as it could not be found in the directory.`r`n"
                            $message += 'Please update your DSC resource extract with the correct groupId or groupDisplayName.'
                            Write-Warning -Message $message
                            $target = $null
                        }
                        if ($group -and $group.Count -gt 1)
                        {
                            $message = "Skipping assignment for the group with DisplayName {$($target.groupDisplayName)} as it is not unique in the directory.`r`n"
                            $message += 'Please update your DSC resource extract with the correct groupId or a unique group DisplayName.'
                            Write-Warning -Message $message
                            $group = $null
                            $target = $null
                        }
                    }
                    else
                    {
                        $message = "Skipping assignment for the group with Id {$($target.groupId)} as it could not be found in the directory.`r`n"
                        $message += 'Please update your DSC resource extract with the correct groupId or a unique group DisplayName.'
                        Write-Warning -Message $message
                        $target = $null
                    }
                }
                #Skipping assignment if group not found from either groupId or groupDisplayName
                if ($null -ne $group)
                {
                    $formattedTarget.Add('groupId', $group.Id)
                }
            }
            if ($target.collectionId)
            {
                $formattedTarget.Add('collectionId', $target.collectionId)
            }
            if ($target.deviceAndAppManagementAssignmentFilterType)
            {
                $formattedTarget.Add('deviceAndAppManagementAssignmentFilterType', $target.deviceAndAppManagementAssignmentFilterType)
            }
            if ($target.deviceAndAppManagementAssignmentFilterId)
            {
                $formattedTarget.Add('deviceAndAppManagementAssignmentFilterId', $target.deviceAndAppManagementAssignmentFilterId)
            }
            $targetAssignment.Add('target', $formattedTarget)
            $deviceManagementPolicyAssignments += $targetAssignment
        }

        $body = @{$RootIdentifier = $deviceManagementPolicyAssignments } | ConvertTo-Json -Depth 20
        Write-Verbose -Message $body

        Invoke-MgGraphRequest -Method POST -Uri $Uri -Body $body -ErrorAction Stop
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error updating data:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return $null
    }
}

function Update-DeviceAppManagementPolicyAssignment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AppManagementPolicyId,

        [Parameter()]
        [Array]
        $Assignments,

        [Parameter()]
        [System.String]
        $Repository = 'deviceAppManagement/mobileApps',

        [Parameter()]
        [ValidateSet('v1.0', 'beta')]
        [System.String]
        $APIVersion = 'beta',

        [Parameter()]
        [System.String]
        $RootIdentifier = 'mobileAppAssignments'
    )

    try
    {
        $appManagementPolicyAssignments = @()
        $Uri = "/$APIVersion/$Repository/$AppManagementPolicyId/assign"

        foreach ($assignment in $Assignments)
        {
            $formattedAssignment = @{
                '@odata.type' = '#microsoft.graph.mobileAppAssignment'
                intent        = $assignment.intent
            }
            if ($assignment.settings)
            {
                $formattedAssignment.Add('settings', $assignment.settings)
            }

            if ($assignment.target -is [hashtable])
            {
                $target = $assignment.target
            }

            $formattedTarget = @{'@odata.type' = $target.dataType }
            if (-not $formattedTarget.'@odata.type' -and $target.'@odata.type')
            {
                $formattedTarget.'@odata.type' = $target.'@odata.type'
            }
            if ($target.groupId)
            {
                $group = Get-MgGroup -GroupId ($target.groupId) -ErrorAction SilentlyContinue
                if ($null -eq $group)
                {
                    if ($target.groupDisplayName)
                    {
                        $group = Get-MgGroup -Filter "DisplayName eq '$($target.groupDisplayName -replace "'", "''")'" -All -ErrorAction SilentlyContinue
                        if ($null -eq $group)
                        {
                            $message = "Skipping assignment for the group with DisplayName {$($target.groupDisplayName)} as it could not be found in the directory.`r`n"
                            $message += 'Please update your DSC resource extract with the correct groupId or groupDisplayName.'
                            Write-Warning -Message $message
                            $target = $null
                        }
                        if ($group -and $group.Count -gt 1)
                        {
                            $message = "Skipping assignment for the group with DisplayName {$($target.groupDisplayName)} as it is not unique in the directory.`r`n"
                            $message += 'Please update your DSC resource extract with the correct groupId or a unique group DisplayName.'
                            Write-Warning -Message $message
                            $group = $null
                            $target = $null
                        }
                    }
                    else
                    {
                        $message = "Skipping assignment for the group with Id {$($target.groupId)} as it could not be found in the directory.`r`n"
                        $message += 'Please update your DSC resource extract with the correct groupId or a unique group DisplayName.'
                        Write-Warning -Message $message
                        $target = $null
                    }
                }
                #Skipping assignment if group not found from either groupId or groupDisplayName
                if ($null -ne $group)
                {
                    $formattedTarget.Add('groupId', $group.Id)
                }
            }
            if ($target.deviceAndAppManagementAssignmentFilterType)
            {
                $formattedTarget.Add('deviceAndAppManagementAssignmentFilterType', $target.deviceAndAppManagementAssignmentFilterType)
            }
            if ($target.deviceAndAppManagementAssignmentFilterId)
            {
                $formattedTarget.Add('deviceAndAppManagementAssignmentFilterId', $target.deviceAndAppManagementAssignmentFilterId)
            }
            $formattedAssignment.Add('target', $formattedTarget)
            $appManagementPolicyAssignments += $formattedAssignment
        }

        $body = @{$RootIdentifier = $appManagementPolicyAssignments } | ConvertTo-Json -Depth 20
        Write-Verbose -Message $body

        Invoke-MgGraphRequest -Method POST -Uri $Uri -Body $body -ErrorAction Stop
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error updating data:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return $null
    }
}

function Update-DeviceAppManagementAppCategory
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $App,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [Array]
        $Categories,

        [Parameter()]
        [switch]
        $Compare
    )

    if ($Compare)
    {
        [array]$referenceObject = if ($null -ne $App.Categories.DisplayName)
        {
            $App.Categories.DisplayName
        }
        else
        {
            , @()
        }
        [array]$differenceObject = if ($null -ne $Categories.DisplayName)
        {
            $Categories.DisplayName
        }
        else
        {
            , @()
        }
        $delta = Compare-Object -ReferenceObject $referenceObject -DifferenceObject $differenceObject -PassThru
        foreach ($diff in $delta)
        {
            if ($diff.SideIndicator -eq '=>')
            {
                $category = $Categories | Where-Object { $_.DisplayName -eq $diff }
                if ($category.Id)
                {
                    $currentCategory = Get-MgBetaDeviceAppManagementMobileAppCategory -MobileAppCategoryId $category.Id
                }
                else
                {
                    $currentCategory = Get-MgBetaDeviceAppManagementMobileAppCategory -Filter "DisplayName eq '$($category.DisplayName -replace "'", "''")'"
                }

                if ($null -eq $currentCategory)
                {
                    throw "Mobile App Category with DisplayName $($category.DisplayName) not found."
                }

                Invoke-MgGraphRequest -Uri "/beta/deviceAppManagement/mobileApps/$($App.Id)/categories/`$ref" -Method 'POST' -Body @{
                    '@odata.id' = "$((Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl)beta/deviceAppManagement/mobileAppCategories/$($currentCategory.Id)"
                }
            }
            else
            {
                $category = $App.Categories | Where-Object { $_.DisplayName -eq $diff }
                Invoke-MgGraphRequest -Uri "/beta/deviceAppManagement/mobileApps/$($App.Id)/categories/$($category.Id)/`$ref" -Method 'DELETE'
            }
        }
    }
    else
    {
        foreach ($category in $Categories)
        {
            if ($category.Id)
            {
                $currentCategory = Get-MgBetaDeviceAppManagementMobileAppCategory -MobileAppCategoryId $category.Id
            }
            else
            {
                $currentCategory = Get-MgBetaDeviceAppManagementMobileAppCategory -Filter "DisplayName eq '$($category.DisplayName -replace "'", "''")'"
            }

            if ($null -eq $currentCategory)
            {
                throw "Mobile App Category with DisplayName $($category.DisplayName) not found."
            }

            Invoke-MgGraphRequest -Uri "$((Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl)beta/deviceAppManagement/mobileApps/$($App.Id)/categories/`$ref" -Method 'POST' -Body @{
                '@odata.id' = "$((Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl)beta/deviceAppManagement/mobileAppCategories/$($currentCategory.Id)"
            }
        }
    }
}

function Get-M365DSCIntuneDeviceConfigurationSettings
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = 'true')]
        [System.Collections.Hashtable]
        $Properties,

        [Parameter()]
        [System.String]
        $TemplateId
    )

    $templateCategoryId = (Get-MgBetaDeviceManagementTemplateCategory -DeviceManagementTemplateId $TemplateId).Id
    $templateSettings = Get-MgBetaDeviceManagementTemplateCategoryRecommendedSetting `
        -DeviceManagementTemplateId $TemplateId `
        -DeviceManagementTemplateSettingCategoryId $templateCategoryId

    $results = @()
    foreach ($setting in $templateSettings)
    {
        $result = @{}
        $settingType = $setting.AdditionalProperties.'@odata.type'
        $settingValue = $null
        $currentValueKey = $Properties.keys | Where-Object -FilterScript { $setting.DefinitionId -like "*$_" }
        if ($null -ne $currentValueKey)
        {
            $settingValue = $Properties.$currentValueKey
        }

        $requiresValueJson = $false
        switch ($settingType)
        {
            {
                ( $_ -eq '#microsoft.graph.deviceManagementStringSettingInstance' ) -or
                ( $_ -eq '#microsoft.graph.deviceManagementBooleanSettingInstance' )
            }
            {
                if ([String]::IsNullOrEmpty($settingValue))
                {
                    $settingValue = $setting.ValueJson | ConvertFrom-Json
                }
            }
            '#microsoft.graph.deviceManagementCollectionSettingInstance'
            {
                $requiresValueJson = $true
                if ($null -eq $settingValue)
                {
                    $settingValue = ConvertTo-Json -InputObject @()
                }
                else
                {
                    $settingValue = ConvertTo-Json -InputObject ([Array]$settingValue)
                }
            }
            default
            {
                if ($null -eq $settingValue)
                {
                    $settingValue = $setting.ValueJson | ConvertFrom-Json
                }
            }
        }

        $result.Add('@odata.type', $settingType)
        $result.Add('Id', $setting.Id)
        $result.Add('definitionId', $setting.DefinitionId)

        if ($requiresValueJson)
        {
            $result.Add('valueJson', $settingValue)
        }
        else
        {
            $result.Add('value', $settingValue)
        }

        $results += $result
    }

    return $results
}

function Get-OmaSettingPlainTextValue
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $SecretReferenceValueId,

        [Parameter()]
        [ValidateSet('v1.0', 'beta')]
        [System.String]
        $APIVersion = 'beta'
    )

    try
    {
        <#
            e.g. PolicyId for SecretReferenceValueId '35ea58ec-2a79-471d-8eea-7e28e6cd2722_bdf6c690-05fb-4d02-835d-5a7406c35d58_abe32712-2255-445f-a35e-0c6f143d82ca'
            is 'bdf6c690-05fb-4d02-835d-5a7406c35d58'
        #>
        $SplitSecretReferenceValueId = $SecretReferenceValueId.Split('_')
        if ($SplitSecretReferenceValueId.Count -eq 3)
        {
            $PolicyId = $SplitSecretReferenceValueId[1]
        }
        else
        {
            return $null
        }
    }
    catch
    {
        return $null
    }

    $Repository = 'deviceManagement/deviceConfigurations'
    $Uri = "/{0}/{1}/{2}/getOmaSettingPlainTextValue(secretReferenceValueId='{3}')" -f $APIVersion, $Repository, $PolicyId, $SecretReferenceValueId

    try
    {
        $Result = Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop
    }
    catch
    {
        $Message = 'Error decrypting OmaSetting with SecretReferenceValueId {0}:' -f $SecretReferenceValueId
        New-M365DSCLogEntry -Message $Message `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return $null
    }

    if (![String]::IsNullOrEmpty($Result.Value))
    {
        return $Result.Value
    }
    else
    {
        return $null
    }
}

function Get-IntuneSettingCatalogPolicySetting
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $DSCParams,

        [Parameter(
            Mandatory = 'true',
            ParameterSetName = 'Start'
        )]
        [System.String]
        $TemplateId,

        [Parameter(
            Mandatory = 'true',
            ParameterSetName = 'DeviceAndUserSettings'
        )]
        [System.Array]
        $SettingTemplates,

        [Parameter(ParameterSetName = 'Start')]
        [switch]
        $ContainsDeviceAndUserSettings
    )

    if ($null -eq (Get-Command Get-SettingsCatalogSettingName -ErrorAction SilentlyContinue))
    {
        Import-Module -Name (Join-Path $PSScriptRoot M365DSCIntuneSettingsCatalogUtil.psm1) -Force
    }

    $DSCParams.Remove('Identity') | Out-Null
    $DSCParams.Remove('DisplayName') | Out-Null
    $DSCParams.Remove('Description') | Out-Null

    $settingInstances = @()
    if ($PSCmdlet.ParameterSetName -eq 'Start')
    {
        # Prepare setting definitions mapping
        $SettingTemplates = Get-MgBetaDeviceManagementConfigurationPolicyTemplateSettingTemplate `
            -DeviceManagementConfigurationPolicyTemplateId $TemplateId `
            -ExpandProperty 'SettingDefinitions' `
            -All

        if ($ContainsDeviceAndUserSettings)
        {
            $deviceSettingTemplates = $SettingTemplates | Where-Object -FilterScript {
                $_.SettingInstanceTemplate.SettingDefinitionId.StartsWith('device_')
            }
            $userSettingTemplates = $SettingTemplates | Where-Object -FilterScript {
                $_.SettingInstanceTemplate.SettingDefinitionId.StartsWith('user_')
            }
            $deviceDscParams = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $DSCParams.DeviceSettings -SingleLevel -ExcludeUnchangedProperties
            $userDscParams = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $DSCParams.UserSettings -SingleLevel -ExcludeUnchangedProperties
            $combinedSettingInstances = @()
            $combinedSettingInstances += Get-IntuneSettingCatalogPolicySetting -DSCParams $deviceDscParams -SettingTemplates $deviceSettingTemplates
            $combinedSettingInstances += Get-IntuneSettingCatalogPolicySetting -DSCParams $userDscParams -SettingTemplates $userSettingTemplates

            return ,$combinedSettingInstances
        }
    }

    # Iterate over all setting templates
    foreach ($settingTemplate in $SettingTemplates)
    {
        $settingInstanceTemplate = $settingTemplate.SettingInstanceTemplate
        $settingInstance = @{}
        $settingDefinition = $settingTemplate.SettingDefinitions | Where-Object {
            $_.Id -eq $settingInstanceTemplate.SettingDefinitionId -and `
            ($_.AdditionalProperties.dependentOn.Count -eq 0 -and $_.AdditionalProperties.options.dependentOn.Count -eq 0)
        }
        if ($null -eq $settingDefinition)
        {
            continue
        }
        if ($settingDefinition -is [System.Array])
        {
            $settingDefinition = $settingDefinition[0]
        }

        $settingType = $settingInstanceTemplate.AdditionalProperties.'@odata.type'.Replace('InstanceTemplate', 'Instance')
        $settingInstance.Add('@odata.type', $settingType)
        if (-not [string]::IsNullOrEmpty($settingInstanceTemplate.settingInstanceTemplateId))
        {
            $settingInstance.Add('settingInstanceTemplateReference', @{'settingInstanceTemplateId' = $settingInstanceTemplate.settingInstanceTemplateId })
        }
        $settingValueName = $settingType.Replace('#microsoft.graph.deviceManagementConfiguration', '').Replace('Instance', 'Value')
        $settingValueName = $settingValueName.Substring(0, 1).ToLower() + $settingValueName.Substring(1, $settingValueName.Length - 1 )
        [string]$settingValueType = $settingInstanceTemplate.AdditionalProperties."$($settingValueName)Template".'@odata.type' | Select-Object -Unique
        if (-not [System.String]::IsNullOrEmpty($settingValueType))
        {
            $settingValueType = $settingValueType.Replace('ValueTemplate', 'Value')
        }
        if ([System.String]::IsNullOrEmpty($settingValueType) -and $settingValueName -eq 'choiceSettingValue')
        {
            # Special case for ChoiceSettingValue which does not have a ValueTemplate property
            $settingValueType = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
        }

        $settingValueTemplateId = $settingInstanceTemplate.AdditionalProperties."$($settingValueName)Template".settingValueTemplateId

        # Only happened on property ThreatTypeSettings from IntuneAntivirusPolicyLinux
        # SettingValueTemplateIds are from the child settings and not from the parent setting because it is a groupSettingCollection
        if ($settingValueTemplateId -is [array])
        {
            $settingValueTemplateId = $null
        }

        # Get all the values in the setting instance
        $settingValue = Get-IntuneSettingCatalogPolicySettingInstanceValue `
            -DSCParams $DSCParams `
            -SettingDefinition $settingDefinition `
            -SettingInstanceTemplate $settingInstanceTemplate `
            -AllSettingDefinitions $SettingTemplates.SettingDefinitions `
            -CurrentInstanceDefinitions $settingTemplate.SettingDefinitions `
            -SettingType $settingType `
            -SettingValueName $settingValueName `
            -SettingValueType $settingValueType `
            -SettingValueTemplateId $settingValueTemplateId

        if ($settingValue.Count -gt 0)
        {
            if ($settingValue.Keys -contains 'groupSettingCollectionValue' -and $settingValue.groupSettingCollectionValue.children.Count -eq 0)
            {
                continue
            }

            $settingInstance += [Hashtable]$settingValue
            if ($settingInstance.Keys -notcontains 'settingDefinitionId')
            {
                $settingInstance.Add('settingDefinitionId', $settingInstanceTemplate.settingDefinitionId)
            }
            $settingInstances += @{
                '@odata.type'     = '#microsoft.graph.deviceManagementConfigurationSetting'
                'settingInstance' = $settingInstance
            }
        }
    }

    return ,$settingInstances
}

function Get-IntuneSettingCatalogPolicySettingInstanceValue
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = 'true')]
        [System.Collections.Hashtable]
        $DSCParams,

        [Parameter()]
        $SettingDefinition,

        [Parameter()]
        $SettingInstanceTemplate,

        [Parameter()]
        [System.Array]
        $AllSettingDefinitions,

        [Parameter()]
        [System.Array]
        $CurrentInstanceDefinitions,

        [Parameter()]
        [System.String]
        $SettingType,

        [Parameter()]
        [System.String]
        $SettingValueName,

        [Parameter()]
        [System.String]
        $SettingValueType,

        [Parameter()]
        [System.String]
        $SettingValueTemplateId,

        [Parameter()]
        [System.String]
        $SettingInstanceName = 'MSFT_MicrosoftGraphIntuneSettingsCatalog',

        [Parameter()]
        [System.Int32]
        $Level = 1
    )

    $settingValuesToReturn = @{}

    # Depending on the setting type, there is other logic involved
    switch ($SettingType)
    {
        # GroupSettingCollections are a collection of settings without a value of their own
        { $_ -eq '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance' -or $_ -eq '#microsoft.graph.deviceManagementConfigurationSettingGroupCollectionDefinition' }
        {
            $groupSettingCollectionValue = @()
            $groupSettingCollectionDefinitionChildren = @()

            $groupSettingCollectionDefinitionChildren += $CurrentInstanceDefinitions | Where-Object {
                ($_.AdditionalProperties.dependentOn.Count -gt 0 -and $_.AdditionalProperties.dependentOn.parentSettingId -contains $SettingDefinition.Id) -or
                ($_.AdditionalProperties.options.dependentOn.Count -gt 0 -and $_.AdditionalProperties.options.dependentOn.parentSettingId -contains $SettingDefinition.Id)
            }

            $instanceCount = 1
            if (($Level -gt 1 -and $groupSettingCollectionDefinitionChildren.Count -gt 1) -or
                ($Level -eq 1 -and $SettingDefinition.AdditionalProperties.maximumCount -gt 1 -and $groupSettingCollectionDefinitionChildren.Count -ge 1 -and $groupSettingCollectionDefinitionChildren.AdditionalProperties.'@odata.type' -notcontains '#microsoft.graph.deviceManagementConfigurationSettingGroupCollectionDefinition'))
            {
                $SettingInstanceName += Get-SettingsCatalogSettingName -SettingDefinition $SettingDefinition -AllSettingDefinitions $AllSettingDefinitions
                $settingInstanceNameAlternate = $SettingInstanceName + '_Intune'
                $cimDSCParams = @()
                $cimDSCParamsName = ''
                $DSCParams.GetEnumerator() | ForEach-Object {
                    if ($_.Value.CimClass.CimClassName -eq $SettingInstanceName -or $_.Value.CimClass.CimClassName -like "$settingInstanceNameAlternate*")
                    {
                        $cimDSCParams += $_.Value
                        $cimDSCParamsName = $_.Key
                    }
                }
                $newDSCParams = @{
                    $cimDSCParamsName = @()
                }
                foreach ($instance in $cimDSCParams)
                {
                    $newInstanceDSCParams = @{}
                    # Preserve CIM instances when converting to hashtable
                    foreach ($property in $instance.CimInstanceProperties)
                    {
                        if ($property.IsValueModified)
                        {
                            $newInstanceDSCParams.Add($property.Name, $property.Value)
                        }
                    }
                    $newDSCParams.$cimDSCParamsName += $newInstanceDSCParams
                }
                $instanceCount = $newDSCParams.$cimDSCParamsName.Count
                $DSCParams = @{
                    $cimDSCParamsName = if ($instanceCount -eq 1)
                    {
                        $newDSCParams.$cimDSCParamsName[0]
                    }
                    else
                    {
                        $newDSCParams.$cimDSCParamsName
                    }
                }
                $AllSettingDefinitions = $groupSettingCollectionDefinitionChildren + $SettingDefinition
            }

            for ($i = 0; $i -lt $instanceCount; $i++)
            {
                $groupSettingCollectionValueChildren = @()
                $currentDSCParams = if ($instanceCount -eq 1)
                {
                    if (-not [System.String]::IsNullOrEmpty($cimDSCParamsName))
                    {
                        $DSCParams.$cimDSCParamsName
                    }
                    else
                    {
                        $DSCParams
                    }
                }
                else
                {
                    if (-not [System.String]::IsNullOrEmpty($cimDSCParamsName))
                    {
                        $DSCParams.$cimDSCParamsName[$i]
                    }
                    else
                    {
                        $DSCParams[$i]
                    }
                }
                if ($null -eq $currentDSCParams)
                {
                    # Should we continue? Let's try out
                    $currentDSCParams = @{}
                }

                foreach ($childDefinition in $groupSettingCollectionDefinitionChildren)
                {
                    $childSettingType = $childDefinition.AdditionalProperties.'@odata.type'.Replace('Definition', 'Instance').Replace('SettingGroup', 'GroupSetting')
                    $childSettingValueName = $childSettingType.Replace('#microsoft.graph.deviceManagementConfiguration', '').Replace('Instance', 'Value')
                    $childSettingValueType = "#microsoft.graph.deviceManagementConfiguration$($childSettingValueName)"
                    $childSettingValueName = $childSettingValueName.Substring(0, 1).ToLower() + $childSettingValueName.Substring(1, $childSettingValueName.Length - 1 )
                    $childSettingInstanceTemplate = if ($null -ne $SettingInstanceTemplate.AdditionalProperties)
                    {
                        $SettingInstanceTemplate.AdditionalProperties.groupSettingCollectionValueTemplate.children | Where-Object { $_.settingDefinitionId -eq $childDefinition.Id } | Select-Object -First 1
                    }
                    else
                    {
                        $SettingInstanceTemplate.groupSettingCollectionValueTemplate.children | Where-Object { $_.settingDefinitionId -eq $childDefinition.Id } | Select-Object -First 1
                    }

                    $childSettingValueTemplateId = $childSettingInstanceTemplate."$($childSettingValueName)Template".settingValueTemplateId

                    $childSettingValue = Get-IntuneSettingCatalogPolicySettingInstanceValue `
                        -DSCParams $currentDSCParams `
                        -SettingDefinition $childDefinition `
                        -SettingInstanceTemplate $childSettingInstanceTemplate `
                        -AllSettingDefinitions $AllSettingDefinitions `
                        -CurrentInstanceDefinitions $CurrentInstanceDefinitions `
                        -SettingType $childDefinition.AdditionalProperties.'@odata.type' `
                        -SettingValueName $childSettingValueName `
                        -SettingValueType $childSettingValueType `
                        -SettingValueTemplateId $childSettingValueTemplateId `
                        -SettingInstanceName $SettingInstanceName `
                        -Level ($Level + 1)

                    if ($childSettingValue.Keys.Count -gt 0)
                    {
                        # If only one child item is allowed but we have multiple values, we need to create an object for each child
                        # Happens e.g. for the IntuneDeviceControlPolicyWindows10 resource --> {ruleid} and {ruleid}_ruledata definitions
                        if ($childSettingValue.groupSettingCollectionValue.Count -gt 1 -and
                            $childDefinition.AdditionalProperties.maximumCount -eq 1 -and
                            $groupSettingCollectionDefinitionChildren.Count -eq 1)
                        {
                            $childSettingValueOld = $childSettingValue
                            $childSettingValue = @()
                            foreach ($childSettingValueItem in $childSettingValueOld.groupSettingCollectionValue)
                            {
                                $childSettingValueInner = @{
                                    children = @()
                                }
                                $childSettingValueItem.Add('@odata.type', $childSettingType)
                                $childSettingValueInner.children += @{
                                    '@odata.type'               = '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
                                    groupSettingCollectionValue = @(
                                        @{
                                            children = $childSettingValueItem.children
                                        }
                                    )
                                    settingDefinitionId         = $childDefinition.Id
                                }
                                <# GroupSettingCollection do not have a setting instance template reference
                                if (-not [string]::IsNullOrEmpty($childSettingInstanceTemplate.settingInstanceTemplateId))
                                {
                                    $childSettingValueInner.children[0].groupSettingCollectionValue.settingInstanceTemplateReference = @{
                                        'settingInstanceTemplateId' = $childSettingInstanceTemplate.settingInstanceTemplateId
                                    }
                                }
                                #>
                                $childSettingValue += $childSettingValueInner
                            }
                            $groupSettingCollectionValue += $childSettingValue
                        }
                        else
                        {
                            if ($childSettingValue.Keys -notcontains 'settingDefinitionId')
                            {
                                $childSettingValue.Add('settingDefinitionId', $childDefinition.Id)
                            }
                            <# GroupSettingCollection do not have a setting instance template reference
                            if (-not [string]::IsNullOrEmpty($childSettingInstanceTemplate.settingInstanceTemplateId))
                            {
                                $childSettingValue.Add('settingInstanceTemplateReference', @{'settingInstanceTemplateId' = $childSettingInstanceTemplate.settingInstanceTemplateId | Select-Object -First 1 })
                            }
                            #>
                            $childSettingValue.Add('@odata.type', $childSettingType)
                            $groupSettingCollectionValueChildren += $childSettingValue
                        }
                    }
                }

                # Does not happen for wrapped children elements
                if ($groupSettingCollectionValueChildren.Count -gt 0)
                {
                    $groupSettingCollectionValue += @{
                        children = @($groupSettingCollectionValueChildren)
                    }
                }
            }

            if ($groupSettingCollectionDefinitionChildren.Count -gt 0 -and $groupSettingCollectionValue.Count -gt 0)
            {
                $settingValuesToReturn.Add('groupSettingCollectionValue', @($groupSettingCollectionValue))
            }
        }
        # ChoiceSetting is a choice (e.g. dropdown) setting that, depending on the choice, can have children settings
        { $_ -eq '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance' -or $_ -eq '#microsoft.graph.deviceManagementConfigurationChoiceSettingDefinition' }
        {
            $choiceSettingValue = @{}
            $choiceSettingValueChildren = @()
            $choiceSettingDefinitionChildren = @()

            # Choice settings almost always have child settings, so we need to fetch those
            if ($null -ne $SettingDefinition)
            {
                $choiceSettingDefinitionChildren += $CurrentInstanceDefinitions | Where-Object {
                    ($_.AdditionalProperties.dependentOn.Count -gt 0 -and $_.AdditionalProperties.dependentOn.parentSettingId.Contains($SettingDefinition.Id)) -or
                    ($_.AdditionalProperties.options.dependentOn.Count -gt 0 -and $_.AdditionalProperties.options.dependentOn.parentSettingId.Contains($SettingDefinition.Id))
                }
            }

            foreach ($childDefinition in $choiceSettingDefinitionChildren)
            {
                $childSettingType = $childDefinition.AdditionalProperties.'@odata.type'.Replace('Definition', 'Instance')
                $childSettingValueName = $childSettingType.Replace('#microsoft.graph.deviceManagementConfiguration', '').Replace('Instance', 'Value')
                $childSettingValueType = "#microsoft.graph.deviceManagementConfiguration$($childSettingValueName)"
                $childSettingValueName = $childSettingValueName.Substring(0, 1).ToLower() + $childSettingValueName.Substring(1, $childSettingValueName.Length - 1 )
                $childSettingInstanceTemplate = if ($null -ne $SettingInstanceTemplate.AdditionalProperties)
                {
                    $SettingInstanceTemplate.AdditionalProperties.choiceSettingValueTemplate.children | Where-Object { $_.settingDefinitionId -eq $childDefinition.Id }
                }
                else
                {
                    $SettingInstanceTemplate.choiceSettingValueTemplate.children | Where-Object { $_.settingDefinitionId -eq $childDefinition.Id }
                }
                $childSettingValueTemplateId = $childSettingInstanceTemplate."$($childSettingValueName)Template" | Where-Object {
                    $_.settingDefinitionId -eq $childDefinition.Id
                } | Select-Object -ExpandProperty settingValueTemplateId
                $childSettingValue = Get-IntuneSettingCatalogPolicySettingInstanceValue `
                    -DSCParams $DSCParams `
                    -SettingDefinition $childDefinition `
                    -AllSettingDefinitions $AllSettingDefinitions `
                    -CurrentInstanceDefinitions $CurrentInstanceDefinitions `
                    -SettingInstanceTemplate $childSettingInstanceTemplate `
                    -SettingType $childDefinition.AdditionalProperties.'@odata.type' `
                    -SettingValueName $childSettingValueName `
                    -SettingValueType $childSettingValueType `
                    -SettingValueTemplateId $childSettingValueTemplateId `
                    -SettingInstanceName $SettingInstanceName

                if ($childSettingValue.Keys.Count -gt 0)
                {
                    if ($childSettingValue.Keys -notcontains 'settingDefinitionId')
                    {
                        $childSettingValue.Add('settingDefinitionId', $childDefinition.Id)
                    }
                    if (-not [string]::IsNullOrEmpty($childSettingInstanceTemplate.settingInstanceTemplateId))
                    {
                        $childSettingValue.Add('settingInstanceTemplateReference', @{'settingInstanceTemplateId' = $childSettingInstanceTemplate.settingInstanceTemplateId })
                    }
                    if ($childSettingType -eq '#microsoft.graph.deviceManagementConfigurationSettingGroupCollectionInstance')
                    {
                        $childSettingType = '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
                    }
                    $childSettingValue.Add('@odata.type', $childSettingType)
                    $choiceSettingValueChildren += $childSettingValue
                }
            }

            # Depending on the children count, we add the children to the choice setting or an empty array since the children property is required
            if ($choiceSettingDefinitionChildren.Count -gt 0)
            {
                $choiceSettingValue.Add('children', $choiceSettingValueChildren)
            }
            else
            {
                $choiceSettingValue.Add('children', @())
            }

            $valueResult = Get-IntuneSettingCatalogPolicySettingDSCValue `
                -SettingValueType $SettingValueType `
                -AllSettingDefinitions $AllSettingDefinitions `
                -SettingDefinition $SettingDefinition `
                -DSCParams $DSCParams

            $value = $valueResult.Value

            # If there is a value in the DSC params, we add that to the choice setting
            if ($null -ne $value)
            {
                $value = $value
                $choiceSettingValue.Add('value', $value)
                $odataType = $SettingType.Replace('Definition', 'Value').Replace('Instance', 'Value')
                $choiceSettingValue.Add('@odata.type', $odataType)
                if (-not [string]::IsNullOrEmpty($SettingValueTemplateId))
                {
                    $choiceSettingValue.Add('settingValueTemplateReference', @{'settingValueTemplateId' = $SettingValueTemplateId })
                }
            }

            # If there are children or a value is configured, we add the choice setting to the return values
            if ($choiceSettingValue.Children.Count -gt 0 -or $null -ne $choiceSettingValue.value)
            {
                $settingValuesToReturn.Add('choiceSettingValue', $choiceSettingValue)
            }
        }
        # ChoiceSettingCollection is a collection of ChoiceSettings
        { $_ -eq '#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance' -or $_ -eq '#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionDefinition' }
        {
            $choiceSettingValueCollection = @()
            $valueResult = Get-IntuneSettingCatalogPolicySettingDSCValue `
                -SettingValueType $SettingValueType `
                -AllSettingDefinitions $AllSettingDefinitions `
                -SettingDefinition $SettingDefinition `
                -DSCParams $DSCParams

            $values = $valueResult.Value

            if ($null -ne $values)
            {
                # We iterate over all the values in the DSC params and add them to the choice setting collection
                foreach ($value in $values)
                {
                    $choiceSettingValueCollection += @{
                        value         = $value
                        children      = @()
                        '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                    }
                }

                $settingValuesToReturn.Add('choiceSettingCollectionValue', $choiceSettingValueCollection)
            }
        }
        # SimpleSettingCollections are collections of simple settings, e.g. strings or integers
        { $_ -eq '#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance' -or $_ -eq '#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionDefinition' }
        {
            $valuesResult = Get-IntuneSettingCatalogPolicySettingDSCValue `
                -SettingValueType $SettingValueType `
                -AllSettingDefinitions $AllSettingDefinitions `
                -SettingDefinition $SettingDefinition `
                -DSCParams $DSCParams

            if ($null -eq $valuesResult)
            {
                return $null
            }

            $values = $valuesResult.Value
            $SettingValueType = $valuesResult.SettingDefinition.AdditionalProperties.valueDefinition.'@odata.type'.Replace('Definition', '')

            $settingValueCollection = @()
            foreach ($v in $values)
            {
                $settingValueCollection += @{
                    value         = $v
                    '@odata.type' = $SettingValueType
                }
            }
            if ($settingValueCollection.Count -gt 0)
            {
                $settingValuesToReturn.Add($SettingValueName, $settingValueCollection)
            }
        }
        # For all other types, e.g. Integer or String, we add the value directly
        default
        {
            $valueResult = Get-IntuneSettingCatalogPolicySettingDSCValue `
                -SettingValueType $SettingValueType `
                -AllSettingDefinitions $AllSettingDefinitions `
                -SettingDefinition $SettingDefinition `
                -DSCParams $DSCParams

            $value = $valueResult.Value
            $SettingValueType = $valueResult.SettingValueType
            $SettingDefinition = $valueResult.SettingDefinition

            if ($null -eq $value)
            {
                return $null
            }

            $settingValue = @{}
            if (-not [string]::IsNullOrEmpty($SettingValueType))
            {
                if ($SettingDefinition.AdditionalProperties.valueDefinition.isSecret)
                {
                    $SettingValueType = '#microsoft.graph.deviceManagementConfigurationSecretSettingValue'
                    $settingValue.Add('valueState', 'NotEncrypted')
                }
                $settingValue.Add('@odata.type', $SettingValueType)
            }
            if (-not [string]::IsNullOrEmpty($settingValueTemplateId))
            {
                $settingValue.Add('settingValueTemplateReference', @{'settingValueTemplateId' = $settingValueTemplateId })
            }
            $settingValue.Add('value', $value)

            $settingValuesToReturn.Add($SettingValueName, $settingValue)
            $settingValuesToReturn.Add('settingDefinitionId', $SettingDefinition.Id)
        }
    }
    return $settingValuesToReturn
}

function Get-IntuneSettingCatalogPolicySettingDSCValue
{
    param
    (
        [Parameter()]
        [System.String]
        $SettingValueType = '',

        [Parameter()]
        $SettingDefinition,

        [Parameter(Mandatory = $true)]
        [System.Array]
        $AllSettingDefinitions,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $DSCParams
    )

    $key = Get-SettingsCatalogSettingName -SettingDefinition $SettingDefinition -AllSettingDefinitions $AllSettingDefinitions

    if ($DSCParams.Keys -notcontains $key)
    {
        return $null
    }

    # Fixes potential case sensitivity issue.
    foreach ($hashKey in $DSCParams.Keys)
    {
        if ($hashKey -eq $key)
        {
            $key = $hashKey
            break
        }
    }

    $isArray = $false
    if ($SettingValueType -like '*Simple*')
    {
        if ($DSCParams[$key] -is [System.String])
        {
            $SettingValueType = '#microsoft.graph.deviceManagementConfigurationStringSettingValue'
        }
        elseif ($DSCParams[$key] -is [System.Int32])
        {
            $SettingValueType = '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue'
        }
        elseif ($DSCParams[$key] -is [System.String[]])
        {
            $SettingValueType = '#microsoft.graph.deviceManagementConfigurationStringSettingValue'
            $isArray = $true
        }
        elseif ($DSCParams[$key] -is [System.Int32[]])
        {
            $SettingValueType = '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue'
            $isArray = $true
        }
    }

    if ($SettingValueType -like '*Simple*' -or $SettingValueType -in @('#microsoft.graph.deviceManagementConfigurationIntegerSettingValue', '#microsoft.graph.deviceManagementConfigurationStringSettingValue'))
    {
        return @{
            SettingDefinition = $SettingDefinition
            SettingValueType  = $SettingValueType
            Value             = if ($isArray)
            {
                , $DSCParams[$key]
            }
            else
            {
                $DSCParams[$key]
            }
        }
    }
    elseif ($SettingValueType -like '*ChoiceSetting*' -and $SettingValueType -notlike '*Collection*')
    {
        $settingValue = ($SettingDefinition.AdditionalProperties.options | Where-Object { $_.optionValue.value -eq $($DSCParams[$key]) }).itemId
        if ([System.String]::IsNullOrEmpty($settingValue))
        {
            $settingValue = ($SettingDefinition.AdditionalProperties.options | Where-Object { $_.itemId -eq "$($SettingDefinition.Id)_$($DSCParams[$key])" }).itemId
        }
        return @{
            SettingDefinition = $SettingDefinition
            SettingValueType  = $SettingValueType
            Value             = $settingValue
        }
    }
    elseif ($SettingValueType -like '*ChoiceSettingCollection*')
    {
        $values = @()
        foreach ($value in $DSCParams[$key])
        {
            $valueToAdd = ($SettingDefinition.AdditionalProperties.options | Where-Object { $_.optionValue.value -eq "$value" }).itemId
            if ([System.String]::IsNullOrEmpty($valueToAdd))
            {
                $valueToAdd = ($SettingDefinition.AdditionalProperties.options | Where-Object { $_.itemId -eq "$($SettingDefinition.Id)_$value" }).itemId
            }
            $values += $valueToAdd
        }

        return @{
            Value = $values
        }
    }
    else
    {
        return @{
            SettingDefinition = $SettingDefinition
            SettingValueType  = $SettingValueType
            Value             = "$($SettingDefinition.Id)_$($DSCParams[$key])"
        }
    }
}

function Export-IntuneSettingCatalogPolicySettings
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Start'
        )]
        $Settings,

        [Parameter(
            Mandatory = $true
        )]
        [System.Collections.Hashtable]$ReturnHashtable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Setting'
        )]
        $SettingInstance,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Setting'
        )]
        $SettingDefinitions,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Setting'
        )]
        [Parameter(
            ParameterSetName = 'Start'
        )]
        [System.Array]
        $AllSettingDefinitions,

        [Parameter(
            ParameterSetName = 'Setting'
        )]
        [switch]$IsRoot,

        [Parameter(
            ParameterSetName = 'Start'
        )]
        [switch]$ContainsDeviceAndUserSettings
    )
    if ($PSCmdlet.ParameterSetName -eq 'Start')
    {
        if ($ContainsDeviceAndUserSettings)
        {
            $deviceSettingsReturnHashtable = @{}
            $deviceSettings = $Settings | Where-Object -FilterScript {
                $_.SettingInstance.settingDefinitionId.StartsWith('device_')
            }
            if ($AllSettingDefinitions.Count -eq 0)
            {
                $allDeviceSettingDefinitions = $deviceSettings.SettingDefinitions
            }
            else
            {
                $allDeviceSettingDefinitions = $AllSettingDefinitions | Where-Object -FilterScript {
                    $_.Id.StartsWith('device_')
                }
            }
            foreach ($setting in $deviceSettings)
            {
                Export-IntuneSettingCatalogPolicySettings -SettingInstance $setting.SettingInstance -SettingDefinitions $setting.SettingDefinitions -ReturnHashtable $deviceSettingsReturnHashtable -AllSettingDefinitions $allDeviceSettingDefinitions -IsRoot
            }

            $userSettingsReturnHashtable = @{}
            $userSettings = $Settings | Where-Object -FilterScript {
                $_.SettingInstance.settingDefinitionId.StartsWith('user_')
            }
            if ($AllSettingDefinitions.Count -eq 0)
            {
                $allUserSettingDefinitions = $userSettings.SettingDefinitions
            }
            else
            {
                $allUserSettingDefinitions = $AllSettingDefinitions | Where-Object -FilterScript {
                    $_.Id.StartsWith('user_')
                }
            }

            foreach ($setting in $userSettings)
            {
                Export-IntuneSettingCatalogPolicySettings -SettingInstance $setting.SettingInstance -SettingDefinitions $setting.SettingDefinitions -ReturnHashtable $userSettingsReturnHashtable -AllSettingDefinitions $allUserSettingDefinitions -IsRoot
            }

            if ($deviceSettingsReturnHashtable.Keys.Count -gt 0)
            {
                $ReturnHashtable.Add('DeviceSettings', $deviceSettingsReturnHashtable)
            }
            if ($userSettingsReturnHashtable.Keys.Count -gt 0)
            {
                $ReturnHashtable.Add('UserSettings', $userSettingsReturnHashtable)
            }
        }
        else
        {
            if ($AllSettingDefinitions.Count -eq 0)
            {
                $AllSettingDefinitions = $Settings.SettingDefinitions
            }
            foreach ($setting in $Settings)
            {
                Export-IntuneSettingCatalogPolicySettings -SettingInstance $setting.SettingInstance -SettingDefinitions $setting.SettingDefinitions -ReturnHashtable $ReturnHashtable -AllSettingDefinitions $AllSettingDefinitions -IsRoot
            }
        }
        return $ReturnHashtable
    }

    $addToParameters = $true
    $settingDefinition = $SettingDefinitions | Where-Object -FilterScript { $_.Id -eq $SettingInstance.settingDefinitionId }
    $settingName = Get-SettingsCatalogSettingName -SettingDefinition $settingDefinition -AllSettingDefinitions $AllSettingDefinitions
    $odataType = if ($IsRoot)
    {
        $SettingInstance.AdditionalProperties.'@odata.type'
    }
    else
    {
        $SettingInstance.'@odata.type'
    }
    switch ($odataType)
    {
        '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'
        {
            $simpleSetting = if ($IsRoot)
            {
                $SettingInstance.AdditionalProperties.simpleSettingValue
            }
            else
            {
                $SettingInstance.simpleSettingValue
            }
            if ($simpleSetting.'@odata.type' -eq '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue')
            {
                $settingValue = [int]$simpleSetting.value
            }
            else
            {
                $settingValue = $simpleSetting.value
            }
        }
        '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
        {
            $options = $settingDefinition.AdditionalProperties.options
            $beforeSettingValue = if ($IsRoot)
            {
                $SettingInstance.AdditionalProperties.choiceSettingValue.value
            }
            else
            {
                $SettingInstance.choiceSettingValue.value
            }

            $settingValue = ($options | Where-Object { $_.itemId -eq $beforeSettingValue }).optionValue.value
            if ($settingValue -like '*=*' -or $settingValue -like '*{*}*')
            {
                # The value is not an actual value, but rather an assignment string. Fall back to the itemId and strip the prefix
                # Examples are IntuneFirewallPolicyWindows10 -> target is a GUID, IntuneAntivirusPolicyWindows10ConfigMgr -> *Severity* is an assignment, e.g. 2=2
                $settingValue = ($options | Where-Object { $_.itemId -eq $beforeSettingValue }).itemId.Replace("$($settingDefinition.Id)_", '')
            }
            $childSettings = if ($IsRoot)
            {
                $SettingInstance.AdditionalProperties.choiceSettingValue.children
            }
            else
            {
                $SettingInstance.choiceSettingValue.children
            }
            foreach ($childSetting in $childSettings)
            {
                Export-IntuneSettingCatalogPolicySettings -SettingInstance $childSetting -SettingDefinitions $SettingDefinitions -ReturnHashtable $ReturnHashtable -AllSettingDefinitions $AllSettingDefinitions
            }
        }
        '#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance'
        {
            $values = @()
            $options = $settingDefinition.AdditionalProperties.options
            $childValues = if ($IsRoot)
            {
                $SettingInstance.AdditionalProperties.choiceSettingCollectionValue.value
            }
            else
            {
                $SettingInstance.choiceSettingCollectionValue.value
            }
            foreach ($value in $childValues)
            {
                $valueToReturn = ($options | Where-Object { $_.itemId -eq $value }).optionValue.value
                if ($valueToReturn -like '*=*' -or $valueToReturn -like '*{*}*')
                {
                    # The value is not an actual value, but rather an assignment string. Fall back to the itemId and strip the prefix
                    # Examples are IntuneFirewallPolicyWindows10 -> target is a GUID, IntuneAntivirusPolicyWindows10ConfigMgr -> *Severity* is an assignment, e.g. 2=2
                    $valueToReturn = ($options | Where-Object { $_.itemId -eq $value }).itemId.Replace("$($settingDefinition.Id)_", '')
                }
                $values += $valueToReturn
            }
            if ($options[0].optionValue.'@odata.type' -like '*Integer*')
            {
                $values = [int[]]$values
            }
            elseif ($options[0].optionValue.'@odata.type' -like '*String*')
            {
                $values = [string[]]$values
            }
            $settingValue = $values
        }
        '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
        {
            $groupSettingCollectionValue = if ($IsRoot)
            {
                $SettingInstance.AdditionalProperties.groupSettingCollectionValue
            }
            else
            {
                $SettingInstance.groupSettingCollectionValue
            }
            [array]$childSettingDefinitions = $SettingDefinitions | Where-Object -FilterScript {
                $settingDefinition.AdditionalProperties.childIds -contains $_.Id
            }
            $parentSettingDefinition = $SettingDefinitions | Where-Object -FilterScript { $_.Id -eq $settingDefinition.AdditionalProperties.dependentOn.parentSettingId }

            if ($settingDefinition.AdditionalProperties.maximumCount -gt 1 -and $childSettingDefinitions.Count -eq 1)
            {
                # Skip GroupSettingCollection with only one child, go straight to the child property
                foreach ($child in $groupSettingCollectionValue)
                {
                    $childInstances = $child.children
                    foreach ($childInstance in $childInstances)
                    {
                        Export-IntuneSettingCatalogPolicySettings -SettingInstance $childInstance -SettingDefinitions $SettingDefinitions -ReturnHashtable $ReturnHashtable -AllSettingDefinitions $AllSettingDefinitions
                    }
                }
                $addToParameters = $false
            }
            elseif (($settingDefinition.AdditionalProperties.maximumCount -gt 1 -or $parentSettingDefinition.AdditionalProperties.maximumCount -gt 1) -and $childSettingDefinitions.Count -gt 1)
            {
                # If the GroupSettingCollection can appear multiple times (either itself or from the parent), we need to add its name as a property
                # and the child settings as its value
                $childValue = $null
                if (-not $IsRoot)
                {
                    $parentSettingDefinition = $SettingDefinitions | Where-Object -FilterScript { $_.Id -eq $settingDefinition.AdditionalProperties.dependentOn.parentSettingId }
                    if ($settingDefinition.AdditionalProperties.maximumCount -gt 1 -or
                        $parentSettingDefinition.AdditionalProperties.maximumCount -gt 1)
                    {
                        $childValue = @()
                    }
                }
                else
                {
                    if ($settingDefinition.AdditionalProperties.maximumCount -gt 1)
                    {
                        $childValue = @()
                    }
                }

                foreach ($child in $groupSettingCollectionValue)
                {
                    $childHashtable = @{}
                    foreach ($childInstance in $child.children)
                    {
                        Export-IntuneSettingCatalogPolicySettings -SettingInstance $childInstance -SettingDefinitions $SettingDefinitions -ReturnHashtable $childHashtable -AllSettingDefinitions $AllSettingDefinitions
                    }
                    $childValue += $childHashtable
                }
                $settingValue = if ($null -eq $childValue)
                {
                    $childHashtable
                }
                else
                {
                    , $childValue
                }
            }
            else
            {
                # Skip GroupSettingCollection that only appears once, go straight to the child properties
                $childSettings = $groupSettingCollectionValue.children
                foreach ($value in $childSettings)
                {
                    Export-IntuneSettingCatalogPolicySettings -SettingInstance $value -SettingDefinitions $SettingDefinitions -ReturnHashtable $ReturnHashtable -AllSettingDefinitions $AllSettingDefinitions
                    $addToParameters = $false
                }
            }
        }
        '#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance'
        {
            $values = @()
            $childValues = if ($IsRoot)
            {
                $SettingInstance.AdditionalProperties.simpleSettingCollectionValue
            }
            else
            {
                $SettingInstance.simpleSettingCollectionValue
            }
            foreach ($value in $childValues)
            {
                if ($value.'@odata.type' -eq '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue')
                {
                    $values += [int]$value.value
                }
                else
                {
                    $values += $value.value
                }
            }
            $settingValue = $values
        }
        default
        {
            if ($SettingInstance.'@odata.type' -eq '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue')
            {
                $settingValue += [int]$SettingInstance.value
            }
            else
            {
                $settingValue = $SettingInstance.value
            }
        }
    }

    if ($addToParameters)
    {
        if (-not $ReturnHashtable.ContainsKey($settingName))
        {
            $ReturnHashtable.Add($settingName, $settingValue)
        }
        else
        {
            # Only happens when it's a GroupCollection(Collection) with multiple entries
            $ReturnHashtable[$settingName] = @($ReturnHashtable[$settingName]) + $settingValue
        }
    }
}

function Update-IntuneDeviceConfigurationPolicy
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = 'true')]
        [System.String]
        $DeviceConfigurationPolicyId,

        [Parameter()]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $Platforms,

        [Parameter()]
        [System.String]
        $Technologies,

        [Parameter()]
        [System.String]
        $TemplateReferenceId,

        [Parameter()]
        [AllowNull()]
        [System.String]
        $CreationSource,

        [Parameter()]
        [Array]
        $Settings,

        [Parameter()]
        [System.String[]]
        $RoleScopeTagIds
    )

    try
    {
        $Uri = (Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl + "beta/deviceManagement/configurationPolicies/$DeviceConfigurationPolicyId"

        $policy = @{
            'name'            = $Name
            'description'     = $Description
            'platforms'       = $Platforms
            'technologies'    = $Technologies
            'settings'        = $Settings
            'roleScopeTagIds' = $RoleScopeTagIds
        }

        if ($PSBoundParameters.ContainsKey('TemplateReferenceId'))
        {
            $policy.Add('templateReference', @{ 'templateId' = $TemplateReferenceId })
        }

        if ($PSBoundParameters.ContainsKey('CreationSource') -and -not [System.String]::IsNullOrEmpty($CreationSource))
        {
            $policy.Add('creationSource', $CreationSource)
        }

        $body = $policy | ConvertTo-Json -Depth 20
        Write-Verbose -Message "Updating policy with:`r`n$body"
        Invoke-MgGraphRequest -Method PUT -Uri $Uri -Body $body -ErrorAction Stop
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error updating data:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        throw
    }
}

function Get-ComplexFunctionsFromFilterQuery
{
    [CmdletBinding()]
    [OutputType([System.Array])]
    param (
        [string]$FilterQuery
    )

    $complexFunctionsRegex = "startswith\((.*?),\s*'(.*?)'\)|endswith\((.*?),\s*'(.*?)'\)|contains\((.*?),\s*'(.*?)'\)"
    [array]$complexFunctions = [regex]::Matches($FilterQuery, $complexFunctionsRegex) | ForEach-Object {
        $_.Value
    }

    return $complexFunctions
}

function Remove-ComplexFunctionsFromFilterQuery
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [string]$FilterQuery
    )

    $complexFunctionsRegex = "startswith\((.*?),\s*'(.*?)'\)|endswith\((.*?),\s*'(.*?)'\)|contains\((.*?),\s*'(.*?)'\)"
    $basicFilterQuery = [regex]::Replace($FilterQuery, $complexFunctionsRegex, '').Trim()
    $basicFilterQuery = $basicFilterQuery -replace '^and\s', '' -replace '\sand$', '' -replace '\sand\s+', ' and ' -replace '\sor\s+', ' or '

    return $basicFilterQuery
}

function Find-GraphDataUsingComplexFunctions
{
    [CmdletBinding()]
    [OutputType([System.Array])]
    param (
        [array]$Policies,
        [array]$ComplexFunctions
    )

    foreach ($function in $ComplexFunctions)
    {
        if ($function -match "startswith\((.*?),\s*'(.*?)'")
        {
            $property = $matches[1]
            $value = $matches[2]
            $Policies = $Policies | Where-Object { $_.$property -like "$value*" }
        }
        elseif ($function -match "endswith\((.*?),\s*'(.*?)'")
        {
            $property = $matches[1]
            $value = $matches[2]
            $Policies = $Policies | Where-Object { $_.$property -like "*$value" }
        }
        elseif ($function -match "contains\((.*?),\s*'(.*?)'")
        {
            $property = $matches[1]
            $value = $matches[2]
            $Policies = $Policies | Where-Object { $_.$property -like "*$value*" }
        }
    }

    return $Policies
}

function Invoke-M365DSCIntuneMobileAppInitialUpload
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AppId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $OdataType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $FileExtension
    )

    $OdataType = $OdataType.Replace('#', '')
    $contentVersionsUri = "beta/deviceAppManagement/mobileApps/$($AppId)/$OdataType/contentVersions"
    $contentVersion = Invoke-MgGraphRequest -Method POST -Uri $contentVersionsUri -Body @{}

    $manifest = $null
    $size = 1
    $sizeEncrypted = 64
    $base64File = '+drh1SKfuLjdp37gfv8EuWqOTt06m0TirqJJ0xQvrd5sm6NkiYBY8vBkFM+9ZwHRskO83NEfsLPtTzLB9FFsKA=='
    $fileDigest = 'ypeBEsobvcr6wjGzmiPcTaeG7/gUfE5yuYB3ha/uSLs='
    $mac = '+drh1SKfuLjdp37gfv8EuWqOTt06m0TirqJJ0xQvrd4='
    switch ($OdataType)
    {
        'microsoft.graph.androidLobApp'
        {
            $size = 3425
            $sizeEncrypted = 3488
            $manifest = $([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('<?xml version="1.0" encoding="utf-8"?><AndroidManifestProperties xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Package>b.a</Package><PackageVersionCode>1</PackageVersionCode><PackageVersionName></PackageVersionName><ApplicationName>Sample.apk</ApplicationName><MinSdkVersion>3</MinSdkVersion><AWTVersion></AWTVersion></AndroidManifestProperties>')))
            $base64File = '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'
            $fileDigest = 'rCQEPUja3DkId6YVFRVWWx/cHasCjuLZXYC9gAhdk3Y='
            $mac = 'OXtq10WM7mpJAnbN2AU/cqvKGYeKfTfJirK3weR6Y08='
        }
        'microsoft.graph.windowsMobileMSI'
        {
            $manifest = $([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('<MobileMsiData MsiExecutionContext="User" MsiRequiresReboot="false" MsiUpgradeCode="{00000000-0000-0000-0000-000000000000}" MsiIsMachineInstall="false" MsiIsUserInstall="true" MsiRequiresLogon="true" MsiIncludesServices="false" MsiContainsSystemRegistryKeys="false" MsiContainsSystemFolders="false"></MobileMsiData>')))
        }
        'microsoft.graph.windowsUniversalAppx'
        {
            $manifest = $([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("Sample.$($FileExtension)".ToUpper())))
        }
    }

    $fileUri = "beta/deviceAppManagement/mobileApps/$($AppId)/$OdataType/contentVersions/$($contentVersion.id)/files"
    $manifest = $null
    if ($OdataType -eq 'microsoft.graph.windowsUniversalAppx')
    {
        # Manifest is required for Windows Universal Appx
        $manifest = $([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("Sample.$($FileExtension)".ToUpper())))
    }
    elseif ($OdataType -eq 'microsoft.graph.windowsMobileMSI')
    {
        # Manifest is required for Windows Mobile MSI
        $manifest = $([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('<MobileMsiData MsiExecutionContext="User" MsiRequiresReboot="false" MsiUpgradeCode="{00000000-0000-0000-0000-000000000000}" MsiIsMachineInstall="false" MsiIsUserInstall="true" MsiRequiresLogon="true" MsiIncludesServices="false" MsiContainsSystemRegistryKeys="false" MsiContainsSystemFolders="false"></MobileMsiData>')))
    }
    $file = Invoke-MgGraphRequest -Method POST `
        -Uri $fileUri `
        -Body @{
        '@odata.type' = '#microsoft.graph.mobileAppContentFile'
        name          = "Sample.$($FileExtension)"
        size          = $size
        sizeEncrypted = $sizeEncrypted
        isDependency  = $false
        manifest      = $manifest
    }

    $file = Wait-ForFileProcessing -AppId $AppId -OdataType $OdataType -FileId $file.id -ContentVersionId $contentVersion.id -UploadStatePrefix 'AzureStorageUriRequest'

    # Upload the encrypted Sample file to Azure Storage
    $success = $false
    $breakCounter = 0
    do
    {
        try
        {
            Write-Verbose "Uploading file to Azure Storage: $($file.azureStorageUri)"
            $base64File = '+drh1SKfuLjdp37gfv8EuWqOTt06m0TirqJJ0xQvrd5sm6NkiYBY8vBkFM+9ZwHRskO83NEfsLPtTzLB9FFsKA=='
            $sasUri = $file.azureStorageUri
            $uri = "$($sasUri)&comp=block&blockid=0001"
            $iso = [System.Text.Encoding]::GetEncoding('iso-8859-1')
            $body = [System.Convert]::FromBase64String($base64File)
            $encodedBody = $iso.GetString($body)
            Invoke-WebRequest -Uri $uri -Method PUT -Body $encodedBody -Headers @{
                'x-ms-blob-type' = 'BlockBlob'
            } -ErrorAction Stop -UseBasicParsing | Out-Null
            Write-Verbose 'File uploaded successfully to Azure Storage.' -Verbose
            $success = $true
        }
        catch
        {
            Write-Warning -Message "Failed to upload file to Azure Storage: $($_.Exception.Message)" -Verbose
            Start-Sleep -Seconds 2
        }
    } while ($success -eq $false -and $breakCounter -lt 5)

    # Finalize the upload to Azure Storage
    $uri = "$($sasUri)&comp=blocklist"
    $xml = '<?xml version="1.0" encoding="utf-8"?><BlockList><Latest>0001</Latest></BlockList>'
    Invoke-RestMethod -Uri $uri -Method PUT -Body $xml

    # Commit the file and update the app
    $jsonCommit = @{
        fileEncryptionInfo = @{
            fileDigestAlgorithm  = 'SHA256'
            encryptionKey        = 'yqjlzT5KYpwU0wkr5eJGGukMB0Ar8iGqYX3B0lJJnKk='
            initializationVector = 'bJujZImAWPLwZBTPvWcB0Q=='
            fileDigest           = $fileDigest
            mac                  = $mac
            profileIdentifier    = 'ProfileVersion1'
            macKey               = 'mGfhTn/0AB3fftWzENQcoU34xghAfvVq23PoiBD81tM='
        }
    }
    $commitUri = "beta/deviceAppManagement/mobileApps/$AppId/$OdataType/contentVersions/$($contentVersion.id)/files/$($file.id)/commit"
    Invoke-MgGraphRequest -Method POST -Uri $commitUri -Body $($jsonCommit | ConvertTo-Json -Depth 10)

    Wait-ForFileProcessing -AppId $AppId -OdataType $OdataType -FileId $file.id -ContentVersionId $contentVersion.id -UploadStatePrefix 'CommitFile'

    # Update the app with the committed content version
    Invoke-MgGraphRequest -Method PATCH -Uri "beta/deviceAppManagement/mobileApps/$AppId" -Body @{
        '@odata.type'           = "#$OdataType"
        committedContentVersion = '1'
    }
}

function Wait-ForFileProcessing
{
    [CmdletBinding()]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AppId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $OdataType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $FileId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ContentVersionId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $UploadStatePrefix
    )

    $fileUri = "beta/deviceAppManagement/mobileApps/$($AppId)/$OdataType/contentVersions/$ContentVersionId/files/$($FileId)"

    Write-Verbose "Waiting for file processing to complete for AppId: $AppId, OdataType: $OdataType, FileId: $FileId, ContentVersionId: $ContentVersionId"
    $file = Invoke-MgGraphRequest -Method GET -Uri $fileUri

    while ($file.uploadState -ne "$($UploadStatePrefix)Success")
    {
        if ($file.uploadState -like '*Failed')
        {
            throw "File upload failed with state: $($file.uploadState). Please check the file and try again."
        }

        Start-Sleep -Seconds 1
        Write-Verbose "Current upload state: $($file.uploadState). Waiting for processing to complete..."
        $file = Invoke-MgGraphRequest -Method GET -Uri $fileUri
    }

    $file
}

Export-ModuleMember -Function @(
    'Compare-M365DSCIntunePolicyAssignment',
    'ConvertFrom-IntuneMobileAppAssignment',
    'ConvertFrom-IntunePolicyAssignment',
    'ConvertTo-IntuneMobileAppAssignment',
    'ConvertTo-IntunePolicyAssignment',
    'Export-IntuneSettingCatalogPolicySettings',
    'Find-GraphDataUsingComplexFunctions',
    'Get-ComplexFunctionsFromFilterQuery',
    'Get-IntuneSettingCatalogPolicySetting',
    'Get-IntuneSettingCatalogPolicySettingDSCValue',
    'Get-IntuneSettingCatalogPolicySettingInstanceValue',
    'Get-M365DSCIntuneDeviceConfigurationSettings',
    'Get-OmaSettingPlainTextValue',
    'Invoke-M365DSCIntuneMobileAppInitialUpload',
    'Remove-ComplexFunctionsFromFilterQuery',
    'Update-DeviceAppManagementAppCategory',
    'Update-DeviceAppManagementPolicyAssignment',
    'Update-DeviceConfigurationPolicyAssignment',
    'Update-IntuneDeviceConfigurationPolicy',
    'Wait-ForFileProcessing'
)
