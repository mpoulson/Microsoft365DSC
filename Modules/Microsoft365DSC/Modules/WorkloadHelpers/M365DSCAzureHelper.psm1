$Script:AzureBillingApiVersion = '2024-04-01'

<#
.SYNOPSIS
    Throws when an Azure Resource Manager response reports a failure.

.DESCRIPTION
    Invoke-AzRestMethod does not throw on an unsuccessful status code. Without this check a denied or failed
    Azure call is indistinguishable from an empty result and the run reports success.

.PARAMETER Response
    Specifies the response returned by Invoke-AzRestMethod.

.PARAMETER Operation
    Specifies a description of the operation, used in the exception message.

.OUTPUTS
    None
#>
function Assert-M365DSCAzureResponse
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.Object]
        $Response,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Operation
    )

    if ($null -eq $Response)
    {
        throw "No response was returned while $Operation."
    }

    if ($null -ne $Response.StatusCode -and [int]$Response.StatusCode -ge 400)
    {
        throw "Azure returned status {$($Response.StatusCode)} while $($Operation): $($Response.Content)"
    }
}

<#
.SYNOPSIS
    Performs a paged GET against an Azure Resource Manager collection endpoint.

.DESCRIPTION
    Follows the {nextLink} property returned by Azure Resource Manager collection endpoints and returns the
    flattened set of results. Billing collections page at 50 items, so a single unpaged request silently
    truncated larger billing accounts.

.PARAMETER Uri
    Specifies the fully qualified request uri, including the api-version query string.

.OUTPUTS
    System.Object[]
#>
function Invoke-M365DSCAzureRestList
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Uri
    )

    $results = @()
    $currentUri = $Uri

    while (-not [System.String]::IsNullOrEmpty($currentUri))
    {
        $response = Invoke-AzRestMethod -Uri $currentUri -Method Get

        Assert-M365DSCAzureResponse -Response $response `
            -Operation "retrieving {$currentUri}"

        $currentUri = $null

        if ([System.String]::IsNullOrEmpty($response.Content))
        {
            continue
        }

        $content = ConvertFrom-Json $response.Content

        if ($null -ne $content.value)
        {
            $results += $content.value
        }

        if ($null -ne $content.PSObject.Properties['nextLink'])
        {
            $currentUri = $content.nextLink
        }
    }

    return $results
}

<#
.SYNOPSIS
    Performs a single GET against an Azure Resource Manager instance endpoint.

.DESCRIPTION
    Issues a GET for a single Azure Resource Manager instance and returns the deserialized body. A 404 is
    answered with a null result because a missing instance is a valid answer for a DSC Get, while any other
    failure throws so that a denied call is not mistaken for an absent instance.

.PARAMETER Uri
    Specifies the fully qualified request uri, including the api-version query string.

.OUTPUTS
    System.Object
#>
function Invoke-M365DSCAzureRestGet
{
    [CmdletBinding()]
    [OutputType([System.Object])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Uri
    )

    $response = Invoke-AzRestMethod -Uri $Uri -Method Get

    if ($null -ne $response -and [int]$response.StatusCode -eq 404)
    {
        return $null
    }

    Assert-M365DSCAzureResponse -Response $response `
        -Operation "retrieving {$Uri}"

    if ([System.String]::IsNullOrEmpty($response.Content))
    {
        return $null
    }

    return (ConvertFrom-Json $response.Content)
}

<#
.SYNOPSIS
    Gets Azure billing accounts.

.DESCRIPTION
    Retrieves the list of Azure billing accounts for the current authenticated context.

.OUTPUTS
    System.Collections.Hashtable
#>
function Get-M365DSCAzureBillingAccount
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param()

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts?api-version=$($Script:AzureBillingApiVersion)&includeAll=true"
    return @{
        value = [Array](Invoke-M365DSCAzureRestList -Uri $uri)
    }
}

<#
.SYNOPSIS
    Gets associated tenants for a billing account.

.DESCRIPTION
    Retrieves the tenants currently associated to a specific Azure billing account.

.PARAMETER BillingAccountId
    Specifies the billing account identifier.

.OUTPUTS
    System.Collections.Hashtable
#>
function Get-M365DSCAzureBillingAccountsAssociatedTenant
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId
    )

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/associatedTenants?api-version=$($Script:AzureBillingApiVersion)"
    return @{
        value = [Array](Invoke-M365DSCAzureRestList -Uri $uri)
    }
}

<#
.SYNOPSIS
    Removes an associated tenant from a billing account.

.DESCRIPTION
    Deletes the association between an Azure billing account and an associated tenant.

.PARAMETER BillingAccountId
    Specifies the billing account identifier.

.PARAMETER AssociatedTenantId
    Specifies the associated tenant identifier to remove.

.OUTPUTS
    System.Collections.Hashtable
