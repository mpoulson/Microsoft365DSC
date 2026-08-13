Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureDataCollectionRuleAssociation'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $AssociationName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceUri,

        [Parameter()]
        [System.String]
        $DataCollectionRuleId,

        [Parameter()]
        [System.String]
        $DataCollectionEndpointId,

        [Parameter()]
        [System.String]
        $Description,

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

    Write-Verbose -Message "Getting configuration of Azure Data Collection Rule Association {$AssociationName} on resource {$ResourceUri}"

    try
    {
        if (-not $Script:exportedInstance -or $Script:exportedInstance.Name -ne $AssociationName)
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

            $instance = Get-AzDataCollectionRuleAssociation -AssociationName $AssociationName `
                -ResourceUri $ResourceUri `
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

        $results = @{
            AssociationName          = $instance.Name
            ResourceUri              = $ResourceUri
            DataCollectionRuleId     = $instance.DataCollectionRuleId
            DataCollectionEndpointId = $instance.DataCollectionEndpointId
            Description              = $instance.Description
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
        $AssociationName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceUri,

        [Parameter()]
        [System.String]
        $DataCollectionRuleId,

        [Parameter()]
        [System.String]
        $DataCollectionEndpointId,

        [Parameter()]
        [System.String]
        $Description,

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

    Write-Verbose -Message "Setting configuration of Azure Data Collection Rule Association {$AssociationName} on resource {$ResourceUri}"

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

    $instanceParams = @{
        AssociationName = $AssociationName
        ResourceUri     = $ResourceUri
    }
    if (-not [System.String]::IsNullOrEmpty($DataCollectionRuleId))
    {
        $instanceParams.Add('DataCollectionRuleId', $DataCollectionRuleId)
    }
    if (-not [System.String]::IsNullOrEmpty($DataCollectionEndpointId))
    {
        $instanceParams.Add('DataCollectionEndpointId', $DataCollectionEndpointId)
    }
    if (-not [System.String]::IsNullOrEmpty($Description))
    {
        $instanceParams.Add('Description', $Description)
    }

    # CREATE / UPDATE
    if ($Ensure -eq 'Present')
    {
        if ($currentInstance.Ensure -eq 'Absent')
        {
            Write-Verbose -Message "Creating new Azure Data Collection Rule Association {$AssociationName}"
        }
        else
        {
            Write-Verbose -Message "Updating Azure Data Collection Rule Association {$AssociationName}"
        }
        $null = New-AzDataCollectionRuleAssociation @instanceParams
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing Azure Data Collection Rule Association {$AssociationName}"
        $null = Remove-AzDataCollectionRuleAssociation -AssociationName $AssociationName `
            -ResourceUri $ResourceUri
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
        $AssociationName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceUri,

        [Parameter()]
        [System.String]
        $DataCollectionRuleId,

        [Parameter()]
        [System.String]
        $DataCollectionEndpointId,

        [Parameter()]
        [System.String]
        $Description,

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

        # Associations are enumerated through the Data Collection Rules they are bound to.
        [array] $dataCollectionRules = Get-AzDataCollectionRule -ErrorAction Stop
        [array] $Script:exportedInstances = @()
        foreach ($rule in $dataCollectionRules)
        {
            $ruleResourceGroupName = $rule.Id.Split('/')[4]
            [array] $ruleAssociations = Get-AzDataCollectionRuleAssociation -DataCollectionRuleName $rule.Name `
                -ResourceGroupName $ruleResourceGroupName `
                -ErrorAction SilentlyContinue
            $Script:exportedInstances += $ruleAssociations
        }

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

            # The association Id has the form {resourceUri}/providers/Microsoft.Insights/dataCollectionRuleAssociations/{name}
            $resourceUri = $config.Id -replace '/providers/Microsoft.Insights/dataCollectionRuleAssociations/.*$', ''
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $($config.Name)" -DeferWrite
            $params = @{
                AssociationName       = $config.Name
                ResourceUri           = $resourceUri
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
