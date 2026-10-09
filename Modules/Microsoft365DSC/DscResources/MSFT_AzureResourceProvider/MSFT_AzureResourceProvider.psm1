Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureResourceProvider'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ProviderNamespace,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SubscriptionId,

        [Parameter()]
        [System.String]
        $RegistrationState,

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

    Write-Verbose -Message "Getting configuration of Azure Resource Provider {$ProviderNamespace} in subscription {$SubscriptionId}"

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

        $null = Set-M365DSCAzureResourceProviderContext -SubscriptionId $SubscriptionId

        # Get-AzResourceProvider without -ListAvailable reports only the providers that are registered, so a
        # namespace that is absent from the answer is a namespace that is not registered for this subscription.
        $instance = Get-AzResourceProvider -ProviderNamespace $ProviderNamespace -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($null -eq $instance -or $instance.RegistrationState -ne 'Registered')
        {
            if ($null -ne $instance)
            {
                $nullResult.RegistrationState = $instance.RegistrationState
            }
            return $nullResult
        }

        $results = @{
            ProviderNamespace     = $instance.ProviderNamespace
            SubscriptionId        = $SubscriptionId
            RegistrationState     = $instance.RegistrationState
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
        $ProviderNamespace,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SubscriptionId,

        [Parameter()]
        [System.String]
        $RegistrationState,

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

    Write-Verbose -Message "Setting configuration of Azure Resource Provider {$ProviderNamespace} in subscription {$SubscriptionId}"

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

    $null = Set-M365DSCAzureResourceProviderContext -SubscriptionId $SubscriptionId

    # REGISTER
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Registering resource provider {$ProviderNamespace} in subscription {$SubscriptionId}"
        $null = Register-AzResourceProvider -ProviderNamespace $ProviderNamespace
    }
    # UNREGISTER
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Unregistering resource provider {$ProviderNamespace} from subscription {$SubscriptionId}"
        $null = Unregister-AzResourceProvider -ProviderNamespace $ProviderNamespace
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
        $ProviderNamespace,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SubscriptionId,

        [Parameter()]
        [System.String]
        $RegistrationState,

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
        # A resource provider is registered per subscription, so the set of instances to export is the cross product
        # of the subscriptions in scope and the providers registered in each of them.
        if (-not [System.String]::IsNullOrEmpty($SubscriptionId))
        {
            [array] $subscriptionIds = @($SubscriptionId)
        }
        else
        {
            [array] $subscriptionIds = Get-AzSubscription -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }
        }

        $instances = @()
        foreach ($currentSubscriptionId in $subscriptionIds)
        {
            $null = Set-M365DSCAzureResourceProviderContext -SubscriptionId $currentSubscriptionId

            $providers = Get-AzResourceProvider -ErrorAction SilentlyContinue |
                Where-Object -FilterScript { $_.RegistrationState -eq 'Registered' }

            foreach ($providerNamespace in ($providers.ProviderNamespace | Select-Object -Unique))
            {
                $instances += @{
                    ProviderNamespace = $providerNamespace
                    SubscriptionId    = $currentSubscriptionId
                }
            }
        }

        $i = 1
        $dscContent = [System.Text.StringBuilder]::new()
        if ($instances.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }
        foreach ($instance in $instances)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $displayedKey = "$($instance.SubscriptionId)/$($instance.ProviderNamespace)"
            Write-M365DSCHost -Message "    |---[$i/$($instances.Length)] $displayedKey" -DeferWrite

            $params = @{
                ProviderNamespace     = $instance.ProviderNamespace
                SubscriptionId        = $instance.SubscriptionId
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
    Points the Az context at the subscription whose resource providers are being managed.

.DESCRIPTION
    The resource provider cmdlets carry no subscription parameter and act on whichever subscription the Az context
    currently points at, so the context has to be moved before each call. The context is only changed when it is
    not already on the wanted subscription.

.PARAMETER SubscriptionId
    Specifies the subscription to operate against.

.OUTPUTS
    None
#>
function Set-M365DSCAzureResourceProviderContext
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $SubscriptionId
    )

    if ([System.String]::IsNullOrEmpty($SubscriptionId))
    {
        return
    }

    $context = Get-AzContext -ErrorAction SilentlyContinue

    if ($null -ne $context -and $context.Subscription.Id -eq $SubscriptionId)
    {
        return
    }

    Write-Verbose -Message "Pointing the Azure context at subscription {$SubscriptionId}"
    $null = Set-AzContext -Subscription $SubscriptionId
}

function Get-CompareParameters
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param()

    # RegistrationState is reported for visibility only. It passes through Registering and Unregistering while a
    # change settles, so comparing it would report drift on a subscription that is converging correctly.
    return @{
        ExcludedProperties = @('RegistrationState')
    }
}

Export-ModuleMember -Function @('*-TargetResource', 'Get-CompareParameters')
