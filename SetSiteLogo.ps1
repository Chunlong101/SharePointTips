#
# This script is to change the site logo, it does the same as /_layouts/15/prjsetng.aspx
#

$cred = Get-Credential

$siteUrl = "https://xxx.sharepoint.com/sites/Site1/SubSite1"

$logoPath = "/sites/Site1/SubSite1/Shared Documents/xxx.jpg"

Connect-PnPOnline -Url $siteUrl -Credentials $cred

$web = Get-PnPWeb

Set-PnpWeb -Web $web.Id -SiteLogoUrl $logoPath