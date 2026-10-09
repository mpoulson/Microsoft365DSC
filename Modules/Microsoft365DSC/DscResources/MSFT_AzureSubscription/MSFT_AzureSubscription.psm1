Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureSubscription'

$Script:BillingApiVersion = '2024-04-01'
$Script:BillingAccountApiVersion = '2020-05-01'
$Script:SubscriptionAliasApiVersion = '2021-10-01'
$Script:SubscriptionCancelApiVersion = '2019-03-01-preview'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $InvoiceSectionId,

        [Parameter()]
        [System.String]
        $BillingAccountId,

        [Parameter()]
        [System.String]
        $EnrollmentAccountId,

        [Parameter()]
        [System.String]
        $Status,

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

    Write-Verbose -Message "Getting configuration for Azure Subscription with DisplayName $DisplayName"

    try
    {
        $nullResult = $PSBoundParameters
        $nullResult.Ensure = 'Absent'

        if ($null -eq $Script:exportedInstances -or -not $Script:ExportMode)
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

            # Billing subscriptions are always retrieved as a collection and filtered locally. A single-instance
            # GET returns the resource without a {value} wrapper, which makes the two shapes easy to confuse, and
            # collections are the only shape that supports paging through {nextLink}.
            $instances = Get-M365DSCAzureBillingSubscription -InvoiceSectionId $InvoiceSectionId `
                -BillingAccountId $BillingAccountId
        }
        else
        {
            $instances = $Script:exportedInstances
        }

        if (-not [System.String]::IsNullOrEmpty($Id))
        {
            $instance = $instances | Where-Object -FilterScript { $_.name -eq $Id }
        }
        else
        {
            $instance = $instances | Where-Object -FilterScript { $_.properties.displayName -eq $DisplayName }

            # An Enterprise Agreement subscription has no invoice section, so it is narrowed by enrollment
            # account instead. Display names are only unique within a billing scope.
            if (-not [System.String]::IsNullOrEmpty($InvoiceSectionId))
            {
                $instance = $instance | Where-Object -FilterScript { $_.properties.invoiceSectionId -eq $InvoiceSectionId }
            }

            if (-not [System.String]::IsNullOrEmpty($EnrollmentAccountId))
            {
                $instance = $instance | Where-Object -FilterScript { $_.properties.enrollmentAccountId -eq $EnrollmentAccountId }
            }
        }

        if ($null -eq $instance)
        {
            return $nullResult
        }

        if (@($instance).Count -gt 1)
        {
            Write-Verbose -Message "More than one subscription was found matching {$DisplayName}; using the first result. Specify the Id property to disambiguate."
            $instance = @($instance)[0]
        }

        # The billing account is not returned as its own property, it is only present in the resource id, which
        # has the shape /providers/Microsoft.Billing/billingAccounts/{name}/billingSubscriptions/{guid}
        $billingAccountValue = $BillingAccountId
        if ($instance.id -match '/billingAccounts/(?<billingAccount>[^/]+)/')
        {
            $billingAccountValue = $Matches.billingAccount
        }

        $results = @{
            DisplayName           = $instance.properties.displayName
            Id                    = $instance.name
            InvoiceSectionId      = $instance.properties.invoiceSectionId
            BillingAccountId      = $billingAccountValue
            EnrollmentAccountId   = $instance.properties.enrollmentAccountId
            Status                = $instance.properties.status
            Ensure                = 'Present'
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
        $DisplayName,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $InvoiceSectionId,

        [Parameter()]
        [System.String]
        $BillingAccountId,

        [Parameter()]
        [System.String]
        $EnrollmentAccountId,

        [Parameter()]
        [System.String]
        $Status,

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

    Write-Verbose -Message "Setting configuration for Azure Subscription with DisplayName $DisplayName"

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

    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        $billingScope = Get-M365DSCAzureBillingScope -InvoiceSectionId $InvoiceSectionId `
            -BillingAccountId $BillingAccountId `
            -EnrollmentAccountId $EnrollmentAccountId

        if ([System.String]::IsNullOrEmpty($billingScope))
        {
            throw "Cannot create subscription {$DisplayName} without a billing scope. Provide InvoiceSectionId for a Microsoft Customer Agreement billing account, or BillingAccountId and EnrollmentAccountId for an Enterprise Agreement enrollment."
        }

        Write-Verbose -Message "Creating subscription {$DisplayName} against billing scope {$billingScope}"
        $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Subscription/aliases/$((New-Guid).ToString())?api-version=$($Script:SubscriptionAliasApiVersion)"
        $params = @{
            properties = @{
                billingScope = $billingScope
                DisplayName  = $DisplayName
                Workload     = 'Production'
            }
        }
        $payload = ConvertTo-Json $params -Depth 10 -Compress
        Write-Verbose -Message "Creating new subscription {$DisplayName} with payload:`r`n$payload"
        $response = Invoke-AzRestMethod -Uri $uri -Method PUT -Payload $payload
        Write-Verbose -Message "Result: $($response.Content)"

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "creating subscription {$DisplayName}"

        # The alias PUT is asynchronous. Without waiting for it to settle the resource reports success while the
        # subscription is still provisioning, so anything that depends on it runs against a subscription that
        # does not exist yet.
        Wait-M365DSCAzureSubscriptionAlias -Uri $uri
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        if ([System.String]::IsNullOrEmpty($Status) -or $Status -eq $currentInstance.Status)
        {
            Write-Verbose -Message "Subscription {$DisplayName} status is already {$($currentInstance.Status)}; no update required."
        }
        elseif ($Status -eq 'Active')
        {
            Write-Verbose -Message "Enabling subscription {$DisplayName} ({$($currentInstance.Id)})"
            Enable-AzSubscription -Id $currentInstance.Id -Confirm:$false | Out-Null
        }
        elseif ($Status -eq 'Disabled')
        {
            Write-Verbose -Message "Disabling subscription {$DisplayName} ({$($currentInstance.Id)})"
            Disable-AzSubscription -Id $currentInstance.Id -Confirm:$false | Out-Null
        }
        else
        {
            Write-Verbose -Message "Status {$Status} on subscription {$DisplayName} is reported by the billing platform and cannot be set. Only {Active} and {Disabled} are settable."
        }
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Deleting subscription {$DisplayName} ({$($currentInstance.Id)})"
        $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)subscriptions/$($currentInstance.Id)/providers/Microsoft.Subscription/cancel?api-version=$($Script:SubscriptionCancelApiVersion)&ImmediateDelete=true"
        $response = Invoke-AzRestMethod -Uri $uri -Method POST
        Write-Verbose -Message "Response:`r`n$($response.Content)"

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "cancelling subscription {$DisplayName}"
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
        $DisplayName,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $InvoiceSectionId,

        [Parameter()]
        [System.String]
        $BillingAccountId,

        [Parameter()]
        [System.String]
        $EnrollmentAccountId,

        [Parameter()]
        [System.String]
        $Status,

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
        $Script:ExportMode = $true
        $Script:exportedInstances = @()
        $dscContent = [System.Text.StringBuilder]::new()

        $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingaccounts/?api-version=$($Script:BillingAccountApiVersion)"
        [array] $billingAccounts = Invoke-M365DSCAzureRestList -Uri $uri

        if ($billingAccounts.Count -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
            return ''
        }

        # Billing subscriptions are enumerated at the billing account scope rather than by walking billing
        # profiles. Enterprise Agreement accounts expose enrollment accounts instead of billing profiles, so the
        # nested billing profile walk returned nothing at all for them.
        foreach ($billingAccount in $billingAccounts)
        {
            $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($billingAccount.name)/billingSubscriptions?api-version=$($Script:BillingApiVersion)"
            [array] $subscriptions = Invoke-M365DSCAzureRestList -Uri $uri

            # The billing account is not returned as a property of the subscription, so it is carried alongside
            # each instance for the export to emit.
            foreach ($subscription in $subscriptions)
            {
                $subscription | Add-Member -MemberType NoteProperty `
                    -Name 'billingAccountName' `
                    -Value $billingAccount.name `
                    -Force
            }

            $Script:exportedInstances += $subscriptions
        }

        if ($Script:exportedInstances.Count -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
            return ''
        }

        Write-M365DSCHost -Message "`r`n" -DeferWrite

        $i = 1
        foreach ($config in $Script:exportedInstances)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }
            $displayedKey = $config.properties.displayName
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -DeferWrite
            $params = @{
                DisplayName           = $config.properties.displayName
                Id                    = $config.name
                InvoiceSectionId      = $config.properties.invoiceSectionId
                BillingAccountId      = $config.billingAccountName
                EnrollmentAccountId   = $config.properties.enrollmentAccountId
                Status                = $config.properties.status
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
    Retrieves billing subscriptions from the Azure billing plane.

.DESCRIPTION
    Returns the billing subscriptions visible to the current context. When an invoice section is supplied the
    subscriptions are listed at that scope, otherwise every visible billing account is enumerated so that
    Enterprise Agreement subscriptions, which have no invoice section, are still returned.

.PARAMETER InvoiceSectionId
    Specifies the fully qualified invoice section identifier to scope the lookup to. Only billing accounts with
    agreement type Microsoft Customer Agreement have invoice sections.

.PARAMETER BillingAccountId
    Specifies the name of a single billing account to scope the lookup to.

.OUTPUTS
    System.Object[]
#>
function Get-M365DSCAzureBillingSubscription
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param
    (
        [Parameter()]
        [System.String]
        $InvoiceSectionId,

        [Parameter()]
        [System.String]
        $BillingAccountId
    )

    $managementUrl = (Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl

    if (-not [System.String]::IsNullOrEmpty($InvoiceSectionId))
    {
        $uri = "$managementUrl$($InvoiceSectionId.Trim('/'))/billingSubscriptions?api-version=$($Script:BillingApiVersion)"
        return (Invoke-M365DSCAzureRestList -Uri $uri)
    }

    if (-not [System.String]::IsNullOrEmpty($BillingAccountId))
    {
        [array] $billingAccounts = @([PSCustomObject]@{ name = $BillingAccountId })
    }
    else
    {
        $uri = "$managementUrl" + "providers/Microsoft.Billing/billingaccounts/?api-version=$($Script:BillingAccountApiVersion)"
        [array] $billingAccounts = Invoke-M365DSCAzureRestList -Uri $uri
    }

    $results = @()
    foreach ($billingAccount in $billingAccounts)
    {
        $uri = "$managementUrl" + "providers/Microsoft.Billing/billingAccounts/$($billingAccount.name)/billingSubscriptions?api-version=$($Script:BillingApiVersion)"
        $results += Invoke-M365DSCAzureRestList -Uri $uri
    }

    return $results
}

<#
.SYNOPSIS
    Builds the billing scope used to create a new subscription.

.DESCRIPTION
    Returns the billing scope that the Microsoft.Subscription alias endpoint requires. Microsoft Customer
    Agreement accounts are scoped by invoice section, Enterprise Agreement enrollments have no invoice sections
    at all and are scoped by enrollment account instead.

.PARAMETER InvoiceSectionId
    Specifies the fully qualified invoice section identifier.

.PARAMETER BillingAccountId
    Specifies the name of the billing account holding the enrollment account.

.PARAMETER EnrollmentAccountId
    Specifies the enrollment account, either as a bare identifier or as a fully qualified path.

.OUTPUTS
    System.String
#>
function Get-M365DSCAzureBillingScope
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.String]
        $InvoiceSectionId,

        [Parameter()]
        [System.String]
        $BillingAccountId,

        [Parameter()]
        [System.String]
        $EnrollmentAccountId
    )

    if (-not [System.String]::IsNullOrEmpty($InvoiceSectionId))
    {
        return "/$($InvoiceSectionId.Trim('/'))"
    }

    if ([System.String]::IsNullOrEmpty($EnrollmentAccountId))
    {
        return $null
    }

    if ($EnrollmentAccountId -like '*/enrollmentAccounts/*')
    {
        return "/$($EnrollmentAccountId.Trim('/'))"
    }

    if ([System.String]::IsNullOrEmpty($BillingAccountId))
    {
        return $null
    }

    return "/providers/Microsoft.Billing/billingAccounts/$BillingAccountId/enrollmentAccounts/$EnrollmentAccountId"
}

