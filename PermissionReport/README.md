### What can this script do? 

This script helps generate permission report for in sharepoint 2013/2016/2019/SE/Online (see the screenshot below). 

### Why this script is helpful? 

In sharepoint, users can only check permissions in user.aspx page (like screenshot below), and there's no option to export them all or even export more data from multiple web/list/library/item/folder/file objects. 

Permission data is stored along with sharepoint objects such as site/list/library/item/folder/file, so when we check permissions, sharepoint actually gives us information from those objects, and that's the reason why it's easy to know how many users are having acces to a sharepoint object, but not easy to understand how many accesses a user has against multiple sharepoint objects (to do this we need to loop multiple sites/lists/libraries/items/fodlers/files). 

![image](https://user-images.githubusercontent.com/9314578/169375648-26088d49-3868-465a-bee0-084dc1de8be0.png)

![image](https://user-images.githubusercontent.com/9314578/169375785-e2bf22c0-65e8-4d8c-a22f-b5f64b3e5f3c.png)

This script can generate data like below, a csv file with permission report, you can also customize this script to get more details as per your own requirement: 

![image](https://user-images.githubusercontent.com/9314578/169374805-2aa79e7c-3f30-4c78-a57b-913dc2480d49.png)

Some more screenshots: 

![image](https://user-images.githubusercontent.com/9314578/169374580-d078f050-0821-4170-949e-a19f6cba053d.png)

![image](https://user-images.githubusercontent.com/9314578/169375115-30729fae-d99e-49be-a611-265d73f069e2.png)

### Prerequisite 

This script requires pnp powershell, see https://github.com/Chunlong101/SharePointScripts#some-scripts-in-this-repository-are-using-sharepoint-pnp-powershell-here-isn-how-to-install-sharepoint-pnp-powershell-both-for-online-and-onprem how to install pnp powershell. 

### How to use 

This script itself contains some examples: https://github.com/Chunlong101/SharePointScripts/blob/37e1e4e619e573fc84aaee9b60fa705c67a70e56/PermissionReport/PermissionReport.ps1#L220

### Pls note, Microsoft doesn't provide production ready scripts, customers need to test/verify/develop this script by themselves. And this script is out of the support scope.
