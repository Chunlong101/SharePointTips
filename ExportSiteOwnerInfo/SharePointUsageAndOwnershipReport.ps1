# Requires: PnP.PowerShell, ImportExcel
# Purpose:
# 1. Read input CSV (default .\SharePointURLs.csv). It auto-detects the column whose normalized name (remove non-alphanumeric + lowercase) equals 'siteurl'.
# 2. For every valid SiteUrl collect:
#    SiteTitle, StorageQuotaGB / StorageUsedGB, LastContentModifiedDate, OwnerEmail,
#    M365 Group connection (DisplayName / Owners / Members), Site Collection Admins, Owners / Members / Visitors groups,
#    Teams connection flag, PreservationHoldLibrary existence and size (skippable via -SkipPreservationHoldLibrary).
# 3. Export a single worksheet 'Report' into SharePointUsageAndOwnershipReport.xlsx.
# 4. Print error summary to console (no separate error worksheet).
#
# Example:
#   .\SharePointUsageAndOwnershipReport.ps1 -ClientId <appId> -Thumbprint <thumb> -Tenant contoso.onmicrosoft.com -InputCsv .\SharePointURLs.csv
#
# Dependencies:
#   Install-Module PnP.PowerShell
#   Install-Module ImportExcel   (Only used for Export-Excel, not for reading input now)
#
# Notes:
# - The certificate-based app must have required Graph / SharePoint Online permissions.
# - We first connect to the Admin center and cache tenant site metadata (Get-PnPTenantSite) to avoid repeated context switching.
# - Then we connect to each site only for membership / group enrichment.
[CmdletBinding()]
param(
    [string]$ClientId    = "efec52de-b554-40e0-8596-27a895cb4589",
    [string]$Thumbprint  = "xxx",
    [string]$Tenant      = "5xxsz0.onmicrosoft.com",
    [string]$AdminUrl,
    [string]$InputCsv    = ".\SharePointURLs.csv",
    [string]$OutputFile  = ".\SharePointUsageAndOwnershipReport.xlsx",
    [switch]$SkipPreservationHoldLibrary
)

$ErrorActionPreference = "Stop"

# --------------------------------------------
# Report column model (explicit ordering)
# --------------------------------------------
$ReportColumns = @(
    'SiteTitle','SiteUrl','StorageQuotaGB','StorageUsedGB','LastContentModifiedDate',
    'OwnerEmail',
    'IsM365GroupConnected','M365GroupDisplayName','M365GroupOwnersEmails','M365GroupMembersEmails',
    'SiteAdminsEmails','SiteOwnersEmails','SiteMembersEmails','SiteVisitorsEmails',
    'IsTeamsConnected',
    'PreservationHoldLibrary','PreservationHoldLibrarySizeGB'
)

# --------------------------------------------
# Module presence / import
# --------------------------------------------
function Test-Module {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Missing module $Name. Please install: Install-Module $Name"
        exit 1
    }
    Import-Module $Name -ErrorAction Stop
}
Test-Module -Name "PnP.PowerShell"
Test-Module -Name "ImportExcel"   # Only for export

# --------------------------------------------
# Load helper functions (GetSiteOwnerInfo.ps1 must define:
#   Connect-SPOWithCert, Get-SPOBasicSiteMetadata, Get-SPOSiteMembership, Get-SPOM365GroupInfo)
# --------------------------------------------
$helperPath = Join-Path $PSScriptRoot "GetSiteOwnerInfo.ps1"
if (-not (Test-Path $helperPath)) {
    Write-Host "Helper script not found: $helperPath"
    exit 1
}
. $helperPath

# --------------------------------------------
# Runtime state
# --------------------------------------------
$tenantCache = @{}    # Key: SiteUrl, Value: Get-PnPTenantSite object (may be $null on failure)
$currentSite = $null  # Track last connected site to avoid redundant connects
$errors      = New-Object System.Collections.Generic.List[object]

# --------------------------------------------
# Error recording (lightweight in-memory)
# --------------------------------------------
function Add-Err {
    param([string]$SiteUrl,[string]$Stage,[string]$Message)
    $errors.Add([pscustomobject]@{
        SiteUrl = $SiteUrl
        Stage   = $Stage
        Message = $Message
    })
}

# --------------------------------------------
# Admin Center connection (derive if not provided)
# --------------------------------------------
if (-not $AdminUrl -or $AdminUrl.Trim() -eq "") {
    $tenantShort = $Tenant.Split('.')[0]
    $AdminUrl = "https://$tenantShort-admin.sharepoint.com"
}
Write-Host "Connecting to admin center: $AdminUrl"
Connect-SPOWithCert -Url $AdminUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint

