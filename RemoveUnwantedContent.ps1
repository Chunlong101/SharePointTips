<#
.SYNOPSIS
Finds incident-matching folders; optionally recycles trees containing no files.
.DESCRIPTION
Requires PnP.PowerShell 3.x, an Entra application client ID configured for PnP
interactive delegated sign-in, and a site collection administrator account.
The application must have the necessary delegated SharePoint permissions and
tenant consent. The client ID is not a client secret.

F5 usage: open this saved file in VS Code with the PowerShell extension and
select PowerShell 7.4.6 or newer. Edit the defaults in the configuration area
below, save, then press F5 (PowerShell: Launch Current File). Blank SarahLogin
and ClientId values are prompted at startup. Windows PowerShell ISE runs
Windows PowerShell 5.1 and is NOT supported by PnP.PowerShell 3.x.
RunMode defaults to Preview. Set WhatIf to simulate, or Delete to request
recycle-bin deletion with confirmation. Command-line parameters still work.

Scans non-hidden document libraries in the specified SharePoint web and its
subsites. Does not scan other site collections, OneDrive, hidden libraries,
or the recycle bin. Matches Author (Created By), NOT Modified By.

Dates are interpreted in EACH WEB'S regional timezone, not the workstation's.
Use -TimeZoneId if the screenshot used a personal timezone override; supply a
TimeZoneInfo ID supported by the computer running this script.

All list items are paged in indexed ID order; filters are evaluated locally.
This avoids an unindexed Author/date CAML filter on large libraries.
Only metadata-matching folders whose ENTIRE subtree contains ZERO files are
eligible. Empty subfolders at any depth are allowed, even if their own creator
or dates do not match. Recycling a selected root recycles ALL its descendants.
Only the outermost eligible matching roots are selected; matching descendants
are reported as SkippedCoveredByAncestor and are not recycled independently.

Preview CSV is written completely before any deletion. -Delete enables
ShouldProcess confirmation; -WhatIf still prevents recycling. Each selected
folder is re-read AFTER confirmation, compared with its preview snapshot,
and recursively checked for files immediately before recycling.
Candidates.csv uses FileFreeTreeAtScan (not immediate-child emptiness) and
RecycleScope = FolderAndAllDescendants. CoveredByAncestor identifies folders
included in an outer candidate; they remain covered even if that root is
declined or skipped during deletion.

IMPORTANT: SharePoint does not provide an atomic "recycle only if file-free"
operation here. Stop sync clients and other writes to the affected locations
and coordinate a maintenance window BEFORE deletion. A concurrent upload
between the final check and Recycle could otherwise be recycled with its parent.
Recycle-bin retention/policy applies; recovery is not an unlimited backup.

Service/permission errors stop the run, rather than treating unknown contents
as empty. Actions.csv records attempts and outcomes; an AttemptingRecycle row
without a final result requires checking SharePoint before retrying.
Reports contain private tenant metadata. Store them in an approved location.
.EXAMPLE
Open this file in VS Code, save, and press F5. Leave RunMode = 'Preview' first.
.EXAMPLE
.\RemoveUnwantedContent.ps1 -SarahLogin 'actual-UPN@customer-domain' -ClientId 'your-app-client-id'
.EXAMPLE
.\RemoveUnwantedContent.ps1 -SarahLogin 'actual-UPN@customer-domain' -ClientId 'your-app-client-id' -Delete -WhatIf
.EXAMPLE
.\RemoveUnwantedContent.ps1 -SarahLogin 'actual-UPN@customer-domain' -ClientId 'your-app-client-id' -Delete
#>

#requires -Version 7.4.6

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # F5 CONFIGURATION: fill these in, or leave blank to be prompted.
    [string]$SarahLogin = '',

    [guid]$ClientId = [guid]::Empty,

    # Preview = report only; WhatIf = simulated deletion; Delete = recycle.
    [ValidateSet('Preview', 'WhatIf', 'Delete')]
    [string]$RunMode = 'Preview',

    [uri]$SiteUrl = 'https://goodbabyint.sharepoint.com/sites/CYBEXOPSHUB',

    [datetime]$CreatedDate = [datetime]'2026-10-02',
    [datetime]$ModifiedDate = [datetime]'2023-10-16',
    [string]$TimeZoneId,
    [string]$ReportDirectory,
    [switch]$Delete
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-CaseUtc {
    param([Parameter(Mandatory)][datetime]$Value)
    if ($Value.Kind -eq [DateTimeKind]::Local) {
        return $Value.ToUniversalTime()
    }
    # CSOM DatesInUtc can deserialize as Unspecified; do not use the PC timezone.
    return [datetime]::SpecifyKind($Value, [DateTimeKind]::Utc)
}

