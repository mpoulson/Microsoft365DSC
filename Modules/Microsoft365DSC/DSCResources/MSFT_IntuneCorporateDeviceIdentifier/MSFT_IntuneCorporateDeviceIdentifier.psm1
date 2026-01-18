Confirm-M365DSCModuleDependency -ModuleName 'MSFT_IntuneCorporateDeviceIdentifier'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Devices,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
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

    Write-Verbose -Message "Getting configuration of Intune Corporate Device Identifiers with Identity {$Identity}"

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

        $nullResult = $PSBoundParameters
        $nullResult.Ensure = 'Absent'
        $nullResult.Devices = @()

        # Get all imported device identities from Intune
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities'
        $allDevices = @()
        
        do
        {
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri
            if ($null -ne $response.value)
            {
                $allDevices += $response.value
            }
            $uri = $response.'@odata.nextLink'
        } while ($null -ne $uri)

        if ($allDevices.Count -eq 0)
        {
            Write-Verbose -Message "No corporate device identifiers found in Intune"
            return $nullResult
        }

        Write-Verbose -Message "Found $($allDevices.Count) corporate device identifiers in Intune"

        # Convert to CIM instances
        $deviceArray = @()
        foreach ($device in $allDevices)
        {
            $deviceHash = @{
                Id                   = $device.id
                SerialNumber         = $device.serialNumber
                IMEI                 = $device.imei
                Manufacturer         = $device.manufacturer
                Model                = $device.model
                Description          = $device.description
                EnrollmentState      = $device.enrollmentState
                Platform             = if ($device.platform) { $device.platform.ToLower() } else { $null }
                LastModifiedDateTime = $device.lastModifiedDateTime
                CreatedDateTime      = $device.createdDateTime
            }
            $deviceArray += $deviceHash
        }

        $results = @{
            Identity              = $Identity
            Devices               = $deviceArray
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
        $Identity,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Devices,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
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

    Write-Verbose -Message "Setting configuration of Intune Corporate Device Identifiers with Identity {$Identity}"

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

    # Get current state
    $currentInstance = Get-TargetResource @PSBoundParameters
    
    if ($Ensure -eq 'Present')
    {
        # Convert CIM instances to hashtables for comparison
        $desiredDevices = @()
        if ($null -ne $Devices)
        {
            foreach ($device in $Devices)
            {
                $desiredDevices += @{
                    SerialNumber = if ($device.SerialNumber) { $device.SerialNumber.Trim() } else { $null }
                    IMEI         = if ($device.IMEI) { $device.IMEI.Trim() } else { $null }
                    Manufacturer = if ($device.Manufacturer) { $device.Manufacturer.Trim() } else { $null }
                    Model        = if ($device.Model) { $device.Model.Trim() } else { $null }
                    Description  = $device.Description
                    Platform     = if ($device.Platform) { $device.Platform.ToLower() } else { $null }
                }
            }
        }

        $currentDevices = @()
        if ($null -ne $currentInstance.Devices)
        {
            foreach ($device in $currentInstance.Devices)
            {
                $currentDevices += @{
                    Id           = $device.Id
                    SerialNumber = if ($device.SerialNumber) { $device.SerialNumber.Trim() } else { $null }
                    IMEI         = if ($device.IMEI) { $device.IMEI.Trim() } else { $null }
                    Manufacturer = if ($device.Manufacturer) { $device.Manufacturer.Trim() } else { $null }
                    Model        = if ($device.Model) { $device.Model.Trim() } else { $null }
                    Description  = $device.Description
                    Platform     = if ($device.Platform) { $device.Platform.ToLower() } else { $null }
                }
            }
        }

        # Find devices to ADD (in desired but not in current)
        $devicesToAdd = @()
        foreach ($desiredDevice in $desiredDevices)
        {
            $found = $false
            foreach ($currentDevice in $currentDevices)
            {
                if (Compare-DeviceIdentifier -Device1 $desiredDevice -Device2 $currentDevice)
                {
                    $found = $true
                    break
                }
            }
            if (-not $found)
            {
                $devicesToAdd += $desiredDevice
            }
        }

        # Find devices to REMOVE (in current but not in desired)
        $devicesToRemove = @()
        foreach ($currentDevice in $currentDevices)
        {
            $found = $false
            foreach ($desiredDevice in $desiredDevices)
            {
                if (Compare-DeviceIdentifier -Device1 $currentDevice -Device2 $desiredDevice)
                {
                    $found = $true
                    break
                }
            }
            if (-not $found)
            {
                $devicesToRemove += $currentDevice
            }
        }

        # Add new devices
        if ($devicesToAdd.Count -gt 0)
        {
            Write-Verbose -Message "Adding $($devicesToAdd.Count) device identifier(s) to Intune"
            
            $importList = @()
            foreach ($device in $devicesToAdd)
            {
                $deviceToImport = @{}
                
                if (-not [System.String]::IsNullOrEmpty($device.SerialNumber))
                {
                    $deviceToImport.serialNumber = $device.SerialNumber
                }
                if (-not [System.String]::IsNullOrEmpty($device.IMEI))
                {
                    $deviceToImport.imei = $device.IMEI
                }
                if (-not [System.String]::IsNullOrEmpty($device.Manufacturer))
                {
                    $deviceToImport.manufacturer = $device.Manufacturer
                }
                if (-not [System.String]::IsNullOrEmpty($device.Model))
                {
                    $deviceToImport.model = $device.Model
                }
                if (-not [System.String]::IsNullOrEmpty($device.Description))
                {
                    $deviceToImport.description = $device.Description
                }
                if (-not [System.String]::IsNullOrEmpty($device.Platform))
                {
                    $deviceToImport.platform = $device.Platform
                }
                
                $importList += $deviceToImport
            }

            $uri = 'https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/importDeviceIdentityList'
            $body = @{
                importedDeviceIdentities = $importList
            }
            
            try
            {
                Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json -Depth 10)
                Write-Verbose -Message "Successfully added $($devicesToAdd.Count) device identifier(s)"
            }
            catch
            {
                Write-Verbose -Message "Error adding device identifiers: $($_.Exception.Message)"
                throw
            }
        }

        # Remove devices not in desired state
        if ($devicesToRemove.Count -gt 0)
        {
            Write-Verbose -Message "Removing $($devicesToRemove.Count) device identifier(s) from Intune"
            
            foreach ($device in $devicesToRemove)
            {
                $uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/$($device.Id)"
                try
                {
                    Invoke-MgGraphRequest -Method DELETE -Uri $uri
                    Write-Verbose -Message "Successfully removed device identifier with Id: $($device.Id)"
                }
                catch
                {
                    Write-Verbose -Message "Error removing device identifier with Id $($device.Id): $($_.Exception.Message)"
                    throw
                }
            }
        }

        if ($devicesToAdd.Count -eq 0 -and $devicesToRemove.Count -eq 0)
        {
            Write-Verbose -Message "No changes needed - current state matches desired state"
        }
    }
    elseif ($Ensure -eq 'Absent')
    {
        # Remove ALL identifiers
        if ($null -ne $currentInstance.Devices -and $currentInstance.Devices.Count -gt 0)
        {
            Write-Verbose -Message "Removing all $($currentInstance.Devices.Count) device identifier(s) from Intune"
            
            foreach ($device in $currentInstance.Devices)
            {
                $uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/$($device.Id)"
                try
                {
                    Invoke-MgGraphRequest -Method DELETE -Uri $uri
                    Write-Verbose -Message "Successfully removed device identifier with Id: $($device.Id)"
                }
                catch
                {
                    Write-Verbose -Message "Error removing device identifier with Id $($device.Id): $($_.Exception.Message)"
                    throw
                }
            }
        }
        else
        {
            Write-Verbose -Message "No device identifiers to remove"
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
        $Identity,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Devices,

        [Parameter()]
        [System.String]
        [ValidateSet('Absent', 'Present')]
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
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Write-Verbose -Message "Testing configuration of Intune Corporate Device Identifiers with Identity {$Identity}"

    $currentValues = Get-TargetResource @PSBoundParameters
    
    Write-Verbose -Message "Current Values: $(Convert-M365DscHashtableToString -Hashtable $currentValues)"
    Write-Verbose -Message "Target Values: $(Convert-M365DscHashtableToString -Hashtable $PSBoundParameters)"

    # If Ensure is Absent, check if there are any devices
    if ($Ensure -eq 'Absent')
    {
        if ($currentValues.Ensure -eq 'Absent' -or $null -eq $currentValues.Devices -or $currentValues.Devices.Count -eq 0)
        {
            Write-Verbose -Message "Test-TargetResource returned $true - No devices present"
            return $true
        }
        else
        {
            Write-Verbose -Message "Test-TargetResource returned $false - Devices still present"
            return $false
        }
    }

    # If Ensure is Present, compare the device arrays
    if ($currentValues.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Test-TargetResource returned $false - No devices currently configured"
        return $false
    }

    # Normalize and compare devices
    $desiredDevices = @()
    if ($null -ne $Devices)
    {
        foreach ($device in $Devices)
        {
            $desiredDevices += @{
                SerialNumber = if ($device.SerialNumber) { $device.SerialNumber.Trim() } else { $null }
                IMEI         = if ($device.IMEI) { $device.IMEI.Trim() } else { $null }
                Manufacturer = if ($device.Manufacturer) { $device.Manufacturer.Trim() } else { $null }
                Model        = if ($device.Model) { $device.Model.Trim() } else { $null }
                Platform     = if ($device.Platform) { $device.Platform.ToLower() } else { $null }
            }
        }
    }

    $currentDevices = @()
    if ($null -ne $currentValues.Devices)
    {
        foreach ($device in $currentValues.Devices)
        {
            $currentDevices += @{
                SerialNumber = if ($device.SerialNumber) { $device.SerialNumber.Trim() } else { $null }
                IMEI         = if ($device.IMEI) { $device.IMEI.Trim() } else { $null }
                Manufacturer = if ($device.Manufacturer) { $device.Manufacturer.Trim() } else { $null }
                Model        = if ($device.Model) { $device.Model.Trim() } else { $null }
                Platform     = if ($device.Platform) { $device.Platform.ToLower() } else { $null }
            }
        }
    }

    # Check if counts match
    if ($desiredDevices.Count -ne $currentDevices.Count)
    {
        Write-Verbose -Message "Test-TargetResource returned $false - Device count mismatch (Desired: $($desiredDevices.Count), Current: $($currentDevices.Count))"
        return $false
    }

    # Check if all desired devices exist in current state
    foreach ($desiredDevice in $desiredDevices)
    {
        $found = $false
        foreach ($currentDevice in $currentDevices)
        {
            if (Compare-DeviceIdentifier -Device1 $desiredDevice -Device2 $currentDevice)
            {
                $found = $true
                break
            }
        }
        if (-not $found)
        {
            Write-Verbose -Message "Test-TargetResource returned $false - Desired device not found in current state"
            return $false
        }
    }

    # Check if all current devices exist in desired state
    foreach ($currentDevice in $currentDevices)
    {
        $found = $false
        foreach ($desiredDevice in $desiredDevices)
        {
            if (Compare-DeviceIdentifier -Device1 $currentDevice -Device2 $desiredDevice)
            {
                $found = $true
                break
            }
        }
        if (-not $found)
        {
            Write-Verbose -Message "Test-TargetResource returned $false - Current device not found in desired state"
            return $false
        }
    }

    Write-Verbose -Message "Test-TargetResource returned $true"
    return $true
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
        $dscContent = ''
        
        # Get all imported device identities
        $uri = 'https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities'
        $allDevices = @()
        
        do
        {
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri
            if ($null -ne $response.value)
            {
                $allDevices += $response.value
            }
            $uri = $response.'@odata.nextLink'
        } while ($null -ne $uri)

        if ($allDevices.Count -eq 0)
        {
            Write-M365DSCHost -Message $Global:M365DSCEmojiGreenCheckMark -CommitWrite
        }
        else
        {
            Write-M365DSCHost -Message "`r`n" -DeferWrite
            Write-M365DSCHost -Message "  |---[$($allDevices.Count)] Corporate Device Identifiers" -CommitWrite
            
            $params = @{
                Identity              = 'CorporateDevices'
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                ApplicationSecret     = $ApplicationSecret
                CertificateThumbprint = $CertificateThumbprint
                ManagedIdentity       = $ManagedIdentity.IsPresent
                AccessTokens          = $AccessTokens
            }

            $results = Get-TargetResource @params
            $results = Update-M365DSCExportAuthenticationResults -ConnectionMode $ConnectionMode `
                -Results $results

            # Build the devices array content
            $devicesArray = @()
            foreach ($device in $allDevices)
            {
                $deviceEntry = @{}
                if (-not [System.String]::IsNullOrEmpty($device.serialNumber))
                {
                    $deviceEntry.SerialNumber = $device.serialNumber
                }
                if (-not [System.String]::IsNullOrEmpty($device.imei))
                {
                    $deviceEntry.IMEI = $device.imei
                }
                if (-not [System.String]::IsNullOrEmpty($device.manufacturer))
                {
                    $deviceEntry.Manufacturer = $device.manufacturer
                }
                if (-not [System.String]::IsNullOrEmpty($device.model))
                {
                    $deviceEntry.Model = $device.model
                }
                if (-not [System.String]::IsNullOrEmpty($device.description))
                {
                    $deviceEntry.Description = $device.description
                }
                if (-not [System.String]::IsNullOrEmpty($device.platform))
                {
                    $deviceEntry.Platform = $device.platform
                }
                $devicesArray += $deviceEntry
            }

            $results.Devices = $devicesArray
            
            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $results `
                -Credential $Credential
            
            $dscContent += $currentDSCBlock
            Save-M365DSCPartialExport -Content $currentDSCBlock `
                -FileName $Global:PartialExportFileName
            
            Write-M365DSCHost -Message "    Exported $($allDevices.Count) device identifier(s)" -CommitWrite
        }

        return $dscContent
    }
    catch
    {
        Write-M365DSCHost -Message $Global:M365DSCEmojiRedX -CommitWrite

        New-M365DSCLogEntry -Message 'Error during Export:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return ''
    }
}

#region Helper Functions
function Compare-DeviceIdentifier
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Device1,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Device2
    )

    # Match on IMEI if both have it
    if (-not [System.String]::IsNullOrEmpty($Device1.IMEI) -and -not [System.String]::IsNullOrEmpty($Device2.IMEI))
    {
        return ($Device1.IMEI -eq $Device2.IMEI)
    }

    # Match on SerialNumber if both have it
    if (-not [System.String]::IsNullOrEmpty($Device1.SerialNumber) -and -not [System.String]::IsNullOrEmpty($Device2.SerialNumber))
    {
        # Case-insensitive comparison for serial numbers
        return ($Device1.SerialNumber.ToLower() -eq $Device2.SerialNumber.ToLower())
    }

    # Match on Manufacturer + Model + SerialNumber if all three are present
    if (-not [System.String]::IsNullOrEmpty($Device1.Manufacturer) -and 
        -not [System.String]::IsNullOrEmpty($Device1.Model) -and 
        -not [System.String]::IsNullOrEmpty($Device1.SerialNumber) -and
        -not [System.String]::IsNullOrEmpty($Device2.Manufacturer) -and 
        -not [System.String]::IsNullOrEmpty($Device2.Model) -and 
        -not [System.String]::IsNullOrEmpty($Device2.SerialNumber))
    {
        return (($Device1.Manufacturer.ToLower() -eq $Device2.Manufacturer.ToLower()) -and 
                ($Device1.Model.ToLower() -eq $Device2.Model.ToLower()) -and
                ($Device1.SerialNumber.ToLower() -eq $Device2.SerialNumber.ToLower()))
    }

    # If we can't determine a match, consider them different
    return $false
}
#endregion

Export-ModuleMember -Function *-TargetResource
