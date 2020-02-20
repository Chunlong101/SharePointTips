#
# Variables that need to be changed to meet your environment
#
$workSpace = "C:\Users\chunlonl\source\repos\Test\18450478" # Where this ps1 file is located

#
# Get a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

try {
    $cred = Get-Credential

    $log.Info($cred.UserName + " now is running this script, loading the csv file")

    $csv = Import-Csv "$workspace\sites.csv"
    $urls = $csv.Url
    
    foreach ($url in $urls) {
        $log.Info("Connecting $url")
        Connect-PnPOnline -Url $url -Credentials $cred
        $target = Get-PnPUser | ? { $_.Title -eq "Everyone except external users" }
        if ($target -ne $null) 
        {
            $log.Info("Found " + $target.Title + ", the LoginName is " + $target.LoginName + ", now removing it from " + $url)
            Remove-PnPUser $target.LoginName -Force
            $log.Info($target.Title + " has been removed from " + $url)
        }
        else 
        {
            $log.Info("Didn't find Everyone except external users from " + $url)
        }
    }
}
catch {
    $log.Error($_)
    $log.Error($_.ScriptStackTrace)
}
