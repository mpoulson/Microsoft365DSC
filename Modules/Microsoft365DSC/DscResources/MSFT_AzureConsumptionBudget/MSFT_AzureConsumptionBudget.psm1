Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureConsumptionBudget'

# The Consumption Budgets api is pinned to a stable version that is available in every Azure cloud, including
# the US Government clouds. Newer previews add no property this resource models.
$Script:ConsumptionBudgetApiVersion = '2023-05-01'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [ValidateSet('Cost')]
        [System.String]
        $Category,

        [Parameter()]
        [System.Double]
        $Amount,

        [Parameter()]
        [ValidateSet('Annually', 'BillingAnnual', 'BillingMonth', 'BillingQuarter', 'Monthly', 'Quarterly')]
        [System.String]
        $TimeGrain,

        [Parameter()]
        [System.String]
        $StartDate,

        [Parameter()]
        [System.String]
        $EndDate,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Notifications,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $FilterDimensions,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $FilterTags,

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

    Write-Verbose -Message "Getting configuration of Azure Consumption Budget {$Name} at scope {$Scope}"

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

        $uri = Get-M365DSCAzureConsumptionBudgetUri -Scope $Scope -Name $Name
        $instance = Invoke-M365DSCAzureRestGet -Uri $uri

        if ($null -eq $instance -or $null -eq $instance.properties)
        {
            return $nullResult
        }

        $NotificationsValue = @()
        if ($null -ne $instance.properties.notifications)
        {
            # The billing plane returns notifications as a dictionary keyed by notification name. DSC cannot model an
            # open ended dictionary, so the key is carried as the {Name} property of each entry instead.
            foreach ($notification in $instance.properties.notifications.PSObject.Properties)
            {
                $NotificationsValue += @{
                    Name          = $notification.Name
                    Enabled       = $notification.Value.enabled
                    Operator      = $notification.Value.operator
                    Threshold     = $notification.Value.threshold
                    ThresholdType = $notification.Value.thresholdType
                    ContactEmails = [Array]($notification.Value.contactEmails)
                    ContactRoles  = [Array]($notification.Value.contactRoles)
                    ContactGroups = [Array]($notification.Value.contactGroups)
                    Locale        = $notification.Value.locale
                }
            }
        }

        $FilterDimensionsValue = @()
        $FilterTagsValue = @()
        foreach ($filter in (Get-M365DSCAzureConsumptionBudgetFilterEntry -Filter $instance.properties.filter))
        {
            if ($null -ne $filter.dimensions)
            {
                $FilterDimensionsValue += @{
                    Name     = $filter.dimensions.name
                    Operator = $filter.dimensions.operator
                    Values   = [Array]($filter.dimensions.values)
                }
            }

            if ($null -ne $filter.tags)
            {
                $FilterTagsValue += @{
                    Name     = $filter.tags.name
                    Operator = $filter.tags.operator
                    Values   = [Array]($filter.tags.values)
                }
            }
        }

        $results = @{
            Name                  = $Name
            Scope                 = $Scope
            Category              = $instance.properties.category
            Amount                = $instance.properties.amount
            TimeGrain             = $instance.properties.timeGrain
            StartDate             = $instance.properties.timePeriod.startDate
            EndDate               = $instance.properties.timePeriod.endDate
            Notifications         = $NotificationsValue
            FilterDimensions      = $FilterDimensionsValue
            FilterTags            = $FilterTagsValue
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
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [ValidateSet('Cost')]
        [System.String]
        $Category,

        [Parameter()]
        [System.Double]
        $Amount,

        [Parameter()]
        [ValidateSet('Annually', 'BillingAnnual', 'BillingMonth', 'BillingQuarter', 'Monthly', 'Quarterly')]
        [System.String]
        $TimeGrain,

        [Parameter()]
        [System.String]
        $StartDate,

        [Parameter()]
        [System.String]
        $EndDate,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Notifications,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $FilterDimensions,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $FilterTags,

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

    Write-Verbose -Message "Setting configuration of Azure Consumption Budget {$Name} at scope {$Scope}"

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
    $uri = Get-M365DSCAzureConsumptionBudgetUri -Scope $Scope -Name $Name

    # CREATE or UPDATE
    if ($Ensure -eq 'Present')
    {
        $properties = @{
            category  = $Category
            amount    = $Amount
            timeGrain = $TimeGrain
        }

        if (-not [System.String]::IsNullOrEmpty($StartDate))
        {
            $timePeriod = @{
                startDate = $StartDate
            }

            if (-not [System.String]::IsNullOrEmpty($EndDate))
            {
                $timePeriod.Add('endDate', $EndDate)
            }

            $properties.Add('timePeriod', $timePeriod)
        }

        $notificationEntries = [ordered]@{}
        foreach ($notification in $Notifications)
        {
            $entry = @{
                enabled       = [System.Boolean]$notification.Enabled
                operator      = $notification.Operator
                threshold     = $notification.Threshold
                contactEmails = [Array]($notification.ContactEmails)
            }

            if (-not [System.String]::IsNullOrEmpty($notification.ThresholdType))
            {
                $entry.Add('thresholdType', $notification.ThresholdType)
            }
            if ($null -ne $notification.ContactRoles -and $notification.ContactRoles.Count -gt 0)
            {
                $entry.Add('contactRoles', [Array]($notification.ContactRoles))
            }
            if ($null -ne $notification.ContactGroups -and $notification.ContactGroups.Count -gt 0)
            {
                $entry.Add('contactGroups', [Array]($notification.ContactGroups))
            }
            if (-not [System.String]::IsNullOrEmpty($notification.Locale))
            {
                $entry.Add('locale', $notification.Locale)
            }

            $notificationEntries.Add($notification.Name, $entry)
        }

        if ($notificationEntries.Count -gt 0)
        {
            $properties.Add('notifications', $notificationEntries)
        }

        $filterEntries = @()
        foreach ($dimension in $FilterDimensions)
        {
            $filterEntries += @{
                dimensions = @{
                    name     = $dimension.Name
                    operator = $dimension.Operator
                    values   = [Array]($dimension.Values)
                }
            }
        }
        foreach ($tag in $FilterTags)
        {
            $filterEntries += @{
                tags = @{
                    name     = $tag.Name
                    operator = $tag.Operator
                    values   = [Array]($tag.Values)
                }
            }
        }

        if ($filterEntries.Count -eq 1)
        {
            # A single criterion is sent on its own. The api rejects an {and} array that holds a single entry.
            $properties.Add('filter', $filterEntries[0])
        }
        elseif ($filterEntries.Count -gt 1)
        {
            $properties.Add('filter', @{ and = $filterEntries })
        }

        $payload = ConvertTo-Json @{ properties = $properties } -Depth 10 -Compress

        if ($currentInstance.Ensure -eq 'Absent')
        {
            Write-Verbose -Message "Creating new consumption budget {$Name} with payload:`r`n$($payload)"
        }
        else
        {
            Write-Verbose -Message "Updating consumption budget {$Name} with payload:`r`n$($payload)"
        }

        $response = Invoke-AzRestMethod -Uri $uri -Method PUT -Payload $payload

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "creating or updating consumption budget {$Name} at scope {$Scope}"

        Write-Verbose -Message "Response:`r`n$($response.Content)"
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing consumption budget {$Name} at scope {$Scope}"
        $response = Invoke-AzRestMethod -Uri $uri -Method DELETE

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "removing consumption budget {$Name} at scope {$Scope}"
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
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [ValidateSet('Cost')]
        [System.String]
        $Category,

        [Parameter()]
        [System.Double]
        $Amount,

        [Parameter()]
        [ValidateSet('Annually', 'BillingAnnual', 'BillingMonth', 'BillingQuarter', 'Monthly', 'Quarterly')]
        [System.String]
        $TimeGrain,

        [Parameter()]
        [System.String]
        $StartDate,

        [Parameter()]
        [System.String]
        $EndDate,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Notifications,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $FilterDimensions,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $FilterTags,

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
        [array] $budgets = Get-M365DSCAzureConsumptionBudget

        $i = 1
        $dscContent = [System.Text.StringBuilder]::new()
        if ($budgets.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }
        foreach ($budget in $budgets)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $displayedKey = $budget.Name
            Write-M365DSCHost -Message "    |---[$i/$($budgets.Length)] $displayedKey" -DeferWrite

            $params = @{
                Name                  = $budget.Name
                Scope                 = $budget.Scope
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

            if ($Results.Ensure -eq 'Absent')
            {
                $i++
                Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
                continue
            }

            if ($Results.Notifications.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject ([Array]$Results.Notifications) `
                    -CIMInstanceName AzureConsumptionBudgetNotification
                if ($complexTypeStringResult)
                {
                    $Results.Notifications = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('Notifications') | Out-Null
                }
            }
            else
            {
                $Results.Remove('Notifications') | Out-Null
            }

            if ($Results.FilterDimensions.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject ([Array]$Results.FilterDimensions) `
                    -CIMInstanceName AzureConsumptionBudgetFilterDimension
                if ($complexTypeStringResult)
                {
                    $Results.FilterDimensions = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('FilterDimensions') | Out-Null
                }
            }
            else
            {
                $Results.Remove('FilterDimensions') | Out-Null
            }

            if ($Results.FilterTags.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject ([Array]$Results.FilterTags) `
                    -CIMInstanceName AzureConsumptionBudgetFilterTag
                if ($complexTypeStringResult)
                {
                    $Results.FilterTags = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('FilterTags') | Out-Null
                }
            }
            else
            {
                $Results.Remove('FilterTags') | Out-Null
            }

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential `
                -NoEscape @('Notifications', 'FilterDimensions', 'FilterTags')

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
    Builds the request uri for a consumption budget.

.DESCRIPTION
    Composes the Microsoft.Consumption budgets uri for any Azure Resource Manager scope. The scope is normalized
    so that a caller may supply it with or without the surrounding slashes.

.PARAMETER Scope
    Specifies the Azure Resource Manager scope holding the budget.

.PARAMETER Name
    Specifies the name of the budget. When omitted the collection uri is returned.

.OUTPUTS
    System.String
#>
function Get-M365DSCAzureConsumptionBudgetUri
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [System.String]
        $Name
    )

    $managementUrl = (Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl
    $normalizedScope = $Scope.Trim('/')

    if ([System.String]::IsNullOrEmpty($Name))
    {
        return "$managementUrl$normalizedScope/providers/Microsoft.Consumption/budgets?api-version=$($Script:ConsumptionBudgetApiVersion)"
    }

    return "$managementUrl$normalizedScope/providers/Microsoft.Consumption/budgets/$($Name)?api-version=$($Script:ConsumptionBudgetApiVersion)"
}

<#
.SYNOPSIS
    Flattens a budget filter into its individual criteria.

.DESCRIPTION
    A budget filter holds a single criterion directly and multiple criteria under an {and} array. Returning both
    shapes as a flat list keeps the caller from having to branch on how many criteria the budget carries.

.PARAMETER Filter
    Specifies the filter object returned by the Consumption Budgets api.

.OUTPUTS
    System.Object[]
#>
function Get-M365DSCAzureConsumptionBudgetFilterEntry
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param
    (
        [Parameter()]
        [System.Object]
        $Filter
    )

    if ($null -eq $Filter)
    {
        return @()
    }

    if ($null -ne $Filter.and)
    {
        return [Array]($Filter.and)
    }

    return @($Filter)
}

<#
.SYNOPSIS
    Enumerates the consumption budgets that can be discovered for the current context.

.DESCRIPTION
    Budgets are scoped resources and Azure offers no tenant wide list operation for them, so discovery walks the
    scopes that an Enterprise Agreement tenant actually uses: every billing account and every subscription the
    caller can see. Each result carries the scope it was found at so that the export can round trip it.

.OUTPUTS
    System.Object[]
#>
function Get-M365DSCAzureConsumptionBudget
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    $scopes = @()

    $billingAccounts = Get-M365DSCAzureBillingAccount
    foreach ($billingAccount in $billingAccounts.value)
    {
        $scopes += "providers/Microsoft.Billing/billingAccounts/$($billingAccount.name)"
    }

    foreach ($subscription in (Get-AzSubscription -ErrorAction SilentlyContinue))
    {
        $scopes += "subscriptions/$($subscription.Id)"
    }

    $results = @()
    foreach ($scope in $scopes)
    {
        $uri = Get-M365DSCAzureConsumptionBudgetUri -Scope $scope

        # A scope the caller cannot read answers with a failure rather than an empty collection. Discovery keeps
        # walking the remaining scopes instead of aborting the whole export.
        try
        {
            [array] $budgets = Invoke-M365DSCAzureRestList -Uri $uri
        }
        catch
        {
            Write-Verbose -Message "Skipping scope {$scope} while enumerating consumption budgets: $($_.Exception.Message)"
            continue
        }

        foreach ($budget in $budgets)
        {
            $results += @{
                Name  = $budget.name
                Scope = $scope
            }
        }
    }

    return $results
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
