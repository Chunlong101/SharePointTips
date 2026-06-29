<#
.SYNOPSIS
    Restore files/folders from a site's Preservation Hold Library (PHL) back to
    their original location, using PnP PowerShell.

.DESCRIPTION
    When content under a retention policy / hold is deleted or modified, SharePoint
    keeps a copy in the hidden "Preservation Hold Library". Each preserved item carries
    a "PreservationOriginalURL" field pointing to where it originally lived.

    This script connects to the site, scans the Preservation Hold Library, finds items
    whose original path matches the file name or folder name you specify, downloads each
    preserved copy, recreates the original folder path if needed, and re-uploads the file
    to its original location.

.PARAMETER SiteUrl
    The SharePoint site (web) URL, e.g. https://chunlong101.sharepoint.com/sites/RetentionPolicy

.PARAMETER Name
    The file name (e.g. "readme.txt") OR folder name (e.g. "2023") to restore.
    - If it matches a file name, only that file is restored.
    - If it matches a folder name, every preserved item whose original path contains
      that folder is restored (recursively).
    Matching is case-insensitive and is done against the original path / file name.

.PARAMETER LatestOnly
    If a file was preserved multiple times, restore only the most recent preserved copy
    (by Date Preserved). Default: $true.

.PARAMETER Overwrite
    Overwrite the file at the original location if it already exists. Default: $false.

.PARAMETER ClientId
    (Optional) Entra app (client) ID to use for the interactive connection. If your tenant
    has blocked the default multi-tenant "PnP Management Shell" app, register your own app
    (Register-PnPEntraIDApp) and pass its client id here.

.PARAMETER WhatIf
    Show what would be restored without actually writing anything.

.EXAMPLE
    # Restore a single file to its original location
    .\Restore-FromPreservationHold.ps1 -SiteUrl https://chunlong101.sharepoint.com/sites/RetentionPolicy -Name "readme.txt"

.EXAMPLE
    # Restore everything that originally lived under the "2023" folder
    .\Restore-FromPreservationHold.ps1 -SiteUrl https://chunlong101.sharepoint.com/sites/RetentionPolicy -Name "2023"

.EXAMPLE
    # Preview only
    .\Restore-FromPreservationHold.ps1 -SiteUrl https://.../sites/RetentionPolicy -Name "2023" -WhatIf

.NOTES
    Requires the PnP.PowerShell module:  Install-Module PnP.PowerShell -Scope CurrentUser
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [bool]$LatestOnly = $true,

    [switch]$Overwrite,

    [string]$ClientId
)

$ErrorActionPreference = 'Stop'

# --- Ensure module ---------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    throw "PnP.PowerShell module not found. Install it with: Install-Module PnP.PowerShell -Scope CurrentUser"
}
Import-Module PnP.PowerShell -ErrorAction Stop

# --- Connect ---------------------------------------------------------------
Write-Host "Connecting to $SiteUrl ..." -ForegroundColor Cyan
if ($ClientId) {
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
}
else {
    Connect-PnPOnline -Url $SiteUrl -Interactive
}

$web = Get-PnPWeb
$webServerRel = $web.ServerRelativeUrl.TrimEnd('/')   # e.g. /sites/RetentionPolicy
Write-Host "Connected to web: $($web.Url)" -ForegroundColor Green

# --- Locate the Preservation Hold Library ----------------------------------
# Its title is normally "Preservation Hold Library"; resolve defensively by URL too.
$phl = Get-PnPList | Where-Object {
    $_.Title -eq 'Preservation Hold Library' -or
    $_.RootFolder.ServerRelativeUrl -match '/PreservationHoldLibrary$'
} | Select-Object -First 1

if (-not $phl) {
    throw "Preservation Hold Library not found on $SiteUrl. (It only exists when a retention/hold policy has preserved content.)"
}
Write-Host "Found library: $($phl.Title)" -ForegroundColor Green

# --- Read all preserved items ----------------------------------------------
# Fields of interest:
#   FileRef                  -> current server-relative URL inside the PHL
#   FileLeafRef              -> file name
#   PreservationOriginalURL  -> original server-relative URL (where to restore to)
#   PreservationDatePreserved-> when it was preserved
Write-Host "Reading preserved items (this can take a moment for large libraries)..." -ForegroundColor Cyan
$items = Get-PnPListItem -List $phl -PageSize 500 -Fields 'FileRef','FileLeafRef','PreservationOriginalURL','PreservationDatePreserved','FSObjType'

# keep files only (FSObjType 0 = file, 1 = folder); we restore files and rebuild folders
$files = $items | Where-Object { $_.FieldValues.FSObjType -eq 0 }

