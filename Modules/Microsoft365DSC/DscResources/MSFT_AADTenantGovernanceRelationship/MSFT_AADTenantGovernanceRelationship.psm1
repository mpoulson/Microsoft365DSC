Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AADTenantGovernanceRelationship'

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
        $GovernedTenantId,

        [Parameter()]
        [System.String]
        $GovernedTenantName,

        [Parameter()]
        [System.String]
        $GoverningTenantId,

        [Parameter()]
        [System.String]
        $GoverningTenantName,

        [Parameter()]
        [System.String]
        $CreationDateTime,

        [Parameter()]
        [ValidateSet('active', 'terminated', 'terminationRequestedByGoverningTenant', 'unknownFutureValue')]
        [System.String]
        $Status,

        [Parameter()]
        [ValidateSet('approvedByAdmin', 'addOnTenant', 'unknownFutureValue')]
        [System.String]
        $CreatedType,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $PolicySnapshot,

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

    Write-Verbose -Message "Getting the Microsoft Entra tenant governance relationship with identifier {$Id}."

    try
    {
        if (-not $Script:exportedInstance -or $Script:exportedInstance.id -ne $Id)
        {
            $null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
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

            $connectionProfile = Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph
            if ($null -eq $connectionProfile -or [System.String]::IsNullOrWhiteSpace($connectionProfile.ResourceUrl))
            {
                throw 'Could not determine the Microsoft Graph endpoint for AADTenantGovernanceRelationship.'
            }

            $graphBaseUri = $connectionProfile.ResourceUrl.TrimEnd('/')
            $encodedFilter = [System.Uri]::EscapeDataString("id eq '$Id'")
            $uri = "$graphBaseUri/beta/directory/tenantGovernance/governanceRelationships?`$filter=$encodedFilter"
            $response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $uri `
                -ErrorAction Stop
            $getValue = @($response.value)[0]
        }
        else
        {
            $getValue = $Script:exportedInstance
        }

        if ($null -eq $getValue)
        {
            Write-Verbose -Message "Could not find a Microsoft Entra tenant governance relationship with identifier {$Id}."
            return @{
                Id                    = $Id
                Ensure                = 'Absent'
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                ApplicationSecret     = $ApplicationSecret
                CertificateThumbprint = $CertificateThumbprint
                CertificatePath       = $CertificatePath
                CertificatePassword   = $CertificatePassword
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }
        }

        $policySnapshotValue = $null
        if ($null -ne $getValue.policySnapshot)
        {
            $policySnapshotValue = Get-M365DSCDRGComplexTypeToHashtable `
                -ComplexObject $getValue.policySnapshot
        }

        return @{
            Id                    = $getValue.id
            GovernedTenantId      = $getValue.governedTenantId
            GovernedTenantName    = $getValue.governedTenantName
            GoverningTenantId     = $getValue.governingTenantId
            GoverningTenantName   = $getValue.governingTenantName
            CreationDateTime      = $getValue.creationDateTime
            Status                = $getValue.status
            CreatedType           = $getValue.createdType
            PolicySnapshot        = $policySnapshotValue
            Ensure                = 'Present'
            Credential            = $Credential
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            ApplicationSecret     = $ApplicationSecret
            CertificateThumbprint = $CertificateThumbprint
            CertificatePath       = $CertificatePath
            CertificatePassword   = $CertificatePassword
            ManagedIdentity       = $ManagedIdentity.IsPresent
            AccessTokens          = $AccessTokens
        }
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error retrieving the Microsoft Entra tenant governance relationship:' `
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
        $Id,

        [Parameter()]
        [System.String]
        $GovernedTenantId,

        [Parameter()]
        [System.String]
        $GovernedTenantName,

        [Parameter()]
        [System.String]
        $GoverningTenantId,

        [Parameter()]
        [System.String]
        $GoverningTenantName,

        [Parameter()]
        [System.String]
        $CreationDateTime,

        [Parameter()]
        [ValidateSet('active', 'terminated', 'terminationRequestedByGoverningTenant', 'unknownFutureValue')]
        [System.String]
        $Status,

        [Parameter()]
        [ValidateSet('approvedByAdmin', 'addOnTenant', 'unknownFutureValue')]
        [System.String]
        $CreatedType,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $PolicySnapshot,

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

    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        throw 'AADTenantGovernanceRelationship cannot create a tenant governance relationship. Establish the relationship by using a governance request.'
    }
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        throw 'This resource cannot delete a tenant governance relationship. Please make sure you set its Ensure value to Present.'
    }
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present' -and
        -not [System.String]::IsNullOrWhiteSpace($Status) -and $Status -ne $currentInstance.Status)
    {
        if ($Status -notin @('terminated', 'terminationRequestedByGoverningTenant'))
        {
            throw "AADTenantGovernanceRelationship cannot change the status to '$Status'. Only termination status changes are supported."
        }

        $connectionProfile = Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph
        if ($null -eq $connectionProfile -or [System.String]::IsNullOrWhiteSpace($connectionProfile.ResourceUrl))
        {
            throw 'Could not determine the Microsoft Graph endpoint for AADTenantGovernanceRelationship.'
        }

        $graphBaseUri = $connectionProfile.ResourceUrl.TrimEnd('/')
        $uri = "$graphBaseUri/beta/directory/tenantGovernance/governanceRelationships/$Id"
        $body = @{
            status = $Status
        } | ConvertTo-Json

        Write-Verbose -Message "Updating the Microsoft Entra tenant governance relationship with identifier {$Id}."
        Invoke-MgGraphRequest `
            -Method PATCH `
            -Uri $uri `
            -Body $body `
            -ErrorAction Stop | Out-Null
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
        $GovernedTenantId,

        [Parameter()]
        [System.String]
        $GovernedTenantName,

        [Parameter()]
        [System.String]
        $GoverningTenantId,

        [Parameter()]
        [System.String]
        $GoverningTenantName,

        [Parameter()]
        [System.String]
        $CreationDateTime,

        [Parameter()]
        [ValidateSet('active', 'terminated', 'terminationRequestedByGoverningTenant', 'unknownFutureValue')]
        [System.String]
        $Status,

        [Parameter()]
        [ValidateSet('approvedByAdmin', 'addOnTenant', 'unknownFutureValue')]
        [System.String]
        $CreatedType,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $PolicySnapshot,

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
        [System.String]
        $Filter,

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

    $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
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
        $connectionProfile = Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph
        if ($null -eq $connectionProfile -or [System.String]::IsNullOrWhiteSpace($connectionProfile.ResourceUrl))
        {
            throw 'Could not determine the Microsoft Graph endpoint for AADTenantGovernanceRelationship.'
        }

        $graphBaseUri = $connectionProfile.ResourceUrl.TrimEnd('/')
        $uri = "$graphBaseUri/beta/directory/tenantGovernance/governanceRelationships"
        if (-not [System.String]::IsNullOrWhiteSpace($Filter))
        {
            $encodedFilter = [System.Uri]::EscapeDataString($Filter)
            $uri = "${uri}?`$filter=$encodedFilter"
        }

        $getValue = @()
        do
        {
            $response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $uri `
                -ErrorAction Stop
            if ($null -ne $response.value)
            {
                $getValue += @($response.value)
            }
            $uri = $response.'@odata.nextLink'
        } while (-not [System.String]::IsNullOrWhiteSpace($uri))

        $i = 1
        $dscContent = [System.Text.StringBuilder]::new()
        if ($getValue.Length -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
        }

        foreach ($config in $getValue)
        {
            if ($null -ne $Global:M365DSCExportResourceInstancesCount)
            {
                $Global:M365DSCExportResourceInstancesCount++
            }

            $displayedKey = $config.id
            if (-not [System.String]::IsNullOrWhiteSpace($config.governedTenantName))
            {
                $displayedKey = "$($config.governedTenantName) ($($config.governedTenantId))"
            }

            Write-M365DSCHost -Message "    |---[$i/$($getValue.Count)] $displayedKey" -DeferWrite
            $params = @{
                Id                    = $config.id
                Ensure                = 'Present'
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                ApplicationSecret     = $ApplicationSecret
                CertificateThumbprint = $CertificateThumbprint
                CertificatePath       = $CertificatePath
                CertificatePassword   = $CertificatePassword
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $Script:exportedInstance = $config
            $Results = Get-TargetResource @Params
            if ($null -ne $Results.PolicySnapshot)
            {
                $complexMapping = @(
                    @{
                        Name            = 'PolicySnapshot'
                        CimInstanceName = 'AADTenantGovernanceRelationshipPolicySnapshot'
                        IsRequired      = $false
                    }
                    @{
                        Name            = 'DelegatedAdministrationRoleAssignments'
                        CimInstanceName = 'AADTenantGovernanceRelationshipDelegatedAdminRoleAssignmentSnapshot'
                        IsRequired      = $false
                    }
                    @{
                        Name            = 'RoleTemplates'
                        CimInstanceName = 'AADTenantGovernanceRelationshipRoleTemplate'
                        IsRequired      = $false
                    }
                    @{
                        Name            = 'MultiTenantApplicationsToProvision'
                        CimInstanceName = 'AADTenantGovernanceRelationshipMultiTenantApplication'
                        IsRequired      = $false
                    }
                    @{
                        Name            = 'RequiredResourceAccesses'
                        CimInstanceName = 'AADTenantGovernanceRelationshipRequiredResourceAccess'
                        IsRequired      = $false
                    }
                    @{
                        Name            = 'Permissions'
                        CimInstanceName = 'AADTenantGovernanceRelationshipResourcePermission'
                        IsRequired      = $false
                    }
                )
                $Results.PolicySnapshot = Get-M365DSCDRGComplexTypeToString `
                    -ComplexObject $Results.PolicySnapshot `
                    -CIMInstanceName 'AADTenantGovernanceRelationshipPolicySnapshot' `
                    -ComplexTypeMapping $complexMapping
            }
            else
            {
                $Results.Remove('PolicySnapshot') | Out-Null
            }

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential `
                -NoEscape @('PolicySnapshot')
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
        New-M365DSCLogEntry -Message 'Error exporting Microsoft Entra tenant governance relationships:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        throw
    }
}

Export-ModuleMember -Function *-TargetResource
