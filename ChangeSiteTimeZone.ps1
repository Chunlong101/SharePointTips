$cred = Get-Credential

Connect-PnPOnline -Url "https://xxx-my.sharepoint.com/personal/xxx_xxx_onmicrosoft_com" -Credentials $cred

$web = Get-PnPWeb
$ctx = Get-PnPContext
$ctx.Load($web.RegionalSettings)
$ctx.ExecuteQuery()
$tz = $web.RegionalSettings.TimeZones.GetById(76) # Get-PnPTimeZoneId
$web.RegionalSettings.Timezone = $tz
$web.Update()
$ctx.ExecuteQuery()

Disconnect-PnPOnline