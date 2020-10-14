$workSpace = "C:\Users\chunlonl\source\repos\Scripts\21462879" # Where this script is stored 
$logFilePath = "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\LOGS\RequestUsage" # Where the usage log file is located on the sharepoint sever 
$daysToKeep = 1 # For example, if the value here is 1 then all usage log files before yesterday will be auto deleted, if it's 2 then the day before yesteray, and so on 

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
    
    $now = get-date
    
    $usageLogs = dir $logFilePath -Filter *.usage | ? -FilterScript {($_.LastWriteTime -le $now.AddDays(1-$daysToKeep).Date)}
    
    if ($null -ne $usageLogs -and "Object[]" -eq $usageLogs.GetType().Name) 
    {
        $log.Info("{0} log files has been loaded", $usageLogs.Count)
    }

    foreach ($file in $usageLogs)
    {
        $file.Delete()
        $log.Warn("{0} has been deleted", $file.FullName)
    }

    $log.Info("Mission complete")
}
catch {
    $log.Fatal($_, "Something went wrong, pls check the log file")
    $log.Error($_.ScriptStackTrace)
}