function Test-CaseFolderMatch {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Fields,
          [Parameter(Mandatory)][hashtable]$Criteria)
    foreach ($name in 'FSObjType', 'Author', 'Created', 'Modified') {
        if (-not $Fields.ContainsKey($name) -or $null -eq $Fields[$name]) { return $false }
    }
    if ([int]$Fields.FSObjType -ne 1 -or $Fields.Author.LookupId -ne $Criteria.AuthorId) {
        return $false
    }
    $created = ConvertTo-CaseUtc $Fields.Created
    $modified = ConvertTo-CaseUtc $Fields.Modified
    return ($created -ge $Criteria.CreatedStartUtc -and $created -lt $Criteria.CreatedEndUtc -and
            $modified -ge $Criteria.ModifiedStartUtc -and $modified -lt $Criteria.ModifiedEndUtc)
}

function New-CaseSnapshot {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Fields)
    return @{
        UniqueId = ([guid]$Fields.UniqueId).ToString()
        FileRef = [string]$Fields.FileRef
        AuthorId = [int]$Fields.Author.LookupId
        CreatedUtc = (ConvertTo-CaseUtc $Fields.Created).ToString('o')
        ModifiedUtc = (ConvertTo-CaseUtc $Fields.Modified).ToString('o')
    }
}

function Test-CaseSnapshot {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Fields,
          [Parameter(Mandatory)][hashtable]$Snapshot)
    $current = New-CaseSnapshot $Fields
    foreach ($key in $Snapshot.Keys) {
        if ($current[$key] -cne $Snapshot[$key]) { return $false }
    }
    return $true
}

function Test-CaseFileFreeItems {
    param([Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][object[]]$Items)
    if ($null -eq $Items) { throw 'Descendant enumeration is unknown; refusing to treat the tree as file-free.' }
    foreach ($item in $Items) {
        if ($null -eq $item -or -not $item.FieldValues.ContainsKey('FSObjType') -or
            $null -eq $item.FieldValues.FSObjType) {
            throw 'Unknown descendant item type; refusing to recycle the tree.'
        }
        $type = [int]$item.FieldValues.FSObjType
        if ($type -eq 0) { return $false }
        if ($type -ne 1) { throw 'Unknown descendant item type; refusing to recycle the tree.' }
    }
    return $true
}

function Test-CaseFolderTreeFileFree {
    param($List, [string]$FolderPath, $Connection)
    $query = [Microsoft.SharePoint.Client.CamlQuery]::new()
    $query.FolderServerRelativePath = [Microsoft.SharePoint.Client.ResourcePath]::FromDecodedUrl($FolderPath)
    # Page all descendants in ID order; a server-side type filter can hit list thresholds.
    $query.ViewXml = "<View Scope='RecursiveAll'><Query><OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy></Query><ViewFields><FieldRef Name='ID'/><FieldRef Name='FSObjType'/></ViewFields><RowLimit Paged='TRUE'>2000</RowLimit></View>"
    do {
        $items = $List.GetItems($query)
        if ($null -eq $items) { throw 'Descendant enumeration is unknown; refusing to treat the tree as file-free.' }
        $Connection.Context.Load($items)
        Invoke-PnPQuery -Connection $Connection
        if (-not (Test-CaseFileFreeItems -Items $items)) { return $false }
        $query.ListItemCollectionPosition = $items.ListItemCollectionPosition
    } while ($null -ne $query.ListItemCollectionPosition)
    return $true
}

function Write-CaseCsvRow {
    param([Parameter(Mandatory)]$Row, [Parameter(Mandatory)][string]$Path)
    $safe = [ordered]@{}
    foreach ($property in $Row.PSObject.Properties) {
        $value = $property.Value
        if ($value -is [string] -and $value -match '^[=+\-@\t\r\n]') {
            $value = "'" + $value
        }
        $safe[$property.Name] = $value
    }
    [pscustomobject]$safe | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8BOM -Append -WhatIf:$false -Confirm:$false
}

