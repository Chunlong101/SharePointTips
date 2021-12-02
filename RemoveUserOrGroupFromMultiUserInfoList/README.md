# What is this script? 

This script is intended to remove the specified user or group from a batch of sharepoint online site collections. 

# How to use? 

1. Pls install "PnP PowerShell" first before running this script: https://pnp.github.io/powershell/articles/installation.html

2. Download "RemoveUserOrGroupFromMultiUserInfoList.zip" 

3. Note: As this file is downloadeded from the internet you may need to unblock the file. To do this right click the file RemoveUserOrGroupFromMultiUserInfoList.zip and select properties. Now click on "unblock" to unblock the zip file. 

4. Unzip the contents of the zip file to a working directory e.g. C:\scripts

5. Edit the file "Sites.csv" to meet your requirement by entering a single site collection URL per line of the file. The script will go through all the Urls (sites) in that csv file and remove the specified user or group from the sites. You may also wish to add extra columns into that csv file for your reference, but the “Url” column is mandatory, all other columns will be ignored. You can get all sites against your tenant by Get-PnPTenantSite: https://docs.microsoft.com/en-us/powershell/module/sharepoint-pnp/get-pnptenantsite?view=sharepoint-ps

6. Inside "RemoveUserOrGroupFromMultiUserInfoList.ps1", pls change the "$workSpace" variable to the path where you unzip "RemoveUserOrGroupFromMultiUserInfoList.zip" to, e.g. c:\scripts\RemoveUserOrGroupFromMultiUserInfoList". 

7. To target a specific user update the line $groupName = "Everyone except external users", replacing "Everyone except external users" with the name of the user to be removed from the site(s).

8. Run "RemoveUserOrGroupFromMultiUserInfoList.ps1", and input the credential of the runner (should be a tenant admin). 

9. Logs can be found from "\Common\Logging\Logs". 

This script can run with sharepoint add-in so that you can have tenant level permissions (you need to register a tenant level sharepoint add-in) see more details: https://docs.microsoft.com/en-us/sharepoint/dev/solution-guidance/security-apponly-azureacs, or can also use azure ad registered app with different parameters of connect-pnponline, or grant site admin permissions to each site collection 

# Pls note 

1. This script does the same as manually removing the specified user or group from "_layouts/15/people.aspx?MembershipGroupId=0", it's one way trip and cannot be rolled back. If the specified user or group is added back to a site collection, this will be inherited by sub-site/documents/etc under the collection and any unique permissions added earlier will not take effect. If needed, unique permissions will need to be re-added manually to the sub-site/documents/etc". 

2. Microsoft doesn't provide production ready scripts, customers need to test/verify/develop this script by themselves, this script is actually out of the support scope. 

# In case you hit below errors 

If the logging dll is blocked, you can the following to unblock the files first: Get-ChildItem -Path $workSpace -Recurse | Unblock-File
