# What is this script? 

This script is intended to list item count of each library/list under a site, below is the output for example: 

![image](https://user-images.githubusercontent.com/9314578/195763091-47a23435-0f04-4cb1-bd99-0852a4b7d549.png)

It's the same as you can see in site content page [SiteUrl]/_layouts/15/viewlsts.aspx: 

![image](https://user-images.githubusercontent.com/9314578/195763214-b9396c69-de8d-4ab4-9070-e9320c56d417.png)

# How to use? 

1. Pls install "PnP PowerShell" first before running this script: https://github.com/Chunlong101/SharePointScripts#sharepointscripts

2. Copy below to your powershell console:  

```powershell
$Cred = Get-Credential
$SiteURL = "https://xxx.sharepoint.com/sites/xxx"
Connect-PnPOnline -Url $SiteURL -Credentials $Cred
Get-PnPList | sort ItemCount -Descending | ft ItemCount, Title
```