# --- Filter by the requested name ------------------------------------------
$needle = $Name.Trim().Trim('/')
function Get-OriginalUrl($it) {
    $u = $it.FieldValues.PreservationOriginalURL
    if ($u -is [Microsoft.SharePoint.Client.FieldUrlValue]) { return $u.Url }
    return [string]$u
}

$matches = foreach ($it in $files) {
    $orig = Get-OriginalUrl $it
    if ([string]::IsNullOrWhiteSpace($orig)) { $orig = $it.FieldValues.FileRef }
    $leaf = $it.FieldValues.FileLeafRef
    $segments = $orig -split '/'
    # match if the needle equals the file name, or appears as a folder segment, or is a substring of path
    $isMatch =
        ($leaf -ieq $needle) -or
        ($segments -icontains $needle) -or
        ($orig -ilike "*/$needle/*") -or
        ($orig -ilike "*/$needle")
    if ($isMatch) {
        [pscustomobject]@{
            Item        = $it
            OriginalUrl = $orig
            FileRef     = $it.FieldValues.FileRef
            Leaf        = $leaf
            Preserved   = $it.FieldValues.PreservationDatePreserved
        }
    }
}

if (-not $matches) {
    Write-Warning "No preserved items in the Preservation Hold Library match '$Name'."
    Disconnect-PnPOnline
    return
}

# --- Optionally keep only the most recent preserved copy per original URL ---
if ($LatestOnly) {
    $matches = $matches |
        Group-Object OriginalUrl |
        ForEach-Object { $_.Group | Sort-Object Preserved -Descending | Select-Object -First 1 }
}

Write-Host ("Matched {0} item(s) to restore." -f ($matches | Measure-Object).Count) -ForegroundColor Yellow

# --- Restore loop ----------------------------------------------------------
$tempRoot = Join-Path $env:TEMP ("PHLRestore_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$restored = 0; $skipped = 0; $failed = 0

foreach ($m in $matches) {
    $orig = $m.OriginalUrl
    # Compute site-relative original folder + filename
    if ($orig.StartsWith($webServerRel, [System.StringComparison]::OrdinalIgnoreCase)) {
        $siteRel = $orig.Substring($webServerRel.Length).TrimStart('/')   # e.g. Shared Documents/2023/readme.txt
    }
    else {
        $siteRel = $orig.TrimStart('/')
    }
    $fileName   = Split-Path $siteRel -Leaf
    $folderRel  = Split-Path $siteRel -Parent
    $folderRel  = ($folderRel -replace '\\','/').Trim('/')               # site-relative folder
    $destFull   = "$webServerRel/$siteRel" -replace '//','/'

    Write-Host ""
    Write-Host "Restore: $($m.FileRef)" -ForegroundColor Cyan
    Write-Host "     -> $destFull"

    if ($PSCmdlet.ShouldProcess($destFull, "Restore from Preservation Hold Library")) {
        try {
            # Skip if target exists and not overwriting
            if (-not $Overwrite) {
                $existing = Get-PnPFile -Url $destFull -AsListItem -ErrorAction SilentlyContinue
                if ($existing) {
                    Write-Warning "  Target already exists; skipping (use -Overwrite to replace)."
                    $skipped++
                    continue
                }
            }

            # Ensure the destination folder exists (creates nested folders).
            # Note: newer PnP.PowerShell uses -SiteRelativePath (older used -SiteRelativeUrl).
            if ($folderRel) { Resolve-PnPFolder -SiteRelativePath $folderRel | Out-Null }

            # Download the preserved copy to temp
            $localPath = Join-Path $tempRoot ([guid]::NewGuid().ToString('N') + '_' + $fileName)
            Get-PnPFile -Url $m.FileRef -Path $tempRoot -FileName ([System.IO.Path]::GetFileName($localPath)) -AsFile -Force | Out-Null

            # Re-upload to original folder. Add-PnPFile -Folder expects a SITE-relative path
            # (e.g. "Shared Documents/2023"), not a server-relative one.
            Add-PnPFile -Path $localPath -Folder $folderRel -NewFileName $fileName | Out-Null

            Write-Host "  Restored OK" -ForegroundColor Green
            $restored++
        }
        catch {
            Write-Warning "  FAILED: $($_.Exception.Message)"
            $failed++
        }
    }
}

# --- Cleanup & summary ------------------------------------------------------
Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==================== Summary ====================" -ForegroundColor Magenta
Write-Host ("Restored: {0}   Skipped: {1}   Failed: {2}" -f $restored, $skipped, $failed)
Disconnect-PnPOnline
