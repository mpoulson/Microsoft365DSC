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

        $nullResult = @{
            Id                                              = $Id
            PermissionGrantPolicyId                         = $PermissionGrantPolicyId
            PermissionType                                  = $null
            ResourceApplication                             = $null
            Permissions                                     = $null
            PermissionClassification                        = $null
            ClientApplicationIds                            = $null
            ClientApplicationTenantIds                      = $null
            ClientApplicationPublisherIds                   = $null
            ClientApplicationsFromVerifiedPublisherOnly     = $null
            Ensure                                          = 'Absent'
            Credential                                      = $Credential
            ApplicationId                                   = $ApplicationId
            TenantId                                        = $TenantId
            ApplicationSecret                               = $ApplicationSecret
            CertificateThumbprint                           = $CertificateThumbprint
            ManagedIdentity                                 = $ManagedIdentity.IsPresent
            AccessTokens                                    = $AccessTokens
        }

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

        $uri = "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/$PermissionGrantPolicyId/includes/$Id"
        
        $getValue = $null
        try
        {
            $getValue = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction SilentlyContinue
        }
        catch
        {
            if ($_.Exception.Message -notlike '*ResourceNotFound*' -and $_.Exception.Message -notlike '*Request_ResourceNotFound*')
            {
                throw $_
            }
        }

        if ($null -eq $getValue)
        {
            Write-Verbose -Message "Include condition {$Id} not found for policy {$PermissionGrantPolicyId}"
            return $nullResult
        }

        Write-Verbose -Message "Found Include condition {$Id} for policy {$PermissionGrantPolicyId}"

        $result = @{
            Id                                              = $getValue.id
            PermissionGrantPolicyId                         = $PermissionGrantPolicyId
            PermissionType                                  = $getValue.permissionType
            ResourceApplication                             = $getValue.resourceApplication
            Permissions                                     = [string[]]$getValue.permissions
            PermissionClassification                        = $getValue.permissionClassification
            ClientApplicationIds                            = [string[]]$getValue.clientApplicationIds
            ClientApplicationTenantIds                      = [string[]]$getValue.clientApplicationTenantIds
            ClientApplicationPublisherIds                   = [string[]]$getValue.clientApplicationPublisherIds
            ClientApplicationsFromVerifiedPublisherOnly     = $getValue.clientApplicationsFromVerifiedPublisherOnly
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
            
            $uri = "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/$PermissionGrantPolicyId/includes"
            
            $body = @{
                id = $Id
            }

            if ($PSBoundParameters.ContainsKey('PermissionType'))
            {
                $body.permissionType = $PermissionType
            }
            
            if ($PSBoundParameters.ContainsKey('ResourceApplication'))
            {
                $body.resourceApplication = $ResourceApplication
            }
            
            if ($PSBoundParameters.ContainsKey('Permissions'))
            {
                $body.permissions = $Permissions
            }
            
            if ($PSBoundParameters.ContainsKey('PermissionClassification'))
            {
                $body.permissionClassification = $PermissionClassification
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationIds'))
            {
                $body.clientApplicationIds = $ClientApplicationIds
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationTenantIds'))
            {
                $body.clientApplicationTenantIds = $ClientApplicationTenantIds
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationPublisherIds'))
            {
                $body.clientApplicationPublisherIds = $ClientApplicationPublisherIds
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationsFromVerifiedPublisherOnly'))
            {
                $body.clientApplicationsFromVerifiedPublisherOnly = $ClientApplicationsFromVerifiedPublisherOnly
            }

            $bodyJson = $body | ConvertTo-Json -Depth 10
            Invoke-MgGraphRequest -Method POST -Uri $uri -Body $bodyJson -ContentType 'application/json' | Out-Null
        }
        elseif ($Ensure -eq 'Present' -and $currentCondition.Ensure -eq 'Present')
        {
            Write-Verbose -Message "Include conditions cannot be updated. Recreating Include condition {$Id} for policy {$PermissionGrantPolicyId}"
            
            # Delete existing condition
            $deleteUri = "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/$PermissionGrantPolicyId/includes/$Id"
            Invoke-MgGraphRequest -Method DELETE -Uri $deleteUri | Out-Null

            # Create new condition
            $createUri = "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/$PermissionGrantPolicyId/includes"
            
            $body = @{
                id = $Id
            }

            if ($PSBoundParameters.ContainsKey('PermissionType'))
            {
                $body.permissionType = $PermissionType
            }
            
            if ($PSBoundParameters.ContainsKey('ResourceApplication'))
            {
                $body.resourceApplication = $ResourceApplication
            }
            
            if ($PSBoundParameters.ContainsKey('Permissions'))
            {
                $body.permissions = $Permissions
            }
            
            if ($PSBoundParameters.ContainsKey('PermissionClassification'))
            {
                $body.permissionClassification = $PermissionClassification
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationIds'))
            {
                $body.clientApplicationIds = $ClientApplicationIds
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationTenantIds'))
            {
                $body.clientApplicationTenantIds = $ClientApplicationTenantIds
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationPublisherIds'))
            {
                $body.clientApplicationPublisherIds = $ClientApplicationPublisherIds
            }
            
            if ($PSBoundParameters.ContainsKey('ClientApplicationsFromVerifiedPublisherOnly'))
            {
                $body.clientApplicationsFromVerifiedPublisherOnly = $ClientApplicationsFromVerifiedPublisherOnly
            }

            $bodyJson = $body | ConvertTo-Json -Depth 10
            Invoke-MgGraphRequest -Method POST -Uri $createUri -Body $bodyJson -ContentType 'application/json' | Out-Null
        }
        elseif ($Ensure -eq 'Absent' -and $currentCondition.Ensure -eq 'Present')
        {
            Write-Verbose -Message "Removing Include condition {$Id} for policy {$PermissionGrantPolicyId}"
            
            $uri = "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/$PermissionGrantPolicyId/includes/$Id"
            Invoke-MgGraphRequest -Method DELETE -Uri $uri | Out-Null
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
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -NoNewLine
        }

        foreach ($policy in $policies)
        {
            $uri = "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/$($policy.Id)/includes"
            
            try
            {
                $includes = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
                
                if ($null -ne $includes.value -and $includes.value.Count -gt 0)
                {
                    foreach ($include in $includes.value)
                    {
                        if ($null -ne $Global:M365DSCExportResourceInstancesCount)
                        {
                            $Global:M365DSCExportResourceInstancesCount++
                        }

                        Write-M365DSCHost -Message "    |---[$i/$($includes.value.Count)] $($include.id) (Policy: $($policy.Id))" -NoNewLine

                        $Params = @{
                            Id                        = $include.id
                            PermissionGrantPolicyId   = $policy.Id
                            Credential                = $Credential
                            ApplicationId             = $ApplicationId
                            TenantId                  = $TenantId
                            ApplicationSecret         = $ApplicationSecret
                            CertificateThumbprint     = $CertificateThumbprint
                            ManagedIdentity           = $ManagedIdentity.IsPresent
                            AccessTokens              = $AccessTokens
                        }

                        $Results = Get-TargetResource @Params

                        if ($Results.Ensure -eq 'Present')
                        {
                            $Results = Update-M365DSCExportAuthenticationResults -ConnectionMode $ConnectionMode `
                                -Results $Results

                            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                                -ConnectionMode $ConnectionMode `
                                -ModulePath $PSScriptRoot `
                                -Results $Results `
                                -Credential $Credential

                            $dscContent += $currentDSCBlock
                            Save-M365DSCPartialExport -Content $currentDSCBlock `
                                -FileName $Global:PartialExportFileName

                            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark
                            $i++
                        }
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
