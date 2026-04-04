# AADDomainFederation

## Description

This resource manages Azure Active Directory Domain Federation configurations for federated domains. It allows administrators to configure and manage federation settings including SAML/WS-Fed parameters, signing certificates, and authentication protocols for domains that use federated authentication.

## Key Features

- **Create Federation Configurations**: Set up federation for managed domains with comprehensive SAML/WS-Fed settings
- **Update Federation Settings**: Modify existing federation configurations including URIs, certificates, and authentication protocols
- **Remove Federation**: Remove federation configurations to return domains to managed authentication
- **Certificate Management**: Support for both current and next signing certificates with automatic debugging information
- **Export Configurations**: Export existing federation settings for backup or migration purposes
- **Authentication Type Validation**: Ensures domains are in "Managed" state before creating federation configurations
