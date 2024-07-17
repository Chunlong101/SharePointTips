# SharePoint Site Ownership/Membership Retrieval Script

![alt text](image.png)

![alt text](image-1.png)

This script retrieves the ownership/membership of a or multiple SharePoint site(s) and exports the information to a CSV file. You can modify the variables `$SiteUrl`, `$GlobalAdminUserName`, and `$CsvPath` to fit your environment.

## Prerequisites
- This script requires the PnP PowerShell module. You can install it by running the following command:
  ```
  Install-Module pnp.powershell -Force
  ```

- Please note that the latest PnP PowerShell requires PowerShell 7.0+.

## Usage example: 
```powershell
Connect-PnPOnline -Url "https://xxx-admin.sharepoint.com" -Interactive
$GlobalAdminUserName = "SpAdmin@xxx.onmicrosoft.com"
$CvsPath = "C:\Users\xxx\Downloads\SiteInfo.csv"
$AllSites = Get-PnPTenantSite -Filter "Url -like 'test'"
# $AllSites = Get-PnPTenantSite -GroupIdDefined $true
$AllSites | Select-Object -ExpandProperty Url | foreach { 
    $SiteUrl = $_
    GetSiteOwnerInfo -SiteUrl $SiteUrl -GlobalAdminUserName $GlobalAdminUserName -CvsPath $CvsPath
}
```

### Pls note: Microsoft doesn't provide production ready scripts, customers need to test/verify/develop/implement this script by themselves. This script is just a demo and out of the support scope. 
