#
# Variables that need to be changed to meet your environment
#
$workSpace = "C:\Users\chunlonl\source\repos\SharePointScripts\RemoveUserOrGroupFromMultiUserInfoList" # Where this ps1 file is located
$groupName = "Everyone except external users" # Specify which user or group you'd like to remove from site(s)
$csv = Import-Csv "$workspace\sites.csv" # Where the csv file located, by default it's under the workspace, that csv file at least needs a header "Url"

#
# Get a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

try {
    $urls = $csv.Url
    
    foreach ($url in $urls) {
        $log.Info("Connecting the site: $url")
        Connect-PnPOnline -Url $url -UseWebLogin # This should use your IE cookies so that you don't need to input credentials everytime time 
        $target = Get-PnPUser | ? { $_.Title -eq $groupName }
        if ($target -ne $null) 
        {
            $log.Info("Found " + $target.Title + ", the LoginName is " + $target.LoginName + ", now removing it from " + $url)
            Remove-PnPUser $target.LoginName -Force
            $log.Info($target.Title + " has been removed from " + $url)
        }
        else 
        {
            $log.Info("Didn't find " + $groupName + " from " + $url)
        }
    }
}
catch {
    $log.Error($_)
    $log.Error($_.ScriptStackTrace)
}
