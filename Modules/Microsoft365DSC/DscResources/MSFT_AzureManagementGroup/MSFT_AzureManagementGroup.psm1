Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureManagementGroup'

$Script:ManagementGroupApiVersion = '2021-04-01'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupId,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $ParentGroupId,

        [Parameter()]
        [System.String[]]
        $Subscriptions,

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

    Write-Verbose -Message "Getting configuration of Azure Management Group {$GroupId}"

    try
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

        # The children collection is only returned when it is explicitly expanded, and it is the only place the
        # subscriptions assigned to the group are reported.
        $uri = "$(Get-M365DSCAzureManagementGroupUri -GroupId $GroupId)&`$expand=children"
        $instance = Invoke-M365DSCAzureRestGet -Uri $uri

        if ($null -eq $instance -or $null -eq $instance.properties)
        {
            return $nullResult
        }

        $SubscriptionsValue = @()
        foreach ($child in $instance.properties.children)
        {
            if ($child.type -eq '/subscriptions' -or $child.type -eq 'Microsoft.Management/managementGroups/subscriptions')
            {
                $SubscriptionsValue += $child.name
            }
        }

        $ParentGroupIdValue = $null
        if ($null -ne $instance.properties.details -and $null -ne $instance.properties.details.parent)
        {
            $ParentGroupIdValue = $instance.properties.details.parent.name
        }

        $results = @{
            GroupId               = $instance.name
            DisplayName           = $instance.properties.displayName
            ParentGroupId         = $ParentGroupIdValue
            Subscriptions         = $SubscriptionsValue
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
        $GroupId,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $ParentGroupId,

        [Parameter()]
        [System.String[]]
        $Subscriptions,

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

    Write-Verbose -Message "Setting configuration of Azure Management Group {$GroupId}"

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

    $currentInstance = Get-TargetResource @PSBoundParameters
    $uri = Get-M365DSCAzureManagementGroupUri -GroupId $GroupId

    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        $properties = @{
            displayName = $DisplayName
        }

        if (-not [System.String]::IsNullOrEmpty($ParentGroupId))
        {
            $properties.Add('details', @{
                    parent = @{
                        id = Get-M365DSCAzureManagementGroupResourceId -GroupId $ParentGroupId
                    }
                })
        }

        $payload = ConvertTo-Json @{ properties = $properties } -Depth 10 -Compress
        Write-Verbose -Message "Creating new management group {$GroupId} with payload:`r`n$($payload)"

        $response = Invoke-AzRestMethod -Uri $uri -Method PUT -Payload $payload

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "creating management group {$GroupId}"

        Set-M365DSCAzureManagementGroupSubscription -GroupId $GroupId `
            -DesiredSubscriptions $Subscriptions `
            -CurrentSubscriptions @()
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        $patch = @{}

        if (-not [System.String]::IsNullOrEmpty($DisplayName) -and $DisplayName -ne $currentInstance.DisplayName)
        {
            $patch.Add('displayName', $DisplayName)
        }
        if (-not [System.String]::IsNullOrEmpty($ParentGroupId) -and $ParentGroupId -ne $currentInstance.ParentGroupId)
        {
            $patch.Add('parentGroupId', (Get-M365DSCAzureManagementGroupResourceId -GroupId $ParentGroupId))
        }

        if ($patch.Count -gt 0)
        {
            # Display name and parent are changed through PATCH. A PUT against an existing group is rejected when
            # the caller does not own the whole hierarchy.
            $payload = ConvertTo-Json $patch -Depth 10 -Compress
            Write-Verbose -Message "Updating management group {$GroupId} with payload:`r`n$($payload)"

            $response = Invoke-AzRestMethod -Uri $uri -Method PATCH -Payload $payload

            Assert-M365DSCAzureResponse -Response $response `
                -Operation "updating management group {$GroupId}"
        }

        if ($PSBoundParameters.ContainsKey('Subscriptions'))
        {
            Set-M365DSCAzureManagementGroupSubscription -GroupId $GroupId `
                -DesiredSubscriptions $Subscriptions `
                -CurrentSubscriptions $currentInstance.Subscriptions
        }
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        # Azure refuses to delete a management group that still holds children, so the subscriptions are moved back
        # to the tenant root first.
        Set-M365DSCAzureManagementGroupSubscription -GroupId $GroupId `
            -DesiredSubscriptions @() `
            -CurrentSubscriptions $currentInstance.Subscriptions

        Write-Verbose -Message "Removing management group {$GroupId}"
        $response = Invoke-AzRestMethod -Uri $uri -Method DELETE

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "removing management group {$GroupId}"
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
        $GroupId,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $ParentGroupId,

        [Parameter()]
        [System.String[]]
        $Subscriptions,

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
        $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Management/managementGroups?api-version=$($Script:ManagementGroupApiVersion)"
        [array] $groups = Invoke-M365DSCAzureRestList -Uri $uri

        $i = 1
        $dscContent = [System.Text.StringBuilder]::new()
        if ($groups.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }
        foreach ($group in $groups)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $displayedKey = $group.name
            Write-M365DSCHost -Message "    |---[$i/$($groups.Length)] $displayedKey" -DeferWrite

            $params = @{
                GroupId               = $group.name
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

            $Results = Get-TargetResource @Params

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential

            [void]$dscContent.Append($currentDSCBlock)
            Save-M365DSCPartialExport -Content $currentDSCBlock `
                -FileName $Global:PartialExportFileName
            $i++
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
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

<#
.SYNOPSIS
    Builds the request uri for a management group.

.DESCRIPTION
    Composes the Microsoft.Management managementGroups uri for a single management group.

.PARAMETER GroupId
    Specifies the name of the management group.

.OUTPUTS
    System.String
#>
function Get-M365DSCAzureManagementGroupUri
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupId
    )

    $managementUrl = (Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl
    return "$($managementUrl)providers/Microsoft.Management/managementGroups/$($GroupId)?api-version=$($Script:ManagementGroupApiVersion)"
}

<#
.SYNOPSIS
    Builds the fully qualified resource id of a management group.

.DESCRIPTION
    Returns the resource id form that the parent reference of a management group requires. A caller may supply
    either the bare group name or an already qualified resource id.

.PARAMETER GroupId
    Specifies the name or resource id of the management group.

.OUTPUTS
    System.String
#>
function Get-M365DSCAzureManagementGroupResourceId
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupId
    )

    if ($GroupId -like '*/providers/Microsoft.Management/managementGroups/*')
    {
        return "/$($GroupId.Trim('/'))"
    }

    return "/providers/Microsoft.Management/managementGroups/$($GroupId)"
}

