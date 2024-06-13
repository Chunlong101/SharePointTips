# What is this script? 

This script is a workaround and intended to monitor memory usage of appfabric and restart DistributedCacheService if necessary to avoid heavy server load and slow performance. 

# Background 

There's a web front end with distributed cache server on sharepoint 2019, appfabric process is consuming a lot of memory, which increases everyday and never goes down, for example, day1 appfabric uses 20% memory, day2 40%, day3 60%... day5 100%, on day5 users are impacted by slowness, only workaround now is to manually restart AppFabricCachingService. 

Dump file indicated that most memory consuming .NET objects are: 

<img width="953" alt="image" src="https://user-images.githubusercontent.com/9314578/146530199-86998897-489d-4152-bb14-861a248917b8.png">

# How to use? 

1. Download the zip file (MonitorAppFabricMemoryUsage.zip). 

2. Note: As this zip file is downloadeded from the internet you may need to unblock the file. To do this just right click the zip file and select properties. Now click on "unblock" to unblock the zip file. 

3. Unzip the contents of the zip file to a working directory e.g. C:\scripts

4. Open the ps1 file and change those parameters to meet your enironment (e.g. workSpace: C:\scripts\MonitorAppFabricMemoryUsage, processName: DistributedCacheService, threshold: 50, serviceName:AppFabricCachingService). 

5. You can run task scheduler with this script on that appfabric server. 

6. Logs can be found from "\Common\Logging\Logs". 

# Pls note 

Microsoft doesn't provide production ready scripts, customers need to test/verify/develop this script by themselves, this script is actually out of the support scope. 

# In case you hit below errors 

If the logging dll is blocked, you can the following to unblock the files first: Get-ChildItem -Path $workSpace -Recurse | Unblock-File

# How to run task scheduler with this script? 