function Get-CaseDateBoundaries {
    param($Web, [datetime]$CreatedDay, [datetime]$ModifiedDay,
          [string]$OverrideTimeZoneId, $Connection)
    $days = @($CreatedDay.Date, $CreatedDay.Date.AddDays(1),
              $ModifiedDay.Date, $ModifiedDay.Date.AddDays(1))
    if ($OverrideTimeZoneId) {
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById($OverrideTimeZoneId)
        $utc = foreach ($day in $days) {
            $local = [datetime]::SpecifyKind($day, [DateTimeKind]::Unspecified)
            if ($zone.IsInvalidTime($local) -or $zone.IsAmbiguousTime($local)) {
                throw "Ambiguous or invalid local midnight: $local ($OverrideTimeZoneId)."
            }
            [TimeZoneInfo]::ConvertTimeToUtc($local, $zone)
        }
        $description = $zone.Id
    }
    else {
        $regional = Get-PnPProperty -ClientObject $Web -Property RegionalSettings -Connection $Connection
        $zone = Get-PnPProperty -ClientObject $regional -Property TimeZone -Connection $Connection
        $description = Get-PnPProperty -ClientObject $zone -Property Description -Connection $Connection
        $results = foreach ($day in $days) {
            $zone.LocalTimeToUTC([datetime]::SpecifyKind($day, [DateTimeKind]::Unspecified))
        }
        Invoke-PnPQuery -Connection $Connection
        $utc = @($results | ForEach-Object { ConvertTo-CaseUtc $_.Value })
    }
    return @{
        CreatedStartUtc = $utc[0]; CreatedEndUtc = $utc[1]
        ModifiedStartUtc = $utc[2]; ModifiedEndUtc = $utc[3]
        TimeZone = [string]$description
    }
}

# Dot-sourcing loads pure helpers for offline tests without contacting SharePoint.
if ($MyInvocation.InvocationName -eq '.') { return }

if ($SiteUrl.Scheme -ne 'https' -or $SiteUrl.Query -or $SiteUrl.Fragment) {
    throw 'SiteUrl must be an HTTPS SharePoint web URL without query or fragment.'
}
if ([string]::IsNullOrWhiteSpace($SarahLogin)) {
    $SarahLogin = Read-Host 'Enter Sarah actual email or UPN'
}
$SarahLogin = $SarahLogin.Trim()
if ($SarahLogin -notmatch '^[^@\s]+@[^@\s]+$') {
    throw 'SarahLogin must be Sarah actual email or UPN, not a display name.'
}
if ($ClientId -eq [guid]::Empty) {
    $inputClientId = Read-Host 'Enter the authorized Entra application Client ID'
    if (-not [guid]::TryParse($inputClientId, [ref]$ClientId)) {
        throw 'Client ID must be a valid application GUID, not a secret.'
    }
}
if ($ClientId -eq [guid]::Empty) { throw 'A nonempty Entra application client ID is required.' }
if (-not $PSBoundParameters.ContainsKey('Delete') -and $RunMode -ne 'Preview') {
    $Delete = $true
}
if ($RunMode -eq 'WhatIf') {
    $WhatIfPreference = $true
}
Import-Module PnP.PowerShell -MinimumVersion 3.0.0 -ErrorAction Stop
if (-not $ReportDirectory) {
    $ReportDirectory = Join-Path $PSScriptRoot (
        'Case2610150040002985-{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N').Substring(0, 8))
}
if (Test-Path -LiteralPath $ReportDirectory) {
    throw "ReportDirectory already exists. Choose a new directory: $ReportDirectory"
}
# Local report output remains intentional even under -WhatIf.
$null = New-Item -ItemType Directory -Path $ReportDirectory -WhatIf:$false -Confirm:$false
$previewPath = Join-Path $ReportDirectory 'Candidates.csv'
$actionsPath = Join-Path $ReportDirectory 'Actions.csv'
$connection = Connect-PnPOnline -Url $SiteUrl.AbsoluteUri -Interactive -ClientId $ClientId -ReturnConnection
$ctx = $connection.Context
$currentUser = Get-PnPProperty -ClientObject $ctx.Web -Property CurrentUser -Connection $connection
$isAdmin = Get-PnPProperty -ClientObject $currentUser -Property IsSiteAdmin -Connection $connection
if (-not $isAdmin) {
    throw 'Sign in as a site collection administrator. Trimmed access cannot prove a folder is empty.'
}
$author = Get-PnPUser -Identity $SarahLogin -Connection $connection
if ($null -eq $author) { throw "Sarah's account was not found in this site collection: $SarahLogin" }
$loginSuffix = ($author.LoginName -split '\|')[-1]
if ($author.Email -ine $SarahLogin -and $loginSuffix -ine $SarahLogin) {
    throw "Resolved account does not exactly match the supplied email/UPN: $($author.LoginName)"
}
Write-Host "Author: $($author.Title) / $($author.LoginName) / site user ID $($author.Id)"
Write-Host "Mode: $(if ($Delete) { 'DELETE requested (confirmation/WhatIf applies)' } else { 'PREVIEW ONLY' })"
Write-Warning 'Confirm the screenshot timezone. Site regional time is the default, not necessarily the viewer personal timezone.'

