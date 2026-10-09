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
        AzureConsumptionBudget "AzureConsumptionBudget-MonthlyPlatformBudget"
        {
            Amount                = 7500; # Drift
            ApplicationId         = $ApplicationId;
            Category              = "Cost";
            CertificateThumbprint = $CertificateThumbprint;
            Ensure                = "Present";
            FilterDimensions      = @(
                MSFT_AzureConsumptionBudgetFilterDimension{
                    Name = 'ResourceGroupName'
                    Operator = 'In'
                    Values = @('rg-platform-prod')
                }
            );
            Name                  = "MonthlyPlatformBudget";
            Notifications         = @(
                MSFT_AzureConsumptionBudgetNotification{
                    Name = 'Actual_GreaterThan_80_Percent'
                    Enabled = $True
                    Operator = 'GreaterThan'
                    Threshold = 80
                    ThresholdType = 'Actual'
                    ContactEmails = @('finops@contoso.com')
                    ContactRoles = @('Owner')
                    Locale = 'en-us'
                }
                MSFT_AzureConsumptionBudgetNotification{
                    Name = 'Forecasted_GreaterThan_100_Percent'
                    Enabled = $True
                    Operator = 'GreaterThan'
                    Threshold = 100
                    ThresholdType = 'Forecasted'
                    ContactEmails = @('finops@contoso.com')
                    Locale = 'en-us'
                }
            );
            Scope                 = "/subscriptions/00000000-0000-0000-0000-000000000000";
            StartDate             = "2026-10-01T00:00:00Z";
            TenantId              = $TenantId;
            TimeGrain             = "Monthly";
        }
    }
}
