<#
This example demonstrates certificate rollover for a federation configuration
by specifying both the current SigningCertificate and NextSigningCertificate.
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
        AADFederationConfiguration "MyFederationWithRollover"
        {
            IssuerUri                       = 'https://contoso.com/issuerUri'
            DisplayName                     = 'contoso display name'
            PassiveSignInUri                = 'https://contoso.com/signin'
            PreferredAuthenticationProtocol = 'wsFed'
            Domains                         = @('contoso.com')
            SigningCertificate              = 'MIIDADCCAeigAwIBAgIQEX41y8r6...' # Current certificate
            NextSigningCertificate          = 'MIIDATCCAemgAwIBAgIRANEXample...' # Next certificate for rollover
            Ensure                          = 'Present'
            ApplicationId                   = $ApplicationId
            TenantId                        = $TenantId
            CertificateThumbprint           = $CertificateThumbprint
        }
    }
}