<#
.SYNOPSIS
    Waits for an Azure subscription alias to finish provisioning.

.DESCRIPTION
    Polls a subscription alias until its provisioning state settles. Creating a subscription through the alias
    endpoint is asynchronous and initially reports a state of Accepted.

.PARAMETER Uri
    Specifies the fully qualified alias uri, including the api-version query string.

.PARAMETER TimeoutInSeconds
    Specifies how long to wait for the alias to settle before giving up.

.OUTPUTS
    System.String
#>
function Wait-M365DSCAzureSubscriptionAlias
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Uri,

        [Parameter()]
        [System.UInt32]
        $TimeoutInSeconds = 600
    )

    $terminalStates = @('Succeeded', 'Failed', 'Canceled')
    $elapsedSeconds = 0
    $intervalInSeconds = 10
    $provisioningState = $null

    while ($elapsedSeconds -lt $TimeoutInSeconds)
    {
        $response = Invoke-AzRestMethod -Uri $Uri -Method Get

        if ([System.String]::IsNullOrEmpty($response.Content))
        {
            break
        }

        $alias = ConvertFrom-Json $response.Content
        $provisioningState = $alias.properties.provisioningState

        if ($provisioningState -in $terminalStates)
        {
            break
        }

        Write-Verbose -Message "Subscription alias is in state {$provisioningState}; waiting $intervalInSeconds seconds."
        Start-Sleep -Seconds $intervalInSeconds
        $elapsedSeconds += $intervalInSeconds
    }

    if ($provisioningState -eq 'Succeeded')
    {
        Write-Verbose -Message "Subscription alias provisioned successfully with subscription id {$($alias.properties.subscriptionId)}."
    }
    elseif ($provisioningState -in @('Failed', 'Canceled'))
    {
        throw "The subscription alias finished in state {$provisioningState}. Response: $($response.Content)"
    }
    else
    {
        Write-Verbose -Message "The subscription alias did not settle within $TimeoutInSeconds seconds; last known state was {$provisioningState}."
    }

    return $provisioningState
}

Export-ModuleMember -Function *-TargetResource
