# What is this script? 

This script is intended to remove the specified user or group from a batch of sharepoint online site collections. 

# How to use? 

1. Pls install "PnP PowerShell for SharePoint Online" first before running this script, https://github.com/SharePoint/PnP-PowerShell/releases/download/3.11.1907.0/SharePointPnPPowerShellOnline.msi (or follow instruction here to install it) 

2. Download "27613730.zip" 

3. Note: As this file was downloaded from the internet you may need to unblock the file. To do this right click the file 27613730.zip and select properties. Now click on "unblock" to unblock the zip file. 

4. Unzip the contents of the zip file to a working directory e.g. C:\scripts

5. Edit the file "Sites.csv" to meet your requirement by entering a single site collection URL per line of the file. The script will go through all the Urls (sites) in that csv file and remove the specified user or group from the sites. You may also wish to add extra columns into that csv file for your reference, but the “Url” column is mandatory. All other columns will be ignored. 

6. Inside "RemoveUserOrGroupFromMultiUserInfoList.ps1", pls change the "$workSpace" variable to the path where you unzip "27613730.zip" to, e.g. c:\scripts\27613730". 

7. To target a specific user update the line $groupName = "Everyone except external users", replacing "Everyone except external users" with the name of the user to be removed from the site(s).

8. Run "RemoveUserOrGroupFromMultiUserInfoList.ps1", and input the credential of the runner (should be a tenant admin). 

9. Logs can be found from "\Common\Logging\Logs". 

# Pls note 

1. This script does the same as manually removing the specified user or group from "_layouts/15/people.aspx?MembershipGroupId=0", it's one way trip and cannot be rolled back. If the specified user or group is added back to a site collection, this will be inherited by sub-site/documents/etc under the collection and any unique permissions added earlier will not take effect. If needed, unique permissions will need to be re-added manually to the sub-site/documents/etc". 

2. Microsoft doesn't provide production ready scripts, customers need to test/verify/develop this script by themselves, this script is actually out of the support scope. 

# In case you hit below errors 

If the logging dll is blocked, you can the following to unblock the files first: Get-ChildItem -Path $workSpace -Recurse | Unblock-File