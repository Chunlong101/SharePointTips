#
# Variables that need to be changed to meet your environment
#
$onedriveUrl = "https://chunlong-my.sharepoint.com/personal/test_chunlong_onmicrosoft_com"

Connect-PnPOnline -Url $onedriveUrl -Interactive

#
# We can use below to purge a document library directly but sometimes you'll see error like "cannot do this you need to delete files inside the folder first" 
#
# Remove-PnPListItem -List "Documents" -Force -Recycle

$items = Get-PnPListItem -List "Documents" -PageSize 5000

foreach ($item in $items) {
    Remove-PnPListItem -List "Documents" -Identity $item.Id -Force -Recycle
}