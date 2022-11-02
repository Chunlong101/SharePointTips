## What does this do?  

This script helps delete sharepoint files automatically. Just download the zip file, and change below parameters in ps1 file to meet your environment: 

$workSpace = "C:\DeleteFilesAutomatically" # Where this script is stored 
$daysToKeep = 30 # For example, if the value here is 1 then all files before yesterday will be auto deleted, if it's 2 then the day before yesteray, etc. 
$sharepointSiteUrl = "https://xxx.sharepoint.com/sites/xxx"
$folderName = "/Shared Documents/32812631"
$username = "xxx@xxx.onmicrosoft.com"
$password = "xxx

You can run task scheduler with this script, How to run task scheduler with this script? See https://github.com/Chunlong101/SharePointScripts/blob/ebd60affaf56c4edb2c844655f38b0e25a4c78a2/MonitorAppFabricMemoryUsage/README.md#how-to-run-task-scheduler-with-this-script

## Pls note 

Microsoft doesn't provide production ready scripts, customers need to test/verify/extend this script by themselves. And this script is out of the support scope. 
