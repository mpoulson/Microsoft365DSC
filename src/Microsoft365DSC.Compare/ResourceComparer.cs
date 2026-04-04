using Microsoft365DSC.Converter;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace Microsoft365DSC.Compare
{
    /// <summary>
    /// High-level resource comparison entry point.
    /// Normalizes both sides to Hashtable trees, resolves schema metadata,
    /// aligns complex arrays by primary keys, then delegates to
    /// ComplexObjectComparer and SimpleObjectComparer for the actual diff.
    ///
    /// This class replaces the complex PowerShell orchestration loop that
    /// previously lived in Compare-M365DSCResourceState, eliminating
    /// CimInstance type checks, the Address property workaround, and the
    /// two-phase complex-then-simple split.
    /// </summary>
    public static class ResourceComparer
    {
        // Properties that are always excluded from comparison
        private static readonly HashSet<string> AlwaysExcludedProperties = new(StringComparer.OrdinalIgnoreCase)
        {
            "Verbose", "Credential", "ApplicationId", "CertificateThumbprint",
            "CertificatePath", "CertificatePassword", "TenantId",
            "ApplicationSecret", "ManagedIdentity", "AccessTokens"
        };

        /// <summary>
        /// Compares desired vs current values for a single DSC resource.
        /// Both sides are normalized to Hashtable trees before comparison.
        /// </summary>
        /// <param name="desiredValues">Desired state hashtable (from PSBoundParameters)</param>
        /// <param name="currentValues">Current state hashtable (from Get-TargetResource)</param>
        /// <param name="schema">The full schema array (deserialized SchemaDefinition.json)</param>
        /// <param name="resourceName">Resource name without MSFT_ prefix (e.g. "AADUser")</param>
        /// <param name="excludedProperties">Properties to skip during comparison</param>
        /// <param name="includedProperties">Properties to force-include even if otherwise skipped</param>
        /// <returns>A CompareResult with test result, drift info, and value snapshots</returns>
        public static CompareResult Compare(
            Hashtable desiredValues,
            Hashtable currentValues,
            Hashtable valuesToCheck,
            IEnumerable<object> schema,
            string resourceName,
            string[]? excludedProperties = null,
            string[]? includedProperties = null)
        {
            if (desiredValues is null)
                throw new ArgumentNullException(nameof(desiredValues));
            if (desiredValues is null)
                throw new ArgumentNullException(nameof(currentValues));
            if (desiredValues is null)
                throw new ArgumentNullException(nameof(schema));
            if (string.IsNullOrEmpty(resourceName))
                throw new ArgumentNullException(nameof(resourceName));

            // Transform schema elements from PSObject to their BaseObject if needed for easier access
            var result = new CompareResult();
            var excludedSet = new HashSet<string>(AlwaysExcludedProperties, StringComparer.OrdinalIgnoreCase);
            if (excludedProperties != null)
            {
                foreach (string prop in excludedProperties)
                    excludedSet.Add(prop);
            }
            var includedSet = includedProperties != null
                ? new HashSet<string>(includedProperties, StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            // Look up the resource definition from the schema
            string fullClassName = "MSFT_" + resourceName;
            var resourceDef = FindSchemaEntry(schema, fullClassName) ?? throw new InvalidOperationException($"Resource definition not found in schema for '{fullClassName}'.");

            // Build a dictionary of parameter definitions for this resource
            var parameterDefs = BuildParameterLookup(resourceDef);

            // Build a schema lookup for nested CIM type resolution
            var schemaLookup = BuildSchemaLookup(schema);

            // Determine which keys to compare: start from desired, remove keys/credentials/excluded, add included
            var keysToCompare = BuildKeysToCompare(valuesToCheck, parameterDefs, excludedSet, includedSet);

            // Handle Ensure early: if both sides agree on Absent, skip everything
            bool skipEvaluation = false;
            string? desiredEnsure = GetStringValue(desiredValues, "Ensure");
            string? currentEnsure = GetStringValue(currentValues, "Ensure");

            if (string.Equals(desiredEnsure ?? "Present", "Present", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(currentEnsure, "Absent", StringComparison.OrdinalIgnoreCase))
            {
                result.AddDrift("Ensure", "Absent", "Present");
                result.TestResult = false;
                excludedSet.Add("Ensure");
                keysToCompare.Remove("Ensure");
            }
            else if (string.Equals(desiredEnsure ?? "Present", "Absent", StringComparison.OrdinalIgnoreCase) &&
                     string.Equals(currentEnsure, "Present", StringComparison.OrdinalIgnoreCase))
            {
                result.AddDrift("Ensure", "Present", "Absent");
                result.TestResult = false;
                excludedSet.Add("Ensure");
                keysToCompare.Remove("Ensure");
            }
            else if (string.Equals(desiredEnsure ?? "Present", "Absent", StringComparison.OrdinalIgnoreCase) &&
                     string.Equals(currentEnsure, "Absent", StringComparison.OrdinalIgnoreCase))
            {
                skipEvaluation = true;
            }

            if (skipEvaluation)
                return result;

            // Separate keys into complex (MSFT_* CIM types) and simple
            List<string> complexKeys = [];
            List<string> simpleKeys = [];

            foreach (string key in keysToCompare)
            {
                if (excludedSet.Contains(key))
                    continue;

                if (parameterDefs.TryGetValue(key, out var paramDef))
                {
                    string? cimType = GetStringProperty(paramDef, "CIMType");
                    if (!string.IsNullOrEmpty(cimType) && cimType!.IndexOf("MSFT_", StringComparison.OrdinalIgnoreCase) > -1)
                    {
                        complexKeys.Add(key);
                        continue;
                    }
                }

                // Also check if the actual value is a complex object (CimInstance, Hashtable with nested structure from CIM)
                object? desiredVal = desiredValues.ContainsKey(key) ? desiredValues[key] : null;
                if (desiredVal is not null && IsComplexValue(desiredVal))
                {
                    complexKeys.Add(key);
                    continue;
                }

                simpleKeys.Add(key);
            }

            // --- Complex property comparison ---
            foreach (string key in complexKeys)
            {
                object? desiredRaw = desiredValues.ContainsKey(key) ? desiredValues[key] : null;
                object? currentRaw = currentValues.ContainsKey(key) ? currentValues[key] : null;

                if (desiredRaw is null)
                    continue;

                // Normalize both sides to uniform Hashtable/object[] trees
                object? normalizedDesired = ObjectNormalizer.Normalize(desiredRaw);
                object? normalizedCurrent = ObjectNormalizer.Normalize(currentRaw);

                // For array properties: align target items by primary keys before comparison
                if (normalizedDesired is object[] desiredArray)
                {
                    object[] currentArray = normalizedCurrent as object[] ?? [];

                    // Resolve CIM primary keys from schema
                    string? cimType = GetStringProperty(
                        parameterDefs.TryGetValue(key, out object? value) ? value : null, "CIMType");
                    string cimName = cimType?.Replace("[]", "") ?? string.Empty;

                    var primaryKeyNames = GetPrimaryKeys(cimName, schemaLookup);
                    bool isIntunePolicyAssignment = IsIntunePolicyAssignmentType(cimName);

                    // For Intune policy assignments that have group-specific targets,
                    // add groupDisplayName as an alignment key
                    if (isIntunePolicyAssignment)
                    {
                        bool hasGroupTargets = HasGroupTargets(desiredArray) || HasGroupTargets(currentArray);
                        if (hasGroupTargets && !primaryKeyNames.Contains("groupDisplayName", StringComparer.OrdinalIgnoreCase))
                        {
                            primaryKeyNames.Add("groupDisplayName");
                        }
                    }

                    // Align: filter current array to only items whose primary keys match any desired item
                    object[] alignedCurrent = AlignArrayByPrimaryKeys(desiredArray, currentArray, primaryKeyNames);

                    // Remove primary keys from target items before comparison (unless force-included)
                    // to avoid false positives when primary keys differ in casing etc.
                    if (!isIntunePolicyAssignment || primaryKeyNames.Count > 0)
                    {
                        bool noPrimaryKeyRemoval = ShouldSkipPrimaryKeyRemoval(desiredArray, primaryKeyNames);
                        if (!noPrimaryKeyRemoval)
                        {
                            RemovePrimaryKeysFromTargets(alignedCurrent, primaryKeyNames, includedSet, isIntunePolicyAssignment);
                        }
                    }

                    // Delegate to ComplexObjectComparer
                    var compResult = ComplexObjectComparer.Compare(desiredArray, alignedCurrent, key);
                    if (!compResult.Item2)
                    {
                        result.TestResult = false;
                        foreach (var drift in compResult.Item1)
                        {
                            result.DriftInfo.Add(ConvertDriftDict(drift));
                        }
                    }
                }
                else
                {
                    // Single complex object (not array)
                    var compResult = ComplexObjectComparer.Compare(normalizedDesired, normalizedCurrent, key);
                    if (!compResult.Item2)
                    {
                        result.TestResult = false;
                        foreach (var drift in compResult.Item1)
                        {
                            result.DriftInfo.Add(ConvertDriftDict(drift));
                        }
                    }
                }
            }

            // --- Simple property comparison ---
            // Build filtered desired/current for simple comparison
            Hashtable simpleDesired = new(StringComparer.OrdinalIgnoreCase);
            foreach (string key in simpleKeys)
            {
                if (desiredValues.ContainsKey(key))
                    simpleDesired[key] = desiredValues[key];
            }

            if (simpleKeys.Count > 0)
            {
                var simpleResult = SimpleObjectComparer.Compare(
                    currentValues,
                    simpleDesired,
                    simpleKeys.ToArray(),
                    null,
                    true,  // noEventMessage: true because we handle drift reporting ourselves
                    true,  // noDriftReset: true because we own the drift state
                    excludedProperties != null ? [.. excludedProperties] : null);

                bool simpleTestResult = (bool)simpleResult["TestResult"];
                if (!simpleTestResult)
                {
                    result.TestResult = false;

                    // Extract drift info from SimpleObjectComparer result
                    if (simpleResult["DriftObject"] is Hashtable driftObject)
                    {
                        if (driftObject["DriftInfo"] is List<Hashtable> driftInfoList)
                        {
                            foreach (Hashtable drift in driftInfoList)
                            {
                                result.DriftInfo.Add(drift);
                            }
                        }
                    }
                }

                // Copy drifted parameter event strings for telemetry
                if (simpleResult["DriftedParameters"] is Hashtable driftedParams)
                {
                    foreach (DictionaryEntry entry in driftedParams)
                    {
                        result.DriftedParameters[entry.Key] = entry.Value;
                    }
                }
            }

            return result;
        }

        #region Schema helpers

        /// <summary>
        /// Finds a schema entry by ClassName from the schema collection.
        /// Handles both PSObject (Windows PowerShell) and Hashtable (PowerShell Core) representations.
        /// </summary>
        private static object? FindSchemaEntry(IEnumerable<object> schema, string className)
        {
            foreach (object entry in schema)
            {
                string? name = GetStringProperty(entry, "ClassName");
                if (string.Equals(name, className, StringComparison.OrdinalIgnoreCase))
                    return entry;
            }
            return null;
        }

        /// <summary>
        /// Builds a lookup dictionary mapping ClassName to schema entry for fast nested type resolution.
        /// </summary>
        private static Dictionary<string, object> BuildSchemaLookup(IEnumerable<object> schema)
        {
            var lookup = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            foreach (object entry in schema)
            {
                string? name = GetStringProperty(entry, "ClassName");
                if (!string.IsNullOrEmpty(name) && !lookup.ContainsKey(name!))
                    lookup[name!] = entry;
            }
            return lookup;
        }

        /// <summary>
        /// Builds a case-insensitive dictionary of parameter name to parameter definition object.
        /// </summary>
        private static Dictionary<string, object> BuildParameterLookup(object resourceDef)
        {
            var result = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            object parameters = GetProperty(resourceDef, "Parameters");
            if (parameters is null)
                return result;

            IEnumerable<object> paramList = parameters is IEnumerable<object> list
                ? list
                : (parameters is IEnumerable enumerable ? enumerable.Cast<object>() : []);

            foreach (object param in paramList)
            {
                string? name = GetStringProperty(param, "Name");
                if (!string.IsNullOrEmpty(name))
                    result[name!] = param;
            }
            return result;
        }

        /// <summary>
        /// Determines which keys from desired values should be compared,
        /// excluding Key parameters, PSCredential types, Id/Identity, and explicitly excluded properties.
        /// </summary>
        private static HashSet<string> BuildKeysToCompare(
            Hashtable desiredValues,
            Dictionary<string, object> parameterDefs,
            HashSet<string> excludedSet,
            HashSet<string> includedSet)
        {
            var keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (string key in desiredValues.Keys.Cast<string>())
            {
                // Always skip Id and Identity (they are lookup fields, not config)
                if (string.Equals(key, "Id", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(key, "Identity", StringComparison.OrdinalIgnoreCase))
                    continue;

                // Skip if explicitly excluded
                if (excludedSet.Contains(key))
                    continue;

                // Skip Key parameters and PSCredential types (from schema)
                if (parameterDefs.TryGetValue(key, out var paramDef))
                {
                    string? option = GetStringProperty(paramDef, "Option");
                    string? cimType = GetStringProperty(paramDef, "CIMType");

                    if (string.Equals(option, "Key", StringComparison.OrdinalIgnoreCase))
                        continue;
                    if (string.Equals(cimType, "PSCredential", StringComparison.OrdinalIgnoreCase))
                        continue;
                }

                keys.Add(key);
            }

            // Force-include any explicitly requested properties
            foreach (string prop in includedSet)
            {
                if (desiredValues.ContainsKey(prop))
                    keys.Add(prop);
            }

            return keys;
        }

        /// <summary>
        /// Gets the primary key names (Required parameters) for a CIM class from the schema.
        /// </summary>
        private static List<string> GetPrimaryKeys(string cimClassName, Dictionary<string, object> schemaLookup)
        {
            var primaryKeys = new List<string>();
            if (string.IsNullOrEmpty(cimClassName) || !schemaLookup.TryGetValue(cimClassName, out object cimDef))
                return primaryKeys;

            object parameters = GetProperty(cimDef, "Parameters");
            if (parameters is null)
                return primaryKeys;

            IEnumerable<object> paramList = parameters is IEnumerable<object> list
                ? list
                : (parameters is IEnumerable enumerable ? enumerable.Cast<object>() : Enumerable.Empty<object>());

            foreach (object param in paramList)
            {
                string? option = GetStringProperty(param, "Option");
                if (string.Equals(option, "Required", StringComparison.OrdinalIgnoreCase))
                {
                    string? name = GetStringProperty(param, "Name");
                    if (!string.IsNullOrEmpty(name))
                        primaryKeys.Add(name!);
                }
            }

            return primaryKeys;
        }

        #endregion

        #region Array alignment

        /// <summary>
        /// Filters the current array to only include items whose primary key values
        /// match any of the desired items' primary key values.
        /// This is the C# equivalent of the PowerShell Where-Object block that previously
        /// suffered from the Address property workaround. Since we work with normalized
        /// Hashtables here, we simply do case-insensitive dictionary lookups.
        /// </summary>
        private static object[] AlignArrayByPrimaryKeys(
            object[] desired,
            object[] current,
            List<string> primaryKeyNames)
        {
            if (primaryKeyNames.Count == 0 || desired.Length == 0)
                return current;

            // Collect all primary key values from desiredarray per key name
            var desiredKeyValues = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (string pk in primaryKeyNames)
            {
                var values = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (object item in desired)
                {
                    string val = GetHashtableStringValue(item as Hashtable, pk);
                    if (val != null)
                        values.Add(val);
                }
                desiredKeyValues[pk] = values;
            }

            var aligned = new List<object>();
            foreach (object currentItem in current)
            {
                if (currentItem is not Hashtable currentHash)
                    continue;

                bool match = true;
                foreach (string pk in primaryKeyNames)
                {
                    string currentVal = GetHashtableStringValue(currentHash, pk);
                    if (currentVal != null && desiredKeyValues.TryGetValue(pk, out var allowedValues))
                    {
                        if (!allowedValues.Contains(currentVal))
                        {
                            match = false;
                            break;
                        }
                    }
                }

                if (match)
                    aligned.Add(currentItem);
            }

            return aligned.ToArray();
        }

        /// <summary>
        /// Removes primary key entries from each target Hashtable so they do not
        /// cause false-positive drifts. Skips removal for explicitly included properties
        /// and for the dataType key on Intune policy assignments.
        /// </summary>
        private static void RemovePrimaryKeysFromTargets(
            object[] targets,
            List<string> primaryKeyNames,
            HashSet<string> includedSet,
            bool isIntunePolicyAssignment)
        {
            foreach (object item in targets)
            {
                if (item is not Hashtable hash)
                    continue;

                foreach (string pk in primaryKeyNames)
                {
                    // Keep dataType on Intune assignments (needed by IntunePolicyAssignmentComparer)
                    if (isIntunePolicyAssignment &&
                        string.Equals(pk, "dataType", StringComparison.OrdinalIgnoreCase))
                        continue;

                    // Keep if explicitly included
                    if (includedSet.Contains(pk))
                        continue;

                    hash.Remove(pk);
                }
            }
        }

        /// <summary>
        /// Checks if we should skip primary key removal.
        /// This happens when a primary key has multiple distinct values across source items
        /// (meaning it is not truly a "primary key" for matching but rather a data field).
        /// </summary>
        private static bool ShouldSkipPrimaryKeyRemoval(object[] desired, List<string> primaryKeyNames)
        {
            foreach (string pk in primaryKeyNames)
            {
                var values = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (object item in desired)
                {
                    string val = GetHashtableStringValue(item as Hashtable, pk);
                    if (val != null)
                        values.Add(val);
                }
                if (values.Count > 1)
                    return true;
            }
            return false;
        }

        #endregion

        #region Intune helpers

        /// <summary>
        /// Determines if a CIM class name represents an Intune policy assignment type.
        /// </summary>
        private static bool IsIntunePolicyAssignmentType(string cimName)
        {
            if (string.IsNullOrEmpty(cimName))
                return false;

            // Exclude the special case that should not be treated as Intune assignment
            if (string.Equals(cimName, "MSFT_IntuneDeviceRemediationPolicyAssignments", StringComparison.OrdinalIgnoreCase))
                return false;

            bool matchesIntune = cimName.IndexOf("Intune", StringComparison.OrdinalIgnoreCase) > -1 &&
                                 cimName.EndsWith("PolicyAssignments", StringComparison.OrdinalIgnoreCase);
            bool matchesDevMgmt = cimName.IndexOf("DeviceManagementConfigurationPolicyAssignments", StringComparison.OrdinalIgnoreCase) > -1;

            return matchesIntune || matchesDevMgmt;
        }

        /// <summary>
        /// Checks if any item in the array has a dataType that is group-specific
        /// (not allLicensedUsers or allDevices).
        /// </summary>
        private static bool HasGroupTargets(object[] items)
        {
            if (items is null || items.Length == 0)
                return false;

            if (items[0] is not Hashtable first)
                return false;

            string dataType = GetHashtableStringValue(first, "dataType");
            if (string.IsNullOrEmpty(dataType))
                return false;

            return !string.Equals(dataType, "#microsoft.graph.allLicensedUsersAssignmentTarget", StringComparison.OrdinalIgnoreCase) &&
                   !string.Equals(dataType, "#microsoft.graph.allDevicesAssignmentTarget", StringComparison.OrdinalIgnoreCase);
        }

        #endregion

        #region Property access helpers

        /// <summary>
        /// Gets a string property from an object that could be a PSObject, Hashtable, or other type.
        /// Handles both Windows PowerShell (PSObject) and PowerShell Core (Hashtable) schema representations.
        /// </summary>
        private static string? GetStringProperty(object? obj, string propertyName)
        {
            if (obj is null)
                return null;

            if (obj is Hashtable hash)
                return hash.ContainsKey(propertyName) ? hash[propertyName]?.ToString() : null;

            if (obj is IDictionary dict)
                return dict.Contains(propertyName) ? dict[propertyName]?.ToString() : null;

            if (obj is PSObject psObj)
            {
                var prop = psObj.Properties[propertyName];
                return prop?.Value?.ToString();
            }

            // Try dynamic access as last resort
            try
            {
                var type = obj.GetType();
                var propInfo = type.GetProperty(propertyName);
                return propInfo?.GetValue(obj)?.ToString();
            }
            catch
            {
                return null;
            }
        }

        /// <summary>
        /// Gets a property value from an object (supports Hashtable, IDictionary, PSObject).
        /// </summary>
        private static object? GetProperty(object obj, string propertyName)
        {
            if (obj is null)
                return null;

            if (obj is Hashtable hash)
                return hash.ContainsKey(propertyName) ? hash[propertyName] : null;

            if (obj is IDictionary dict)
                return dict.Contains(propertyName) ? dict[propertyName] : null;

            if (obj is PSObject psObj)
            {
                var prop = psObj.Properties[propertyName];
                return prop?.Value;
            }

            try
            {
                var type = obj.GetType();
                var propInfo = type.GetProperty(propertyName);
                return propInfo?.GetValue(obj);
            }
            catch
            {
                return null;
            }
        }

        /// <summary>
        /// Gets a string value from a hashtable by key with null safety.
        /// </summary>
        private static string? GetHashtableStringValue(Hashtable hash, string key)
        {
            if (hash is null || !hash.ContainsKey(key))
                return null;
            return hash[key]?.ToString();
        }

        /// <summary>
        /// Gets a string from a Hashtable, defaulting to null if not present.
        /// </summary>
        private static string? GetStringValue(Hashtable hash, string key)
        {
            if (hash is null || !hash.ContainsKey(key))
                return null;
            return hash[key]?.ToString();
        }

        /// <summary>
        /// Checks whether a value is a complex type that needs ComplexObjectComparer
        /// rather than SimpleObjectComparer.
        /// </summary>
        private static bool IsComplexValue(object value)
        {
            if (value is null)
                return false;

            if (value is PSObject psObj)
                value = psObj.BaseObject;

            // CimInstance or CimInstance[]
            string typeName = value.GetType().Name;
            if (typeName.IndexOf("CimInstance", StringComparison.OrdinalIgnoreCase) > -1)
                return true;

            // Array of hashtables (already normalized complex objects)
            if (value is Array array && array.Length > 0)
            {
                object first = array.GetValue(0);
                if (first is PSObject firstPs)
                    first = firstPs.BaseObject;
                if (first is Hashtable || first is IDictionary)
                    return true;
                if (first != null && first.GetType().Name.IndexOf("CimInstance", StringComparison.OrdinalIgnoreCase) > -1)
                    return true;
            }

            return false;
        }

        /// <summary>
        /// Converts a Dictionary&lt;string, object&gt; drift entry to a Hashtable for PowerShell consumption.
        /// </summary>
        private static Hashtable ConvertDriftDict(Dictionary<string, object> drift)
        {
            var ht = new Hashtable(StringComparer.OrdinalIgnoreCase);
            foreach (var kvp in drift)
                ht[kvp.Key] = kvp.Value;
            return ht;
        }
        #endregion
    }

    /// <summary>
    /// Result object for ResourceComparer.Compare.
    /// Contains the test result (true = no drift), drift info entries,
    /// and drifted parameter event strings for telemetry.
    /// </summary>
    public class CompareResult
    {
        /// <summary>
        /// True if no drift was detected; false otherwise.
        /// </summary>
        public bool TestResult { get; set; } = true;

        /// <summary>
        /// List of drift entries. Each entry has PropertyName, CurrentValue, DesiredValue.
        /// </summary>
        public List<Hashtable> DriftInfo { get; } = [];

        /// <summary>
        /// Drifted parameter event strings for telemetry (key = param name, value = XML snippet).
        /// </summary>
        public Hashtable DriftedParameters { get; } = new Hashtable(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// Adds a drift entry.
        /// </summary>
        public void AddDrift(string propertyName, object currentValue, object desiredValue)
        {
            DriftInfo.Add(new Hashtable(StringComparer.OrdinalIgnoreCase)
            {
                { "PropertyName", propertyName },
                { "CurrentValue", currentValue },
                { "DesiredValue", desiredValue }
            });
        }
    }
}
