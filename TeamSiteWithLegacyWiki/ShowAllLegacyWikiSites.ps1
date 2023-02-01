$tanentUrl = 'https://5xxsz0.sharepoint.com'
Connect-PnPOnline -Url $tanentUrl -Interactive
$groups = Get-PnPMicrosoft365Group -IncludeSiteUrl
foreach ($group in $groups) {
    Connect-PnPOnline $group.SiteUrl -Interactive
    $web = Get-PnPWeb
    $lists = Get-PnPList | ? {$_.Title -match "Wiki"}
    if ($lists -ne $null) 
    {
        Write-Host $group.SiteUrl
    }
}