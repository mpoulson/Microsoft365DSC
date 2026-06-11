---
applyTo: "**/*.ps1,**/*.psm1"
description: "Common patterns and helper functions in Microsoft365DSC"
---

# Common Patterns in Microsoft365DSC

This guide defines the shared logic patterns used throughout the project.

## Connection Handling

## Authentication Requirements

All Microsoft365DSC resources authenticate using `New-M365DSCConnection` from the `MSCloudLoginAssistant` PowerShell module.

Resources must **not** require explicit authentication per resource.
They depend on the global Microsoft365DSC auth session.

Do **not** call Graph or service connections manually.

Helpers location and usage:

- Common helper functions live in `Modules/Microsoft365DSC/Modules/M365DSCUtil` and utility templates in `ResourceGenerator/Module.Template.psm1`.
- Prefer `New-M365DSCConnection` for creating authenticated sessions. Example pattern:

```powershell
...
$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
            -InboundParameters $PSBoundParameters
```

Forbidden patterns:

- Do not perform resource-level direct Graph auth (e.g. `Connect-MgGraph` inside each resource) unless a documented exception is provided.
- Do not embed raw secrets, tokens, or credentials in code or telemetry at any time.

## Logging

Use:

- `Write-M365DSCHost` for user output
- `Write-Verbose` for Verbose messages
- Never use `Write-Host` except for interactive scenarios
- **Do not** add extra `Write-Verbose` in catch blocks — only use `New-M365DSCLogEntry` + `throw`
- **Do not** output the results of `Get-TargetResource` to log or console
- **Do not** output status messages for `Test-TargetResource` results — it must only return `$true` or `$false`

## Exception Handling

Use the built-in error helpers with a try/catch block. **Do not** add extra `Write-Verbose` statements in catch blocks. Follow the standard `New-M365DSCLogEntry` + `throw` pattern used across the codebase. Example pattern:

```powershell
New-M365DSCLogEntry -Message 'Error retrieving data:' `
    -Exception $_ `
    -Source $($MyInvocation.MyCommand.Source) `
    -TenantId $TenantId `
    -Credential $Credential

throw
```

## Debugging

- **Do not** add helper methods or functions for debugging purposes. Use the existing logging utilities (`Write-Verbose`, `New-M365DSCLogEntry`, etc.).

## Set-TargetResource Rules

- **Never call `Test-TargetResource` inside `Set-TargetResource`.** The DSC engine handles the Test -> Set flow automatically. The Set function must only implement the configuration changes.

## Endpoint URLs

- **Never hardcode** URLs to Microsoft endpoints (e.g., `https://graph.microsoft.com`, `https://management.azure.com`). Use `Get-MSCloudLoginConnectionProfile` or equivalent helpers to obtain base URLs at runtime. This ensures cloud-agnostic behaviour for GCC, GCC-High, DoD, China, and other sovereign clouds.

## Complex Type Handling

For detailed patterns on working with complex types (CIM instances, embedded objects, nested arrays), including conversion helpers, deep comparison, export serialization, and unit testing, see `m365dsc-complex-types.instructions.md`.

## Data Caching & Performance Optimization

Export and drift detection can call `Get-TargetResource` hundreds of times per tenant, so reuse data instead of re-querying the service. Follow the existing caching patterns rather than inventing new ones.

- **Reuse the exported-instance cache.** During export, `Get-TargetResource` is invoked once per instance. Set `$Script:exportedInstance` (or `$Script:exportedInstances` for the full list) in `Export-TargetResource` and have `Get-TargetResource` check it before hitting the API. The cache check **must** compare against the `[Key]` property from the `.schema.mof`. See `m365dsc-complex-types.instructions.md` (section "Export Instance Caching") for the full pattern.
- **Cache expensive, reusable lookups at script scope.** The codebase caches comparison metadata and resource reflection data in module-scoped dictionaries that are populated lazily and reused (e.g., `$Script:CompareParametersCache` and `$Script:AllM365DSCResources` in `M365DSCUtil.psm1`, `$Script:MandatoryParametersCache` in `M365DSCReport.psm1`). When adding a similar lookup, initialize the cache only when `$null`, key it by resource name, and return the cached value on subsequent calls. Use a case-insensitive comparer (e.g., `[System.StringComparer]::InvariantCultureIgnoreCase`) where names are matched.
- **Build large strings with `[System.Text.StringBuilder]`.** When assembling sizeable output such as telemetry/report XML or exported configuration, use `StringBuilder` with `.Append(...) | Out-Null` rather than repeated `+=` string concatenation (see `New-M365DSCLogEntry` in `M365DSCUtil.psm1`). Avoid `$array += $item` inside hot loops that run per instance; prefer a typed list (e.g., `[System.Collections.Generic.List[Object]]`) when the collection can grow large.
- **Batch and defer console output.** Use `Write-M365DSCHost` with `-DeferWrite` to buffer host messages and `-CommitWrite` to flush them, instead of many individual `Write-Host` calls during export.
- **Honor the `$Filter` parameter.** Server-side `-Filter` queries (when the resource supports them) avoid exporting and discarding every instance. Always wire `$Filter` through `Export-TargetResource`.

