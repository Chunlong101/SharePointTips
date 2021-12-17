$workSpace = "C:\Users\Chunlong\Desktop\MonitorAppFabricMemoryUsage" # Where this script is stored 
$processName = "DistributedCacheService" 
$threshold = 90 # 0 - 100 
$serviceName = "AppFabricCachingService" # Which service you'd like to restart once $processName consumes $threshold% memory 

#
# Load a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

try {
    $log.Info("Let's get started, processName: $processName, threshold: $threshold, serviceName: $serviceName")
    
    $CompName = HOSTNAME.EXE
    $CompObject = Get-WmiObject -Class WIN32_OperatingSystem -ComputerName $CompName 
    $MemoryConsumedPercentage = ((($CompObject.TotalVisibleMemorySize - $CompObject.FreePhysicalMemory) * 100) / $CompObject.TotalVisibleMemorySize)
    
    $log.Info("How many percentage of memory usage are consumed now: {0}%", $MemoryConsumedPercentage)

    $processMemoryUsage = Get-WmiObject WIN32_PROCESS -ComputerName $CompName | ? { $_.Name -match $processName } | Sort-Object -Property ws -Descending | Select-Object -first 1 ProcessID, ProcessName, @{Name = "Memory Usage(MB)"; Expression = { [math]::round($_.ws / 1mb) } }
    
    $log.Info("How mamy memory $processName is comusing now: {0} MB", $processMemoryUsage.'Memory Usage(MB)')

    $processMemoryUsagePercentage = $processMemoryUsage.'Memory Usage(MB)' / ($CompObject.TotalVisibleMemorySize / 1kb)

    $log.Info("How many percentage of memory usage are consumed by $processName now: {0}%", $processMemoryUsagePercentage)

    if ($processMemoryUsagePercentage -ge $threshold) {
        $log.Info("threshold: $threshold has been met, restarting $serviceName now...")
        Restart-Service -Name $serviceName 
        $log.Info("$serviceName has been restarted")
    } 
    else {
        $log.Info("threshold: $threshold hasn't been met, let's just keep monitoring")
    }

    $log.Info("Mission complete")
}
catch {
    $log.Fatal($_, "Something went wrong, pls check the log file")
    $log.Error($_.ScriptStackTrace)
}