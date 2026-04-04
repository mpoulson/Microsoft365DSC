Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AADTenantGovernanceRelationship'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GovernedTenantId,

        [Parameter()]
        [System.String]
        $Id,

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

    Write-Verbose -Message "Getting configuration of the Azure AD Tenant Governance Relationship for governed tenant {$GovernedTenantId}"

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

            $nullResult = $PSBoundParameters
            $nullResult.Ensure = 'Absent'

            $graphBaseUri = (Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl
            $uri = "$graphBaseUri/beta/tenantGovernance/governanceRelationships"

            $getValue = $null

            if (-not [System.String]::IsNullOrEmpty($Id))
            {
                try
                {
                    $getValue = Invoke-MgGraphRequest -Uri "$uri/$Id" -Method GET -ErrorAction SilentlyContinue
                }
                catch
                {
                    Write-Verbose -Message "Could not find an Azure AD Tenant Governance Relationship with Id {$Id}"
                }
            }

            if ($null -eq $getValue -and -not [System.String]::IsNullOrEmpty($GovernedTenantId))
            {
                $allRelationships = Invoke-MgGraphRequest -Uri "$uri" -Method GET -ErrorAction SilentlyContinue

                if ($null -ne $allRelationships -and $null -ne $allRelationships.value)
                {
                    $getValue = $allRelationships.value | Where-Object -FilterScript { $_.governedTenantId -eq $GovernedTenantId }

                    if ($null -ne $getValue -and @($getValue).Count -gt 1)
                    {
                        # Take the first active one if multiple exist
                        $getValue = @($getValue | Where-Object -FilterScript { $_.status -eq 'active' })[0]
                    }
                }
            }
        }
        else
        {
            $getValue = $Script:exportedInstance
        }

        if ($null -eq $getValue)
        {
            Write-Verbose -Message "Could not find an Azure AD Tenant Governance Relationship for governed tenant {$GovernedTenantId}."
            return $nullResult
        }

        $Id = $getValue.id
        Write-Verbose -Message "An Azure AD Tenant Governance Relationship with Id {$Id} was found"

        $policySnapshotValue = $null
        if ($null -ne $getValue.policySnapshot)
        {
            $delegatedAssignmentsSnapshot = @()
            if ($null -ne $getValue.policySnapshot.delegatedAdministrationRoleAssignments)
            {
                foreach ($assignment in $getValue.policySnapshot.delegatedAdministrationRoleAssignments)
                {
                    $roleTemplatesValue = @()
                    if ($null -ne $assignment.roleTemplates)
                    {
                        foreach ($role in $assignment.roleTemplates)
                        {
                            $roleTemplatesValue += @{
                                Id   = $role.id
                                Name = $role.name
                            }
                        }
                    }

                    $delegatedAssignmentsSnapshot += @{
                        GroupDisplayName = $assignment.groupDisplayName
                        GroupId          = $assignment.groupId
                        RoleTemplates    = $roleTemplatesValue
                    }
                }
            }

            $policySnapshotValue = @{
                PolicyId                               = $getValue.policySnapshot.policyId
                GovernedTenantCanTerminate              = $getValue.policySnapshot.governedTenantCanTerminate
                DelegatedAdministrationRoleAssignments  = $delegatedAssignmentsSnapshot
            }
        }

        $results = @{
            GovernedTenantId      = $getValue.governedTenantId
            Id                    = $getValue.id
            GovernedTenantName    = $getValue.governedTenantName
            GoverningTenantId     = $getValue.governingTenantId
            GoverningTenantName   = $getValue.governingTenantName
            Status                = $getValue.status
            CreatedType           = $getValue.createdType
            PolicySnapshot        = $policySnapshotValue
            Ensure                = 'Present'
            Credential            = $Credential
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            ApplicationSecret     = $ApplicationSecret
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
        $GovernedTenantId,

        [Parameter()]
        [System.String]
        $Id,

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
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $currentInstance = Get-TargetResource @PSBoundParameters

    $graphBaseUri = (Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl
    $uri = "$graphBaseUri/beta/tenantGovernance/governanceRelationships"

    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        # Only update the status (e.g., to request termination)
        if (-not [System.String]::IsNullOrEmpty($Status) -and $Status -ne $currentInstance.Status)
        {
            Write-Verbose -Message "Updating the Azure AD Tenant Governance Relationship with Id {$($currentInstance.Id)} - setting status to {$Status}"

            $bodyParams = @{
                status = $Status
            }
            $bodyJson = $bodyParams | ConvertTo-Json -Depth 10

            Invoke-MgGraphRequest -Uri "$uri/$($currentInstance.Id)" -Method PATCH -Body $bodyJson
        }
        else
        {
            Write-Verbose -Message "Azure AD Tenant Governance Relationship with Id {$($currentInstance.Id)} is already in the desired state."
        }
    }
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Azure AD Tenant Governance Relationships cannot be directly created. Use governance invitations to establish new relationships."
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
        $GovernedTenantId,

        [Parameter()]
        [System.String]
        $Id,

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
        $graphBaseUri = (Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl
        $uri = "$graphBaseUri/beta/tenantGovernance/governanceRelationships"

        $response = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop

        [array]$getValue = $response.value

        $i = 1
        $dscContent = ''
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
            $displayedKey = $config.id
            if (-not [String]::IsNullOrEmpty($config.governedTenantName))
            {
                $displayedKey = "$($config.governedTenantName) ($($config.governedTenantId))"
            }

            Write-M365DSCHost -Message "    |---[$i/$($getValue.Count)] $displayedKey" -DeferWrite
            $params = @{
                GovernedTenantId      = $config.governedTenantId
                Id                    = $config.id
                Ensure                = 'Present'
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                ApplicationSecret     = $ApplicationSecret
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $Script:exportedInstance = $config
            $Results = Get-TargetResource @Params

            if ($null -ne $Results.PolicySnapshot)
            {
                $Results.PolicySnapshot = Get-M365DSCDRGComplexTypeToString `
                    -ComplexObject $Results.PolicySnapshot `
                    -CIMInstanceName 'MSFT_AADTenantGovernanceRelationshipPolicySnapshot'
            }
            else
            {
                $Results.Remove('PolicySnapshot') | Out-Null
            }

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential

            if ($null -ne $Results.PolicySnapshot)
            {
                $currentDSCBlock = Convert-DSCStringParamToVariable -DSCBlock $currentDSCBlock `
                    -ParameterName 'PolicySnapshot'
            }

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
