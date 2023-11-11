# What can this script do?
Copying existing list to another one

# Quick start
Assuming I have a sharepoint list with multiple different columns: 
![screencapture-5xxsz0-sharepoint-sites-Test-layouts-15-listedit-aspx-2023-11-12-00_58_08](https://github.com/Chunlong101/SharePointScripts/assets/9314578/9208bd71-9c01-4bdf-a527-7171b39bbb2e)
And data: 
![screencapture-5xxsz0-sharepoint-sites-Test-Lists-AllColumnsList-AllItems-aspx-2023-11-12-00_57_51](https://github.com/Chunlong101/SharePointScripts/assets/9314578/8974fd67-1187-45e0-8ba1-327a4a568006)
After this script I will get another indentical list: 
![screencapture-5xxsz0-sharepoint-sites-Test-Lists-AllColumns-Copy-AllItems-aspx-2023-11-12-01_04_02](https://github.com/Chunlong101/SharePointScripts/assets/9314578/3484d879-708c-440b-93fd-7631ecdecdc9)
Currently this scirpt doens't support multi-values-column (single-value is ok), which means, if you have a people picker column that allow multiple values then this script will skip that column (data loss). 

# Use gpt to help us change the code to meet different enviorment (different columns)
Now imaging we have another brand-new list that needs to be copied, let's print out all the columns: 

1. Get-PnPField -List $ListName | ? { $_.Hidden -eq $False } | select InternalName, Title, TypeDisplayName | ft -a
```
InternalName              Title                    TypeDisplayName
------------              -----                    ---------------
Title                     Title                    Single line of text
LinkTitle                 Title                    Computed
_ColorTag                 Color Tag                Single line of text
ComplianceAssetId         Compliance Asset Id      Single line of text
Text                      Text                     Single line of text
Choice                    Choice                   Choice
DateTime                  DateTime                 Date and Time
MultiLine                 MultiLine                Multiple lines of text
People                    People                   Person or Group
Number                    Number                   Number
YesNo                     YesNo                    Yes/No
Hyperlink                 Hyperlink                Hyperlink or Picture
Currency                  Currency                 Currency
Location                  Location                 Location
CountryOrRegion           Location: Country/Region Single line of text
State                     Location: State          Single line of text
City                      Location: City           Single line of text
PostalCode                Location: Postal Code    Single line of text
Street                    Location: Street         Single line of text
GeoLoc                    Location: Coordinates    Geolocation
DispName                  Location: Name           Single line of text
Image                     Image                    Thumbnail
ManagedMetadata           ManagedMetadata          Managed Metadata
Lookup                    Lookup                   Lookup
ID                        ID                       Counter
ContentType               Content Type             Computed
Modified                  Modified                 Date and Time
Created                   Created                  Date and Time
Author                    Created By               Person or Group
Editor                    Modified By              Person or Group
_UIVersionString          Version                  Single line of text
Attachments               Attachments              Attachments
Edit                      Edit                     Computed
LinkTitleNoMenu           Title                    Computed
DocIcon                   Type                     Computed
ItemChildCount            Item Child Count         Lookup
FolderChildCount          Folder Child Count       Lookup
_ComplianceFlags          Label setting            Lookup
_ComplianceTag            Retention label          Lookup
_ComplianceTagWrittenTime Retention label Applied  Lookup
_ComplianceTagUserId      Label applied by         Lookup
_IsRecord                 Item is a Record         Computed
AppAuthor                 App Created By           Lookup
AppEditor                 App Modified By          Lookup
```

2. Remove those system columns from #1 and use below prompt in Gpt: 
The following is the column information for a SharePoint list, including the InternalName, Title, and TypeDisplayName for each column:
```
InternalName              Title                    TypeDisplayName
------------              -----                    ---------------
Title                     Title                    Single line of text
Text                      Text                     Single line of text
Choice                    Choice                   Choice
DateTime                  DateTime                 Date and Time
MultiLine                 MultiLine                Multiple lines of text
People                    People                   Person or Group
Number                    Number                   Number
YesNo                     YesNo                    Yes/No
Hyperlink                 Hyperlink                Hyperlink or Picture
Currency                  Currency                 Currency
Location                  Location                 Location
Image                     Image                    Thumbnail
ManagedMetadata           ManagedMetadata          Managed Metadata
Lookup                    Lookup                   Lookup
Modified                  Modified                 Date and Time
Created                   Created                  Date and Time
Author                    Created By               Person or Group
Editor                    Modified By              Person or Group
Attachments               Attachments              Attachments
```
Based on the above information, complete the following powershell command by filling in all the fields using the mentioned InternalName. Please note, ignore those columns with the following TypeDisplayName: Person or Group, Hyperlink or Picture, Currency, Thumbnail, Managed Metadata, Lookup, Attachments. This is the PowerShell script that needs your completion: 
```
Add-PnPListItem -List $TargetListName -Values @{"Modified" = $item["Modified"]; "Title" = $item["Title"]; }
```

3. Gpt will respond with code like below, don't forget to verify:
```
Certainly! Based on the provided information, we can complete the PowerShell command by including only the columns with relevant `TypeDisplayName`. Here's the completed command:

Add-PnPListItem -List $TargetListName -Values @{
    "Modified" = $item["Modified"];
    "Title" = $item["Title"];
    "Text" = $item["Text"];
    "Choice" = $item["Choice"];
    "DateTime" = $item["DateTime"];
    "MultiLine" = $item["MultiLine"];
    "Number" = $item["Number"];
    "YesNo" = $item["YesNo"];
}
```

4. Replace "Add-PnPListItem" with gpt code in this script.

5. Modify those code to handle special fields like people picker according to your list columns: https://github.com/Chunlong101/SharePointScripts/blob/6ae80d50e44d0e5cc6788a9b87a4395f2de6ee11/CopyList/CopyList.ps1#L48
