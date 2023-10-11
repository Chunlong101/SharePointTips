$SiteUrl = "https://5xxsz0.sharepoint.com/sites/Test"
$ListName = "Copy of 2308310010000489"
$TargetSiteUrl = "https://5xxsz0.sharepoint.com/sites/test"
$TargetListName = "Copy of 2308310010000489 V2"

Connect-PnPOnline $SiteUrl -Interactive
$List = Get-PnPList -Identity $ListName
Copy-PnPList -Identity $List -Title $TargetListName -DestinationWebUrl $TargetSiteUrl
$Items = Get-PnPListItem -List $ListName -PageSize 1000 

$Items.FieldValues[0]

#
# 此刻，让ChatGpt帮忙补全代码，Prompt可以这样写：
# ```
# 上文打印出来的东西
# ```
# 根据以上信息（包含如ContentTypeId等字段），完成以下命令，补全所有字段：
# ```
# Add-PnPListItem -List $TargetListName -Values @{"ContentTypeId" = $item["ContentTypeId"]; "Title" = $item["Title"]; }
# ```
# 可以用Get-PnPField -List $ListName | ? {$_.Hidden -eq $True} |  select * | ogv来筛选出属于用户自己创建的字段

foreach ($item in $Items) {
    Add-PnPListItem -List $TargetListName -Values @{
        "ContentTypeId" = $item.FieldValues["ContentTypeId"];
        "Title"         = $item.FieldValues["Title"];
        "field_0"       = $item.FieldValues["field_0"];
        "field_1"       = $item.FieldValues["field_1"];
        "field_2"       = $item.FieldValues["field_2"];
        "field_3"       = $item.FieldValues["field_3"];
        "field_4"       = $item.FieldValues["field_4"];
        "field_5"       = $item.FieldValues["field_5"];
        "field_9"       = $item.FieldValues["field_9"];
        "field_10"      = $item.FieldValues["field_10"];
        "field_11"      = $item.FieldValues["field_11"];
        "field_13"      = $item.FieldValues["field_13"];
        "field_14"      = $item.FieldValues["field_14"];
        "field_15"      = $item.FieldValues["field_15"];
        "field_16"      = $item.FieldValues["field_16"];
        "field_17"      = $item.FieldValues["field_17"];
        "field_18"      = $item.FieldValues["field_18"];
        "field_19"      = $item.FieldValues["field_19"];
        "field_20"      = $item.FieldValues["field_20"];
        "field_27"      = $item.FieldValues["field_27"];
        "field_28"      = $item.FieldValues["field_28"];
        "field_29"      = $item.FieldValues["field_29"];
        "field_30"      = $item.FieldValues["field_30"];
        "field_31"      = $item.FieldValues["field_31"];
        "field_32"      = $item.FieldValues["field_32"];
        "HotWorkPermit" = $item.FieldValues["HotWorkPermit"];
        "Modified"      = $item.FieldValues["Modified"];
        "Created"       = $item.FieldValues["Created"];
        "Author"        = $item.FieldValues["Author"].Email;
        "Editor"        = $item.FieldValues["Editor"].Email
    }
}