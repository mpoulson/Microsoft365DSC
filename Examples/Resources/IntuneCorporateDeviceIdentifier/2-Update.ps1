<#
This example updates corporate device identifiers by adding an additional device.
#>

Configuration Example
{
    param(
        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Import-DscResource -ModuleName Microsoft365DSC

    node localhost
    {
        IntuneCorporateDeviceIdentifier 'CorporateDevices'
        {
            Identity              = 'CorporateDevices'
            Devices               = @(
                MSFT_IntuneCorporateDeviceIdentifier {
                    SerialNumber = 'ABC123456'
                    Manufacturer = 'Dell Inc.'
                    Model        = 'Latitude 7490'
                    Description  = 'Corporate laptop'
                    Platform     = 'windows'
                }
                MSFT_IntuneCorporateDeviceIdentifier {
                    IMEI         = '353456789012345'
                    Description  = 'Corporate phone'
                    Platform     = 'android'
                }
                MSFT_IntuneCorporateDeviceIdentifier {
                    SerialNumber = 'XYZ987654'
                    Manufacturer = 'Apple Inc.'
                    Model        = 'MacBook Pro'
                    Description  = 'Executive laptop'
                    Platform     = 'macOS'
                }
            )
            Ensure                = 'Present'
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
        }
    }
}
