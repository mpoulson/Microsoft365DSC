Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AADTenantGovernancePolicyTemplate'

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
        $Description,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $DelegatedAdministrationRoleAssignments,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $MultiTenantApplicationsToProvision,

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

    Write-Verbose -Message "Getting configuration of the Azure AD Tenant Governance Policy Template with DisplayName {$DisplayName}"

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
            $uri = "$graphBaseUri/beta/tenantGovernance/governancePolicyTemplates"

            $getValue = $null

            if (-not [System.String]::IsNullOrEmpty($Id))
            {
                try
                {
                    $getValue = Invoke-MgGraphRequest -Uri "$uri/$Id" -Method GET -ErrorAction SilentlyContinue
                }
                catch
                {
                    Write-Verbose -Message "Could not find an Azure AD Tenant Governance Policy Template with Id {$Id}"
                }
            }

            if ($null -eq $getValue)
            {
                Write-Verbose -Message "Could not find an Azure AD Tenant Governance Policy Template with Id {$Id}"

                if (-not [System.String]::IsNullOrEmpty($DisplayName))
                {
                    $allTemplates = Invoke-MgGraphRequest -Uri "$uri" -Method GET -ErrorAction SilentlyContinue

                    if ($null -ne $allTemplates -and $null -ne $allTemplates.value)
                    {
                        $getValue = $allTemplates.value | Where-Object -FilterScript { $_.displayName -eq $DisplayName }

                        if ($null -ne $getValue -and @($getValue).Count -gt 1)
                        {
                            throw "Multiple Azure AD Tenant Governance Policy Templates with the DisplayName '$DisplayName' exist in the tenant."
                        }
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
            Write-Verbose -Message "Could not find an Azure AD Tenant Governance Policy Template with DisplayName {$DisplayName}."
            return $nullResult
        }

        $Id = $getValue.id
        Write-Verbose -Message "An Azure AD Tenant Governance Policy Template with Id {$Id} and DisplayName {$DisplayName} was found"

        $delegatedAdminRoleAssignmentsValue = @()
        if ($null -ne $getValue.delegatedAdministrationRoleAssignments)
        {
            foreach ($assignment in $getValue.delegatedAdministrationRoleAssignments)
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

                $groupDisplayName = $null
                $groupId = $null
                if ($null -ne $assignment.group)
                {
                    $groupId = $assignment.group.id
                    $groupDisplayName = $assignment.group.displayName

                    if ([System.String]::IsNullOrEmpty($groupDisplayName) -and -not [System.String]::IsNullOrEmpty($groupId))
                    {
                        try
                        {
                            $groupObj = Get-MgBetaGroup -GroupId $groupId -ErrorAction SilentlyContinue
                            if ($null -ne $groupObj)
                            {
                                $groupDisplayName = $groupObj.DisplayName
                            }
                        }
                        catch
                        {
                            Write-Verbose -Message "Could not resolve group with Id {$groupId}"
                        }
                    }
                }

                $delegatedAdminRoleAssignmentsValue += @{
                    GroupDisplayName = $groupDisplayName
                    GroupId          = $groupId
                    RoleTemplates    = $roleTemplatesValue
                }
            }
        }

        $multiTenantAppsValue = @()
        if ($null -ne $getValue.multiTenantApplicationsToProvision)
        {
            foreach ($app in $getValue.multiTenantApplicationsToProvision)
            {
                $requiredAccessesValue = @()
                if ($null -ne $app.requiredResourceAccesses)
                {
                    foreach ($access in $app.requiredResourceAccesses)
                    {
                        $permissionsValue = @()
                        if ($null -ne $access.permissions)
                        {
                            foreach ($perm in $access.permissions)
                            {
                                $permissionsValue += @{
                                    Id   = $perm.id
                                    Type = $perm.type
                                }
                            }
                        }

                        $requiredAccessesValue += @{
                            ResourceAppId = $access.resourceAppId
                            Permissions   = $permissionsValue
                        }
                    }
                }

                $multiTenantAppsValue += @{
                    AppId                   = $app.appId
                    DisplayName             = $app.displayName
                    ObjectId                = $app.objectId
                    RequiredResourceAccesses = $requiredAccessesValue
                }
            }
        }

        $results = @{
            DisplayName                              = $getValue.displayName
            Description                              = $getValue.description
            Id                                       = $getValue.id
            DelegatedAdministrationRoleAssignments    = [Array]$delegatedAdminRoleAssignmentsValue
            MultiTenantApplicationsToProvision        = [Array]$multiTenantAppsValue
            Ensure                                   = 'Present'
            Credential                               = $Credential
            ApplicationId                            = $ApplicationId
            TenantId                                 = $TenantId
            ApplicationSecret                        = $ApplicationSecret
            CertificateThumbprint                    = $CertificateThumbprint
            ManagedIdentity                          = $ManagedIdentity.IsPresent
            AccessTokens                             = $AccessTokens
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
        $Description,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $DelegatedAdministrationRoleAssignments,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $MultiTenantApplicationsToProvision,

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
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $currentInstance = Get-TargetResource @PSBoundParameters

    $graphBaseUri = (Get-MSCloudLoginConnectionProfile -Workload MicrosoftGraph).ResourceUrl
    $uri = "$graphBaseUri/beta/tenantGovernance/governancePolicyTemplates"

    $bodyParams = @{
        displayName = $DisplayName
    }

    if (-not [System.String]::IsNullOrEmpty($Description))
    {
        $bodyParams.Add('description', $Description)
    }

    if ($null -ne $DelegatedAdministrationRoleAssignments -and $DelegatedAdministrationRoleAssignments.Length -gt 0)
    {
        $delegatedAssignments = [System.Collections.ArrayList]@()
        foreach ($assignment in $DelegatedAdministrationRoleAssignments)
        {
            $roleTemplates = [System.Collections.ArrayList]@()
            if ($null -ne $assignment.RoleTemplates)
            {
                foreach ($role in $assignment.RoleTemplates)
                {
                    $roleEntry = @{
                        id   = $role.Id
                        name = $role.Name
                    }
                    $roleTemplates.Add($roleEntry) | Out-Null
                }
            }

            $assignmentEntry = @{
                'group@odata.bind' = "https://graph.microsoft.com/beta/groups/$($assignment.GroupId)"
                roleTemplates      = $roleTemplates
            }
            $delegatedAssignments.Add($assignmentEntry) | Out-Null
        }
        $bodyParams.Add('delegatedAdministrationRoleAssignments', $delegatedAssignments)
    }

    if ($null -ne $MultiTenantApplicationsToProvision -and $MultiTenantApplicationsToProvision.Length -gt 0)
    {
        $multiTenantApps = [System.Collections.ArrayList]@()
        foreach ($app in $MultiTenantApplicationsToProvision)
        {
            $requiredAccesses = [System.Collections.ArrayList]@()
            if ($null -ne $app.RequiredResourceAccesses)
            {
                foreach ($access in $app.RequiredResourceAccesses)
                {
                    $permissions = [System.Collections.ArrayList]@()
                    if ($null -ne $access.Permissions)
                    {
                        foreach ($perm in $access.Permissions)
                        {
                            $permEntry = @{
                                id   = $perm.Id
                                type = $perm.Type
                            }
                            $permissions.Add($permEntry) | Out-Null
                        }
                    }

                    $accessEntry = @{
                        resourceAppId = $access.ResourceAppId
                        permissions   = $permissions
                    }
                    $requiredAccesses.Add($accessEntry) | Out-Null
                }
            }

            $appEntry = @{
                appId                  = $app.AppId
                displayName            = $app.DisplayName
                objectId               = $app.ObjectId
                requiredResourceAccesses = $requiredAccesses
            }
            $multiTenantApps.Add($appEntry) | Out-Null
        }
        $bodyParams.Add('multiTenantApplicationsToProvision', $multiTenantApps)
    }

    $bodyJson = $bodyParams | ConvertTo-Json -Depth 10

    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Creating an Azure AD Tenant Governance Policy Template with DisplayName {$DisplayName}"
        Invoke-MgGraphRequest -Uri $uri -Method POST -Body $bodyJson
    }
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating the Azure AD Tenant Governance Policy Template with Id {$($currentInstance.Id)}"
        Invoke-MgGraphRequest -Uri "$uri/$($currentInstance.Id)" -Method PATCH -Body $bodyJson
    }
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing the Azure AD Tenant Governance Policy Template with Id {$($currentInstance.Id)}"
        Invoke-MgGraphRequest -Uri "$uri/$($currentInstance.Id)" -Method DELETE
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
        $Description,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $DelegatedAdministrationRoleAssignments,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $MultiTenantApplicationsToProvision,

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
        $uri = "$graphBaseUri/beta/tenantGovernance/governancePolicyTemplates"

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
            if (-not [String]::IsNullOrEmpty($config.displayName))
            {
                $displayedKey = $config.displayName
            }

            Write-M365DSCHost -Message "    |---[$i/$($getValue.Count)] $displayedKey" -DeferWrite
            $params = @{
                Id                    = $config.id
                DisplayName           = $config.displayName
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

            if ($null -ne $Results.DelegatedAdministrationRoleAssignments -and $Results.DelegatedAdministrationRoleAssignments.Count -gt 0)
            {
                $Results.DelegatedAdministrationRoleAssignments = Get-M365DSCDRGComplexTypeToString `
                    -ComplexObject ([Array]$Results.DelegatedAdministrationRoleAssignments) `
                    -CIMInstanceName 'MSFT_AADTenantGovernancePolicyTemplateDelegatedAdminRoleAssignment'
            }
            else
            {
                $Results.Remove('DelegatedAdministrationRoleAssignments') | Out-Null
            }

            if ($null -ne $Results.MultiTenantApplicationsToProvision -and $Results.MultiTenantApplicationsToProvision.Count -gt 0)
            {
                $Results.MultiTenantApplicationsToProvision = Get-M365DSCDRGComplexTypeToString `
                    -ComplexObject ([Array]$Results.MultiTenantApplicationsToProvision) `
                    -CIMInstanceName 'MSFT_AADTenantGovernancePolicyTemplateMultiTenantApp'
            }
            else
            {
                $Results.Remove('MultiTenantApplicationsToProvision') | Out-Null
            }

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential

            if ($null -ne $Results.DelegatedAdministrationRoleAssignments)
            {
                $currentDSCBlock = Convert-DSCStringParamToVariable -DSCBlock $currentDSCBlock `
                    -ParameterName 'DelegatedAdministrationRoleAssignments'
            }

            if ($null -ne $Results.MultiTenantApplicationsToProvision)
            {
                $currentDSCBlock = Convert-DSCStringParamToVariable -DSCBlock $currentDSCBlock `
                    -ParameterName 'MultiTenantApplicationsToProvision'
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