## Encoding & Decoding

- **Do not double-encode values that are already encoded.** Many Graph SDK / REST properties (for example certificate blobs) are already returned as Base64 strings. Only call `[System.Convert]::ToBase64String(...)` on a raw `[System.Byte[]]`; never on a value that is already a Base64 `String`. This bug was fixed for `AADOrganizationCertificateBasedAuthConfiguration` (FIXES #7193) — assign the value through directly when the API already returns a string.
- **Use the .NET primitives for conversion.** Convert text to/from Base64 with `[System.Text.Encoding]::UTF8.GetBytes(...)` + `[System.Convert]::ToBase64String(...)`, and decode with `[System.Convert]::FromBase64String(...)`. Do not hand-roll encoders.
- **Write files as UTF-8.** When persisting exports, documentation, or generated content, use `-Encoding utf8` (the `SchemaDefinition.json` generation and export utilities all use UTF-8). Match the encoding already used by the surrounding code path.

## Unicode Characters & Emojis

- **Never embed raw Unicode / emoji literals in source files.** All emoji and symbol glyphs are defined centrally in `Modules/Microsoft365DSC/Modules/EncodingHelpers/M365DSCEmojis.psm1` using `[char]::ConvertFromUtf32(0x....)` and exposed as `$Global:M365DSCEmoji*` / `$Global:M365DSCMagnifyingGlass` variables (loaded as a nested module in `Microsoft365DSC.psd1`). Reference those globals (e.g., `$Global:M365DSCEmojiGreenCheckmark`, `$Global:M365DSCEmojiRedX`) instead of pasting the glyph. If a needed symbol is missing, add it to `M365DSCEmojis.psm1` via `ConvertFromUtf32` in alphabetical order rather than inlining a literal.
- **Build any new code-point from its hex value** with `[char]::ConvertFromUtf32(0x....)`; this keeps source files ASCII-safe and avoids corruption from editors or non-UTF-8 sessions.
- **UTF-8 session requirement.** Rendering these characters relies on a UTF-8 console code page (65001). `Test-CodePage` in `M365DSCUtil.psm1` warns when the session is not UTF-8 — do not work around it by stripping Unicode output.

## Drift Detection Patterns

Test-TargetResource must always use the pre-defined comparison block:

```powershell
#region Telemetry
$ResourceName = $MyInvocation.MyCommand.ModuleName.Replace('MSFT_', '')
$CommandName = $MyInvocation.MyCommand
$data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
    -CommandName $CommandName `
    -Parameters $PSBoundParameters
Add-M365DSCTelemetryEvent -Data $data
#endregion

# This block is optional and can be omitted if no customization is required
<#
$postProcessingScript = {
    param($DesiredValues, $CurrentValues, $ValuesToCheck, $ignore)
    # Do something with $DesiredValues, $CurrentValues or $ValuesToCheck
    # ...

    return [System.Tuple[Hashtable, Hashtable, Hashtable]]::new($DesiredValues, $CurrentValues, $ValuesToCheck)
}
#>

$result = Test-M365DSCTargetResource -DesiredValues $PSBoundParameters `
                                        -ResourceName $($MyInvocation.MyCommand.Source).Replace('MSFT_', '')
return $result
```

If the `postProcessingScript` is defined, then the parameter `-PostProcessing` with the value `$postProcessingScript` must be appended to `Test-M365DSCTargetResource`.

## Reverse DSC (Export-TargetResource)

When generating exported configuration:

- Output objects in alphabetical parameter order
- Avoid emitting default values
- **Always include `$Filter` parameter support** for client-side filtering. See `ResourceGenerator/Templates/Module.Template.psm1` for the standard pattern.

It is always the same set of steps. Refer to `ResourceGenerator/Templates/Module.Template.psm1` with the function `Export-TargetResource`.

## Documentation Rules

The documentation is built automatically inside of the pipeline and deployed to the website https://microsoft365dsc.com.

The cmdlet responsible for this is `Update-M365DSCResourceDocumentationPage` and `New-M365DSCCmdletDocumentation` from the module `Modules/Microsoft365DSC/Modules/M365DSCDogGenerator` and `Modules/Microsoft365DSC/Modules/M365DSCUtil`.

Telemetry rules:

- Telemetry must never include PII. Use `Format-M365DSCTelemetryParameters` to normalize events.
- Telemetry helper functions live in `Modules/Microsoft365DSC/Modules/M365DSCUtil` - prefer those helpers instead of ad-hoc telemetry code.
