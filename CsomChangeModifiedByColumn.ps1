Add-Type -Path "C:\Program Files\SharePoint Online Management Shell\Microsoft.Online.SharePoint.PowerShell\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\SharePoint Online Management Shell\Microsoft.Online.SharePoint.PowerShell\Microsoft.SharePoint.Client.Runtime.dll"
 
$SiteURL = "https://xia053.sharepoint.com/sites/Chunlong"
 
$ModifiedBy = "chunlonl@microsoft.com"

$Cred = Get-Credential -Message "Enter the Admin Credentials:"
 
$Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
$Ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Cred.UserName, $Cred.Password)
 
$List = $Ctx.web.Lists.GetByTitle("32281226")
$Ctx.Load($List)
$Ctx.ExecuteQuery()

$ListItems = $List.GetItems([Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery()) 
$Ctx.Load($ListItems)
$Ctx.ExecuteQuery()
 
$Editor = $Ctx.Web.EnsureUser($ModifiedBy)
$Ctx.Load($Editor)
$Ctx.ExecuteQuery()
 
$ListItem = $ListItems | select -first 1
$ListItem["Editor"] = $Editor
$ListItem.Update()
$Ctx.ExecuteQuery()

# ----- 

Connect-PnPOnline -Url http://MyServer/sites/MySiteCollection
 
$clientContext = Get-PnPContext
 
$targetField = Get-PnPField -List "Demo list" -Identity "Demo column"
 
$targetField.ReadOnlyField = 1   
   
$targetField.Update()
 
$clientContext.ExecuteQuery()
 
Disconnect-PnPOnline

Set-PnPListItem -List 32281226 -Identity 1 -Values @{"Editor" = "chunlonl@microsoft.com" }