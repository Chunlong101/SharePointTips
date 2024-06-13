# How to run task scheduler with a script? 

Assuming now we have a script "MonitorAppFabricMemoryUsage.ps1" and we want to run it with task scheduler.

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
