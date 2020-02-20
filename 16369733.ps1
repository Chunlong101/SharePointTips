#
# Migrate/Copy a library to another 1
#
$Cred = Get-Credential
$SiteURL = "https://xia053.sharepoint.com/sites/Chunlong"
$SourceLibraryName = "16369733"
$TargetLibraryName = "163697332"
Connect-PnPOnline -Url $SiteURL -Credentials $Cred

$AllDocs = (Get-PnPListItem -List $SourceLibraryName).FieldValues

foreach ($item in $AllDocs) {
    $source = $SourceLibraryName + "/" + $item.FileLeafRef
    $target = $TargetLibraryName + "/" + $item.FileLeafRef
    $file = Get-PnPFile -Url $source
    
    $file.CopyTo($target, $true)
}
