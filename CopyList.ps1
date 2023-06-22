Connect-PnPOnline https://5xxsz0.sharepoint.com -UseWebLogin
$list = Get-PnPList -Identity "TestList"
Copy-PnPList -Identity $list -Title "Copy of TestList" -DestinationWebUrl https://5xxsz0.sharepoint.com
$items = Get-PnPListItem -List "TestList"
foreach ($item in $items) {
    Add-PnPListItem -List "Copy of TestList" -Values @{"Title" = $item["Title"]; "Text" = $item["Text"]; "Choice" = $item["Choice"]; "DateTime" = $item["DateTime"]; "Person" = $item["Person"].Email; "Number" = $item["Number"]; "YesNo" = $item["YesNo"]; "HyperLink" = $item["HyperLink"]; "Currency" = $item["Currency"]; "Location" = $item["Location"] } 
}