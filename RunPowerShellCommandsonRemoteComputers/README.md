# What is this script? 

This script is intended to execute powershell script remotely and scan files against remote severs. 

# How to use? 

1. Download "RunPowerShellCommandsonRemoteComputers.zip" 

2. As this file was downloaded from the internet you may need to unblock the file. To do this right click the file RunPowerShellCommandsonRemoteComputers.zip and select properties. Now click on "unblock" to unblock the zip file. 

3. Unzip the contents of the zip file to a working directory e.g. C:\scripts

5. Edit the file "RemoteSevers.csv" to meet your requirement by entering a single site collection "SeverName" per line of the file. The script will go through all the "SeverName" in that csv file. You may also wish to add extra columns into that csv file for your reference, but the “SeverName” column is mandatory, all other columns will be ignored. 

6. Inside "RunPowerShellCommandsonRemoteComputers.ps1", pls change the "$workSpace" variable to the path where you unzip "RunPowerShellCommandsonRemoteComputers.zip" to, e.g. c:\scripts\RunPowerShellCommandsonRemoteComputers", you need also change the file extension to be scaned, by default it's ".pst". 

9. Logs can be found from "\Common\Logging\Logs". 

# Pls note 

Microsoft doesn't provide production ready scripts, customers need to test/verify/develop this script by themselves, this script is actually out of the support scope. 

# In case you hit below errors 

If the logging dll is blocked, you can the following to unblock the files first: Get-ChildItem -Path $workSpace -Recurse | Unblock-File

# References for remote powershell 

https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands?view=powershell-7.2#windows-powershell-remoting

https://www.youtube.com/watch?v=qvJRaYlxI1w
