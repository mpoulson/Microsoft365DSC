Confirm-M365DSCModuleDependency -ModuleName 'MSFT_DefenderXdrIncident'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $IncidentId,

        [Parameter()]
        [System.String]
        $IncidentName,

        [Parameter()]
        [ValidateSet('Informational', 'Low', 'Medium', 'High')]
        [System.String]
        $Severity,

        [Parameter()]
        [ValidateSet('Active', 'Resolved', 'Redirected')]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $AssignedTo,

        [Parameter()]
        [ValidateSet('Unknown', 'FalsePositive', 'TruePositive', 'InformationalExpectedActivity')]
        [System.String]
        $Classification,

        [Parameter()]
        [System.String]
        $CreatedTime,

        [Parameter()]
        [System.String]
        $LastUpdateTime,

        [Parameter()]
        [ValidateSet('Present')]
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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    Write-Verbose -Message "Getting configuration for Defender XDR Incident with IncidentId $IncidentId"

    try
    {
        if (-not $Script:exportedInstance -or $Script:exportedInstance.incidentId -ne $IncidentId)
        {
            $null = New-M365DSCConnection -Workload 'DefenderForEndpoint' `
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

            $xdrBaseUrl = Get-M365DSCDefenderXdrBaseUrl
            $instances = (Invoke-M365DSCDefenderREST -Uri "$xdrBaseUrl/api/incidents" `
                    -Method GET).value

            $instance = $instances | Where-Object -FilterScript { [System.String]$_.incidentId -eq $IncidentId }
        }
        else
        {
            $instance = $Script:exportedInstance
        }

        if ($null -eq $instance)
        {
            return $nullResult
        }

        $classificationValue = $null
        if (-not [System.String]::IsNullOrEmpty($instance.classification))
        {
            $classificationValue = $instance.classification
        }

        $results = @{
            IncidentId            = [System.String]$instance.incidentId
            IncidentName          = $instance.incidentName
            Severity              = $instance.severity
            Status                = $instance.status
            AssignedTo            = $instance.assignedTo
            Classification        = $classificationValue
            CreatedTime           = $instance.createdTime
            LastUpdateTime        = $instance.lastUpdateTime
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
        $IncidentId,

        [Parameter()]
        [System.String]
        $IncidentName,

        [Parameter()]
        [ValidateSet('Informational', 'Low', 'Medium', 'High')]
        [System.String]
        $Severity,

        [Parameter()]
        [ValidateSet('Active', 'Resolved', 'Redirected')]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $AssignedTo,

        [Parameter()]
        [ValidateSet('Unknown', 'FalsePositive', 'TruePositive', 'InformationalExpectedActivity')]
        [System.String]
        $Classification,

        [Parameter()]
        [System.String]
        $CreatedTime,

        [Parameter()]
        [System.String]
        $LastUpdateTime,

        [Parameter()]
        [ValidateSet('Present')]
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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    # This resource is read-only. Incidents are managed by Microsoft Defender XDR and cannot be created or deleted through DSC.
    throw "DefenderXdrIncident is a read-only resource. Incidents are managed by Microsoft Defender XDR and cannot be modified through DSC."
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $IncidentId,

        [Parameter()]
        [System.String]
        $IncidentName,

        [Parameter()]
        [ValidateSet('Informational', 'Low', 'Medium', 'High')]
        [System.String]
        $Severity,

        [Parameter()]
        [ValidateSet('Active', 'Resolved', 'Redirected')]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $AssignedTo,

        [Parameter()]
        [ValidateSet('Unknown', 'FalsePositive', 'TruePositive', 'InformationalExpectedActivity')]
        [System.String]
        $Classification,

        [Parameter()]
        [System.String]
        $CreatedTime,

        [Parameter()]
        [System.String]
        $LastUpdateTime,

        [Parameter()]
        [ValidateSet('Present')]
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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    $ConnectionMode = New-M365DSCConnection -Workload 'DefenderForEndpoint' `
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
        $xdrBaseUrl = Get-M365DSCDefenderXdrBaseUrl
        [array] $Script:exportedInstances = (Invoke-M365DSCDefenderREST -Uri "$xdrBaseUrl/api/incidents" `
                -Method GET).value

        $i = 1
        $dscContent = ''
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

            $displayedKey = $config.incidentId
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -DeferWrite
            $params = @{
                IncidentId            = [System.String]$config.incidentId
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $Script:exportedInstance = $config
            $Results = Get-TargetResource @Params

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential

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
        New-M365DSCLogEntry -Message 'Error during Export:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        throw
    }
}

Export-ModuleMember -Function *-TargetResource
