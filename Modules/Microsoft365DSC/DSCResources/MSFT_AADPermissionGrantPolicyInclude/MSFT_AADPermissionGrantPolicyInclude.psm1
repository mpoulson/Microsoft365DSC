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
        [System.String]
        [ValidateSet('delegated', 'application')]
        $PermissionType,

        [Parameter()]
        [System.String]
        $ResourceApplication,

        [Parameter()]
        [System.String[]]
        $Permissions,

        [Parameter()]
        [System.String]
        [ValidateSet('low', 'medium', 'high', 'all')]
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

    Write-Verbose -Message "Getting configuration of Azure AD Permission Grant Policy Include condition {$Id} for policy {$PermissionGrantPolicyId}"

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

            # Check if parent policy exists
            $parentPolicy = $null
            try
            {
                $parentPolicy = Get-MgBetaPolicyPermissionGrantPolicy -PermissionGrantPolicyId $PermissionGrantPolicyId -ErrorAction SilentlyContinue
            }
            catch
            {
                Write-Verbose -Message "Parent policy {$PermissionGrantPolicyId} not found"
                return $nullResult
            }

            if ($null -eq $parentPolicy)
            {
                Write-Verbose -Message "Parent policy {$PermissionGrantPolicyId} not found"
                return $nullResult
            }

            $getValue = $null
            try
            {
                $getValue = Get-MgBetaPolicyPermissionGrantPolicyInclude `
                    -PermissionGrantPolicyId $PermissionGrantPolicyId `
                    -PermissionGrantConditionSetId $Id `
                    -ErrorAction SilentlyContinue
            }
            catch
            {
                if ($_.Exception.Message -notlike '*ResourceNotFound*' -and $_.Exception.Message -notlike '*Request_ResourceNotFound*')
                {
                    throw $_
                }
            }
        }
        else
        {
            $getValue = $Script:exportedInstance
        }

        if ($null -eq $getValue)
        {
            Write-Verbose -Message "Include condition {$Id} not found for policy {$PermissionGrantPolicyId}"
            return $nullResult
        }

        Write-Verbose -Message "Found Include condition {$Id} for policy {$PermissionGrantPolicyId}"

        $result = @{
            Id                                              = $getValue.Id
            PermissionGrantPolicyId                         = $PermissionGrantPolicyId
            PermissionType                                  = $getValue.PermissionType
            ResourceApplication                             = $getValue.ResourceApplication
            Permissions                                     = [string[]]$getValue.Permissions
            PermissionClassification                        = $getValue.PermissionClassification
            ClientApplicationIds                            = [string[]]$getValue.ClientApplicationIds
            ClientApplicationTenantIds                      = [string[]]$getValue.ClientApplicationTenantIds
            ClientApplicationPublisherIds                   = [string[]]$getValue.ClientApplicationPublisherIds
            ClientApplicationsFromVerifiedPublisherOnly     = $getValue.ClientApplicationsFromVerifiedPublisherOnly
            Ensure                                          = 'Present'
            Credential                                      = $Credential
            ApplicationId                                   = $ApplicationId
            TenantId                                        = $TenantId
            ApplicationSecret                               = $ApplicationSecret
            CertificateThumbprint                           = $CertificateThumbprint
            ManagedIdentity                                 = $ManagedIdentity.IsPresent
            AccessTokens                                    = $AccessTokens
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $PermissionGrantPolicyId,

        [Parameter()]
        [System.String]
        [ValidateSet('delegated', 'application')]
        $PermissionType,

        [Parameter()]
        [System.String]
        $ResourceApplication,

        [Parameter()]
        [System.String[]]
        $Permissions,

        [Parameter()]
        [System.String]
        [ValidateSet('low', 'medium', 'high', 'all')]
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

    Write-Verbose -Message "Setting configuration of Azure AD Permission Grant Policy Include condition {$Id} for policy {$PermissionGrantPolicyId}"

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

        $currentCondition = Get-TargetResource @PSBoundParameters

        if ($Ensure -eq 'Present' -and $currentCondition.Ensure -eq 'Absent')
        {
            Write-Verbose -Message "Creating new Include condition {$Id} for policy {$PermissionGrantPolicyId}"

            $createParameters = @{
                PermissionGrantPolicyId = $PermissionGrantPolicyId
                Id                      = $Id
            }

            if ($PSBoundParameters.ContainsKey('PermissionType'))
            {
                $createParameters.PermissionType = $PermissionType
            }

            if ($PSBoundParameters.ContainsKey('ResourceApplication'))
            {
                $createParameters.ResourceApplication = $ResourceApplication
            }

            if ($PSBoundParameters.ContainsKey('Permissions'))
            {
                $createParameters.Permissions = $Permissions
            }

            if ($PSBoundParameters.ContainsKey('PermissionClassification'))
            {
                $createParameters.PermissionClassification = $PermissionClassification
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationIds'))
            {
                $createParameters.ClientApplicationIds = $ClientApplicationIds
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationTenantIds'))
            {
                $createParameters.ClientApplicationTenantIds = $ClientApplicationTenantIds
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationPublisherIds'))
            {
                $createParameters.ClientApplicationPublisherIds = $ClientApplicationPublisherIds
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationsFromVerifiedPublisherOnly'))
            {
                $createParameters.ClientApplicationsFromVerifiedPublisherOnly = $ClientApplicationsFromVerifiedPublisherOnly
            }

            New-MgBetaPolicyPermissionGrantPolicyInclude @createParameters | Out-Null
        }
        elseif ($Ensure -eq 'Present' -and $currentCondition.Ensure -eq 'Present')
        {
            Write-Verbose -Message "Include conditions cannot be updated. Recreating Include condition {$Id} for policy {$PermissionGrantPolicyId}"

            # Delete existing condition
            Remove-MgBetaPolicyPermissionGrantPolicyInclude `
                -PermissionGrantPolicyId $PermissionGrantPolicyId `
                -PermissionGrantConditionSetId $Id | Out-Null

            # Create new condition
            $createParameters = @{
                PermissionGrantPolicyId = $PermissionGrantPolicyId
                Id                      = $Id
            }

            if ($PSBoundParameters.ContainsKey('PermissionType'))
            {
                $createParameters.PermissionType = $PermissionType
            }

            if ($PSBoundParameters.ContainsKey('ResourceApplication'))
            {
                $createParameters.ResourceApplication = $ResourceApplication
            }

            if ($PSBoundParameters.ContainsKey('Permissions'))
            {
                $createParameters.Permissions = $Permissions
            }

            if ($PSBoundParameters.ContainsKey('PermissionClassification'))
            {
                $createParameters.PermissionClassification = $PermissionClassification
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationIds'))
            {
                $createParameters.ClientApplicationIds = $ClientApplicationIds
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationTenantIds'))
            {
                $createParameters.ClientApplicationTenantIds = $ClientApplicationTenantIds
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationPublisherIds'))
            {
                $createParameters.ClientApplicationPublisherIds = $ClientApplicationPublisherIds
            }

            if ($PSBoundParameters.ContainsKey('ClientApplicationsFromVerifiedPublisherOnly'))
            {
                $createParameters.ClientApplicationsFromVerifiedPublisherOnly = $ClientApplicationsFromVerifiedPublisherOnly
            }

            New-MgBetaPolicyPermissionGrantPolicyInclude @createParameters | Out-Null
        }
        elseif ($Ensure -eq 'Absent' -and $currentCondition.Ensure -eq 'Present')
        {
            Write-Verbose -Message "Removing Include condition {$Id} for policy {$PermissionGrantPolicyId}"

            Remove-MgBetaPolicyPermissionGrantPolicyInclude `
                -PermissionGrantPolicyId $PermissionGrantPolicyId `
                -PermissionGrantConditionSetId $Id | Out-Null
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $PermissionGrantPolicyId,

        [Parameter()]
        [System.String]
        [ValidateSet('delegated', 'application')]
        $PermissionType,

        [Parameter()]
        [System.String]
        $ResourceApplication,

        [Parameter()]
        [System.String[]]
        $Permissions,

        [Parameter()]
        [System.String]
        [ValidateSet('low', 'medium', 'high', 'all')]
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

    Write-Verbose -Message "Testing configuration of Azure AD Permission Grant Policy Include condition {$Id} for policy {$PermissionGrantPolicyId}"

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
        [array] $policies = Get-MgBetaPolicyPermissionGrantPolicy -All:$true -ErrorAction Stop

        $dscContent = ''
        $i = 1

        if ($policies.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }

        foreach ($policy in $policies)
        {
            try
            {
                $includes = Get-MgBetaPolicyPermissionGrantPolicyInclude `
                    -PermissionGrantPolicyId $policy.Id `
                    -All `
                    -ErrorAction Stop

                if ($null -ne $includes -and $includes.Count -gt 0)
                {
                    foreach ($include in $includes)
                    {
                        if ($null -ne $Global:M365DSCExportResourceInstancesCount)
                        {
                            $Global:M365DSCExportResourceInstancesCount++
                        }

                        Write-M365DSCHost -Message "    |---[$i/$($includes.Count)] $($include.Id) (Policy: $($policy.Id))" -DeferWrite

                        $Params = @{
                            Id                        = $include.Id
                            PermissionGrantPolicyId   = $policy.Id
                            Credential                = $Credential
                            ApplicationId             = $ApplicationId
                            TenantId                  = $TenantId
                            ApplicationSecret         = $ApplicationSecret
                            CertificateThumbprint     = $CertificateThumbprint
                            ManagedIdentity           = $ManagedIdentity.IsPresent
                            AccessTokens              = $AccessTokens
                        }
                        $Script:exportedInstance = $include
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
                }
            }
            catch
            {
                Write-Verbose -Message "No includes found for policy $($policy.Id)"
            }
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

Export-ModuleMember -Function *-TargetResource
