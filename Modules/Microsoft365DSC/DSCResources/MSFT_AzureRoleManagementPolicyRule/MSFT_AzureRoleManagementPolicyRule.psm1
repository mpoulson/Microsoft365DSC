Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AzureRoleManagementPolicyRule'

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
        $RoleDefinitionDisplayName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [System.String]
        $RuleType,

        [Parameter()]
        [System.String]
        $PolicyId,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ExpirationRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $NotificationRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $EnablementRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ApprovalRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $AuthenticationContextRule,

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

    Write-Verbose -Message "Getting configuration of Azure Role Management Policy Rule with Id {$Id} for Role {$RoleDefinitionDisplayName} at Scope {$Scope}"

    try
    {
        if ($null -eq $Script:exportedInstance)
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

            # Get all role management policy assignments for the scope
            $apiVersion = '2020-10-01'
            $uri = "https://management.azure.com/$Scope/providers/Microsoft.Authorization/roleManagementPolicyAssignments?api-version=$apiVersion"
            $response = Invoke-AzRest -Uri $uri -Method GET
            $assignments = (ConvertFrom-Json $response.Content).value

            if ($null -eq $assignments -or $assignments.Count -eq 0)
            {
                Write-Verbose -Message "No role management policy assignments found at scope {$Scope}."
                return $nullResult
            }

            # Find the assignment for the specified role
            $assignment = $assignments | Where-Object {
                $_.properties.roleDefinitionDisplayName -eq $RoleDefinitionDisplayName -or
                $_.properties.policyAssignmentProperties.roleDefinition.displayName -eq $RoleDefinitionDisplayName
            }

            if ($null -eq $assignment)
            {
                # Try to resolve via role definitions
                $roleDefUri = "https://management.azure.com/$Scope/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01&`$filter=roleName eq '$RoleDefinitionDisplayName'"
                $roleDefResponse = Invoke-AzRest -Uri $roleDefUri -Method GET
                $roleDefinitions = (ConvertFrom-Json $roleDefResponse.Content).value

                if ($null -ne $roleDefinitions -and $roleDefinitions.Count -gt 0)
                {
                    $roleDefId = $roleDefinitions[0].id
                    $assignment = $assignments | Where-Object {
                        $_.properties.roleDefinitionId -eq $roleDefId
                    }
                }
            }

            if ($null -eq $assignment)
            {
                Write-Verbose -Message "Could not find role management policy assignment for role {$RoleDefinitionDisplayName} at scope {$Scope}."
                return $nullResult
            }

            $policyIdValue = $assignment.properties.policyId.Split('/')[-1]

            # Get the policy with its rules
            $policyUri = "https://management.azure.com/$Scope/providers/Microsoft.Authorization/roleManagementPolicies/$($policyIdValue)?api-version=$apiVersion"
            $policyResponse = Invoke-AzRest -Uri $policyUri -Method GET
            $policy = ConvertFrom-Json $policyResponse.Content

            if ($null -eq $policy -or $null -eq $policy.properties -or $null -eq $policy.properties.rules)
            {
                Write-Verbose -Message "Could not retrieve role management policy {$policyIdValue} at scope {$Scope}."
                return $nullResult
            }

            # Find the specific rule
            $getValue = $policy.properties.rules | Where-Object { $_.id -eq $Id }

            if ($null -eq $getValue)
            {
                Write-Verbose -Message "Could not find rule with Id {$Id} in policy {$policyIdValue}."
                return $nullResult
            }
        }
        else
        {
            $getValue = $Script:exportedInstance.rule
            $policyIdValue = $Script:exportedInstance.policyId
        }

        Write-Verbose -Message "An Azure Role Management Policy Rule with Id {$($getValue.id)} was found"
        $rule = Get-AzureRoleManagementPolicyRuleObject -Rule $getValue

        $results = @{
            Id                        = $getValue.id
            RoleDefinitionDisplayName = $RoleDefinitionDisplayName
            Scope                     = $Scope
            RuleType                  = $rule.ruleType
            PolicyId                  = $policyIdValue
            ExpirationRule            = $rule.expirationRule
            NotificationRule          = $rule.notificationRule
            EnablementRule            = $rule.enablementRule
            ApprovalRule              = $rule.approvalRule
            AuthenticationContextRule = $rule.authenticationContextRule
            Credential                = $Credential
            ApplicationId             = $ApplicationId
            TenantId                  = $TenantId
            ApplicationSecret         = $ApplicationSecret
            CertificateThumbprint     = $CertificateThumbprint
            ManagedIdentity           = $ManagedIdentity.IsPresent
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
        $Id,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RoleDefinitionDisplayName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [System.String]
        $RuleType,

        [Parameter()]
        [System.String]
        $PolicyId,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ExpirationRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $NotificationRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $EnablementRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ApprovalRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $AuthenticationContextRule,

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

    Write-Verbose -Message "Setting configuration of Azure Role Management Policy Rule with Id {$Id} for Role {$RoleDefinitionDisplayName} at Scope {$Scope}"

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

    $policyIdValue = $currentInstance.PolicyId
    if ([System.String]::IsNullOrEmpty($policyIdValue))
    {
        throw "Could not find role management policy for role {$RoleDefinitionDisplayName} at scope {$Scope}"
    }

    # Get the full policy to retrieve all current rules
    $apiVersion = '2020-10-01'
    $policyUri = "https://management.azure.com/$Scope/providers/Microsoft.Authorization/roleManagementPolicies/$($policyIdValue)?api-version=$apiVersion"
    $policyResponse = Invoke-AzRest -Uri $policyUri -Method GET
    $policy = ConvertFrom-Json $policyResponse.Content

    # Find and update the specific rule in the policy
    $ruleIndex = -1
    for ($i = 0; $i -lt $policy.properties.rules.Count; $i++)
    {
        if ($policy.properties.rules[$i].id -eq $Id)
        {
            $ruleIndex = $i
            break
        }
    }

    if ($ruleIndex -lt 0)
    {
        throw "Could not find rule with Id {$Id} in policy {$policyIdValue}"
    }

    $currentRule = $policy.properties.rules[$ruleIndex]

    if ($RuleType -eq 'RoleManagementPolicyExpirationRule' -and $null -ne $ExpirationRule)
    {
        $expirationRuleHashmap = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $ExpirationRule
        if ($expirationRuleHashmap.ContainsKey('isExpirationRequired'))
        {
            $currentRule.isExpirationRequired = $expirationRuleHashmap.isExpirationRequired
        }
        if ($expirationRuleHashmap.ContainsKey('maximumDuration'))
        {
            $currentRule.maximumDuration = $expirationRuleHashmap.maximumDuration
        }
    }

    if ($RuleType -eq 'RoleManagementPolicyNotificationRule' -and $null -ne $NotificationRule)
    {
        $notificationRuleHashmap = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $NotificationRule
        if ($notificationRuleHashmap.ContainsKey('notificationType'))
        {
            $currentRule.notificationType = $notificationRuleHashmap.notificationType
        }
        if ($notificationRuleHashmap.ContainsKey('recipientType'))
        {
            $currentRule.recipientType = $notificationRuleHashmap.recipientType
        }
        if ($notificationRuleHashmap.ContainsKey('notificationLevel'))
        {
            $currentRule.notificationLevel = $notificationRuleHashmap.notificationLevel
        }
        if ($notificationRuleHashmap.ContainsKey('isDefaultRecipientsEnabled'))
        {
            $currentRule.isDefaultRecipientsEnabled = $notificationRuleHashmap.isDefaultRecipientsEnabled
        }
        if ($notificationRuleHashmap.ContainsKey('notificationRecipients'))
        {
            $currentRule.notificationRecipients = @($notificationRuleHashmap.notificationRecipients)
        }
    }

    if ($RuleType -eq 'RoleManagementPolicyEnablementRule' -and $null -ne $EnablementRule)
    {
        $enablementRuleHashmap = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $EnablementRule
        if ($enablementRuleHashmap.ContainsKey('enabledRules'))
        {
            $currentRule.enabledRules = @($enablementRuleHashmap.enabledRules)
        }
    }

    if ($RuleType -eq 'RoleManagementPolicyApprovalRule' -and $null -ne $ApprovalRule)
    {
        $approvalRuleHashmap = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $ApprovalRule
        if ($null -ne $approvalRuleHashmap.setting)
        {
            $settingHashmap = $approvalRuleHashmap.setting
            if ($settingHashmap.ContainsKey('isApprovalRequired'))
            {
                $currentRule.setting.isApprovalRequired = $settingHashmap.isApprovalRequired
            }
            if ($settingHashmap.ContainsKey('isApprovalRequiredForExtension'))
            {
                $currentRule.setting.isApprovalRequiredForExtension = $settingHashmap.isApprovalRequiredForExtension
            }
            if ($settingHashmap.ContainsKey('isRequestorJustificationRequired'))
            {
                $currentRule.setting.isRequestorJustificationRequired = $settingHashmap.isRequestorJustificationRequired
            }
            if ($settingHashmap.ContainsKey('approvalMode'))
            {
                $currentRule.setting.approvalMode = $settingHashmap.approvalMode
            }
            if ($null -ne $settingHashmap.approvalStages)
            {
                $currentRule.setting.approvalStages = @($settingHashmap.approvalStages)
            }
        }
    }

    if ($RuleType -eq 'RoleManagementPolicyAuthenticationContextRule' -and $null -ne $AuthenticationContextRule)
    {
        $authContextRuleHashmap = Convert-M365DSCDRGComplexTypeToHashtable -ComplexObject $AuthenticationContextRule
        if ($authContextRuleHashmap.ContainsKey('isEnabled'))
        {
            $currentRule.isEnabled = $authContextRuleHashmap.isEnabled
        }
        if ($authContextRuleHashmap.ContainsKey('claimValue'))
        {
            $currentRule.claimValue = $authContextRuleHashmap.claimValue
        }
    }

    # Update the rule in the policy
    $policy.properties.rules[$ruleIndex] = $currentRule

    # Build the update payload with only rules
    $updateBody = @{
        properties = @{
            rules = @($policy.properties.rules)
        }
    }

    $payload = ConvertTo-Json $updateBody -Depth 20 -Compress
    Write-Verbose -Message "Updating policy {$policyIdValue} at scope {$Scope}"
    $null = Invoke-AzRest -Uri $policyUri -Method PATCH -Payload $payload
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
        $RoleDefinitionDisplayName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope,

        [Parameter()]
        [System.String]
        $RuleType,

        [Parameter()]
        [System.String]
        $PolicyId,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ExpirationRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $NotificationRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $EnablementRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ApprovalRule,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $AuthenticationContextRule,

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
        $apiVersion = '2020-10-01'

        # Collect all scopes to enumerate
        $scopes = @()

        # Add subscriptions
        $subUri = 'https://management.azure.com/subscriptions?api-version=2022-12-01'
        $subResponse = Invoke-AzRest -Uri $subUri -Method GET
        $subscriptions = (ConvertFrom-Json $subResponse.Content).value

        foreach ($sub in $subscriptions)
        {
            $scopes += @{
                Scope       = "subscriptions/$($sub.subscriptionId)"
                DisplayName = $sub.displayName
                ScopeType   = 'Subscription'
            }

            # Add resource groups under each subscription
            $rgUri = "https://management.azure.com/subscriptions/$($sub.subscriptionId)/resourcegroups?api-version=2021-04-01"
            $rgResponse = Invoke-AzRest -Uri $rgUri -Method GET
            $resourceGroups = (ConvertFrom-Json $rgResponse.Content).value

            foreach ($rg in $resourceGroups)
            {
                $scopes += @{
                    Scope       = "subscriptions/$($sub.subscriptionId)/resourceGroups/$($rg.name)"
                    DisplayName = $rg.name
                    ScopeType   = 'ResourceGroup'
                }
            }
        }

        # Add management groups
        $mgUri = 'https://management.azure.com/providers/Microsoft.Management/managementGroups?api-version=2021-04-01'
        $mgResponse = Invoke-AzRest -Uri $mgUri -Method GET
        $managementGroups = (ConvertFrom-Json $mgResponse.Content).value

        foreach ($mg in $managementGroups)
        {
            $scopes += @{
                Scope       = "providers/Microsoft.Management/managementGroups/$($mg.name)"
                DisplayName = $mg.properties.displayName
                ScopeType   = 'ManagementGroup'
            }
        }

        $dscContent = [System.Text.StringBuilder]::new()
        Write-M365DSCHost -Message "`r`n" -DeferWrite
        $j = 1

        foreach ($scopeInfo in $scopes)
        {
            $currentScope = $scopeInfo.Scope
            Write-M365DSCHost -Message "    |---[$j/$($scopes.Count)] $($scopeInfo.ScopeType): $($scopeInfo.DisplayName)`r`n" -DeferWrite

            # Get role management policy assignments for this scope
            $assignUri = "https://management.azure.com/$currentScope/providers/Microsoft.Authorization/roleManagementPolicyAssignments?api-version=$apiVersion"
            $assignResponse = Invoke-AzRest -Uri $assignUri -Method GET
            $assignments = (ConvertFrom-Json $assignResponse.Content).value

            if ($null -eq $assignments -or $assignments.Count -eq 0)
            {
                $j++
                continue
            }

            $i = 1
            foreach ($assignment in $assignments)
            {
                $roleDisplayName = $null
                if ($null -ne $assignment.properties.policyAssignmentProperties -and
                    $null -ne $assignment.properties.policyAssignmentProperties.roleDefinition)
                {
                    $roleDisplayName = $assignment.properties.policyAssignmentProperties.roleDefinition.displayName
                }

                if ([System.String]::IsNullOrEmpty($roleDisplayName))
                {
                    # Resolve role name from role definition ID
                    $roleDefId = $assignment.properties.roleDefinitionId
                    if (-not [System.String]::IsNullOrEmpty($roleDefId))
                    {
                        $roleDefUri = "https://management.azure.com/$roleDefId`?api-version=2022-04-01"
                        $roleDefResponse = Invoke-AzRest -Uri $roleDefUri -Method GET
                        $roleDef = ConvertFrom-Json $roleDefResponse.Content
                        $roleDisplayName = $roleDef.properties.roleName
                    }
                }

                if ([System.String]::IsNullOrEmpty($roleDisplayName))
                {
                    $i++
                    continue
                }

                $assignmentPolicyId = $assignment.properties.policyId.Split('/')[-1]

                # Get the policy rules
                $policyUri = "https://management.azure.com/$currentScope/providers/Microsoft.Authorization/roleManagementPolicies/$($assignmentPolicyId)?api-version=$apiVersion"
                $policyResponse = Invoke-AzRest -Uri $policyUri -Method GET
                $policyContent = ConvertFrom-Json $policyResponse.Content

                if ($null -eq $policyContent -or $null -eq $policyContent.properties -or $null -eq $policyContent.properties.rules)
                {
                    $i++
                    continue
                }

                $rules = $policyContent.properties.rules
                Write-M365DSCHost -Message "        |---[$i/$($assignments.Count)] $roleDisplayName`r`n" -DeferWrite

                $k = 1
                foreach ($rule in $rules)
                {
                    if ($null -ne $Global:M365DSCExportResourceInstancesCount)
                    {
                        $Global:M365DSCExportResourceInstancesCount++
                    }
                    Write-M365DSCHost -Message "            |---[$k/$($rules.Count)] $($rule.id)" -DeferWrite

                    $Params = @{
                        Id                        = $rule.id
                        RoleDefinitionDisplayName = $roleDisplayName
                        Scope                     = $currentScope
                        ApplicationId             = $ApplicationId
                        TenantId                  = $TenantId
                        CertificateThumbprint     = $CertificateThumbprint
                        ApplicationSecret         = $ApplicationSecret
                        Credential                = $Credential
                        ManagedIdentity           = $ManagedIdentity.IsPresent
                        AccessTokens              = $AccessTokens
                    }

                    $Script:exportedInstance = @{
                        rule     = $rule
                        policyId = $assignmentPolicyId
                    }
                    $Results = Get-TargetResource @Params

                    if ($null -ne $Results.ExpirationRule)
                    {
                        $complexMapping = @(
                            @{
                                Name            = 'expirationRule'
                                CimInstanceName = 'AADRoleManagementPolicyExpirationRule'
                                IsRequired      = $False
                            }
                        )
                        $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString `
                            -ComplexObject $Results.ExpirationRule`
                            -CIMInstanceName 'AADRoleManagementPolicyExpirationRule' `
                            -ComplexTypeMapping $complexMapping

                        if (-not [String]::IsNullOrWhiteSpace($complexTypeStringResult))
                        {
                            $Results.ExpirationRule = $complexTypeStringResult
                        }
                        else
                        {
                            $Results.Remove('ExpirationRule') | Out-Null
                        }
                    }

                    if ($null -ne $Results.NotificationRule)
                    {
                        $complexMapping = @(
                            @{
                                Name            = 'notificationRule'
                                CimInstanceName = 'AADRoleManagementPolicyNotificationRule'
                                IsRequired      = $False
                            }
                        )
                        $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString `
                            -ComplexObject $Results.NotificationRule`
                            -CIMInstanceName 'AADRoleManagementPolicyNotificationRule' `
                            -ComplexTypeMapping $complexMapping

                        if (-not [String]::IsNullOrWhiteSpace($complexTypeStringResult))
                        {
                            $Results.NotificationRule = $complexTypeStringResult
                        }
                        else
                        {
                            $Results.Remove('NotificationRule') | Out-Null
                        }
                    }

                    if ($null -ne $Results.EnablementRule)
                    {
                        $complexMapping = @(
                            @{
                                Name            = 'enablementRule'
                                CimInstanceName = 'AADRoleManagementPolicyEnablementRule'
                                IsRequired      = $False
                            }
                        )
                        $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString `
                            -ComplexObject $Results.EnablementRule`
                            -CIMInstanceName 'AADRoleManagementPolicyEnablementRule' `
                            -ComplexTypeMapping $complexMapping

                        if (-not [String]::IsNullOrWhiteSpace($complexTypeStringResult))
                        {
                            $Results.EnablementRule = $complexTypeStringResult
                        }
                        else
                        {
                            $Results.Remove('EnablementRule') | Out-Null
                        }
                    }

                    if ($null -ne $Results.AuthenticationContextRule)
                    {
                        $complexMapping = @(
                            @{
                                Name            = 'authenticationContextRule'
                                CimInstanceName = 'AADRoleManagementPolicyAuthenticationContextRule'
                                IsRequired      = $False
                            }
                        )
                        $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString `
                            -ComplexObject $Results.AuthenticationContextRule`
                            -CIMInstanceName 'AADRoleManagementPolicyAuthenticationContextRule' `
                            -ComplexTypeMapping $complexMapping

                        if (-not [String]::IsNullOrWhiteSpace($complexTypeStringResult))
                        {
                            $Results.AuthenticationContextRule = $complexTypeStringResult
                        }
                        else
                        {
                            $Results.Remove('AuthenticationContextRule') | Out-Null
                        }
                    }

                    if ($null -ne $Results.ApprovalRule)
                    {
                        $complexMapping = @(
                            @{
                                Name            = 'approvalRule'
                                CimInstanceName = 'AADRoleManagementPolicyApprovalRule'
                                IsRequired      = $False
                            }
                            @{
                                Name            = 'setting'
                                CimInstanceName = 'AADRoleManagementPolicyApprovalSettings'
                                IsRequired      = $False
                            }
                            @{
                                Name            = 'approvalStages'
                                CimInstanceName = 'AADRoleManagementPolicyApprovalStage'
                                IsRequired      = $False
                            }
                            @{
                                Name            = 'escalationApprovers'
                                CimInstanceName = 'AADRoleManagementPolicySubjectSet'
                                IsRequired      = $False
                            }
                            @{
                                Name            = 'primaryApprovers'
                                CimInstanceName = 'AADRoleManagementPolicySubjectSet'
                                IsRequired      = $False
                            }
                        )
                        $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString `
                            -ComplexObject $Results.ApprovalRule`
                            -CIMInstanceName 'AADRoleManagementPolicyApprovalRule' `
                            -ComplexTypeMapping $complexMapping

                        if (-not [String]::IsNullOrWhiteSpace($complexTypeStringResult))
                        {
                            $Results.ApprovalRule = $complexTypeStringResult
                        }
                        else
                        {
                            $Results.Remove('ApprovalRule') | Out-Null
                        }
                    }

                    $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                        -ConnectionMode $ConnectionMode `
                        -ModulePath $PSScriptRoot `
                        -Results $Results `
                        -Credential $Credential `
                        -NoEscape @('ExpirationRule', 'NotificationRule', 'EnablementRule', 'ApprovalRule', 'AuthenticationContextRule')

                    $dscContent.Append($currentDSCBlock) | Out-Null
                    Save-M365DSCPartialExport -Content $currentDSCBlock `
                        -FileName $Global:PartialExportFileName
                    Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
                    $k++
                }
                $i++
            }
            $j++
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

function Get-AzureRoleManagementPolicyRuleObject
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        $Rule
    )

    if ($null -eq $Rule)
    {
        return $null
    }

    $values = [ordered]@{
        id       = $Rule.id
        ruleType = $Rule.ruleType
    }

    if ($values.ruleType -eq 'RoleManagementPolicyExpirationRule')
    {
        $expirationRule = [ordered]@{
            isExpirationRequired = $Rule.isExpirationRequired
            maximumDuration      = $Rule.maximumDuration
        }
        $values.Add('expirationRule', $expirationRule)
    }

    if ($values.ruleType -eq 'RoleManagementPolicyNotificationRule')
    {
        $notificationRule = [ordered]@{
            notificationType           = $Rule.notificationType
            recipientType              = $Rule.recipientType
            notificationLevel          = $Rule.notificationLevel
            isDefaultRecipientsEnabled = $Rule.isDefaultRecipientsEnabled
            notificationRecipients     = [array]$Rule.notificationRecipients
        }
        $values.Add('notificationRule', $notificationRule)
    }

    if ($values.ruleType -eq 'RoleManagementPolicyEnablementRule')
    {
        $enablementRule = [ordered]@{
            enabledRules = [array]$Rule.enabledRules
        }
        $values.Add('enablementRule', $enablementRule)
    }

    if ($values.ruleType -eq 'RoleManagementPolicyApprovalRule')
    {
        $approvalStages = @()
        $foreachApprovalStages = $Rule.setting.approvalStages
        foreach ($stage in $foreachApprovalStages)
        {
            $primaryApprovers = @()
            foreach ($approver in $stage.primaryApprovers)
            {
                $primaryApprover = @{
                    odataType = $approver.'@odata.type'
                }
                $primaryApprovers += $primaryApprover
            }

            $escalationApprovers = @()
            foreach ($approver in $stage.escalationApprovers)
            {
                $escalationApprover = @{
                    odataType = $approver.'@odata.type'
                }
                $escalationApprovers += $escalationApprover
            }

            $approvalStage = [ordered]@{
                approvalStageTimeOutInDays      = $stage.approvalStageTimeOutInDays
                escalationTimeInMinutes         = $stage.escalationTimeInMinutes
                isApproverJustificationRequired = $stage.isApproverJustificationRequired
                isEscalationEnabled             = $stage.isEscalationEnabled
                escalationApprovers             = [array]$escalationApprovers
                primaryApprovers                = [array]$primaryApprovers
            }

            $approvalStages += $approvalStage
        }

        $setting = [ordered]@{
            approvalMode                     = $Rule.setting.approvalMode
            isApprovalRequired               = $Rule.setting.isApprovalRequired
            isApprovalRequiredForExtension   = $Rule.setting.isApprovalRequiredForExtension
            isRequestorJustificationRequired = $Rule.setting.isRequestorJustificationRequired
            approvalStages                   = [array]$approvalStages
        }
        $approvalRule = [ordered]@{
            setting = $setting
        }
        $values.Add('ApprovalRule', $approvalRule)
    }

    if ($values.ruleType -eq 'RoleManagementPolicyAuthenticationContextRule')
    {
        $authenticationContextRule = [ordered]@{
            isEnabled  = $Rule.isEnabled
            claimValue = $Rule.claimValue
        }
        $values.Add('authenticationContextRule', $authenticationContextRule)
    }

    return $values
}

Export-ModuleMember -Function *-TargetResource