<#
.SYNOPSIS
    Reconciles the subscriptions assigned to a management group.

.DESCRIPTION
    Adds the subscriptions that are missing from the management group and removes the ones that are no longer
    wanted. A subscription removed from a management group is moved back under the tenant root group, which is
    where Azure places any subscription that is not explicitly assigned.

.PARAMETER GroupId
    Specifies the name of the management group.

.PARAMETER DesiredSubscriptions
    Specifies the subscription identifiers that should be assigned to the group.

.PARAMETER CurrentSubscriptions
    Specifies the subscription identifiers currently assigned to the group.

.OUTPUTS
    None
#>
function Set-M365DSCAzureManagementGroupSubscription
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupId,

        [Parameter()]
        [AllowEmptyCollection()]
        [System.String[]]
        $DesiredSubscriptions,

        [Parameter()]
        [AllowEmptyCollection()]
        [System.String[]]
        $CurrentSubscriptions
    )

    $managementUrl = (Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl

    if ($null -eq $DesiredSubscriptions)
    {
        $DesiredSubscriptions = @()
    }
    if ($null -eq $CurrentSubscriptions)
    {
        $CurrentSubscriptions = @()
    }

    foreach ($subscription in $DesiredSubscriptions)
    {
        if ($CurrentSubscriptions -contains $subscription)
        {
            continue
        }

        Write-Verbose -Message "Adding subscription {$subscription} to management group {$GroupId}"
        $uri = "$($managementUrl)providers/Microsoft.Management/managementGroups/$($GroupId)/subscriptions/$($subscription)?api-version=$($Script:ManagementGroupApiVersion)"
        $response = Invoke-AzRestMethod -Uri $uri -Method PUT

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "adding subscription {$subscription} to management group {$GroupId}"
    }

    foreach ($subscription in $CurrentSubscriptions)
    {
        if ($DesiredSubscriptions -contains $subscription)
        {
            continue
        }

        Write-Verbose -Message "Removing subscription {$subscription} from management group {$GroupId}"
        $uri = "$($managementUrl)providers/Microsoft.Management/managementGroups/$($GroupId)/subscriptions/$($subscription)?api-version=$($Script:ManagementGroupApiVersion)"
        $response = Invoke-AzRestMethod -Uri $uri -Method DELETE

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "removing subscription {$subscription} from management group {$GroupId}"
    }
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