# --------------------------------------------
# Resolve input CSV path with heuristic similar to previous Excel logic
# --------------------------------------------
function Resolve-InputCsvPath {
    param([string]$PathArg)
    if ([string]::IsNullOrWhiteSpace($PathArg)) { return $null }

    # Direct path
    if (Test-Path $PathArg) { return (Resolve-Path $PathArg).ProviderPath }

    $candidates = New-Object System.Collections.Generic.List[string]
    $scriptDirName = Split-Path $PSScriptRoot -Leaf
    $collapsed = $PathArg
    $pattern = "($scriptDirName\\)+"
    if ($collapsed -match $pattern) {
        $collapsed = ($collapsed -replace $pattern, "$scriptDirName\")
        if (Test-Path $collapsed) { return (Resolve-Path $collapsed).ProviderPath }
    }

    if (-not [IO.Path]::IsPathRooted($PathArg)) {
        $leaf = Split-Path -Leaf $PathArg
        $candidates.Add( (Join-Path $PSScriptRoot $PathArg) )
        $candidates.Add( (Join-Path $PSScriptRoot $leaf) )
        if ($PathArg -like "$scriptDirName*") {
            $trimmed = $PathArg.Substring($scriptDirName.Length).TrimStart('\','/')
            if ($trimmed) {
                $candidates.Add( (Join-Path $PSScriptRoot $trimmed) )
            }
        }
        if ($leaf -ne 'SharePointURLs.csv') {
            $candidates.Add( (Join-Path $PSScriptRoot 'SharePointURLs.csv') )
        }
    }

    foreach ($c in $candidates) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if (Test-Path $c) { return (Resolve-Path $c).ProviderPath }
    }
    return $null
}

$resolvedInput = Resolve-InputCsvPath -PathArg $InputCsv
if (-not $resolvedInput) {
    Write-Host "Input CSV not found (multiple resolution attempts): $InputCsv"
    Write-Host "Script directory: $PSScriptRoot"
    Write-Host "Verify the file location or provide a full path with -InputCsv."
    exit 1
}
$InputCsv = $resolvedInput
Write-Host "Using input file: $InputCsv"

# --------------------------------------------
# Read CSV
# --------------------------------------------
try {
    $rows = @(Import-Csv -Path $InputCsv)
} catch {
    Write-Host "Failed to read CSV: $($_.Exception.Message)"
    exit 1
}

if (-not $rows -or $rows.Count -eq 0) {
    Write-Host "CSV has no data rows."
    exit 0
}
Write-Host "Raw row count (including possible invalid site rows): $($rows.Count)"

# --------------------------------------------
# Extract & normalize SiteUrl values
# - We scan each object's properties; property name normalized (remove non-alphanumeric, lowercase) == 'siteurl'
# - Filter: non-empty, not '#N/A', must start with http/https
# --------------------------------------------
function Resolve-SiteUrl {
    param($Row)
    if (-not $Row) { return $null }
    foreach ($p in $Row.PSObject.Properties) {
        $canon = ($p.Name -replace '[^A-Za-z0-9]','').ToLowerInvariant()
        if ($canon -eq 'siteurl') {
            return $p.Value
        }
    }
    return $null
}

$siteUrls = New-Object System.Collections.Generic.List[string]
foreach ($r in $rows) {
    $siteUrl = Resolve-SiteUrl -Row $r
    if ([string]::IsNullOrWhiteSpace($siteUrl)) { continue }
    $siteUrl = $siteUrl.ToString().Trim()
    if ($siteUrl -eq "#N/A") { continue }
    if ($siteUrl -notmatch '^https?://') { continue }
    $siteUrls.Add($siteUrl)
}

$siteUrls = $siteUrls | Select-Object -Unique
if (-not $siteUrls -or $siteUrls.Count -eq 0) {
    Write-Host "No valid site URLs after filtering."
    exit 0
}
Write-Host "Total sites to process: $($siteUrls.Count)"

# --------------------------------------------
# Pre-cache tenant metadata (stays in admin context). Failures recorded but do not abort.
# --------------------------------------------
foreach ($u in $siteUrls) {
    if ($tenantCache.ContainsKey($u)) { continue }
    try {
        $tenantCache[$u] = Get-PnPTenantSite -Identity $u -ErrorAction Stop
    } catch {
        Add-Err -SiteUrl $u -Stage "Get-PnPTenantSite" -Message $_.Exception.Message
        $tenantCache[$u] = $null
    }
}

# --------------------------------------------
# Preservation Hold Library helper
# --------------------------------------------
function Get-PreservationHoldLibraryInfo {
    param([switch]$Skip,[string]$ListName = "PreservationHoldLibrary")
    if ($Skip) {
        return [pscustomobject]@{ Exists = $false; SizeGB = 0 }
    }
    $result = [pscustomobject]@{ Exists = $false; SizeGB = 0 }
    try {
        $bytes = Get-PnPFolderStorageMetric -List $ListName | Select-Object -ExpandProperty TotalSize
        if ($bytes) {
            $result.Exists = $true
            $result.SizeGB = [math]::Round($bytes / 1GB, 2)
        }
    } catch {
        # swallow
    }
    return $result
}

# --------------------------------------------
# Connect to a site only if it differs from last one
# --------------------------------------------
function Connect-SiteIfNeeded {
    param([string]$SiteUrl)
    if ($script:currentSite -eq $SiteUrl) { return }
    Connect-SPOWithCert -Url $SiteUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint
    $script:currentSite = $SiteUrl
}

# --------------------------------------------
# Build one record for output
# Steps:
#   - Use cached tenantSite if available (gives title, quota, usage, owner, group, teams flag)
#   - If missing, call Get-SPOBasicSiteMetadata (helper)
#   - Membership & group info from helper functions
#   - Preservation Hold Library info (optional)
#   - Normalize into consistent property order
# --------------------------------------------
function Build-Record {
    param([string]$SiteUrl)

    $tenantSite = $tenantCache[$SiteUrl]

    try {
        Connect-SiteIfNeeded -SiteUrl $SiteUrl

        $basic = if ($tenantSite) {
            [pscustomobject]@{
                SiteUrl          = $SiteUrl
                OwnerEmail       = $tenantSite.OwnerEmail
                GroupId          = $tenantSite.GroupId.Guid
                IsTeamsConnected = $tenantSite.IsTeamsConnected
            }
        } else {
            Get-SPOBasicSiteMetadata -SiteUrl $SiteUrl
        }

        $assoc = Get-SPOSiteMembership -SiteUrl $SiteUrl
        $ginfo = Get-SPOM365GroupInfo -GroupIdString $basic.GroupId
        $ph    = Get-PreservationHoldLibraryInfo -Skip:$SkipPreservationHoldLibrary

        $storageQuotaGB = if ($tenantSite -and $tenantSite.StorageQuota -gt 0) { [math]::Round($tenantSite.StorageQuota / 1024, 2) } else { '' }
        $storageUsedGB  = if ($tenantSite -and $tenantSite.StorageUsageCurrent -ge 0) { [math]::Round($tenantSite.StorageUsageCurrent / 1024, 2) } else { '' }

        $obj = [pscustomobject]@{
            SiteTitle                 = if ($tenantSite) { $tenantSite.Title } else { 'N/A' }
            SiteUrl                   = $SiteUrl
            StorageQuotaGB            = $storageQuotaGB
            StorageUsedGB             = $storageUsedGB
            LastContentModifiedDate   = if ($tenantSite) { $tenantSite.LastContentModifiedDate } else { $null }
            OwnerEmail                = $basic.OwnerEmail
            IsM365GroupConnected      = $ginfo.IsM365GroupConnected
            M365GroupDisplayName      = $ginfo.M365GroupDisplayName
            M365GroupOwnersEmails     = ($ginfo.M365GroupOwnersEmails -join '; ')
            M365GroupMembersEmails    = ($ginfo.M365GroupMembersEmails -join '; ')
            SiteAdminsEmails          = ($assoc.SiteAdminsEmails -join '; ')
            SiteOwnersEmails          = ($assoc.SiteOwnersEmails -join '; ')
            SiteMembersEmails         = ($assoc.SiteMembersEmails -join '; ')
            SiteVisitorsEmails        = ($assoc.SiteVisitorsEmails -join '; ')
            IsTeamsConnected          = $basic.IsTeamsConnected
            PreservationHoldLibrary   = $ph.Exists
            PreservationHoldLibrarySizeGB = $ph.SizeGB
        }

        return $obj | Select-Object -Property $ReportColumns
    } catch {
        Add-Err -SiteUrl $SiteUrl -Stage "BuildRecord" -Message $_.Exception.Message
        Write-Warning "Failed processing: $SiteUrl -> $($_.Exception.Message)"
        return $null
    }
}

# --------------------------------------------
# Main processing loop
# --------------------------------------------
$records = New-Object System.Collections.Generic.List[object]
$total   = $siteUrls.Count
$idx     = 0

foreach ($s in $siteUrls) {
    $idx++
    Write-Host "[$idx/$total] $s"
    $rec = Build-Record -SiteUrl $s
    if ($rec) { $records.Add($rec) }
}

if ($records.Count -eq 0) {
    Write-Host "No records to export."
    exit 0
}

# --------------------------------------------
# Export results
# --------------------------------------------
try {
    $records | Export-Excel -Path $OutputFile -WorksheetName 'Report' -TableName 'Report' -AutoSize -ClearSheet
    Write-Host "Written output file: $OutputFile (records: $($records.Count))"
} catch {
    Write-Host "Export failed: $($_.Exception.Message)"
    exit 1
}

# --------------------------------------------
# Error summary (console only)
# --------------------------------------------
if ($errors.Count -gt 0) {
    Write-Host "Completed with errors. Error count: $($errors.Count)"
    $errors | Select-Object -First 10 | Format-Table -AutoSize | Out-String | Write-Host
} else {
    Write-Host "Completed successfully with no errors."
}
