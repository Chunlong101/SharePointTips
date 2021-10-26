#
# This script is trying to grant site admin permission to a specific user for all/new onedrive sites. 
#
# Pls note: Microsoft doesn't provide production ready scripts, customers need to test/verify/develop/implement this script by themselves. This script is just a demo and out of the support scope. 
#

$tenantUrl = "https://xxx.sharepoint.com"
$adminUrl = "https://xxx-admin.sharepoint.com"
$cred = Get-Credential # Get the runner credential, should be a tenant admin

Connect-PnPOnline $tenantUrl -Credentials $cred
Connect-SPOService -Url $adminUrl -Credential $cred

function SetSiteAdmin ([string] $UserName, [string] $SiteUrl) {
    Set-SPOUser -Site $SiteUrl -LoginName $UserName -IsSiteCollectionAdmin $true 
}

function RemoveSiteAdmin ([string] $UserName, [string] $SiteUrl) {
    Set-SPOUser -Site $SiteUrl -LoginName $UserName -IsSiteCollectionAdmin $false 
}

function SetSiteAdminForAllOneDrive ([string] $UserName) {
    $onedriveSites = Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'"
    
    foreach ($site in $onedriveSites) {
        SetSiteAdmin -UserName $UserName -SiteUrl $site.Url
    }
}

function ExportAllOneDriveAdminsCsv ($Credential, $CsvFilePath) {
    $onedriveSites = Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'"

    foreach ($site in $onedriveSites) {
        Connect-PnPOnline $site.Url -Credentials $Credential
        $admins = Get-PnPSiteCollectionAdmin
        
        foreach ($admin in $admins) {
            $A = $site.Url
            $B = $admin.Email
            $C = $admin.LoginName
            $D = $admin.Title
    
            $wrapper = New-Object PSObject -Property @{ SiteUrl = $A; AdminEmail = $B; LoginName = $C; Title = $D }
            Export-Csv -InputObject $wrapper -Path $CsvFilePath -Append -NoTypeInformation    
        }
    }
}

function SetSiteAdminForNewOneDrive () {
    #
    # There's no existing method that we can determin if a onedrive is "new" or "old", your team need to implement this logic themselves
    #
}

SetSiteAdminForAllOneDrive $cred.UserName

ExportAllOneDriveAdminsCsv -Credential $cred -CsvFilePath .\Admins.csv