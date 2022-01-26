$siteUrl = "https://chunlong.sharepoint.com/sites/Test"
$listName = "29392471"
$fileWithPath = "C:\Users\chunlonl\Desktop\Tools\ulsviewer.exe"

Connect-PnPOnline -Url $siteUrl -Interactive
$item = Get-PnPListItem -List 29392471 # Use Id, UniqueId, Query, PageSize etc parameters to get your own item(s) 
$attch = Get-PnPProperty -ClientObject $item -Property AttachmentFiles

#
# Add list item attchment 
#
$memoryStream = New-Object IO.FileStream($fileWithPath,[System.IO.FileMode]::Open)
$fileName = Split-Path $fileWithPath -Leaf
$attachInfo = New-Object -TypeName Microsoft.SharePoint.Client.AttachmentCreationInformation
$attachInfo.FileName = $fileName
$attachInfo.ContentStream = $memoryStream
$attch.Add($attachInfo)
Invoke-PnPQuery

#
# Remove list item attchment 
#
$file = $attch.GetByFileName($fileName)
$file.DeleteObject()
Invoke-PnPQuery

#
# Remove all attchments 
#
$files = $attch.GetEnumerator()
$files | % {
    $_.DeleteObject()
    Invoke-PnPQuery
}