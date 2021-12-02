#
# Variables that need to be changed to meet your environment
#
$workSpace = "C:\Users\chunlonl\source\repos\SharePointScripts\RunPowerShellCommandsonRemoteComputers" # Where this ps1 file is located
$csv = Import-Csv "$workspace\RemoteSevers.csv" # Where the csv file located, by default it's under the workspace, that csv file at least needs a header "SeverName"

#
# Get a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
# $ErrorActionPreference = "Stop"

try {
    $severs = $csv.SeverName
    foreach ($sever in $severs) {
        $log.Info("Connecting the sever: $sever")
        $target = Invoke-Command -ComputerName $sever -ScriptBlock {
            $array = @()
            $drives = Get-PSDrive | ? { $_.Used -gt 0 }
            foreach ($drive in $drives) {
                $filesFiltered = dir $drive.Root -Recurse | ? { $_.Extension -eq ".pst" } # You have to manually change the file extension here
                foreach ($f in $filesFiltered) {
                    $array += $f
                }
            }
            return $array
        }
        foreach ($t in $target) {
            $log.Info("Files have been detected on $sever, file name is : $t.Name, size is : $($t.Length) byte, path is : $($t.PSParentPath)");
        }
    }
}
catch {
    $log.Error($_)
    $log.Error($_.ScriptStackTrace)
}