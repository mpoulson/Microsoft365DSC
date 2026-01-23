Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AADPermissionGrantPolicyInclude'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Id,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PermissionGrantPolicyId,

        [Parameter()]
        [ValidateSet('delegated', 'application')]
        [System.String]
        $PermissionType,

        [Parameter()]
        [System.String]
        $ResourceApplication,

        [Parameter()]
        [System.String[]]
        $Permissions,

        [Parameter()]
        [ValidateSet('low', 'medium', 'high', 'all')]
        [System.String]
        $PermissionClassification,

        [Parameter()]
        [System.String[]]
        $ClientApplicationIds,

        [Parameter()]
        [System.String[]]
        $ClientApplicationTenantIds,

        [Parameter()]
        [System.String[]]
        $ClientApplicationPublisherIds,

        [Parameter()]
        [System.Boolean]
        $ClientApplicationsFromVerifiedPublisherOnly,

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

    try
    {
        $null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
            -InboundParameters $PSBoundParameters

        #region Telemetry
        $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
        $CommandName = $MyInvocation.MyCommand
        $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
            -CommandName $CommandName `
            -Parameters $PSBoundParameters
        Add-M365DSCTelemetryEvent -Data $data
        #endregion

        $condition = Get-MgPolicyPermissionGrantPolicyInclude `
            -PermissionGrantPolicyId $PermissionGrantPolicyId `
            -PermissionGrantConditionSetId $Id -ErrorAction Stop

        $result = @{
            Id                                        = $condition.Id
            PermissionGrantPolicyId                   = $PermissionGrantPolicyId
            PermissionType                            = $condition.PermissionType
            ResourceApplication                       = $condition.ResourceApplication
            Permissions                               = $condition.Permissions
            PermissionClassification                  = $condition.PermissionClassification
            ClientApplicationIds                      = $condition.ClientApplicationIds
            ClientApplicationTenantIds                = $condition.ClientApplicationTenantIds
            ClientApplicationPublisherIds             = $condition.ClientApplicationPublisherIds
            ClientApplicationsFromVerifiedPublisherOnly = $condition.ClientApplicationsFromVerifiedPublisherOnly
            Ensure                                    = 'Present'
            Credential                                = $Credential
            ApplicationId                             = $ApplicationId
            TenantId                                  = $TenantId
            ApplicationSecret                         = $ApplicationSecret
            CertificateThumbprint                     = $CertificateThumbprint
            ManagedIdentity                           = $ManagedIdentity.IsPresent
            AccessTokens                              = $AccessTokens
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

        $nullResult = @{
            Id                                        = $Id
            PermissionGrantPolicyId                   = $PermissionGrantPolicyId
            PermissionType                            = $PermissionType
            ResourceApplication                       = $ResourceApplication
            Permissions                               = $Permissions
            PermissionClassification                  = $PermissionClassification
            ClientApplicationIds                      = $ClientApplicationIds
            ClientApplicationTenantIds                = $ClientApplicationTenantIds
            ClientApplicationPublisherIds             = $ClientApplicationPublisherIds
            ClientApplicationsFromVerifiedPublisherOnly = $ClientApplicationsFromVerifiedPublisherOnly
            Ensure                                    = 'Absent'
            Credential                                = $Credential
            ApplicationId                             = $ApplicationId
            TenantId                                  = $TenantId
            ApplicationSecret                         = $ApplicationSecret
            CertificateThumbprint                     = $CertificateThumbprint
            ManagedIdentity                           = $ManagedIdentity.IsPresent
            AccessTokens                              = $AccessTokens
        }

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

        [Parameter(Mandatory = $true)]
        [System.String]
        $PermissionGrantPolicyId,

        [Parameter()]
        [ValidateSet('delegated', 'application')]
        [System.String]
        $PermissionType,

        [Parameter()]
        [System.String]
        $ResourceApplication,

        [Parameter()]
        [System.String[]]
        $Permissions,

        [Parameter()]
        [ValidateSet('low', 'medium', 'high', 'all')]
        [System.String]
        $PermissionClassification,

        [Parameter()]
        [System.String[]]
        $ClientApplicationIds,

        [Parameter()]
        [System.String[]]
        $ClientApplicationTenantIds,

        [Parameter()]
        [System.String[]]
        $ClientApplicationPublisherIds,

        [Parameter()]
        [System.Boolean]
        $ClientApplicationsFromVerifiedPublisherOnly,

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

    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $currentValues = Get-TargetResource @PSBoundParameters
        $body = @{
            Id                                        = $Id
            PermissionType                            = $PermissionType
            ResourceApplication                       = $ResourceApplication
            Permissions                               = $Permissions
            PermissionClassification                  = $PermissionClassification
            ClientApplicationIds                      = $ClientApplicationIds
            ClientApplicationTenantIds                = $ClientApplicationTenantIds
            ClientApplicationPublisherIds             = $ClientApplicationPublisherIds
            ClientApplicationsFromVerifiedPublisherOnly = $ClientApplicationsFromVerifiedPublisherOnly
        }

        try
        {
            if ($Ensure -eq 'Present' -and $currentValues.Ensure -eq 'Absent')
            {
                $null = New-MgPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $PermissionGrantPolicyId `
                    -BodyParameter $body -ErrorAction Stop
            }
            elseif ($Ensure -eq 'Present' -and $currentValues.Ensure -eq 'Present')
            {
                $null = Remove-MgPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $PermissionGrantPolicyId `
                    -PermissionGrantConditionSetId $Id -ErrorAction Stop
                $null = New-MgPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $PermissionGrantPolicyId `
                    -BodyParameter $body -ErrorAction Stop
            }
            elseif ($Ensure -eq 'Absent' -and $currentValues.Ensure -eq 'Present')
            {
                $null = Remove-MgPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $PermissionGrantPolicyId `
                    -PermissionGrantConditionSetId $Id -ErrorAction Stop
            }
        }
        catch
        {
        New-M365DSCLogEntry -Message 'Error applying configuration:' `
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $PermissionGrantPolicyId,

        [Parameter()]
        [ValidateSet('delegated', 'application')]
        [System.String]
        $PermissionType,

        [Parameter()]
        [System.String]
        $ResourceApplication,

        [Parameter()]
        [System.String[]]
        $Permissions,

        [Parameter()]
        [ValidateSet('low', 'medium', 'high', 'all')]
        [System.String]
        $PermissionClassification,

        [Parameter()]
        [System.String[]]
        $ClientApplicationIds,

        [Parameter()]
        [System.String[]]
        $ClientApplicationTenantIds,

        [Parameter()]
        [System.String[]]
        $ClientApplicationPublisherIds,

        [Parameter()]
        [System.Boolean]
        $ClientApplicationsFromVerifiedPublisherOnly,

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

    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
        -InboundParameters $PSBoundParameters

    try
    {
        if ($null -ne $Global:M365DSCExportResourceInstancesCount)
        {
            $Global:M365DSCExportResourceInstancesCount++
        }

        $content = ''
        $policies = Get-MgPolicyPermissionGrantPolicy -All -ErrorAction Stop
        foreach ($policy in $policies)
        {
            $includes = Get-MgPolicyPermissionGrantPolicyInclude -PermissionGrantPolicyId $policy.Id -All -ErrorAction Stop
            $index = 1
            foreach ($include in $includes)
            {
                Write-M365DSCHost -Message "`r`n" -DeferWrite
                Write-M365DSCHost -Message "    |---[$index/$($includes.Count)] $($include.Id)" -DeferWrite

                $results = @{
                    Id                                        = $include.Id
                    PermissionGrantPolicyId                   = $policy.Id
                    PermissionType                            = $include.PermissionType
                    ResourceApplication                       = $include.ResourceApplication
                    Permissions                               = $include.Permissions
                    PermissionClassification                  = $include.PermissionClassification
                    ClientApplicationIds                      = $include.ClientApplicationIds
                    ClientApplicationTenantIds                = $include.ClientApplicationTenantIds
                    ClientApplicationPublisherIds             = $include.ClientApplicationPublisherIds
                    ClientApplicationsFromVerifiedPublisherOnly = $include.ClientApplicationsFromVerifiedPublisherOnly
                    Ensure                                    = 'Present'
                    Credential                                = $Credential
                    ApplicationId                             = $ApplicationId
                    TenantId                                  = $TenantId
                    ApplicationSecret                         = $ApplicationSecret
                    CertificateThumbprint                     = $CertificateThumbprint
                    ManagedIdentity                           = $ManagedIdentity
                    AccessTokens                              = $AccessTokens
                }

                $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                    -ConnectionMode $ConnectionMode `
                    -ModulePath $PSScriptRoot `
                    -Results $results `
                    -Credential $Credential

                Save-M365DSCPartialExport -Content $currentDSCBlock `
                    -FileName $Global:PartialExportFileName

                Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
                $content += $currentDSCBlock
                $index++
            }
        }

        return $content
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
