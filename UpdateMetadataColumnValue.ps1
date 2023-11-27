$siteUrl = "https://xxx.sharepoint.com/sites/xxx"
$listName = "xxx"
$columnName = "xxx"
$termId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # We can get it from the hidden list: https://xxx.sharepoint.com/sites/xxx/lists/taxonomyhiddenlist/allItems.aspx
$itemId = xxx
Connect-PnPOnline -Url $siteUrl -UseWebLogin
$list = Get-PnPList -Identity $listName
$field = Get-PnPField -List $list -Identity $columnName
$item = Get-PnPListItem -List $listName -Id $itemId
Set-PnPListItem -List $listName -Identity $item.Id -Values @{$columnName = $termId } 