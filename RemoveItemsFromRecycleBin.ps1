##
## Script: RemoveItemsFromRecycleBin.ps1
## Purpose:
##   Permanently delete items/files from the SharePoint site recycle bin
##   based on their "Date Deleted" value.
##
## Date filters (all dates are inclusive and only the date part is compared):
##   - DeletedDateString : delete items where Date Deleted = this date
##   - DeletedDateAfter  : delete items where Date Deleted >= this date
##   - DeletedDateBefore : delete items where Date Deleted <= this date
##   - If DeletedDateAfter and DeletedDateBefore are both set, items
##     with DeletedDate between them (inclusive) are deleted.
##
## Usage examples (run in PowerShell):
##   1) Delete items deleted on a specific date:
##        - Set DeletedDateString = "2026-01-09"
##        - .\RemoveItemsFromRecycleBin.ps1
##
##   2) Delete items deleted on/after a specific date:
##        - Set DeletedDateAfter = "2026-01-08"
##        - .\RemoveItemsFromRecycleBin.ps1
##
##   3) Delete items deleted on/before a specific date:
##        - Set DeletedDateBefore = "2026-01-08"
##        - .\RemoveItemsFromRecycleBin.ps1
##
##   4) Delete items within a date range:
##        - Set DeletedDateAfter  = "2026-01-01"
##        - Set DeletedDateBefore = "2026-01-31"
##        - .\RemoveItemsFromRecycleBin.ps1
##
## Requirements:
##   - PnP.PowerShell module installed
##   - An Entra ID app with appropriate SharePoint permissions, and its ClientId
##
## Variables that need to be changed to match your environment
##
$siteUrl = "https://xxx.sharepoint.com/sites/xxx"
$ClientId = "xxx"
$DeletedDateString = "2026-01-09"       # Exact match of a single date (Date Deleted)
$DeletedDateAfter  = ""                 # Delete items on/after this date (>=, inclusive)
$DeletedDateBefore = ""                 # Delete items on/before this date (<=, inclusive)

$ErrorActionPreference = "Stop"

$targetDateExact  = $null
$targetDateAfter  = $null
$targetDateBefore = $null

if ($DeletedDateString) {
    $targetDateExact = Get-Date $DeletedDateString
    Write-Host ("Target deleted date (Exact, local): {0}" -f $targetDateExact.Date)
}

if ($DeletedDateAfter) {
    $targetDateAfter = Get-Date $DeletedDateAfter
    Write-Host ("Target deleted date (After or equal, local): >= {0}" -f $targetDateAfter.Date)
}

if ($DeletedDateBefore) {
    $targetDateBefore = Get-Date $DeletedDateBefore
    Write-Host ("Target deleted date (Before or equal, local): <= {0}" -f $targetDateBefore.Date)
}

Connect-PnPOnline -Url $siteUrl -Interactive -ClientId $ClientId

Write-Host "Getting recycle bin items..."

$recycleItems = Get-PnPRecycleBinItem -RowLimit 1000

if (-not $recycleItems -or $recycleItems.Count -eq 0) {
    Write-Host "Recycle Bin is empty. Nothing to delete."
    return
}

Write-Host ("Total items in recycle bin: {0}" -f $recycleItems.Count)

$itemsToDelete = $null

if ($targetDateExact) {
    # Mode 1: Date Deleted equals a specific day
    $itemsToDelete = $recycleItems | Where-Object { $_.DeletedDate.Date -eq $targetDateExact.Date }
    if (-not $itemsToDelete -or $itemsToDelete.Count -eq 0) {
        Write-Host ("No items found in recycle bin with Date Deleted = {0}" -f $targetDateExact.ToShortDateString())
        return
    }
    Write-Host ("Items to delete (Date Deleted = {0}): {1}" -f $targetDateExact.ToShortDateString(), $itemsToDelete.Count)
}
elseif ($targetDateAfter -and -not $targetDateBefore) {
    # Mode 2: Date Deleted on/after a specific day (>=, inclusive)
    $itemsToDelete = $recycleItems | Where-Object { $_.DeletedDate.Date -ge $targetDateAfter.Date }
    if (-not $itemsToDelete -or $itemsToDelete.Count -eq 0) {
        Write-Host ("No items found in recycle bin with Date Deleted >= {0}" -f $targetDateAfter.ToShortDateString())
        return
    }
    Write-Host ("Items to delete (Date Deleted >= {0}): {1}" -f $targetDateAfter.ToShortDateString(), $itemsToDelete.Count)
}
elseif ($targetDateBefore -and -not $targetDateAfter) {
    # Mode 3: Date Deleted on/before a specific day (<=, inclusive)
    $itemsToDelete = $recycleItems | Where-Object { $_.DeletedDate.Date -le $targetDateBefore.Date }
    if (-not $itemsToDelete -or $itemsToDelete.Count -eq 0) {
        Write-Host ("No items found in recycle bin with Date Deleted <= {0}" -f $targetDateBefore.ToShortDateString())
        return
    }
    Write-Host ("Items to delete (Date Deleted <= {0}): {1}" -f $targetDateBefore.ToShortDateString(), $itemsToDelete.Count)
}
elseif ($targetDateAfter -and $targetDateBefore) {
    # Mode 4: Optional range mode, Date Deleted between two days (inclusive)
    $itemsToDelete = $recycleItems | Where-Object { $_.DeletedDate.Date -ge $targetDateAfter.Date -and $_.DeletedDate.Date -le $targetDateBefore.Date }
    if (-not $itemsToDelete -or $itemsToDelete.Count -eq 0) {
        Write-Host ("No items found in recycle bin with {0} <= Date Deleted <= {1}" -f $targetDateAfter.ToShortDateString(), $targetDateBefore.ToShortDateString())
        return
    }
    Write-Host ("Items to delete ({0} <= Date Deleted <= {1}): {2}" -f $targetDateAfter.ToShortDateString(), $targetDateBefore.ToShortDateString(), $itemsToDelete.Count)
}
else {
    Write-Host "Please set at least one of DeletedDateString, DeletedDateAfter, or DeletedDateBefore."
    return
}

foreach ($item in $itemsToDelete) {
    try {
        Clear-PnPRecycleBinItem -Identity $item.Id -Force
        Write-Host ("Deleted recycle bin item: Id={0}, Type={1}, Title={2}, Path={3}/{4}, DeletedDate={5}, DeletedBy={6}" -f $item.Id, $item.ItemType, $item.Title, $item.DirName, $item.LeafName, $item.DeletedDate, $item.DeletedByName)
    }
    catch {
        Write-Host "Something went wrong when deleting a recycle bin item, pls check the output for more details"
        Write-Host ("Failed to delete recycle bin item: Id={0}, Title={1}, Path={2}/{3}, DeletedDate={4}" -f $item.Id, $item.Title, $item.DirName, $item.LeafName, $item.DeletedDate)
    }
}

Write-Host "Done."