Confirm-M365DSCModuleDependency -ModuleName 'MSFT_AADDomainFederation'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DomainId,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $IssuerUri,

        [Parameter()]
        [System.String]
        $MetadataExchangeUri,

        [Parameter()]
        [System.String]
        $SigningCertificate,

        [Parameter()]
        [System.String]
        $NextSigningCertificate,

        [Parameter()]
        [System.String]
        $PassiveSignInUri,

        [Parameter()]
        [System.String]
        $ActiveSignInUri,

        [Parameter()]
        [System.String]
        $SignOutUri,

        [Parameter()]
        [System.String]
        $PreferredAuthenticationProtocol,

        [Parameter()]
        [System.String]
        $SigningCertificateUpdateStatus,

        [Parameter()]
        [System.String]
        $PromptLoginBehavior,

        [Parameter()]
        [System.String]
        $FederatedIdpMfaBehavior,

        [Parameter()]
        [System.String]
        $PasswordResetUri,

        [Parameter()]
        [System.Boolean]
        $IsSignedAuthenticationRequestRequired,

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

    Write-Verbose -Message "Getting configuration of Azure AD Domain Federation for domain {$DomainId}"

    try
    {
        if (-not $Script:exportedInstance -or $Script:exportedInstance.DomainId -ne $DomainId)
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

            # Get domain to verify it exists
            $domain = Get-MgBetaDomain -DomainId $DomainId -ErrorAction SilentlyContinue
            if ($null -eq $domain)
            {
                Write-Verbose -Message "Domain {$DomainId} not found"
                return $nullResult
            }

            # Get federation configuration for the domain
            $instance = Get-MgBetaDomainFederationConfiguration -DomainId $DomainId -ErrorAction SilentlyContinue

            if ($null -eq $instance -or $instance.Count -eq 0)
            {
                Write-Verbose -Message "No federation configuration found for domain {$DomainId}"
                return $nullResult
            }

            # If multiple configurations exist, take the first one or match by Id if provided
            if ($instance -is [System.Array])
            {
                if (-not [System.String]::IsNullOrEmpty($Id))
                {
                    $instance = $instance | Where-Object -FilterScript { $_.Id -eq $Id }
                }
                else
                {
                    $instance = $instance[0]
                }
            }

            if ($null -eq $instance)
            {
                Write-Verbose -Message "Federation configuration with Id {$Id} not found for domain {$DomainId}"
                return $nullResult
            }
        }
        else
        {
            $instance = $Script:exportedInstance
        }

        # Handle SigningCertificateUpdateStatus which is a complex type from the API
        $signingCertUpdateStatus = $null
        if ($null -ne $instance.SigningCertificateUpdateStatus)
        {
            if ($instance.SigningCertificateUpdateStatus -is [System.String])
            {
                $signingCertUpdateStatus = $instance.SigningCertificateUpdateStatus
            }
            elseif ($null -ne $instance.SigningCertificateUpdateStatus.CertificateUpdateResult)
            {
                $signingCertUpdateStatus = $instance.SigningCertificateUpdateStatus.CertificateUpdateResult
            }
        }

        $results = @{
            DomainId                                = $DomainId
            Id                                      = $instance.Id
            DisplayName                             = $instance.DisplayName
            IssuerUri                               = $instance.IssuerUri
            MetadataExchangeUri                     = $instance.MetadataExchangeUri
            SigningCertificate                      = $instance.SigningCertificate
            NextSigningCertificate                  = $instance.NextSigningCertificate
            PassiveSignInUri                        = $instance.PassiveSignInUri
            ActiveSignInUri                         = $instance.ActiveSignInUri
            SignOutUri                              = $instance.SignOutUri
            PreferredAuthenticationProtocol         = $instance.PreferredAuthenticationProtocol
            SigningCertificateUpdateStatus          = $signingCertUpdateStatus
            PromptLoginBehavior                     = $instance.PromptLoginBehavior
            FederatedIdpMfaBehavior                 = $instance.FederatedIdpMfaBehavior
            PasswordResetUri                        = $instance.PasswordResetUri
            IsSignedAuthenticationRequestRequired   = $instance.IsSignedAuthenticationRequestRequired
            Ensure                                  = 'Present'
            Credential                              = $Credential
            ApplicationId                           = $ApplicationId
            TenantId                                = $TenantId
            ApplicationSecret                       = $ApplicationSecret
            CertificateThumbprint                   = $CertificateThumbprint
            ManagedIdentity                         = $ManagedIdentity.IsPresent
            AccessTokens                            = $AccessTokens
        }

        Write-Verbose -Message "Found federation configuration for domain {$DomainId}"
        Write-Verbose -Message "Current Values: $(Convert-M365DscHashtableToString -Hashtable $results)"

        return $results
    }
    catch
    {
        Write-Verbose -Message $_
        New-M365DSCLogEntry -Message "Error retrieving data:" `
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
        $DomainId,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $IssuerUri,

        [Parameter()]
        [System.String]
        $MetadataExchangeUri,

        [Parameter()]
        [System.String]
        $SigningCertificate,

        [Parameter()]
        [System.String]
        $NextSigningCertificate,

        [Parameter()]
        [System.String]
        $PassiveSignInUri,

        [Parameter()]
        [System.String]
        $ActiveSignInUri,

        [Parameter()]
        [System.String]
        $SignOutUri,

        [Parameter()]
        [System.String]
        $PreferredAuthenticationProtocol,

        [Parameter()]
        [System.String]
        $SigningCertificateUpdateStatus,

        [Parameter()]
        [System.String]
        $PromptLoginBehavior,

        [Parameter()]
        [System.String]
        $FederatedIdpMfaBehavior,

        [Parameter()]
        [System.String]
        $PasswordResetUri,

        [Parameter()]
        [System.Boolean]
        $IsSignedAuthenticationRequestRequired,

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

    Write-Verbose -Message "Setting configuration of Azure AD Domain Federation for domain {$DomainId}"

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
    $setParameters = Remove-M365DSCAuthenticationParameter -BoundParameters $PSBoundParameters

    # Remove parameters that are not valid for the API calls
    $setParameters.Remove('DomainId') | Out-Null
    $setParameters.Remove('Ensure') | Out-Null
    $setParameters.Remove('Id') | Out-Null
    $setParameters.Remove('SigningCertificateUpdateStatus') | Out-Null

    # CREATE
    if ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Creating federation configuration for domain {$DomainId}"

        try
        {
            # Get domain to verify authentication type
            $domain = Get-MgBetaDomain -DomainId $DomainId -ErrorAction Stop

            # Verify domain AuthenticationType is Managed before creating federation configuration
            if ($domain.AuthenticationType -ne 'Managed')
            {
                $message = "Cannot create federation configuration. Domain '$DomainId' must have AuthenticationType 'Managed' but found '$($domain.AuthenticationType)'. " +
                           "Please ensure the domain is set to Managed authentication type before configuring federation."
                Write-Verbose -Message $message
                throw $message
            }

            # Display certificate debug info if signing certificate is provided
            if (-not [System.String]::IsNullOrEmpty($SigningCertificate))
            {
                Write-CertificateDebugInfo -Certificate $SigningCertificate -CertificateName "SigningCertificate"
            }

            if (-not [System.String]::IsNullOrEmpty($NextSigningCertificate))
            {
                Write-CertificateDebugInfo -Certificate $NextSigningCertificate -CertificateName "NextSigningCertificate"
            }

            Write-Verbose -Message "Creating federation configuration with parameters: $(Convert-M365DscHashtableToString -Hashtable $setParameters)"
            $null = New-MgBetaDomainFederationConfiguration -DomainId $DomainId -BodyParameter $setParameters
            Write-Verbose -Message "Successfully created federation configuration for domain {$DomainId}"
        }
        catch
        {
            Write-Verbose -Message $_
            New-M365DSCLogEntry -Message "Error creating federation configuration:" `
                -Exception $_ `
                -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $TenantId `
                -Credential $Credential
            throw
        }
    }
    # UPDATE
    elseif ($Ensure -eq 'Present' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Updating federation configuration for domain {$DomainId}"

        try
        {
            # Display certificate debug info if signing certificate is provided
            if (-not [System.String]::IsNullOrEmpty($SigningCertificate))
            {
                Write-CertificateDebugInfo -Certificate $SigningCertificate -CertificateName "SigningCertificate"
            }

            if (-not [System.String]::IsNullOrEmpty($NextSigningCertificate))
            {
                Write-CertificateDebugInfo -Certificate $NextSigningCertificate -CertificateName "NextSigningCertificate"
            }

            Write-Verbose -Message "Updating federation configuration with parameters: $(Convert-M365DscHashtableToString -Hashtable $setParameters)"
            Update-MgBetaDomainFederationConfiguration -DomainId $DomainId `
                -InternalDomainFederationId $currentInstance.Id `
                -BodyParameter $setParameters
            Write-Verbose -Message "Successfully updated federation configuration for domain {$DomainId}"
        }
        catch
        {
            Write-Verbose -Message $_
            New-M365DSCLogEntry -Message "Error updating federation configuration:" `
                -Exception $_ `
                -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $TenantId `
                -Credential $Credential
            throw
        }
    }
    # REMOVE
    elseif ($Ensure -eq 'Absent' -and $currentInstance.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Removing federation configuration for domain {$DomainId}"

        try
        {
            Remove-MgBetaDomainFederationConfiguration -DomainId $DomainId `
                -InternalDomainFederationId $currentInstance.Id `
                -ErrorAction Stop
            Write-Verbose -Message "Successfully removed federation configuration for domain {$DomainId}"
        }
        catch
        {
            Write-Verbose -Message $_
            New-M365DSCLogEntry -Message "Error removing federation configuration:" `
                -Exception $_ `
                -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $TenantId `
                -Credential $Credential
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
        $DomainId,

        [Parameter()]
        [System.String]
        $Id,

        [Parameter()]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $IssuerUri,

        [Parameter()]
        [System.String]
        $MetadataExchangeUri,

        [Parameter()]
        [System.String]
        $SigningCertificate,

        [Parameter()]
        [System.String]
        $NextSigningCertificate,

        [Parameter()]
        [System.String]
        $PassiveSignInUri,

        [Parameter()]
        [System.String]
        $ActiveSignInUri,

        [Parameter()]
        [System.String]
        $SignOutUri,

        [Parameter()]
        [System.String]
        $PreferredAuthenticationProtocol,

        [Parameter()]
        [System.String]
        $SigningCertificateUpdateStatus,

        [Parameter()]
        [System.String]
        $PromptLoginBehavior,

        [Parameter()]
        [System.String]
        $FederatedIdpMfaBehavior,

        [Parameter()]
        [System.String]
        $PasswordResetUri,

        [Parameter()]
        [System.Boolean]
        $IsSignedAuthenticationRequestRequired,

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

    Write-Verbose -Message "Testing configuration of Azure AD Domain Federation for domain {$DomainId}"

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
    $ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        [array] $domains = Get-MgBetaDomain -ErrorAction Stop
        [array] $Script:exportedInstances = @()

        # Get federation configurations for all domains
        foreach ($domain in $domains)
        {
            try
            {
                $federationConfigs = Get-MgBetaDomainFederationConfiguration -DomainId $domain.Id -ErrorAction SilentlyContinue
                if ($null -ne $federationConfigs)
                {
                    if ($federationConfigs -is [System.Array])
                    {
                        foreach ($config in $federationConfigs)
                        {
                            # Create a new object with the DomainId property
                            $configWithDomain = [PSCustomObject]@{
                                DomainId = $domain.Id
                            }
                            # Copy all properties from the original config
                            $config.PSObject.Properties | ForEach-Object {
                                $configWithDomain | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                            $Script:exportedInstances += $configWithDomain
                        }
                    }
                    else
                    {
                        $federationConfigs | Add-Member -MemberType NoteProperty -Name 'DomainId' -Value $domain.Id -Force
                        $Script:exportedInstances += $federationConfigs
                    }
                }
            }
            catch
            {
                Write-Verbose -Message "No federation configuration found for domain $($domain.Id)"
            }
        }

        $i = 1
        $dscContent = ''
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

            $displayedKey = "$($config.DomainId) - $($config.DisplayName)"
            Write-M365DSCHost -Message "    |---[$i/$($Script:exportedInstances.Count)] $displayedKey" -DeferWrite
            
            $params = @{
                DomainId              = $config.DomainId
                Id                    = $config.Id
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

            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential
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
        Write-Verbose -Message $_
        New-M365DSCLogEntry -Message 'Error during Export:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        throw
    }
}

<#
.SYNOPSIS
    Displays certificate information for debugging purposes.

.DESCRIPTION
    This helper function parses a Base64-encoded X509 certificate string and displays
    key certificate details including thumbprint, subject, issuer, and expiration date.
    Used during Set-TargetResource operations to help administrators verify they are
    using the correct certificates and monitor certificate expiration.

.PARAMETER Certificate
    The Base64-encoded certificate string (without headers/footers).
    Must be a valid Base64 string representing an X509 certificate.

.PARAMETER CertificateName
    A descriptive name for the certificate (e.g., "SigningCertificate" or "NextSigningCertificate").
    Used in the display output to identify which certificate is being shown.

.EXAMPLE
    Write-CertificateDebugInfo -Certificate $SigningCertificate -CertificateName "SigningCertificate"
    
    Displays information about the signing certificate including thumbprint, subject, issuer, and expiration.

.NOTES
    - Validates certificate format before attempting to parse
    - Silently handles invalid certificate formats by writing to verbose stream
    - Does not throw exceptions to avoid disrupting Set operations
#>
function Write-CertificateDebugInfo
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Certificate,

        [Parameter(Mandatory = $true)]
        [System.String]
        $CertificateName
    )

    try
    {
        # Validate certificate string is not empty and appears to be base64
        if ([string]::IsNullOrWhiteSpace($Certificate))
        {
            Write-Verbose -Message "Certificate string is empty or null"
            return
        }

        # Basic validation for base64 format (should only contain valid base64 characters)
        if ($Certificate -notmatch '^[A-Za-z0-9+/]*={0,2}$')
        {
            Write-Verbose -Message "Certificate string does not appear to be valid base64 format"
            return
        }

        $verifyCert = [System.Security.Cryptography.X509Certificates.X509Certificate2][Convert]::FromBase64String($Certificate)
        
        Write-M365DSCHost -Message "====================="
        Write-M365DSCHost -Message "$CertificateName Information"
        Write-M365DSCHost -Message "====================="
        Write-M365DSCHost -Message "Thumbprint: $($verifyCert.Thumbprint)"
        Write-M365DSCHost -Message "Subject: $($verifyCert.Subject)"
        Write-M365DSCHost -Message "Issuer: $($verifyCert.Issuer)"
        Write-M365DSCHost -Message "Expires: $($verifyCert.NotAfter)"
        Write-M365DSCHost -Message "====================="
    }
    catch
    {
        Write-Verbose -Message "Error parsing certificate: $_"
    }
}

Export-ModuleMember -Function *-TargetResource
