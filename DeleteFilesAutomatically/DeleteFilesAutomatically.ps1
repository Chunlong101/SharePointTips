$workSpace = "C:\DeleteFilesAutomatically" # Where this script is stored 
$daysToKeep = 30 # For example, if the value here is 1 then all files before yesterday will be auto deleted, if it's 2 then the day before yesteray, etc. 
$sharepointSiteUrl = "https://xxx.sharepoint.com/sites/xxx"
$folderName = "/Shared Documents/32812631"
$username = "xxx@xxx.onmicrosoft.com"
$password = "xxx"

#
# Load a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

try {
    $log.Info("Let's get started")
    
    $password = convertto-securestring -String $password -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
    Connect-PnPOnline -Url $sharepointSiteUrl -Credentials $cred
 
    $log.Info("Scanning target folder: " + $folderName)
    $folderItems = Get-PnPFolderItem -FolderSiteRelativeUrl $folderName -Recursive
    $log.Info("Target folder has files count: " + $folderItems.Count)

    $log.Info("Checking files that are expired")
    $now = get-date
    foreach ($item in $folderItems) {
        $dif = $now - $item.TimeCreated
        if ($dif.Days -ge $daysToKeep) {
            $log.Warn("This file was created more than $daysToKeep days, now deleting: " + $item.ServerRelativeUrl)
            $item.DeleteObject()
            Invoke-PnPQuery
        }
    }
    
    $log.Info("Mission complete")
}
catch {
    $log.Fatal($_, "Something went wrong, pls check the log file")
    $log.Error($_.ScriptStackTrace)
}