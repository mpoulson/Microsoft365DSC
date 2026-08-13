Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureDataCollectionRule'

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
        $ResourceGroupName,

        [Parameter()]
        [System.String]
        $Location,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $Kind,

        [Parameter()]
        [System.String]
        $DataCollectionEndpointId,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $WindowsEventLogs,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $WindowsFirewallLogs,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $LogAnalyticsDestinations,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $DataFlows,

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

    Write-Verbose -Message "Getting configuration of Azure Data Collection Rule {$Name} in resource group {$ResourceGroupName}"

    try
    {
        if (-not $Script:exportedInstance -or $Script:exportedInstance.Name -ne $Name)
        {
            $null = New-M365DSCConnection -Workload 'Azure' `
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

            $instance = Get-AzDataCollectionRule -Name $Name `
                -ResourceGroupName $ResourceGroupName `
                -ErrorAction SilentlyContinue
        }
        else
        {
            $instance = $Script:exportedInstance
        }

        if ($null -eq $instance)
        {
            return $nullResult
        }

        $windowsEventLogsValue = @()
        foreach ($eventLog in $instance.DataSourceWindowsEventLog)
        {
            $windowsEventLogsValue += @{
                Name         = $eventLog.Name
                Streams      = [Array]$eventLog.Stream
                XPathQueries = [Array]$eventLog.XPathQuery
            }
        }

        $windowsFirewallLogsValue = @()
        foreach ($firewallLog in $instance.DataSourceWindowsFirewallLog)
        {
            $windowsFirewallLogsValue += @{
                Name    = $firewallLog.Name
                Streams = [Array]$firewallLog.Stream
            }
        }

        $logAnalyticsDestinationsValue = @()
        foreach ($destination in $instance.DestinationLogAnalytic)
        {
            $logAnalyticsDestinationsValue += @{
                Name                = $destination.Name
                WorkspaceResourceId = $destination.WorkspaceResourceId
            }
        }

        $dataFlowsValue = @()
        foreach ($dataFlow in $instance.DataFlow)
        {
            $dataFlowEntry = @{
                Streams      = [Array]$dataFlow.Stream
                Destinations = [Array]$dataFlow.Destination
            }
            if (-not [System.String]::IsNullOrEmpty($dataFlow.OutputStream))
            {
                $dataFlowEntry.Add('OutputStream', $dataFlow.OutputStream)
            }
            if (-not [System.String]::IsNullOrEmpty($dataFlow.TransformKql))
            {
                $dataFlowEntry.Add('TransformKql', $dataFlow.TransformKql)
            }
            if (-not [System.String]::IsNullOrEmpty($dataFlow.BuiltInTransform))
            {
                $dataFlowEntry.Add('BuiltInTransform', $dataFlow.BuiltInTransform)
            }
            $dataFlowsValue += $dataFlowEntry
        }

        $results = @{
            Name                     = $instance.Name
            ResourceGroupName        = $ResourceGroupName
            Location                 = $instance.Location
            Description              = $instance.Description
            Kind                     = $instance.Kind
            DataCollectionEndpointId = $instance.DataCollectionEndpointId
            WindowsEventLogs         = $windowsEventLogsValue
            WindowsFirewallLogs      = $windowsFirewallLogsValue
            LogAnalyticsDestinations = $logAnalyticsDestinationsValue
            DataFlows                = $dataFlowsValue
            Ensure                   = 'Present'
            SubscriptionId           = $SubscriptionId
            Credential               = $Credential
            ApplicationId            = $ApplicationId
            TenantId                 = $TenantId
            CertificateThumbprint    = $CertificateThumbprint
            CertificatePath          = $CertificatePath
            CertificatePassword      = $CertificatePassword
            ManagedIdentity          = $ManagedIdentity.IsPresent
            AccessTokens             = $AccessTokens
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
        $ResourceGroupName,

        [Parameter()]
        [System.String]
        $Location,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $Kind,

        [Parameter()]
        [System.String]
        $DataCollectionEndpointId,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $WindowsEventLogs,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $WindowsFirewallLogs,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $LogAnalyticsDestinations,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $DataFlows,

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

    Write-Verbose -Message "Setting configuration of Azure Data Collection Rule {$Name} in resource group {$ResourceGroupName}"

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

    $currentInstance = Get-TargetResource @PSBoundParameters

    $windowsEventLogObjects = @()
    foreach ($eventLog in $WindowsEventLogs)
    {
        $windowsEventLogObjects += New-AzWindowsEventLogDataSourceObject `
            -Name $eventLog.Name `
            -Stream ([Array]$eventLog.Streams) `
            -XPathQuery ([Array]$eventLog.XPathQueries)
    }

    $windowsFirewallLogObjects = @()
    foreach ($firewallLog in $WindowsFirewallLogs)
    {
        $windowsFirewallLogObjects += New-AzWindowsFirewallLogsDataSourceObject `
            -Name $firewallLog.Name `
            -Stream ([Array]$firewallLog.Streams)
    }

    $logAnalyticsDestinationObjects = @()
    foreach ($destination in $LogAnalyticsDestinations)
    {
        $logAnalyticsDestinationObjects += New-AzLogAnalyticsDestinationObject `
            -Name $destination.Name `
            -WorkspaceResourceId $destination.WorkspaceResourceId
    }

    $dataFlowObjects = @()
    foreach ($dataFlow in $DataFlows)
    {
        $dataFlowParams = @{
            Stream      = [Array]$dataFlow.Streams
            Destination = [Array]$dataFlow.Destinations
        }
        if (-not [System.String]::IsNullOrEmpty($dataFlow.OutputStream))
        {
            $dataFlowParams.Add('OutputStream', $dataFlow.OutputStream)
        }
        if (-not [System.String]::IsNullOrEmpty($dataFlow.TransformKql))
        {
            $dataFlowParams.Add('TransformKql', $dataFlow.TransformKql)
        }
        if (-not [System.String]::IsNullOrEmpty($dataFlow.BuiltInTransform))
        {
            $dataFlowParams.Add('BuiltInTransform', $dataFlow.BuiltInTransform)
        }
        $dataFlowObjects += New-AzDataFlowObject @dataFlowParams
    }

    $instanceParams = @{
        Name              = $Name
        ResourceGroupName = $ResourceGroupName
    }
    if ($windowsEventLogObjects.Count -gt 0)
    {
        $instanceParams.Add('DataSourceWindowsEventLog', $windowsEventLogObjects)
    }
    if ($windowsFirewallLogObjects.Count -gt 0)
    {
        $instanceParams.Add('DataSourceWindowsFirewallLog', $windowsFirewallLogObjects)
    }
    if ($logAnalyticsDestinationObjects.Count -gt 0)
    {
        $instanceParams.Add('DestinationLogAnalytic', $logAnalyticsDestinationObjects)
    }
    if ($dataFlowObjects.Count -gt 0)
    {
        $instanceParams.Add('DataFlow', $dataFlowObjects)
    }
    if (-not [System.String]::IsNullOrEmpty($Description))
    {
        $instanceParams.Add('Description', $Description)
    }
    if (-not [System.String]::IsNullOrEmpty($Kind))
    {
        $instanceParams.Add('Kind', $Kind)
    }
    if (-not [System.String]::IsNullOrEmpty($DataCollectionEndpointId))
    {
        $instanceParams.Add('DataCollectionEndpointId', $DataCollectionEndpointId)
    }

    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Creating new Azure Data Collection Rule {$Name}"
        if (-not [System.String]::IsNullOrEmpty($Location))
        {
            $instanceParams.Add('Location', $Location)
        }
        $null = New-AzDataCollectionRule @instanceParams
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating Azure Data Collection Rule {$Name}"
        $null = Update-AzDataCollectionRule @instanceParams
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing Azure Data Collection Rule {$Name}"
        $null = Remove-AzDataCollectionRule -Name $Name `
            -ResourceGroupName $ResourceGroupName
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
        $ResourceGroupName,

        [Parameter()]
        [System.String]
        $Location,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $Kind,

        [Parameter()]
        [System.String]
        $DataCollectionEndpointId,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $WindowsEventLogs,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $WindowsFirewallLogs,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $LogAnalyticsDestinations,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $DataFlows,

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
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
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

    $ConnectionMode = New-M365DSCConnection -Workload 'Azure' `
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
        [array] $Script:exportedInstances = Get-AzDataCollectionRule -ErrorAction Stop

        $dscContent = [System.Text.StringBuilder]::new()
        $i = 1
        if ($Script:exportedInstances.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }
        foreach ($config in $Script:exportedInstances)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $resourceGroupName = $config.Id.Split('/')[4]
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $($config.Name)" -DeferWrite
            $params = @{
                Name                  = $config.Name
                ResourceGroupName     = $resourceGroupName
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

            $Script:exportedInstance = $config
            $Results = Get-TargetResource @params

            if ($Results.WindowsEventLogs.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject $Results.WindowsEventLogs -CIMInstanceName AzureDataCollectionRuleWindowsEventLog
                if ($complexTypeStringResult)
                {
                    $Results.WindowsEventLogs = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('WindowsEventLogs') | Out-Null
                }
            }
            else
            {
                $Results.Remove('WindowsEventLogs') | Out-Null
            }

            if ($Results.WindowsFirewallLogs.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject $Results.WindowsFirewallLogs -CIMInstanceName AzureDataCollectionRuleWindowsFirewallLog
                if ($complexTypeStringResult)
                {
                    $Results.WindowsFirewallLogs = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('WindowsFirewallLogs') | Out-Null
                }
            }
            else
            {
                $Results.Remove('WindowsFirewallLogs') | Out-Null
            }

            if ($Results.LogAnalyticsDestinations.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject $Results.LogAnalyticsDestinations -CIMInstanceName AzureDataCollectionRuleLogAnalyticsDestination
                if ($complexTypeStringResult)
                {
                    $Results.LogAnalyticsDestinations = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('LogAnalyticsDestinations') | Out-Null
                }
            }
            else
            {
                $Results.Remove('LogAnalyticsDestinations') | Out-Null
            }

            if ($Results.DataFlows.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject $Results.DataFlows -CIMInstanceName AzureDataCollectionRuleDataFlow
                if ($complexTypeStringResult)
                {
                    $Results.DataFlows = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('DataFlows') | Out-Null
                }
            }
            else
            {
                $Results.Remove('DataFlows') | Out-Null
            }

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential `
                -NoEscape @('WindowsEventLogs', 'WindowsFirewallLogs', 'LogAnalyticsDestinations', 'DataFlows')
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
