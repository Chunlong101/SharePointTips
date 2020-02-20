#
# Variables that need to be changed to meet your environment
#
$workSpace = "C:\Users\chunlonl\VsCode\Repo\Test\15608887" # Where this scripts is stored
$siteUrl = "https://xia053.sharepoint.com"

#
# Get a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

$credentials = Get-Credential
Connect-PnPOnline -Url $siteUrl -Credentials $credentials

$log.Info("Getting big lists")

$bigLists = Get-PnPList | ? { $_.ItemCount -ge 5000 }

$log.Info("Some feedbacks...")

foreach ($l in $bigLists) {
    $items = Get-PnPListItem -List $l.Title -PageSize 1000
    foreach ($i in $items) {
        try {
            Remove-PnPListItem -List $l.Title -Identity $i.Id -Force
            $log.Info("Removed an item from {0}, item id: {1}, item title: {2}, item ref: {3}", $l.Title, $i.Id, $i.FieldValues.Title, $i.FieldValues.FileRef)
        }
        catch {
            $log.Error($_, "Something went wrong, pls check the log file for more details")
            $log.Error("Failed to remove an item from {0}, item id: {1}, item title: {2}, item ref: {3}", $l.Title, $i.Id, $i.FieldValues.Title, $i.FieldValues.FileRef)
        }
    }
}