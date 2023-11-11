# ----- 
# Description: This script copies all data from a list to another list.
# How to use: Pls just change the variables in the first section of the script and execute it.
# ----- 
$SiteUrl = "https://xxx.sharepoint.com/sites/Test"
$ListName = "xxx"
$TargetSiteUrl = "https://xxx.sharepoint.com/sites/xxx"
$TargetListName = "a copy of xxx"

Connect-PnPOnline $SiteUrl -Interactive
$List = Get-PnPList -Identity $ListName

Write-Host "Creating an identical list: $ListName vs $TargetListName"
Copy-PnPList -Identity $List -Title $TargetListName -DestinationWebUrl $TargetSiteUrl | Out-Null # There is a bug in PnP.PowerShell 2.2.0's Copy-PnPList command. Sometimes, if the source list has Lookup fields, Copy-PnPList actually creates another list for the Lookup fields.
Write-Host "List creation completed: $ListName vs $TargetListName"

Write-Host "Getting all data from $ListName"
$Items = Get-PnPListItem -List $ListName -PageSize 1000 
Write-Host "Total $($Items.Count) items to copy"

Write-Host "Filtering out user-created fields in the list and displaying corresponding internal field names"
Get-PnPField -List $ListName | ? { $_.Hidden -eq $False } | select InternalName, Title, TypeDisplayName | ft -a

Write-Host "Printing all fields and values for the first item as a reference"
$Items | select -first 1 | % { $_.FieldValues } | ft -a

Write-Host "Start copying data"
foreach ($item in $Items) {
    $t = Add-PnPListItem -List $TargetListName -Values @{
        "Modified"  = $item["Modified"];
        "Title"     = $item["Title"];
        "Text"      = $item["Text"];
        "Choice"    = $item["Choice"];
        "DateTime"  = $item["DateTime"];
        "MultiLine" = $item["MultiLine"];
        "Number"    = $item["Number"];
        "YesNo"     = $item["YesNo"];
        "Location"  = $item["Location"];
        "Created"   = $item["Created"];
    }    

    Write-Host "Copying data for item $($t.Id)"

    # ----- 
    # After the above code is executed, you can see that all the data has been copied to the target list. However, there are still some issues, such as some special fields: People, Lookup, Managed Metadata, Thumbnile/Image, Created By, Modified By, Attachments, etc.
    # ----- 

    # Author, Created By
    Write-Host "Handling Author and Created By fields for item $($t.Id)"
    $user = $item["Author"].Email
    Set-PnPListItem -List $TargetListName -Identity $t.Id -Values @{"Author" = $user } | Out-Null

    # People Picker
    Write-Host "Handling People Picker field for item $($t.Id)"
    $user = $item["People"].Email
    Set-PnPListItem -List $TargetListName -Identity $t.Id -Values @{"People" = $user } | Out-Null

    # Hyperlink
    Write-Host "Handling Hyperlink field for item $($t.Id)"
    $url = $item["Hyperlink"].Url
    Set-PnPListItem -List $TargetListName -Identity $t.Id -Values @{"Hyperlink" = $url } | Out-Null

    # Currency
    Write-Host "Handling Currency field for item $($t.Id)"
    $currency = $item["Currency"]
    Set-PnPListItem -List $TargetListName -Identity $t.Id -Values @{"Currency" = $currency } | Out-Null

    # Thumbnail Image field
    Write-Host "Handling Image field for item $($t.Id)"
    $jsonString = $item.FieldValues["Image"] 
    # The value of the Thumbnail field is a JSON string, which needs to be converted to a JSON object first
    $jsonObject = ConvertFrom-Json -InputObject $jsonString
    $fileName = $jsonObject.fileName
    $serverRelativeUrl = $jsonObject.serverRelativeUrl
    # Download the image locally
    Get-PnPFile -Url $serverRelativeUrl -AsFile -Path $env:USERPROFILE\downloads -Filename $fileName -Force
    # Upload the image to the target list
    Set-PnPImageListItemColumn -List $TargetListName -Identity $t.Id -Field "Image" -Path $env:USERPROFILE\downloads\$fileName | Out-Null
    
    # Managed Metadata
    Write-Host "Handling Managed Metadata field for item $($t.Id)"
    $term = $item["ManagedMetadata"]
    Set-PnPListItem -List $TargetListName -Identity $t.Id -Values @{"ManagedMetadata" = $term.TermGuid } | Out-Null
    
    # Lookup
    Write-Host "Handling Lookup field for item $($t.Id)"
    $lookup = $item["Lookup"]
    Set-PnPListItem -List $TargetListName -Identity $t.Id -Values @{"Lookup" = $lookup.LookupId } | Out-Null

    # Attachments
    Write-Host "Handling attachments for item $($t.Id)"
    $attachments = $item["Attachments"]
    if ($attachments -eq $true) {
        # Download Attachments
        Get-PnPListItemAttachment -List $ListName -Identity $item.Id -Path $env:USERPROFILE\downloads -Force | Out-Null
        # Get Attachments Properties
        $filesProperties = Get-PnPProperty -ClientObject $item -Property "AttachmentFiles"
        $filesProperties | % {
            $fileName = $_.FileName
            Add-PnPListItemAttachment -List $TargetListName -Identity $t.Id -Path $env:USERPROFILE\downloads\$fileName | Out-Null
        }
    }

    # Editor, Modified By
    Write-Host "Handling Editor and Modified By fields for item $($t.Id)"
    $user = $item["Editor"].Email
    Set-PnPListItem -List $TargetListName -Identity $t.Id -Values @{"Editor" = $user } | Out-Null
}
Write-Host "Data copying completed"