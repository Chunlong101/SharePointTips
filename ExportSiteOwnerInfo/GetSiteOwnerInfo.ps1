function GetSiteOwnerInfo ($SiteUrl, $GlobalAdminUserName, $CvsPath) {
    Write-Host "Processing site: $SiteUrl"

    # Connect to the SharePoint site, you need to login with a global admin account
    Connect-PnPOnline -Url $SiteUrl -Interactive

    # Add the global admin as a site collection admin to ensure we have access to the site
    Add-PnPSiteCollectionAdmin -Owners $GlobalAdminUserName

    # Initialize variables
    $siteUrl = $SiteUrl
    $ownerEmail = $null
    $isM365GroupConnected = $false
    $isTeamsConnected = $false
    $m365GroupDisplayName = $null
    $m365GroupOwnersEmails = @()
    $m365GroupMembersEmails = @()
    $siteAdminsEmails = @()
    $siteOwnersEmails = @()
    $siteMembersEmails = @()
    $siteVisitorsEmails = @()

    # Get site info
    $tenantSite = Get-PnPTenantSite -Identity $SiteUrl
    $ownerEmail = $tenantSite.OwnerEmail
    $siteAdmins = Get-PnPSiteCollectionAdmin
    # Exclude the global admin from the site admins
    $siteAdmins = $siteAdmins | Where-Object { $_.Email -ne $GlobalAdminUserName }
    $siteAdmins | Select-Object -ExpandProperty Email | foreach { 
        if ($_.Trim() -ne "") {
            $siteAdminsEmails += $_.Trim() 
        } 
    }
    # Check if there's one whose title contains "Everyone"
    $everyoneAdmin = $siteAdmins | Where-Object { $_.Title -like "*Everyone*" }
    # If there's an "Everyone" then add its title to the siteAdminsEmails
    if ($everyoneAdmin) {
        $siteAdminsEmails += $everyoneAdmin.Title
    }
    $siteOwnersGroup = Get-PnPGroup -AssociatedOwnerGroup
    $siteOwners = Get-PnPGroupMember -Group $siteOwnersGroup
    $siteOwners | Select-Object -ExpandProperty Email | foreach { 
        if ($_.Trim() -ne "") {
            $siteOwnersEmails += $_.Trim() 
        } 
    }
    # Cehck if there's an "Everyone" in the site owners
    $everyoneOwner = $siteOwners | Where-Object { $_.Title -like "*Everyone*" }
    # If there's an "Everyone" then add its title to the siteOwnersEmails
    if ($everyoneOwner) {
        $siteOwnersEmails += $everyoneOwner.Title
    }
    $siteMembersGroup = Get-PnPGroup -AssociatedMemberGroup
    $siteMembers = Get-PnPGroupMember -Group $siteMembersGroup
    $siteMembers | Select-Object -ExpandProperty Email | foreach { 
        if ($_.Trim() -ne "") {
            $siteMembersEmails += $_.Trim() 
        } 
    }
    # Check if there's an "Everyone" in the site members
    $everyoneMember = $siteMembers | Where-Object { $_.Title -like "*Everyone*" }
    # If there's an "Everyone" then add its title to the siteMembersEmails
    if ($everyoneMember) {
        $siteMembersEmails += $everyoneMember.Title
    }
    $siteVisitorsGroup = Get-PnPGroup -AssociatedVisitorGroup
    $siteVisitors = Get-PnPGroupMember -Group $siteVisitorsGroup
    $siteVisitors | Select-Object -ExpandProperty Email | foreach { 
        if ($_.Trim() -ne "") {
     
            $siteVisitorsEmails += $_.Trim() 
        } 
    }
    # Check if there's an "Everyone" in the site visitors
    $everyoneVisitor = $siteVisitors | Where-Object { $_.Title -like "*Everyone*" }
    # If there's an "Everyone" then add its title to the siteVisitorsEmails
    if ($everyoneVisitor) {
        $siteVisitorsEmails += $everyoneVisitor.Title
    }

    # Check if the site is connected to a Microsoft 365 Group
    if ($tenantSite.GroupId.Guid -ne "00000000-0000-0000-0000-000000000000") {
        $isM365GroupConnected = $true
        $m365Group = Get-PnPMicrosoft365Group -Identity $tenantSite.GroupId -IncludeOwners
        $m365GroupDisplayName = $m365Group.DisplayName
        $m365Group.Owners | Select-Object -ExpandProperty Email | foreach { $m365GroupOwnersEmails += $_.Trim() }
        $m365GroupMembers = Get-PnPMicrosoft365GroupMember -Identity $tenantSite.GroupId
        $m365GroupMembers | Select-Object -ExpandProperty Email | foreach { $m365GroupMembersEmails += $_.Trim() }
    }

    # Check if Teams is connected
    if ($tenantSite.IsTeamsConnected) {
        $isTeamsConnected = $true
    }

    # Output the results to a CSV file
    $siteInfo = [PSCustomObject]@{
        SiteUrl                = $siteUrl
        OwnerEmail             = $ownerEmail
        IsM365GroupConnected   = $isM365GroupConnected
        M365GroupDisplayName   = $m365GroupDisplayName
        M365GroupOwnersEmails  = $m365GroupOwnersEmails -join "; "
        M365GroupMembersEmails = $m365GroupMembersEmails -join "; "
        SiteAdminsEmails       = $siteAdminsEmails -join "; "
        SiteOwnersEmails       = $siteOwnersEmails -join "; "
        SiteMembersEmails      = $siteMembersEmails -join "; "
        SiteVisitorsEmails     = $siteVisitorsEmails -join "; "
        IsTeamsConnected       = $isTeamsConnected
    }

    $siteInfo | Export-Csv -Path $CvsPath -NoTypeInformation -Append

    # Remove the global admin as a site collection admin
    Remove-PnPSiteCollectionAdmin -Owners $GlobalAdminUserName
}