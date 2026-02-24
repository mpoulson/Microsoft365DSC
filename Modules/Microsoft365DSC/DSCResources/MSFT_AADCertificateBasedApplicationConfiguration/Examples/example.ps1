Configuration Entra {
    param
    (
        [Parameter()]
        [System.String]
        $Domain,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $TenantGuid,

        [Parameter()]
        [System.String]
        $Thumbprint,

        [Parameter()]
        [System.String]
        $Environment,

        [Parameter()]
        [hashtable]
        $ExemptObjects,

        [Parameter()]
        [hashtable]
        $ObjectSets,

        [Parameter()]
        [hashtable]
        $AADGroupMembershipRule,

        [Parameter()]
        [hashtable]
        $PIMSettings,

        [Parameter()]
        [hashtable]
        $ConditionalAccessStatus,

        [Parameter()]
        [hashtable]
        $PIMRoles,

        [Parameter()]
        [hashtable]
        $TenantNames
    )

    Import-DscResource -ModuleName Microsoft365DSC

    AADTenantAppManagementPolicy "AADTenantAppManagementPolicy-Default app management tenant policy"
    {
        ApplicationRestrictions      = MSFT_AADTenantAppManagementPolicyRestrictions{
            keyCredentials = @(
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    maxLifetime = "P366DT0H0M0S"
                    restrictForAppsCreatedAfterDateTime = "2024-11-11T00:00:00.0000000Z"
                    restrictionType = "asymmetricKeyLifetime"
                    state = "enabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    certificateBasedApplicationConfigurationIds = @(
                        "2df02f35-eae6-4d49-afed-7d20ec1d581a"
                    )
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "trustedCertificateAuthority"
                    state = "enabled"
                }
            )
            passwordCredentials = @(
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "passwordAddition"
                    state = "disabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    maxLifetime = "P0DT0H0M0S"
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "passwordLifetime"
                    state = "disabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "customPasswordAddition"
                    state = "enabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "symmetricKeyAddition"
                    state = "enabled"
                }
            )
        };
        Description                  = "Default tenant policy that enforces app management restrictions on applications and service principals. To apply policy to targeted resources, create a new policy under appManagementPolicies collection.";
        DisplayName                  = "Default app management tenant policy";
        Ensure                       = "Present";
        IsEnabled                    = $True;
        ServicePrincipalRestrictions = MSFT_AADTenantAppManagementPolicyRestrictions{
            keyCredentials = @(
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    maxLifetime = "P366DT0H0M0S"
                    restrictForAppsCreatedAfterDateTime = "2024-11-11T00:00:00.0000000Z"
                    restrictionType = "asymmetricKeyLifetime"
                    state = "enabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    certificateBasedApplicationConfigurationIds = @(
                        "2df02f35-eae6-4d49-afed-7d20ec1d581a"
                    )
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "trustedCertificateAuthority"
                    state = "enabled"
                }
            )
            passwordCredentials = @(
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "passwordAddition"
                    state = "disabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    maxLifetime = "P0DT0H0M0S"
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "passwordLifetime"
                    state = "disabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "customPasswordAddition"
                    state = "enabled"
                }
                MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                    restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                    restrictionType = "symmetricKeyAddition"
                    state = "enabled"
                }
            )
        };
        ApplicationId           = $ApplicationId
        TenantId                = $TenantId
        CertificateThumbprint   = $Thumbprint
    }
    AADAppManagementPolicy "AADAppManagementPolicy-366D Carlsbad KCSLS CA"
        {
            ApplicationId         = $ConfigurationData.NonNodeData.ApplicationId;
            CertificateThumbprint = $ConfigurationData.NonNodeData.CertificateThumbprint;
            Description           = "Service Principal policy allow certs from the Carlsbad KCSLS cert chain and 91 day passwords";
            DisplayName           = "366D Carlsbad KCSLS CA";
            Ensure                = "Present";
            Id                    = "c3d19700-9c4f-4598-a24b-193f08d68d62";
            IsEnabled             = $True;
            Restrictions          = MSFT_AADAppManagementPolicyRestrictions{
                keyCredentials = @(
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        maxLifetime = "P366DT0H0M0S"
                        restrictForAppsCreatedAfterDateTime = "2020-11-01T00:00:00.0000000Z"
                        restrictionType = "asymmetricKeyLifetime"
                        state = "enabled"
                    }
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        certificateBasedApplicationConfigurationIds = @("75e34282-dbd7-4662-83ab-04601ae7249c")
                        restrictForAppsCreatedAfterDateTime = "2020-11-01T00:00:00.0000000Z"
                        restrictionType = "trustedCertificateAuthority"
                        state = "enabled"
                    }
                )
                passwordCredentials = @(
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2020-11-01T00:00:00.0000000Z"
                        restrictionType = "passwordAddition"
                        state = "enabled"
                    }
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        maxLifetime = "P0DT0H0M0S"
                        restrictForAppsCreatedAfterDateTime = "2020-11-01T00:00:00.0000000Z"
                        restrictionType = "passwordLifetime"
                        state = "enabled"
                    }
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2020-11-01T00:00:00.0000000Z"
                        restrictionType = "customPasswordAddition"
                        state = "enabled"
                    }
                    MSFT_AADAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2020-11-01T00:00:00.0000000Z"
                        restrictionType = "symmetricKeyAddition"
                        state = "enabled"
                    }
                )
            };
            TenantId              = $OrganizationName;
        }
        AADCertificateBasedApplicationConfiguration "AADCertificateBasedApplicationConfiguration-Carlsbad Root CA - KCSLS Chain"
        {
            ApplicationId                 = $ConfigurationData.NonNodeData.ApplicationId;
            CertificateThumbprint         = $ConfigurationData.NonNodeData.CertificateThumbprint;
            Description                   = "Carlsbad Root CA - KCSLS Chain";
            DisplayName                   = "Carlsbad Root CA - KCSLS Chain";
            Ensure                        = "Present";
            Id                            = "234762af-b29d-43c6-8ef1-ffdb8ed55038";
            TenantId                      = $OrganizationName;
            TrustedCertificateAuthorities = @(
                MSFT_AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority{
                    Certificate = "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"
                    IsRootAuthority = $False
                }
                MSFT_AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority{
                    Certificate = "MIIFnzCCA4egAwIBAgIRAMhtuUapDVf0g1vHYTd6+iMwDQYJKoZIhvcNAQELBQAwaTEeMBwGA1UECgwVQW1hem9uIFByb2plY3QgS3VpcGVyMS4wLAYDVQQLDCVLdWlwZXIgSWRlbnRpdHkgYW5kIEFjY2VzcyBNYW5hZ2VtZW50MRcwFQYDVQQDDA5LSVBLSVJvb3RQcm9kMDAeFw0yNTAxMjkyMDMyNDZaFw0zNTAxMjkyMTMyMjhaMGkxHjAcBgNVBAoMFUFtYXpvbiBQcm9qZWN0IEt1aXBlcjEuMCwGA1UECwwlS3VpcGVyIElkZW50aXR5IGFuZCBBY2Nlc3MgTWFuYWdlbWVudDEXMBUGA1UEAwwOS0lQS0lSb290UHJvZDAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCR8K3ydvMp4Ki2EasPpjJPd/kabUxuwwiuJd7lIHWt3OCiRn8u80MGMZ6u8vE3/w2RuQBTjg4gW/kkAlnMsOcYtx36zT4wA4lAZF+89S5QBtx7eLPyhY3/4OWK6jj05oPoNsQMdz02JT75BaOWFpufZDEoVdtJAgNVhFNDQi+P0c5IQ1AK4ZKL3RtamIMBCqazn6Ki2tktW+/utOoWqnP2dowQwkBHPShgsxDutjGpep48aiRqLmQ7188P38n56SbjIXBhYNZ+B74e76gvEbbdqQmqKlLy9zqu5XSHq8JgTdrBV0HZ73f6OSRqsfQlDmuxf8DdUJi/RWemeqwu/zWW2KXfHls0GRhw94RdXscu9Engz7XblA8r+p5U0QM7UH5zL9kmS84/53pJbm3EKqUJ4TUrT0tCGiXZv8Z6F2v+EffqU9/vadVT9PPi+cd/IQCnT36sfvd6GBaHRuRRi15wDfxWprIr8g4E3BE3IP9NGyr0kqwmdaAwSrnjijt/ntjqq6Cw9gEaK98QN5z7PAJ2TaCVUomWO7+g4h6/CM02+aBSCRqewVP5cphL11WyD/cmp8ohp0lBrxEsFtOEaV0K9QbZ156+Uw/5noD2fDER7Ey32QQD2hvdRZNIPzy+wHAZOBk4jZe95p7sjdkzalsV+xyX2xTJKs1OTg1UonrMVQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSPczS7K9jV6R/++r/34yGT/HcuFDAOBgNVHQ8BAf8EBAMCAYYwDQYJKoZIhvcNAQELBQADggIBAFESHDwZP5jSerLxn8IwJj3qoDkxHRmqjpbp8Ky1DyI0rBSGGyrJihPTT6QQcQLYr4Bbu4EpgWha9/5W0xijkKSFift5HcmoJF6fMjPQgo3VXEFvCRbu+K8zKYieU/9c+jksrSCZN+3162+uHRnriuTCn7wvw+zRvM/jIaQKZdvHtqRZSswMh62/cAJTjVbjUCi4OHMcHttVegf9jE1pXMAnH/8Qbgmk4xcgLMyE+oSOr3xEL73wSD01i0qRvqNsufbBJqhxUbDekhGx7YSI+Lx+dOuW9dtezUafZl0iTl38VJ45D7IaQcVchLpKfNEnrduZJziNxtdiS0u6w0BrDVe8yvgmipWknfovA/RedXAIdVJAdnmmCEKpJSFOXRpcrlADLolFXfOa6G/1Mpw+c4JhdZHZ8ldamDAh26ylbIWSIvaHXzEtCEmu/+EV9gx2Ed0bf+7K/mtHIDu0+4BZ8gl3qKi8Kd0rM2ZCEh9kESNXpe8pGlX4xpV3QlyM7zuSfaYZip2eTzx7nghDMyQMZiA4oLe/1Tog/+GJZIhUO76EDz9m05zhobNGVMVdbDJH3OmkuuxEDnLS4ItYai7ifda+NLtdR353uHhGHn+xAyavtoR3MtWVpnYOKsCGcboP5afs5f0iVh9u8NcFhdy/sujxWCk62DKxlg3gIbHf2AuW"
                    IsRootAuthority = $True
                }
            );
        }
        AADCertificateBasedApplicationConfiguration "AADCertificateBasedApplicationConfiguration-Carlsbad Root CA"
        {
            ApplicationId                 = $ConfigurationData.NonNodeData.ApplicationId;
            CertificateThumbprint         = $ConfigurationData.NonNodeData.CertificateThumbprint;
            Description                   = "Carlsbad Root CA";
            DisplayName                   = "Carlsbad Root CA";
            Ensure                        = "Present";
            Id                            = "2df02f35-eae6-4d49-afed-7d20ec1d581a";
            TenantId                      = $OrganizationName;
            TrustedCertificateAuthorities = @(
                MSFT_AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority{
                    Certificate = "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"
                    IsRootAuthority = $False
                }
                MSFT_AADCertificateBasedApplicationConfigurationTrustedCertificateAuthority{
                    Certificate = "MIIFqDCCA5CgAwIBAgIQVs7qhc/7chZ3E8j1Ym2sZzANBgkqhkiG9w0BAQsFADBuMR4wHAYDVQQKDBVBbWF6b24gUHJvamVjdCBLdWlwZXIxJjAkBgNVBAsMHUt1aXBlciBFbnRlcnByaXNlIEVuZ2luZWVyaW5nMSQwIgYDVQQDDBtLdWlwZXJNMzY1VGVzdFRlbmFudHNSb290LTAwHhcNMjQxMDA0MjEwOTMzWhcNMzQxMDA0MjIwOTA1WjBuMR4wHAYDVQQKDBVBbWF6b24gUHJvamVjdCBLdWlwZXIxJjAkBgNVBAsMHUt1aXBlciBFbnRlcnByaXNlIEVuZ2luZWVyaW5nMSQwIgYDVQQDDBtLdWlwZXJNMzY1VGVzdFRlbmFudHNSb290LTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC+fN8++9KuPok7hTTtSpzWtNskYQtITcHQ0L7KPxurBH+gJd6YDVBR4Qz6FEf8EGGknwyKnUaix0ykJq53YhRLS3rzdxfD6P8GISn0399ZeMzG5bylj16pyA2/CJE9Xs9e+RBE6hOm3KSs1Pw6nx9JQIWW0b9fp2pzpLFfQPt1BfligI2N9I1FZnzh8sCJKogMZvMKi0NKZFotM9tjadPDG4CvP91YKYKfqwnWayte1Aiq6j68D3x2u7qbSexA5n2ozJ1TCv7Fvyb53gLM2gGGmj2Do4uUBzGVO64+nlCJkFX3yYTDUnqGaTwDjTRZfZ67Z5sx333Gin1zlTZjgMazAWp2eh6iCmVPB9G5QydzMa9K/79gAJa/1Po/Bo1+5R6hYuwkheLNKLv2X6njrbFo8O6HbD1GPvHLH2yS5J9urXmI7VhwsaE0uNyTOtdbq3sfkMviDsgsb+ccW8QWZDrf9kJW4+ruJfhzcdGb/dqZBWcjf/xden9lrNhYzX8jgdH+bU5UCHEFA6gLyIOw/xZvbWX7qnrHkiMkGXSKXhzhcNeBWbc1NmPn+hAfQPoA0BlqGbz2KQbKupOxPD+DIMCkiow/sjQEQLJzGkVOvgO3HXbQ05uxTa9sApBrnxRuYSGC5TWYUMNf1UgltWGinas19y1KGuXr0aZVs8OklDbcTwIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQwHkky1Kyf4c0pDvsLbVBzxNr5ATAOBgNVHQ8BAf8EBAMCAYYwDQYJKoZIhvcNAQELBQADggIBACXVpSrMuWMWZIKUGZ7M+VnJVJU/VJXdUQlV1xjhxYKAHDPLbmQ2EakKV13HoS3cQF+kF8h3RJTH2ryo9/Tk6yoSgZyMeSW/GiDpTOBnOu0oRU3SBPpvG9QoZyXSdD2FxrGaTd4dOIm57vlyHAt5H0Cqw6tiuGViVthHbPcT/GZ5NHyO8pEba0sxIupeezzUP/XtWlu/VVzH5LO3EKwPn6UEDmsSkWphPOc+ygzm1Pxso3m4fOmtNeW2M2zIYP3WmXuhR4+Ec+b3aWZayNwJoyKta/uDwtTcCHWXd377eOqJH02JMhyzc3SuaW2G9vHP1KljHbL9gIVi93czkG59TfI9XXS5UB1lXvILX1kXka/eWvusNlpve5D+iLr4MB2+CgYFy7QcoEJsmLRtLKaEiTkN+t4AWY6YBOlX/1I/5ZIjLAAyM634uFwd2/MYY+Bzmu+sQRGVRxDiPM6dN65TaenKyNMPJzS+Qbqby+qPmkwovI7coSYC5x05q5bmdttTrp+af9eYxudoqoYqGj3kf6YP2UbifEx/YyQduNFDxO/n6rWwjEqnItih5hCzpJ6w9RusP0Cd6EYRah/tUuRTzzfuJHYK2kwoCnzm3EBYEyweGcsDRrTuDM76/zLsYszn7pGmgaTQRpGagnMr+uyPMm0OoWUzxcXftO8Sxub0f+zk"
                    IsRootAuthority = $True
                }
            );
        }
        AADTenantAppManagementPolicy "AADTenantAppManagementPolicy-Default app management tenant policy"
        {
            ApplicationId                = $ConfigurationData.NonNodeData.ApplicationId;
            ApplicationRestrictions      = MSFT_AADTenantAppManagementPolicyRestrictions{
                keyCredentials = @(
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        maxLifetime = "P366DT0H0M0S"
                        restrictForAppsCreatedAfterDateTime = "2024-11-11T00:00:00.0000000Z"
                        restrictionType = "asymmetricKeyLifetime"
                        state = "enabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        certificateBasedApplicationConfigurationIds = @(
                            "2df02f35-eae6-4d49-afed-7d20ec1d581a"
                            "234762af-b29d-43c6-8ef1-ffdb8ed55038"
                        )
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "trustedCertificateAuthority"
                        state = "enabled"
                    }
                )
                passwordCredentials = @(
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "passwordAddition"
                        state = "disabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        maxLifetime = "P0DT0H0M0S"
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "passwordLifetime"
                        state = "disabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "customPasswordAddition"
                        state = "enabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "symmetricKeyAddition"
                        state = "enabled"
                    }
                )
            };
            CertificateThumbprint        = $ConfigurationData.NonNodeData.CertificateThumbprint;
            Description                  = "Default tenant policy that enforces app management restrictions on applications and service principals. To apply policy to targeted resources, create a new policy under appManagementPolicies collection.";
            DisplayName                  = "Default app management tenant policy";
            Ensure                       = "Present";
            IsEnabled                    = $True;
            ServicePrincipalRestrictions = MSFT_AADTenantAppManagementPolicyRestrictions{
                keyCredentials = @(
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        maxLifetime = "P366DT0H0M0S"
                        restrictForAppsCreatedAfterDateTime = "2024-11-11T00:00:00.0000000Z"
                        restrictionType = "asymmetricKeyLifetime"
                        state = "enabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        certificateBasedApplicationConfigurationIds = @("2df02f35-eae6-4d49-afed-7d20ec1d581a")
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "trustedCertificateAuthority"
                        state = "enabled"
                    }
                )
                passwordCredentials = @(
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "passwordAddition"
                        state = "disabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        maxLifetime = "P0DT0H0M0S"
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "passwordLifetime"
                        state = "disabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "customPasswordAddition"
                        state = "enabled"
                    }
                    MSFT_AADTenantAppManagementPolicyRestrictionsCredential{
                        restrictForAppsCreatedAfterDateTime = "2024-08-01T00:00:00.0000000Z"
                        restrictionType = "symmetricKeyAddition"
                        state = "enabled"
                    }
                )
            };
            TenantId                     = $OrganizationName;
        }
}
