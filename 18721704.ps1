#
# This script is for exporting data to a csv file from user infomation list, including a user was created by when and who
#

$siteUrl = "https://xia053.sharepoint.com/sites/ChunlongDeveloper"
$csvFile = ".\UserInfo.csv"
$cred = Get-Credential

Connect-PnPOnline $siteUrl -Credentials $cred
$list = Get-PnPList "User Information List"
$items = Get-PnPListItem $list 

foreach ($item in $items)
{
    $A = $item.FieldValues.Name
    $B = $item.FieldValues.Created
    $C = $item.FieldValues.Author.LookupValue

    $wrapper = New-Object PSObject -Property @{ UserName = $A; CreatedDate = $B; CreatedBy=$C }
    Export-Csv -InputObject $wrapper -Path $csvFile -Append -NoTypeInformation
}

# Below server side object model does the same from sharepoint on premise

# $web = Get-SPWeb $siteUrl
# $list = $web.Lists["User Information List"]
# $items = $list.Items

# foreach ($item in $items)
# {
#     [xml]$xml = $item.xml

#     $A = $xml.row.ows_Name
#     $B = $xml.row.ows_Created
#     $C = $xml.row.ows_Author

#     $wrapper = New-Object PSObject -Property @{ UserName = $A; CreatedDate = $B; CreatedBy=$C }
#     Export-Csv -InputObject $wrapper -Path $csvFile -Append -NoTypeInformation
# }