Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzurePolicyAssignment'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $PolicyAssignmentName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $PolicyDefinitionId,

        [Parameter()]
        [ValidateSet('Default', 'DoNotEnforce')]
        [System.String]
        $EnforcementMode,

        [Parameter()]
        [System.String]
        $PolicyParameterValues,

        [Parameter()]
        [System.String[]]
        $NotScopes,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $NonComplianceMessages,

        [Parameter()]
        [System.String]
        $Location,

        [Parameter()]
        [ValidateSet('None', 'SystemAssigned')]
        [System.String]
        $IdentityType,

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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    Write-Verbose -Message "Getting configuration of Azure Policy Assignment {$PolicyAssignmentName} at scope {$Scope}"

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

        if ($null -ne $Script:exportedInstances -and $Script:ExportMode)
        {
            $instance = $Script:exportedInstances | Where-Object -FilterScript {
                $_.name -eq $PolicyAssignmentName -and $_.properties.scope -eq $Scope
            }
        }
        else
        {
            $uri = "https://management.azure.com$($Scope)/providers/Microsoft.Authorization/policyAssignments/$($PolicyAssignmentName)?api-version=2024-05-01"
            $response = Invoke-AzRest -Uri $uri -Method GET
            $statusCode = $response.StatusCode
            if ($statusCode -eq 404)
            {
                return $nullResult
            }
            $instance = ConvertFrom-Json ($response.Content)
        }

        if ($null -eq $instance -or $null -eq $instance.properties)
        {
            return $nullResult
        }

        $NonComplianceMessagesValue = @()
        if ($null -ne $instance.properties.nonComplianceMessages)
        {
            foreach ($msg in $instance.properties.nonComplianceMessages)
            {
                $NonComplianceMessagesValue += @{
                    Message                     = $msg.message
                    PolicyDefinitionReferenceId = $msg.policyDefinitionReferenceId
                }
            }
        }

        $PolicyParameterValuesString = $null
        if ($null -ne $instance.properties.parameters -and
            ($instance.properties.parameters | Get-Member -MemberType NoteProperty).Count -gt 0)
        {
            $PolicyParameterValuesString = ConvertTo-Json $instance.properties.parameters -Depth 10 -Compress
        }

        $IdentityTypeValue = 'None'
        if ($null -ne $instance.identity -and $instance.identity.type -ne 'None')
        {
            $IdentityTypeValue = $instance.identity.type
        }

        $results = @{
            PolicyAssignmentName  = $instance.name
            Scope                 = $Scope
            DisplayName           = $instance.properties.displayName
            Description           = $instance.properties.description
            PolicyDefinitionId    = $instance.properties.policyDefinitionId
            EnforcementMode       = $instance.properties.enforcementMode
            PolicyParameterValues = $PolicyParameterValuesString
            NotScopes             = [Array]$instance.properties.notScopes
            NonComplianceMessages = $NonComplianceMessagesValue
            Location              = $instance.location
            IdentityType          = $IdentityTypeValue
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
        $PolicyAssignmentName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $PolicyDefinitionId,

        [Parameter()]
        [ValidateSet('Default', 'DoNotEnforce')]
        [System.String]
        $EnforcementMode,

        [Parameter()]
        [System.String]
        $PolicyParameterValues,

        [Parameter()]
        [System.String[]]
        $NotScopes,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $NonComplianceMessages,

        [Parameter()]
        [System.String]
        $Location,

        [Parameter()]
        [ValidateSet('None', 'SystemAssigned')]
        [System.String]
        $IdentityType,

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
        [Switch]
        $ManagedIdentity,

        [Parameter()]
        [System.String[]]
        $AccessTokens
    )

    Write-Verbose -Message "Setting configuration of Azure Policy Assignment {$PolicyAssignmentName} at scope {$Scope}"

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

    $uri = "https://management.azure.com$($Scope)/providers/Microsoft.Authorization/policyAssignments/$($PolicyAssignmentName)?api-version=2024-05-01"

    # CREATE or UPDATE
    if ($Ensure -eq 'Present')
    {
        $propertiesValue = @{
            policyDefinitionId = $PolicyDefinitionId
        }

        if (-not [System.String]::IsNullOrEmpty($DisplayName))
        {
            $propertiesValue.displayName = $DisplayName
        }

        if (-not [System.String]::IsNullOrEmpty($Description))
        {
            $propertiesValue.description = $Description
        }

        if (-not [System.String]::IsNullOrEmpty($EnforcementMode))
        {
            $propertiesValue.enforcementMode = $EnforcementMode
        }

        if (-not [System.String]::IsNullOrEmpty($PolicyParameterValues))
        {
            $propertiesValue.parameters = ConvertFrom-Json $PolicyParameterValues
        }

        if ($null -ne $NotScopes -and $NotScopes.Count -gt 0)
        {
            $propertiesValue.notScopes = $NotScopes
        }

        if ($null -ne $NonComplianceMessages -and $NonComplianceMessages.Count -gt 0)
        {
            $messagesArray = @()
            foreach ($msg in $NonComplianceMessages)
            {
                $msgEntry = @{
                    message = $msg.Message
                }
                if (-not [System.String]::IsNullOrEmpty($msg.PolicyDefinitionReferenceId))
                {
                    $msgEntry.policyDefinitionReferenceId = $msg.PolicyDefinitionReferenceId
                }
                $messagesArray += $msgEntry
            }
            $propertiesValue.nonComplianceMessages = $messagesArray
        }

        $instanceParams = @{
            properties = $propertiesValue
        }

        if (-not [System.String]::IsNullOrEmpty($Location))
        {
            $instanceParams.location = $Location
        }

        if (-not [System.String]::IsNullOrEmpty($IdentityType) -and $IdentityType -ne 'None')
        {
            $instanceParams.identity = @{
                type = $IdentityType
            }
        }

        $payload = ConvertTo-Json $instanceParams -Depth 10 -Compress

        if ($currentInstance.Ensure -eq 'Absent')
        {
            Write-Verbose -Message "Creating new policy assignment {$PolicyAssignmentName} with payload:`r`n$payload"
        }
        else
        {
            Write-Verbose -Message "Updating policy assignment {$PolicyAssignmentName} with payload:`r`n$payload"
        }

        $response = Invoke-AzRest -Uri $uri -Method PUT -Payload $payload
        Write-Verbose -Message "Response:`r`n$($response.Content)"
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing policy assignment {$PolicyAssignmentName}"
        $response = Invoke-AzRest -Uri $uri -Method DELETE
        Write-Verbose -Message "Response:`r`n$($response.Content)"
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
        $PolicyAssignmentName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $PolicyDefinitionId,

        [Parameter()]
        [ValidateSet('Default', 'DoNotEnforce')]
        [System.String]
        $EnforcementMode,

        [Parameter()]
        [System.String]
        $PolicyParameterValues,

        [Parameter()]
        [System.String[]]
        $NotScopes,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $NonComplianceMessages,

        [Parameter()]
        [System.String]
        $Location,

        [Parameter()]
        [ValidateSet('None', 'SystemAssigned')]
        [System.String]
        $IdentityType,

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
        [array]$Script:exportedInstances = @()

        $uri = 'https://management.azure.com/subscriptions?api-version=2022-12-01'
        $response = Invoke-AzRest -Uri $uri -Method GET
        $subscriptions = (ConvertFrom-Json ($response.Content)).value

        foreach ($subscription in $subscriptions)
        {
            $subScope = "/subscriptions/$($subscription.subscriptionId)"
            $uri = "https://management.azure.com$($subScope)/providers/Microsoft.Authorization/policyAssignments?api-version=2024-05-01"
            $response = Invoke-AzRest -Uri $uri -Method GET
            $assignments = (ConvertFrom-Json ($response.Content)).value

            if ($null -ne $assignments)
            {
                foreach ($assignment in $assignments)
                {
                    $assignment | Add-Member -NotePropertyName '_exportScope' -NotePropertyValue $subScope -Force
                }
                $Script:exportedInstances += $assignments
            }
        }

        $i = 1
        $dscContent = ''
        if ($Script:exportedInstances.Count -eq 0)
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
            $displayedKey = $config.name
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -DeferWrite

            $assignmentScope = $config._exportScope

            $params = @{
                PolicyAssignmentName  = $config.name
                Scope                 = $assignmentScope
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $Results = Get-TargetResource @Params

            if ($Results.NonComplianceMessages.Count -gt 0)
            {
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString -ComplexObject ([Array]$Results.NonComplianceMessages) -CIMInstanceName AzurePolicyAssignmentNonComplianceMessage
                if ($complexTypeStringResult)
                {
                    $Results.NonComplianceMessages = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('NonComplianceMessages') | Out-Null
                }
            }
            else
            {
                $Results.Remove('NonComplianceMessages') | Out-Null
            }

            if ([System.String]::IsNullOrEmpty($Results.PolicyParameterValues))
            {
                $Results.Remove('PolicyParameterValues') | Out-Null
            }

            if ($null -eq $Results.NotScopes -or $Results.NotScopes.Count -eq 0)
            {
                $Results.Remove('NotScopes') | Out-Null
            }

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential `
                -NoEscape @('NonComplianceMessages')
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
