# What is this script? 

This script is intended to list item count of each library/list under a site, below is the output for example: 

ItemCount Title
--------- -----
    18710 Workflow History
     9733 Big List
     4821 5002
     3846 Files
     3608 5001
     1915 Theme Gallery
     1008 Master Page Gallery
      633 Style Library
      322 Lib0929

It's the same as you can see in site content page <SiteUrl>/_layouts/15/viewlsts.aspx: 

...

# How to use? 

1. Pls install "PnP PowerShell" first before running this script: https://github.com/Chunlong101/SharePointScripts#sharepointscripts

2. Copy below to your powershell console:  

$Cred = Get-Credential
$SiteURL = "https://xxx.sharepoint.com/sites/xxx"
Connect-PnPOnline -Url $SiteURL -Credentials $Cred
Get-PnPList | sort ItemCount -Descending | ft ItemCount, Title