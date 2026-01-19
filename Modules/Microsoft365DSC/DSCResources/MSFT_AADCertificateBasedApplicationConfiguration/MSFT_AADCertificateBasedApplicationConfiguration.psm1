Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AADCertificateBasedApplicationConfiguration'

function ConvertTo-M365DSCBase64CertificateValue
{
    param(
        [Parameter()]
        $CertificateValue
    )

    if ($CertificateValue -is [System.Security.Cryptography.X509Certificates.X509Certificate2])
    {
        return [System.Convert]::ToBase64String($CertificateValue.RawData)
    }
    elseif ($CertificateValue -is [System.Byte[]])
    {
        return [System.Convert]::ToBase64String($CertificateValue)
    }
    elseif ($null -ne $CertificateValue -and -not ($CertificateValue -is [System.String]))
    {
        return $CertificateValue.ToString()
    }

    return $CertificateValue
}

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
        $Id,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.Object[]]
        $TrustedCertificateAuthorities,

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

    Write-Verbose -Message "Getting configuration of Certificate-Based Application Configuration '$DisplayName'"

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
    
    try
    {
        if ($null -ne $Script:exportedInstances -and $Script:ExportMode)
        {
            $instance = $Script:exportedInstances | Where-Object -FilterScript {$_.Id -eq $Id}
        }
        else
        {
            if (-not [System.String]::IsNullOrEmpty($Id))
            {
                $instance = Get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration `
                    -CertificateBasedApplicationConfigurationId $Id `
                    -ErrorAction SilentlyContinue
            }
            else
            {
                $instances = Get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration -All `
                    -ErrorAction SilentlyContinue
                $instance = $instances | Where-Object -FilterScript {$_.DisplayName -eq $DisplayName}
            }
        }

        if ($null -eq $instance)
        {
            return $nullResult
        }

        # Get trusted certificate authorities using the dedicated cmdlet
        $trustedCAs = @()
        try
        {
            $certificateAuthorities = Get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfigurationTrustedCertificateAuthority `
                -CertificateBasedApplicationConfigurationId $instance.Id `
                -ErrorAction SilentlyContinue
            
            foreach ($ca in $certificateAuthorities)
            {
                $certificateValue = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $ca.Certificate

                $trustedCAs += @{
                    Certificate                 = $certificateValue
                    IsRootAuthority             = [System.Boolean]$ca.IsRootAuthority
                    Issuer                      = $ca.Issuer
                    IssuerSubjectKeyIdentifier  = $ca.IssuerSubjectKeyIdentifier
                }
            }
        }
        catch
        {
            Write-Verbose -Message "Could not retrieve certificate authorities: $_"
        }

        $results = @{
            DisplayName                   = $instance.DisplayName
            Id                            = $instance.Id
            Description                   = $instance.Description
            TrustedCertificateAuthorities = $trustedCAs
            Ensure                        = 'Present'
            Credential                    = $Credential
            ApplicationId                 = $ApplicationId
            TenantId                      = $TenantId
            CertificateThumbprint         = $CertificateThumbprint
            ManagedIdentity               = $ManagedIdentity.IsPresent
            AccessTokens                  = $AccessTokens
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
        $DisplayName,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.Object[]]
        $TrustedCertificateAuthorities,

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

    Write-Verbose -Message "Setting configuration of Certificate-Based Application Configuration '$DisplayName'"

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

    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Creating new Certificate-Based Application Configuration: $DisplayName"
        
        $params = @{
            DisplayName = $DisplayName
        }
        
        if (-not [System.String]::IsNullOrEmpty($Description))
        {
            $params.Description = $Description
        }

        try
        {
            if ($null -ne $TrustedCertificateAuthorities)
            {
                $params.trustedCertificateAuthorities = @()
                foreach ($ca in $TrustedCertificateAuthorities)
                {
                    $normalizedCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $ca.Certificate
                    $caParams = @{
                        Certificate     = $normalizedCertificate
                        IsRootAuthority = $ca.IsRootAuthority
                    }
                    
                    if (-not [System.String]::IsNullOrEmpty($ca.Issuer))
                    {
                        $caParams.Issuer = $ca.Issuer
                    }
                    
                    if (-not [System.String]::IsNullOrEmpty($ca.IssuerSubjectKeyIdentifier))
                    {
                        $caParams.IssuerSubjectKeyIdentifier = $ca.IssuerSubjectKeyIdentifier
                    }

                    $params.trustedCertificateAuthorities += $caParams
                }
            }

            $newConfig = New-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration -BodyParameter $params
        }
        catch
        {
            Write-Verbose -Message "Error creating certificate configuration: $_"
            throw
        }
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating Certificate-Based Application Configuration: $DisplayName"
        
        $updateParams = @{
            DisplayName = $DisplayName
        }
        
        if (-not [System.String]::IsNullOrEmpty($Description))
        {
            $updateParams.Description = $Description
        }

        try
        {
            Update-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration `
                -CertificateBasedApplicationConfigurationId $currentInstance.Id `
                -BodyParameter $updateParams
            
            # Compare and update trusted certificate authorities
            # Note: For simplicity, we'll check if the count differs or if any certificate data changed
            $updateCAs = $false
            
            if ($null -eq $TrustedCertificateAuthorities -and $null -ne $currentInstance.TrustedCertificateAuthorities)
            {
                $updateCAs = $true
            }
            elseif ($null -ne $TrustedCertificateAuthorities -and $null -eq $currentInstance.TrustedCertificateAuthorities)
            {
                $updateCAs = $true
            }
            elseif ($null -ne $TrustedCertificateAuthorities -and $null -ne $currentInstance.TrustedCertificateAuthorities)
            {
                if ($TrustedCertificateAuthorities.Count -ne $currentInstance.TrustedCertificateAuthorities.Count)
                {
                    $updateCAs = $true
                }
                else
                {
                    # Check if any certificate differs
                    for ($i = 0; $i -lt $TrustedCertificateAuthorities.Count; $i++)
                    {
                        $desiredCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $TrustedCertificateAuthorities[$i].Certificate
                        $currentCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $currentInstance.TrustedCertificateAuthorities[$i].Certificate
                        if ($desiredCertificate -ne $currentCertificate -or
                            $TrustedCertificateAuthorities[$i].IsRootAuthority -ne $currentInstance.TrustedCertificateAuthorities[$i].IsRootAuthority -or
                            $TrustedCertificateAuthorities[$i].Issuer -ne $currentInstance.TrustedCertificateAuthorities[$i].Issuer -or
                            $TrustedCertificateAuthorities[$i].IssuerSubjectKeyIdentifier -ne $currentInstance.TrustedCertificateAuthorities[$i].IssuerSubjectKeyIdentifier)
                        {
                            $updateCAs = $true
                            break
                        }
                    }
                }
            }
            
            if ($updateCAs)
            {
                Write-Verbose -Message "Certificate authorities need to be updated"
                
                # Get current certificate authorities to compare
                $currentCAs = @()
                try
                {
                    $currentCertAuthorities = Get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfigurationTrustedCertificateAuthority `
                        -CertificateBasedApplicationConfigurationId $currentInstance.Id `
                        -ErrorAction SilentlyContinue
                    
                    if ($null -ne $currentCertAuthorities)
                    {
                        $currentCAs = $currentCertAuthorities
                    }
                }
                catch
                {
                    Write-Verbose -Message "Could not retrieve current certificate authorities: $_"
                }
                
                # Remove certificate authorities that are no longer needed
                foreach ($currentCA in $currentCAs)
                {
                    $found = $false
                    if ($null -ne $TrustedCertificateAuthorities)
                    {
                        foreach ($desiredCA in $TrustedCertificateAuthorities)
                        {
                            $desiredCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $desiredCA.Certificate
                            $currentCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $currentCA.Certificate
                            if ($currentCertificate -eq $desiredCertificate)
                            {
                                $found = $true
                                break
                            }
                        }
                    }
                    
                    if (-not $found)
                    {
                        Write-Verbose -Message "Removing certificate authority: $($currentCA.Issuer)"
                        try
                        {
                            Remove-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfigurationTrustedCertificateAuthority `
                                -CertificateBasedApplicationConfigurationId $currentInstance.Id `
                                -CertificateAuthorityAsEntityId $currentCA.Id `
                                -ErrorAction Stop
                        }
                        catch
                        {
                            Write-Verbose -Message "Error removing certificate authority: $_"
                        }
                    }
                }
                
                # Add or update certificate authorities
                if ($null -ne $TrustedCertificateAuthorities)
                {
                    foreach ($desiredCA in $TrustedCertificateAuthorities)
                    {
                        $existingCA = $null
                        foreach ($currentCA in $currentCAs)
                        {
                            $desiredCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $desiredCA.Certificate
                            $currentCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $currentCA.Certificate
                            if ($currentCertificate -eq $desiredCertificate)
                            {
                                $existingCA = $currentCA
                                break
                            }
                        }
                        
                        if ($null -eq $existingCA)
                        {
                            # Add new certificate authority
                            Write-Verbose -Message "Adding certificate authority: $($desiredCA.Issuer)"
                            $normalizedCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $desiredCA.Certificate
                            $caParams = @{
                                Certificate     = $normalizedCertificate
                                IsRootAuthority = $desiredCA.IsRootAuthority
                            }
                            
                            if (-not [System.String]::IsNullOrEmpty($desiredCA.Issuer))
                            {
                                $caParams.Issuer = $desiredCA.Issuer
                            }
                            
                            if (-not [System.String]::IsNullOrEmpty($desiredCA.IssuerSubjectKeyIdentifier))
                            {
                                $caParams.IssuerSubjectKeyIdentifier = $desiredCA.IssuerSubjectKeyIdentifier
                            }
                            
                            try
                            {
                                New-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfigurationTrustedCertificateAuthority `
                                    -CertificateBasedApplicationConfigurationId $currentInstance.Id `
                                    -BodyParameter $caParams
                            }
                            catch
                            {
                                Write-Verbose -Message "Error adding certificate authority: $_"
                            }
                        }
                        else
                        {
                            # Update existing certificate authority if needed
                            $needsUpdate = $false
                            if ($existingCA.IsRootAuthority -ne $desiredCA.IsRootAuthority -or
                                $existingCA.Issuer -ne $desiredCA.Issuer -or
                                $existingCA.IssuerSubjectKeyIdentifier -ne $desiredCA.IssuerSubjectKeyIdentifier)
                            {
                                $needsUpdate = $true
                            }
                            
                            if ($needsUpdate)
                            {
                                Write-Verbose -Message "Updating certificate authority: $($desiredCA.Issuer)"
                                $normalizedCertificate = ConvertTo-M365DSCBase64CertificateValue -CertificateValue $desiredCA.Certificate
                                $updateCAParams = @{
                                    Certificate     = $normalizedCertificate
                                    IsRootAuthority = $desiredCA.IsRootAuthority
                                }
                                
                                if (-not [System.String]::IsNullOrEmpty($desiredCA.Issuer))
                                {
                                    $updateCAParams.Issuer = $desiredCA.Issuer
                                }
                                
                                if (-not [System.String]::IsNullOrEmpty($desiredCA.IssuerSubjectKeyIdentifier))
                                {
                                    $updateCAParams.IssuerSubjectKeyIdentifier = $desiredCA.IssuerSubjectKeyIdentifier
                                }
                                
                                try
                                {
                                    Update-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfigurationTrustedCertificateAuthority `
                                        -CertificateBasedApplicationConfigurationId $currentInstance.Id `
                                        -CertificateAuthorityAsEntityId $existingCA.Id `
                                        -BodyParameter $updateCAParams
                                }
                                catch
                                {
                                    Write-Verbose -Message "Error updating certificate authority: $_"
                                }
                            }
                        }
                    }
                }
            }
        }
        catch
        {
            Write-Verbose -Message "Error updating certificate configuration: $_"
            throw
        }
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing Certificate-Based Application Configuration: $DisplayName"
        
        try
        {
            Remove-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration `
                -CertificateBasedApplicationConfigurationId $currentInstance.Id
        }
        catch
        {
            Write-Verbose -Message "Error removing certificate configuration: $_"
            throw
        }
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
        $Id,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.Object[]]
        $TrustedCertificateAuthorities,

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
        $Script:ExportMode = $true
        [array] $Script:exportedInstances = Get-MgBetaDirectoryCertificateAuthorityCertificateBasedApplicationConfiguration -All -ErrorAction Stop

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

            $displayedKey = $config.DisplayName
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -DeferWrite
            
            $params = @{
                DisplayName           = $config.DisplayName
                Id                    = $config.Id
                Description           = $config.Description
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $Results = Get-TargetResource @Params
            
            if ($null -ne $Results.TrustedCertificateAuthorities -and $Results.TrustedCertificateAuthorities.Count -gt 0)
            {
                $complexMapping = @(
                    @{
                        Name            = 'TrustedCertificateAuthorities'
                        CimInstanceName = 'AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority'
                        IsRequired      = $False
                    }
                )
                
                $complexTypeStringResult = Get-M365DSCDRGComplexTypeToString `
                    -ComplexObject $Results.TrustedCertificateAuthorities `
                    -CIMInstanceName 'AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority' `
                    -ComplexTypeMapping $complexMapping

                if (-not [String]::IsNullOrWhiteSpace($complexTypeStringResult))
                {
                    $Results.TrustedCertificateAuthorities = $complexTypeStringResult
                }
                else
                {
                    $Results.Remove('TrustedCertificateAuthorities') | Out-Null
                }
            }
            else
            {
                $Results.Remove('TrustedCertificateAuthorities') | Out-Null
            }

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential `
                -NoEscape @('TrustedCertificateAuthorities')
                
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

        return ''
    }
}

Export-ModuleMember -Function *-TargetResource
