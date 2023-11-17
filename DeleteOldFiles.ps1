# ----- 
# Description: This script will delete all files older than 3 years from all document libraries in a SharePoint Online site, uncomment Remove-PnPListItem to actually delete the files, otherwise it will just generate a report on them. 
# ----- 

$siteUrl = "https://xxx.sharepoint.com/sites/xxx"
$reportPath = ".\OldFiles.csv"
Connect-PnPOnline -Url $siteUrl -Interactive

$results = @()
$libraries = Get-PnPList -Includes BaseType, Hidden
$documentLibraries = $libraries | Where-Object { $_.BaseType -eq "DocumentLibrary" -and $_.Hidden -eq $false }
foreach ($library in $documentLibraries) {
    Write-Host "Library: $($library.Title)"
    $files = Get-PnPListItem -List $library.Title -Fields "FileLeafRef", "Modified", "FileDirRef", "File_x0020_Size", "FileRef", "Editor" -PageSize 100
    $currentDate = Get-Date
    # Last modified date > 3 years
    $threeYearsAgo = $currentDate.AddYears(-3)
    $site = Get-PnPTenantSite -Url $siteUrl
    $siteOwner = $site.Owner
    $oldFiles = $files | Where-Object { $_["Modified"] -lt $threeYearsAgo }
    foreach ($file in $oldFiles) {
        Write-Host "Processing File: $($file["FileLeafRef"]), Modified: $($file["Modified"])"
        $fileInfo = [PSCustomObject]@{
            LibraryTitle = $library.Title
            FileName     = $file["FileLeafRef"]
            ModifiedDate = $file["Modified"]
            FileDirRef   = $file["FileDirRef"]
            FileSize     = $file["File_x0020_Size"]
            FileUrl      = $file["FileRef"]
            Editor       = $file["Editor"].LookupValue
            SiteOwner    = $siteOwner
        }

        $results += $fileInfo
        # Remove-PnPListItem -List $library.Title -Identity $file.Id -Force
    }
}

$results | Export-Csv -Path $reportPath -NoTypeInformation