<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.
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
        AzureDataCollectionRule "AzureDataCollectionRule-WindowsSecurityEventsAMA"
        {
            Name                     = "WindowsSecurityEventsAMA";
            ResourceGroupName        = "log-monitoring-001";
            Location                 = "usgovarizona";
            Description              = "Collects Windows Security and System Event Logs via the Azure Monitor Agent."; # Updated
            Kind                     = "Windows";
            WindowsEventLogs         = @(
                MSFT_AzureDataCollectionRuleWindowsEventLog{
                    Name         = 'eventLogsDataSource'
                    Streams      = @('Microsoft-SecurityEvent')
                    XPathQueries = @('Security!*[System[(band(Keywords,13510798882111488))]]', 'System!*') # Added System channel
                }
            );
            LogAnalyticsDestinations = @(
                MSFT_AzureDataCollectionRuleLogAnalyticsDestination{
                    Name                = 'centralWorkspace'
                    WorkspaceResourceId = "/subscriptions/f854132c-570e-4c98-a4c9-3cd902de77dd/resourceGroups/log-monitoring-001/providers/Microsoft.OperationalInsights/workspaces/MySentinelWorkspace"
                }
            );
            DataFlows                = @(
                MSFT_AzureDataCollectionRuleDataFlow{
                    Streams      = @('Microsoft-SecurityEvent')
                    Destinations = @('centralWorkspace')
                }
            );
            Ensure                   = "Present";
            ApplicationId            = $ApplicationId;
            TenantId                 = $TenantId;
            CertificateThumbprint    = $CertificateThumbprint;
        }
    }
}
