#
# Current goal: Update untagged files, setting its managedMetadataColumn to the documentSet name 
#

#
# Variables that need to be changed to meet your environment
#
$workSpace = "C:\Users\chunlonl\VsCode\Repo\Test\15340285" # Where this scripts is stored
$subSiteUrl = "https://xia053.sharepoint.com/sites/Chunlong/SubSite1"
$managedMetadataColumn = "ManagedMetadata"
$managedMetadataDocumentLibraryLevel = "15340285|Office|T1|Canberra|027050"

#
# Get a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

function UpdateTagsDocumentsets {
    param (
        $subSiteUrl
    )
    
    try {
        Connect-PnPOnline -Url $subSiteUrl -Credentials $credentials
        
        $log.Info("Getting lists from sub site: {0}", $subSiteUrl)
    
        $lists = Get-PnPList
    
        $log.Info("Lists were loaded, lists count: {0}", $lists.Count)
    
        foreach ($l in $lists) {
            $log.Info("Loading items from list: {0}", $l.Title)
            $items = Get-PnPListItem -List $l.Title -PageSize 1000 
            $log.Info("Items were loaded, items count: ", $items.Count)
            foreach ($i in $items) {
                if (!$i.FieldValues.ContainsKey($managedMetadataColumn) ) {
                    continue
                }
    
                if ([System.String]::IsNullOrEmpty($i.FieldValues[$managedMetadataColumn]) -and ($i.FieldValues.FileDirRef.Split('/')[-1] -ne $l.Title)) {
                    $log.Info("Found an item that doesn't have {0}, list title: {1}, item id: {2}, item FileRef: {3}", $managedMetadataColumn, $l.Title, $i.Id, $i.FieldValues.FileRef)
                    $tag = $i.FieldValues.FileRef.Split('/')[-2]
                    $fullTag = $managedMetadataDocumentLibraryLevel + "|" + $tag
                    $log.Info("Updating an item, column: {0}, value: {1}, item id: {2}, item FileRef: {3}, list: {4}", $managedMetadataColumn, $fullTag, $i.Id, $i.FieldValues.FileRef, $l.Title)
                    Set-PnPListItem -List $l.Title -Identity $i.Id -Values @{$managedMetadataColumn = $fullTag }
                }
            }
        }
    }
    catch {
        $log.Fatal($_, "Something went wrong, pls check the log file")
        $log.Error($_.ScriptStackTrace)
    }
}

$credentials = Get-Credential

UpdateTagsDocumentsets $subSiteUrl