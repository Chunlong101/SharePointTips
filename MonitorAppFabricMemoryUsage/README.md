# What is this script? 

This script is a workaround and intended to monitor memory usage of appfabric and restart DistributedCacheService if necessary to avoid heavy server load and slow performance. 

# Background 

There's a web front end with distributed cache server on sharepoint 2019, appfabric process is consuming a lot of memory, which increases everyday and never goes down, for example, day1 appfabric uses 20% memory, day2 40%, day3 60%... day5 100%, on day5 users are impacted by slowness, only workaround now is to manually restart AppFabricCachingService. 

Dump file indicated that most memory consuming .NET objects are: 

<img width="953" alt="image" src="https://user-images.githubusercontent.com/9314578/146530199-86998897-489d-4152-bb14-861a248917b8.png">

# How to use? 

1. Download the zip file (MonitorAppFabricMemoryUsage.ps1). 

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

Open "Task Scheduler" and follow below steps to create a basic task: 

![image](https://user-images.githubusercontent.com/9314578/146531478-e9d21537-66bf-4cd9-aedf-199748f84f42.png)

![image](https://user-images.githubusercontent.com/9314578/146531501-a52c37c7-648a-425d-8f35-9f775a4c4dd6.png)

![image](https://user-images.githubusercontent.com/9314578/146531544-8daf9a80-d015-4efb-a5e7-2ed126ffc9dc.png)

Start a Program with: 
Program/script: PowerShell.exe
Add arguments (optional): -ExecutionPolicy Bypass "C:\Users\Chunlong\Downloads\MonitorAppFabricMemoryUsage\MonitorAppFabricMemoryUsage\MonitorAppFabricMemoryUsage.ps1"

![image](https://user-images.githubusercontent.com/9314578/146531615-c3c2a68c-a871-4763-b91c-6076305023ae.png)

![image](https://user-images.githubusercontent.com/9314578/146531629-e213d93d-535d-4e2a-b6bc-6f60871cbc2a.png)

![image](https://user-images.githubusercontent.com/9314578/146531656-7c75e2e6-a8db-4730-bd26-bd7ac3a5ef99.png)

![image](https://user-images.githubusercontent.com/9314578/146531678-15cbfe0b-47a0-4ddf-8ac8-2f496790a386.png)

![image](https://user-images.githubusercontent.com/9314578/146531690-caf3157a-04a8-454b-bd58-fcd67187652f.png)

![image](https://user-images.githubusercontent.com/9314578/146531702-90be7c8d-b125-4c09-8bc2-21299607d44c.png)
