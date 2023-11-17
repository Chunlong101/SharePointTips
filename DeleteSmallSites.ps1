#
# Delete sites that are below a certain storage threshold
#
$tenantName = "xxx"
$storageThreshold = 1 # GB
$reportPath = ".\DeleteSites.csv"

Connect-PnPOnline -Url "https://$tenantname-admin.sharepoint.com" -UseWebLogin
$sites = Get-PnPTenantSite -Detailed

# Create an empty array to hold the site info
$siteInfoArray = @()

foreach ($site in $sites) {
    # If we use "Get-PnPProperty -ClientObject $site -Property Owner" then we will get an error, so we use Get-PnPSite instead
    Connect-PnPOnline -Url $site.Url -UseWebLogin
    $s = Get-PnPSite -Includes Owner 
    # $membersGroup = Get-PnPGroup -AssociatedMemberGroup
    # $members = Get-PnPGroupMember -Group $membersGroup
    # $ownersGroup = Get-PnPGroup -AssociatedOwnerGroup
    # $owners = Get-PnPGroupMember -Group $ownersGroup    
    $storageUsed = $site.StorageUsageCurrent
    if ($storageUsed -lt $storageThreshold * 1024) {
        if ($site.Status -eq "Active") {
            Write-Host "Site: $($site.Url) Storage: $($storageUsed / 1024) GB"
            # Add the site info to the array
            $siteInfoArray += New-Object PSObject -Property @{
                'Site'         = $site.Url
                'Storage (GB)' = $storageUsed / 1024
                'Owner'        = $s.Owner.Email
                'URL'          = $site.Url
            }
            # Remove-PnPTenantSite -Url $site.Url -Force
        }
    }
}

# Export the array to a CSV file
$siteInfoArray | Export-Csv -Path $reportPath -NoTypeInformation