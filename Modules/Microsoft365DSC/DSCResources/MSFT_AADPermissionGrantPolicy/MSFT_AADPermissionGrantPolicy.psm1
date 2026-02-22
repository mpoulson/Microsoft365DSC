Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AADPermissionGrantPolicy'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Includes,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Excludes,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
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

    Write-Verbose -Message "Getting configuration of Azure AD Permission Grant Policy {$Id}"

    try
    {
        if (-not $Script:exportedInstance -or $Script:exportedInstance.Id -ne $Id)
        {
            $null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
                -InboundParameters $PSBoundParameters

            #Ensure the proper dependencies are installed in the current environment.
            Confirm-M365DSCDependencies

            #region Telemetry
            $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
            $CommandName = $MyInvocation.MyCommand
            $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
                -CommandName $CommandName `
                -Parameters $PSBoundParameters
            Add-M365DSCTelemetryEvent -Data $data
            #endregion

            $nullResult = $PSBoundParameters
            $nullResult.Ensure = 'Absent'

            $getValue = Get-MgBetaPolicyPermissionGrantPolicy -PermissionGrantPolicyId $Id #`
                #-ExpandProperty $script:ExpandProperties `
                #-ErrorAction SilentlyContinue
        }
        else
        {
            $getValue = $Script:exportedInstance
        }

        if ($null -eq $getValue)
        {
            Write-Verbose -Message "No Azure AD Permission Grant Policy with Id {$Id} was found"
            return $nullResult
        }

        Write-Verbose -Message "Found Azure AD Permission Grant Policy with Id {$Id}"

        # Convert Includes collection to hashtable array
        $includesArray = @()
        if ($null -ne $getValue.Includes)
        {
            foreach ($include in $getValue.Includes)
            {
                $includesArray += Get-PermissionGrantConditionSetAsHashtable -ConditionSet $include
            }
        }

        # Convert Excludes collection to hashtable array
        $excludesArray = @()
        if ($null -ne $getValue.Excludes)
        {
            foreach ($exclude in $getValue.Excludes)
            {
                $excludesArray += Get-PermissionGrantConditionSetAsHashtable -ConditionSet $exclude
            }
        }

        $result = @{
            Id                    = $getValue.Id
            DisplayName           = $getValue.DisplayName
            Description           = $getValue.Description
            Includes              = [Array]$includesArray
            Excludes              = [Array]$excludesArray
            Ensure                = 'Present'
            Credential            = $Credential
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            ApplicationSecret     = $ApplicationSecret
            CertificateThumbprint = $CertificateThumbprint
            ManagedIdentity       = $ManagedIdentity.IsPresent
            AccessTokens          = $AccessTokens
        }

        return $result
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
        $Id,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Includes,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Excludes,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
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

    Write-Verbose -Message "Setting configuration of Azure AD Permission Grant Policy {$Id}"

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        $null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
            -InboundParameters $PSBoundParameters

        $currentPolicy = Get-TargetResource @PSBoundParameters

        $setParameters = Remove-M365DSCAuthenticationParameter -BoundParameters $PSBoundParameters

        if ($Ensure -eq 'Present' -and $currentPolicy.Ensure -eq 'Absent')
        {
            Write-Verbose -Message "Creating new Azure AD Permission Grant Policy {$Id}"

            $createParameters = @{
                Id          = $Id
                DisplayName = $DisplayName
                Description = $Description
            }

            New-MgBetaPolicyPermissionGrantPolicy @createParameters | Out-Null

            # Add Includes
            if ($null -ne $Includes -and $Includes.Count -gt 0)
            {
                foreach ($include in $Includes)
                {
                    Write-Verbose -Message "Adding include condition set {$($include.Id)}"
                    $includeParams = Get-PermissionGrantConditionSetAsParameters -ConditionSet $include
                    New-MgBetaPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $Id @includeParams | Out-Null
                }
            }

            # Add Excludes
            if ($null -ne $Excludes -and $Excludes.Count -gt 0)
            {
                foreach ($exclude in $Excludes)
                {
                    Write-Verbose -Message "Adding exclude condition set {$($exclude.Id)}"
                    $excludeParams = Get-PermissionGrantConditionSetAsParameters -ConditionSet $exclude
                    New-MgBetaPolicyPermissionGrantPolicyExclude -PermissionGrantPolicyId $Id @excludeParams | Out-Null
                }
            }
        }
        elseif ($Ensure -eq 'Present' -and $currentPolicy.Ensure -eq 'Present')
        {
            Write-Verbose -Message "Updating Azure AD Permission Grant Policy {$Id}"

            $updateParameters = @{
                PermissionGrantPolicyId = $Id
            }

            if ($PSBoundParameters.ContainsKey('DisplayName') -and $DisplayName -ne $currentPolicy.DisplayName)
            {
                $updateParameters.Add('DisplayName', $DisplayName)
            }

            if ($PSBoundParameters.ContainsKey('Description') -and $Description -ne $currentPolicy.Description)
            {
                $updateParameters.Add('Description', $Description)
            }

            if ($updateParameters.Count -gt 1)
            {
                Update-MgBetaPolicyPermissionGrantPolicy @updateParameters | Out-Null
            }

            # Sync Includes
            if ($null -ne $Includes)
            {
                $desiredIncludes = @()
                foreach ($include in $Includes)
                {
                    $desiredIncludes += $include.Id
                }

                $currentIncludes = @()
                foreach ($include in $currentPolicy.Includes)
                {
                    $currentIncludes += $include.Id
                }

                # Remove includes that are not in desired state
                foreach ($currentInclude in $currentPolicy.Includes)
                {
                    if ($currentInclude.Id -notin $desiredIncludes)
                    {
                        Write-Verbose -Message "Removing include condition set {$($currentInclude.Id)}"
                        Remove-MgBetaPolicyPermissionGrantPolicyInclude `
                            -PermissionGrantPolicyId $Id `
                            -PermissionGrantConditionSetId $currentInclude.Id | Out-Null
                    }
                }

                # Add or update includes that are in desired state
                foreach ($include in $Includes)
                {
                    if ($include.Id -in $currentIncludes)
                    {
                        # Check if update is needed
                        $currentInclude = $currentPolicy.Includes | Where-Object { $_.Id -eq $include.Id }
                        if (-not (Test-ConditionSetsEqual -ConditionSet1 $include -ConditionSet2 $currentInclude))
                        {
                            Write-Verbose -Message "Updating include condition set {$($include.Id)}"
                            # Remove and recreate (no update cmdlet available)
                            Remove-MgBetaPolicyPermissionGrantPolicyInclude `
                                -PermissionGrantPolicyId $Id `
                                -PermissionGrantConditionSetId $include.Id | Out-Null

                            $includeParams = Get-PermissionGrantConditionSetAsParameters -ConditionSet $include
                            New-MgBetaPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $Id @includeParams | Out-Null
                        }
                    }
                    else
                    {
                        Write-Verbose -Message "Adding include condition set {$($include.Id)}"
                        $includeParams = Get-PermissionGrantConditionSetAsParameters -ConditionSet $include
                        New-MgBetaPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $Id @includeParams | Out-Null
                    }
                }
            }

            # Sync Excludes
            if ($null -ne $Excludes)
            {
                $desiredExcludes = @()
                foreach ($exclude in $Excludes)
                {
                    $desiredExcludes += $exclude.Id
                }

                $currentExcludes = @()
                foreach ($exclude in $currentPolicy.Excludes)
                {
                    $currentExcludes += $exclude.Id
                }

                # Remove excludes that are not in desired state
                foreach ($currentExclude in $currentPolicy.Excludes)
                {
                    if ($currentExclude.Id -notin $desiredExcludes)
                    {
                        Write-Verbose -Message "Removing exclude condition set {$($currentExclude.Id)}"
                        Remove-MgBetaPolicyPermissionGrantPolicyExclude `
                            -PermissionGrantPolicyId $Id `
                            -PermissionGrantConditionSetId $currentExclude.Id | Out-Null
                    }
                }

                # Add or update excludes that are in desired state
                foreach ($exclude in $Excludes)
                {
                    if ($exclude.Id -in $currentExcludes)
                    {
                        # Check if update is needed
                        $currentExclude = $currentPolicy.Excludes | Where-Object { $_.Id -eq $exclude.Id }
                        if (-not (Test-ConditionSetsEqual -ConditionSet1 $exclude -ConditionSet2 $currentExclude))
                        {
                            Write-Verbose -Message "Updating exclude condition set {$($exclude.Id)}"
                            # Remove and recreate (no update cmdlet available)
                            Remove-MgBetaPolicyPermissionGrantPolicyExclude `
                                -PermissionGrantPolicyId $Id `
                                -PermissionGrantConditionSetId $exclude.Id | Out-Null

                            $excludeParams = Get-PermissionGrantConditionSetAsParameters -ConditionSet $exclude
                            New-MgBetaPolicyPermissionGrantPolicyExclude -PermissionGrantPolicyId $Id @excludeParams | Out-Null
                        }
                    }
                    else
                    {
                        Write-Verbose -Message "Adding exclude condition set {$($exclude.Id)}"
                        $excludeParams = Get-PermissionGrantConditionSetAsParameters -ConditionSet $exclude
                        New-MgBetaPolicyPermissionGrantPolicyExclude -PermissionGrantPolicyId $Id @excludeParams | Out-Null
                    }
                }
            }
        }
        elseif ($Ensure -eq 'Absent' -and $currentPolicy.Ensure -eq 'Present')
        {
            Write-Verbose -Message "Removing Azure AD Permission Grant Policy {$Id}"
            Remove-MgBetaPolicyPermissionGrantPolicy -PermissionGrantPolicyId $Id | Out-Null
        }
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

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Includes,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Excludes,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
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
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Write-Verbose -Message "Testing configuration of Azure AD Permission Grant Policy {$Id}"

    $result = Test-M365DSCTargetResource -DesiredValues $PSBoundParameters `
        -ResourceName $($MyInvocation.MyCommand.Source).Replace('MSFT_', '')

    Write-Verbose -Message "Test-TargetResource returned $result"

    return $result
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
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
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        $Script:ExportMode = $true

        [array] $Script:exportedInstances = Get-MgBetaPolicyPermissionGrantPolicy -All:$true #`
            #-ExpandProperty $script:ExpandProperties `
            #-ErrorAction Stop

        $dscContent = ''
        $i = 1

        if ($Script:exportedInstances.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }

        foreach ($policy in $Script:exportedInstances)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $($policy.Id)" -DeferWrite

            $Params = @{
                Id                    = $policy.Id
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                ApplicationSecret     = $ApplicationSecret
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $Script:exportedInstance = $policy
            $Results = Get-TargetResource @Params

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential
            $dscContent += $currentDSCBlock
            Save-M365DSCPartialExport -Content $currentDSCBlock `
                -FileName $Global:PartialExportFileName

            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
            $i++
        }

        return $dscContent
    }
    catch
    {
        Write-M365DSCHost -Message $Global:M365DSCEmojiRedX

        New-M365DSCLogEntry -Message 'Error during Export:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return ''
    }
}

#region Helper Functions

<#
.SYNOPSIS
Converts a permission grant condition set object to a hashtable representation.

.DESCRIPTION
This helper function takes a condition set object (from the Microsoft Graph API)
and converts it to a hashtable format suitable for DSC configuration comparison.
Only non-null properties are included in the result.

.PARAMETER ConditionSet
The condition set object to convert. This can be a PSCustomObject from the Graph API
or a hashtable/CIM instance from DSC configuration.

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
$hashtable = Get-PermissionGrantConditionSetAsHashtable -ConditionSet $graphObject
#>
function Get-PermissionGrantConditionSetAsHashtable
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $ConditionSet
    )

    $result = @{
        Id = $ConditionSet.Id
    }

    if ($null -ne $ConditionSet.CertifiedClientApplicationsOnly)
    {
        $result.Add('CertifiedClientApplicationsOnly', $ConditionSet.CertifiedClientApplicationsOnly)
    }

    if ($null -ne $ConditionSet.ClientApplicationIds)
    {
        $result.Add('ClientApplicationIds', [string[]]$ConditionSet.ClientApplicationIds)
    }

    if ($null -ne $ConditionSet.ClientApplicationPublisherIds)
    {
        $result.Add('ClientApplicationPublisherIds', [string[]]$ConditionSet.ClientApplicationPublisherIds)
    }

    if ($null -ne $ConditionSet.ClientApplicationTenantIds)
    {
        $result.Add('ClientApplicationTenantIds', [string[]]$ConditionSet.ClientApplicationTenantIds)
    }

    if ($null -ne $ConditionSet.ClientApplicationsFromVerifiedPublisherOnly)
    {
        $result.Add('ClientApplicationsFromVerifiedPublisherOnly', $ConditionSet.ClientApplicationsFromVerifiedPublisherOnly)
    }

    if ($null -ne $ConditionSet.PermissionClassification)
    {
        $result.Add('PermissionClassification', $ConditionSet.PermissionClassification)
    }

    if ($null -ne $ConditionSet.Permissions)
    {
        $result.Add('Permissions', [string[]]$ConditionSet.Permissions)
    }

    if ($null -ne $ConditionSet.PermissionType)
    {
        $result.Add('PermissionType', $ConditionSet.PermissionType)
    }

    if ($null -ne $ConditionSet.ResourceApplication)
    {
        $result.Add('ResourceApplication', $ConditionSet.ResourceApplication)
    }

    return $result
}

<#
.SYNOPSIS
Converts a condition set to Microsoft Graph API parameters.

.DESCRIPTION
This helper function takes a condition set (from DSC configuration) and converts it
to a hashtable of parameters suitable for passing to Microsoft Graph API cmdlets
(New-MgBetaPolicyPermissionGrantPolicyInclude/Exclude).

.PARAMETER ConditionSet
The condition set to convert. This can be a CIM instance or hashtable.

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
$params = Get-PermissionGrantConditionSetAsParameters -ConditionSet $cimInstance
New-MgBetaPolicyPermissionGrantPolicyInclude @params
#>
function Get-PermissionGrantConditionSetAsParameters
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $ConditionSet
    )

    $params = @{}

    if ($null -ne $ConditionSet.CertifiedClientApplicationsOnly)
    {
        $params.Add('CertifiedClientApplicationsOnly', [bool]$ConditionSet.CertifiedClientApplicationsOnly)
    }

    if ($null -ne $ConditionSet.ClientApplicationIds -and $ConditionSet.ClientApplicationIds.Count -gt 0)
    {
        $params.Add('ClientApplicationIds', [string[]]$ConditionSet.ClientApplicationIds)
    }

    if ($null -ne $ConditionSet.ClientApplicationPublisherIds -and $ConditionSet.ClientApplicationPublisherIds.Count -gt 0)
    {
        $params.Add('ClientApplicationPublisherIds', [string[]]$ConditionSet.ClientApplicationPublisherIds)
    }

    if ($null -ne $ConditionSet.ClientApplicationTenantIds -and $ConditionSet.ClientApplicationTenantIds.Count -gt 0)
    {
        $params.Add('ClientApplicationTenantIds', [string[]]$ConditionSet.ClientApplicationTenantIds)
    }

    if ($null -ne $ConditionSet.ClientApplicationsFromVerifiedPublisherOnly)
    {
        $params.Add('ClientApplicationsFromVerifiedPublisherOnly', [bool]$ConditionSet.ClientApplicationsFromVerifiedPublisherOnly)
    }

    if (-not [string]::IsNullOrEmpty($ConditionSet.PermissionClassification))
    {
        $params.Add('PermissionClassification', $ConditionSet.PermissionClassification)
    }

    if ($null -ne $ConditionSet.Permissions -and $ConditionSet.Permissions.Count -gt 0)
    {
        $params.Add('Permissions', [string[]]$ConditionSet.Permissions)
    }

    if (-not [string]::IsNullOrEmpty($ConditionSet.PermissionType))
    {
        $params.Add('PermissionType', $ConditionSet.PermissionType)
    }

    if (-not [string]::IsNullOrEmpty($ConditionSet.ResourceApplication))
    {
        $params.Add('ResourceApplication', $ConditionSet.ResourceApplication)
    }

    return $params
}

<#
.SYNOPSIS
Compares two permission grant condition sets for equality.

.DESCRIPTION
This helper function performs a deep comparison of two condition sets to determine
if they are logically equivalent. Array properties are compared after sorting to
ensure order-independent comparison.

.PARAMETER ConditionSet1
The first condition set to compare.

.PARAMETER ConditionSet2
The second condition set to compare.

.OUTPUTS
System.Boolean
Returns $true if the condition sets are equivalent, $false otherwise.

.EXAMPLE
$areEqual = Test-ConditionSetsEqual -ConditionSet1 $desired -ConditionSet2 $current
#>
function Test-ConditionSetsEqual
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $ConditionSet1,

        [Parameter(Mandatory = $true)]
        [System.Object]
        $ConditionSet2
    )

    # Convert both to hashtables for comparison
    $hash1 = Get-PermissionGrantConditionSetAsHashtable -ConditionSet $ConditionSet1
    $hash2 = Get-PermissionGrantConditionSetAsHashtable -ConditionSet $ConditionSet2

    # Compare each property
    foreach ($key in $hash1.Keys)
    {
        if (-not $hash2.ContainsKey($key))
        {
            return $false
        }

        $value1 = $hash1[$key]
        $value2 = $hash2[$key]

        # Handle array comparison
        if ($value1 -is [Array] -and $value2 -is [Array])
        {
            if ($value1.Count -ne $value2.Count)
            {
                return $false
            }

            $sorted1 = $value1 | Sort-Object
            $sorted2 = $value2 | Sort-Object

            for ($i = 0; $i -lt $sorted1.Count; $i++)
            {
                if ($sorted1[$i] -ne $sorted2[$i])
                {
                    return $false
                }
            }
        }
        else
        {
            if ($value1 -ne $value2)
            {
                return $false
            }
        }
    }

    # Check for keys in hash2 that are not in hash1
    foreach ($key in $hash2.Keys)
    {
        if (-not $hash1.ContainsKey($key))
        {
            return $false
        }
    }

    return $true
}

#endregion

Export-ModuleMember -Function *-TargetResource