$candidates = [System.Collections.Generic.List[object]]::new()
$previewRows = [System.Collections.Generic.List[object]]::new()
$webs = @(Get-PnPSubWeb -Recurse -IncludeRootWeb -Connection $connection)
$fieldNames = @('ID', 'FSObjType', 'FileLeafRef', 'FileRef', 'UniqueId', 'Created',
                'Modified', 'Author', 'Editor', 'ItemChildCount', 'FolderChildCount')
$viewFields = ($fieldNames | ForEach-Object { "<FieldRef Name='$_'/>" }) -join ''
$scannedLibraries = 0
$matched = 0
foreach ($web in $webs) {
    $webUrl = Get-PnPProperty -ClientObject $web -Property Url -Connection $connection
    $criteria = Get-CaseDateBoundaries -Web $web -CreatedDay $CreatedDate -ModifiedDay $ModifiedDate `
        -OverrideTimeZoneId $TimeZoneId -Connection $connection
    $criteria.AuthorId = $author.Id
    Write-Host "Scanning $webUrl; date timezone: $($criteria.TimeZone)"
    $lists = Get-PnPProperty -ClientObject $web -Property Lists -Connection $connection
    foreach ($list in $lists) {
        if ($list.BaseType -ne [Microsoft.SharePoint.Client.BaseType]::DocumentLibrary -or $list.Hidden) { continue }
        $scannedLibraries++
        Write-Host "  Library: $($list.Title)"
        $query = [Microsoft.SharePoint.Client.CamlQuery]::new()
        $query.DatesInUtc = $true
        $query.ViewXml = "<View Scope='RecursiveAll'><Query><OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy></Query><ViewFields>$viewFields</ViewFields><RowLimit Paged='TRUE'>2000</RowLimit></View>"
        do {
            $items = $list.GetItems($query)
            $ctx.Load($items)
            Invoke-PnPQuery -Connection $connection
            foreach ($item in $items) {
                $fields = $item.FieldValues
                if (-not (Test-CaseFolderMatch -Fields $fields -Criteria $criteria)) { continue }
                $matched++
                $fileFree = Test-CaseFolderTreeFileFree -List $list -FolderPath $fields.FileRef -Connection $connection
                $snapshot = New-CaseSnapshot $fields
                $editor = $fields.Editor
                $row = [pscustomobject][ordered]@{
                    WebUrl = $webUrl
                    Library = $list.Title
                    LibraryId = $list.Id.ToString()
                    ItemId = $item.Id
                    UniqueId = $snapshot.UniqueId
                    Name = $fields.FileLeafRef
                    ServerRelativeUrl = $snapshot.FileRef
                    CreatedBy = $fields.Author.LookupValue
                    CreatedById = $snapshot.AuthorId
                    ResolvedAuthorLogin = $author.LoginName
                    ModifiedBy = $(if ($null -ne $editor) { $editor.LookupValue } else { '' })
                    CreatedUtc = $snapshot.CreatedUtc
                    ModifiedUtc = $snapshot.ModifiedUtc
                    DateFilterTimeZone = $criteria.TimeZone
                    CreatedDayFilter = $CreatedDate.ToString('yyyy-MM-dd')
                    ModifiedDayFilter = $ModifiedDate.ToString('yyyy-MM-dd')
                    ReportedFileChildCount = $fields.ItemChildCount
                    ReportedFolderChildCount = $fields.FolderChildCount
                    FileFreeTreeAtScan = $fileFree
                    RecycleScope = 'FolderAndAllDescendants'
                    CoveredByAncestor = ''
                    Status = $(if ($fileFree) { 'PreviewFileFreeTree' } else { 'SkippedContainsFiles' })
                }
                $previewRows.Add($row)
                if ($fileFree) {
                    $candidates.Add([pscustomobject]@{
                        List = $list; ItemId = $item.Id; Snapshot = $snapshot; Criteria = $criteria; Report = $row
                    })
                }
            }
            $query.ListItemCollectionPosition = $items.ListItemCollectionPosition
        } while ($null -ne $query.ListItemCollectionPosition)
    }
}
$selectedRoots = [System.Collections.Generic.List[object]]::new()
foreach ($candidate in ($candidates | Sort-Object { $_.Snapshot.FileRef.Length })) {
    $ancestor = $selectedRoots | Where-Object {
        $_.List.Id -eq $candidate.List.Id -and
        $candidate.Snapshot.FileRef.StartsWith(
            $_.Snapshot.FileRef.TrimEnd('/') + '/', [StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1
    if ($null -ne $ancestor) {
        $candidate.Report.Status = 'SkippedCoveredByAncestor'
        $candidate.Report.CoveredByAncestor = $ancestor.Snapshot.FileRef
    }
    else {
        $selectedRoots.Add($candidate)
    }
}
foreach ($row in $previewRows) {
    Write-CaseCsvRow -Row $row -Path $previewPath
}
Write-Host "Scan complete. Libraries: $scannedLibraries; metadata matches: $matched; file-free matches: $($candidates.Count); selected root trees: $($selectedRoots.Count)."
Write-Host "Reports: $ReportDirectory"
if ($matched -eq 0) {
    Write-Warning 'No matching folders. No Candidates.csv was created. Verify the author, dates, timezone, and web scope.'
}
if (-not $Delete -or $selectedRoots.Count -eq 0) { return }

Write-Warning 'BEFORE proceeding: stop sync/other writes during a maintenance window. Each selected root and ALL its descendant folders will be recycled, including nonmatching descendants. File-check and recycle are not atomic.'
foreach ($candidate in $selectedRoots) {
    $path = $candidate.Snapshot.FileRef
    $action = [pscustomobject][ordered]@{
        TimeUtc = [datetime]::UtcNow.ToString('o')
        LibraryId = $candidate.List.Id.ToString()
        ItemId = $candidate.ItemId
        UniqueId = $candidate.Snapshot.UniqueId
        ServerRelativeUrl = $path
        RecycleScope = 'FolderAndAllDescendants'
        Status = ''
        RecycleBinId = ''
        Error = ''
    }
    if (-not $PSCmdlet.ShouldProcess($path, 'Recycle matching folder and ALL descendant folders in its file-free tree')) {
        $action.Status = 'NotExecuted'
        Write-CaseCsvRow -Row $action -Path $actionsPath
        continue
    }
    try {
        # A fresh query is mandatory: the preview object may now be stale.
        $fresh = $candidate.List.GetItemById($candidate.ItemId)
        $ctx.Load($fresh)
        Invoke-PnPQuery -Connection $connection
        if (-not (Test-CaseFolderMatch -Fields $fresh.FieldValues -Criteria $candidate.Criteria) -or
            -not (Test-CaseSnapshot -Fields $fresh.FieldValues -Snapshot $candidate.Snapshot)) {
            $action.Status = 'SkippedMetadataChanged'
        }
        else {
            if (-not (Test-CaseFolderTreeFileFree -List $candidate.List -FolderPath $path -Connection $connection)) {
                $action.Status = 'SkippedNowContainsFiles'
            }
            else {
                $action.Status = 'AttemptingRecycle'
                Write-CaseCsvRow -Row $action -Path $actionsPath
                $result = $fresh.Recycle()
                Invoke-PnPQuery -Connection $connection
                $action.Status = 'Recycled'
                $action.RecycleBinId = $result.Value.ToString()
            }
        }
    }
    catch {
        $action.Status = 'FailedOrOutcomeUnknown'
        $action.Error = $_.Exception.Message
        $action.TimeUtc = [datetime]::UtcNow.ToString('o')
        Write-CaseCsvRow -Row $action -Path $actionsPath
        throw
    }
    $action.TimeUtc = [datetime]::UtcNow.ToString('o')
    Write-CaseCsvRow -Row $action -Path $actionsPath
    Write-Host "$($action.Status): $path"
}