#>
function Remove-M365DSCAzureBillingAccountsAssociatedTenant
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AssociatedTenantId
    )

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/associatedTenants/$($AssociatedTenantId)?api-version=$($Script:AzureBillingApiVersion)"
    $response = Invoke-AzRestMethod -Method DELETE -Uri $uri

    Assert-M365DSCAzureResponse -Response $response `
        -Operation "removing associated tenant {$AssociatedTenantId} from billing account {$BillingAccountId}"

    if ([System.String]::IsNullOrEmpty($response.Content))
    {
        return $null
    }

    return (ConvertFrom-Json $response.Content)
}

<#
.SYNOPSIS
    Creates or updates an associated tenant for a billing account.

.DESCRIPTION
    Creates or updates the associated tenant relationship for an Azure billing account using the provided request body.

.PARAMETER BillingAccountId
    Specifies the billing account identifier.

.PARAMETER AssociatedTenantId
    Specifies the associated tenant identifier to create or update.

.PARAMETER Body
    Specifies the request payload sent to the Azure Billing API.

.OUTPUTS
    System.Collections.Hashtable
#>
function New-M365DSCAzureBillingAccountsAssociatedTenant
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AssociatedTenantId,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Body
    )

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/associatedTenants/$($AssociatedTenantId)?api-version=$($Script:AzureBillingApiVersion)"
    $payload = ConvertTo-Json $body -Depth 10 -Compress
    $response = Invoke-AzRestMethod -Method PUT -Uri $uri -Payload $payload

    Assert-M365DSCAzureResponse -Response $response `
        -Operation "associating tenant {$AssociatedTenantId} with billing account {$BillingAccountId}"

    if ([System.String]::IsNullOrEmpty($response.Content))
    {
        return $null
    }

    return (ConvertFrom-Json $response.Content)
}

<#
.SYNOPSIS
    Gets billing role assignments for a billing account.

.DESCRIPTION
    Retrieves all billing role assignments for a specific Azure billing account.

.PARAMETER BillingAccountId
    Specifies the billing account identifier.

.OUTPUTS
    System.Collections.Hashtable
#>
function Get-M365DSCAzureBillingAccountsRoleAssignment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId
    )

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/billingRoleAssignments?api-version=$($Script:AzureBillingApiVersion)"
    return @{
        value = [Array](Invoke-M365DSCAzureRestList -Uri $uri)
    }
}

<#
.SYNOPSIS
    Gets billing role definitions for a billing account.

.DESCRIPTION
    Retrieves billing role definitions for a specific Azure billing account, or a single role definition when an identifier is provided.

.PARAMETER BillingAccountId
    Specifies the billing account identifier.

.PARAMETER RoleDefinitionId
    Specifies the role definition identifier. When omitted, all role definitions are returned.

.OUTPUTS
    System.Collections.Hashtable
#>
function Get-M365DSCAzureBillingAccountsRoleDefinition
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId,

        [Parameter()]
        [System.String]
        $RoleDefinitionId
    )

    if ([System.String]::IsNullOrEmpty($RoleDefinitionId))
    {
        $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/billingRoleDefinitions?api-version=$($Script:AzureBillingApiVersion)"
        return @{
            value = [Array](Invoke-M365DSCAzureRestList -Uri $uri)
        }
    }

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/billingRoleDefinitions/$($RoleDefinitionId)?api-version=$($Script:AzureBillingApiVersion)"
    return (Invoke-M365DSCAzureRestGet -Uri $uri)
}

<#
.SYNOPSIS
    Creates a billing role assignment.

.DESCRIPTION
    Creates a new billing role assignment for a specific Azure billing account using the provided request body.

.PARAMETER BillingAccountId
    Specifies the billing account identifier.

.PARAMETER Body
    Specifies the request payload sent to the Azure Billing API.

.OUTPUTS
    System.Collections.Hashtable
#>
function New-M365DSCAzureBillingAccountsRoleAssignment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Body
    )

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/createBillingRoleAssignment?api-version=$($Script:AzureBillingApiVersion)"
    $payload = ConvertTo-Json $Body -Depth 10 -Compress
    $response = Invoke-AzRestMethod -Method POST -Uri $uri -Payload $payload

    Assert-M365DSCAzureResponse -Response $response `
        -Operation "creating a billing role assignment on billing account {$BillingAccountId}"

    if ([System.String]::IsNullOrEmpty($response.Content))
    {
        return $null
    }

    return (ConvertFrom-Json $response.Content)
}

<#
.SYNOPSIS
    Removes a billing role assignment.

.DESCRIPTION
    Deletes a billing role assignment from a specific Azure billing account.

.PARAMETER BillingAccountId
    Specifies the billing account identifier.

.PARAMETER AssignmentId
    Specifies the billing role assignment identifier to remove.

.OUTPUTS
    System.Collections.Hashtable
#>
function Remove-M365DSCAzureBillingAccountsRoleAssignment
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $BillingAccountId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AssignmentId
    )

    $uri = "$((Get-MSCloudLoginConnectionProfile -Workload Azure).ManagementUrl)providers/Microsoft.Billing/billingAccounts/$($BillingAccountId)/billingRoleAssignments/$($AssignmentId)?api-version=$($Script:AzureBillingApiVersion)"
    $response = Invoke-AzRestMethod -Method DELETE -Uri $uri

    Assert-M365DSCAzureResponse -Response $response `
        -Operation "removing billing role assignment {$AssignmentId} from billing account {$BillingAccountId}"

    if ([System.String]::IsNullOrEmpty($response.Content))
    {
        return $null
    }

    return (ConvertFrom-Json $response.Content)
}
