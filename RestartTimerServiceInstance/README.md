# "WARNING: Unable to start job CollectLogFiles_xxx..." 

If you're getting this error above then just copy below scripts to your sharepoint powershell console: 

```powershell
$farm  = Get-SPFarm
$disabledTimers = $farm.TimerService.Instances | where {$_.Status -ne "Online"}
 
if ($disabledTimers -ne $null)
{ 
    foreach ($timer in $disabledTimers)
    { 
        Write-Host "Timer service instance on server " $timer.Server.Name " is not Online. Current status:" $timer.Status
        Write-Host "Attempting to set the status of the service instance to online"
        $timer.Status = [Microsoft.SharePoint.Administration.SPObjectStatus]::Online
        $timer.Update()
    } 
} 
else 
{ 
    Write-Host "All Timer Service Instances in the farm are online! No problems found" 
}
 
$farm = Get-SPFarm
$farm.TimerService.Instances | foreach {$_.Stop();$_.Start();}
```

You can get this job done in more interactive way by running below bunch of lines: 

```powershell
$servers= Get-SPServer | ? {$_.Role -eq "Application"}
foreach ($server in $servers)
{
    Write-Host "Restarting Timer Service on $server"
    $Service = Get-WmiObject -Computer $server.name Win32_Service -Filter "Name='SPTimerV4'"
 
    if ($Service -ne $null)
    {
        $Service.InvokeMethod('StopService',$null)
        Start-Sleep -s 8
        $service.InvokeMethod('StartService',$null)
        Start-Sleep -s 5
        Write-Host -ForegroundColor Green "Timer Job successfully restarted on $server"
    }
    else
    { 
        Write-Host -ForegroundColor Red "Could not find SharePoint Timer Service on $server"
    }
}
```

If issue persists then pls run the following on impacted sharepoint server(s): 

$farm=Get-SPFarm
$farm.TimerService.Instances
 
We can see a list in the output, there will be 4 entries while there might be 1 entry in Disabled status, get the ID and use the ID to run the following: 
 
$si = Get-SPServiceInstance ID
$si.Provision()
 
After that, wait for some mins, then run the 1st group again, to make sure no entry is in Disabled. 
