#
# This script requires the farm account running on a sharepoint server, pls just replace below 4 variables to meet your environment 
#
$workSpace = "C:\Users\chunlonl\source\repos\Scripts\21651008" # Where this script is stored
$siteUrl = "https://xxx/sites/xxx"
$oldDomainName = "OldDomainName"
$newDomainName = "NewDomainName"
$groupInfoCsv = ".\GroupInfo.csv"

#
# Load a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

try {
    $log.Info("Let's get started")

    $groupInfo = Import-Csv -Path $groupInfoCsv
    if ($groupInfo.Count -le 0) {
        $log.Fatal("Error in Import-Csv group info csv file, stopping the task now")
        exit
    }
    $log.Info("Group info csv file was loaded")

    Add-PSSnapin Microsoft.SharePoint.PowerShell
    
    $site = Get-SPSite $siteUrl
    
    $webs = $site.AllWebs

    $log.Info("Webs were loaded, webs count: {0}", $webs.Count)
    
    foreach ($web in $webs) {
        if (!$web.HasUniqueRoleAssignments) {
            $log.Info("Current web doesn't have unique permissions, url: {0}", $web.Url)
            continue
        }
        $log.Info("Current web has unique permissions, url: {0}", $web.Url)

        #
        # Get all existing domain groups, they all have "GX" in their display name 
        #
        $oldDomainGroups = Get-SPUser -Web $web -Limit all | ? { $_.DisplayName -like "GX*" }
        if ($oldDomainGroups.Count -le 0) {
            $log.Info("Error in Get-SPUser, stopping the task now") 
            exit
        }
        $log.Info("Domain groups were loaded, groups count: {0}", $oldDomainGroups.Count)
        
        foreach ($oldDomainGroup in $oldDomainGroups) {
            #
            # If the user is given permissions directly then it should have "Roles" 
            #
            if ($oldDomainGroup.Roles.Count -ne 0) {
                $log.Info("Domain group {0} has {1} role(s) for {2}", $oldDomainGroup.DisplayName, $oldDomainGroup.Roles.Count, $web.Url)
                foreach ($role in $oldDomainGroup.Roles) {
                    $log.Info("Domain group {0} is given permissions directly, url: {1}, permission level: {2}", $oldDomainGroup.DisplayName, $web.Url, $role.Name)
                    $permissionLevel = $role.Name

                    #
                    # Locate target group in group info csv file 
                    #
                    $entry = $groupInfo | ? { $_.displayName -eq $oldDomainGroup.DisplayName }
                    try {
                        if ($entry.Count -gt 1) {
                            $log.Error("More than one same groups were found in group info csv file")
                            exit
                        }
                    }
                    catch {
                        # Only 1 entry is retrived, bad as expected 
                        $log.Info("Target group was found in group info csv file, group alias: {0}, group email: {1}, group display name: (2)", $entry.CN, $entry.mail, $entry.displayName)
                    }
                    $groupAlias = $entry.CN
                    $groupEmail = $entry.mail
                    $groupDisplayName = $entry.displayName

                    #
                    # Grant permissions 
                    #
                    New-SPUser -Web $web -UserAlias "$newDomainName\$groupAlias" -Email $groupEmail -PermissionLevel $permissionLevel -DisplayName $groupDisplayName # that will be fine if the user already exists 
                    $log.Warn("Created a new domain group, url: {0}, domain name: {1}, group alias: {2}, display name: {3}, permissions: {4}", $web.Url, $newDomainName, $groupAlias, $groupDisplayName, $permissionLevel)
                }
            }

            #
            # If the user is given permissions by sharepoint groups then it should have "Groups" 
            #
            if ($oldDomainGroup.Groups.Count -ne 0) {
                #
                # Check if the group is in a unique permission web/sub site, for example, if current group is in "Unique Members" (sub site sharepoint group), 
                # but current web only has "Home Members", Home Owners", "Home Visitors" (root site sharepoint groups), 
                # then which means the current group is in a unique permission sub site (who has a sharepoint group "Unique Members") 
                #
                $webGroups = @()
                foreach ($webGroup in $web.Groups) {
                    $webGroups += ($webGroup.Name)
                }
                foreach ($oldDomainGroupSpGroup in $oldDomainGroup.Groups) {
                    # Now it's O(n*n) but as an alternative we can use another hash table to make it O(n) 
                    if ($oldDomainGroupSpGroup.Name -in $webGroups) {
                        $log.Info("Current domain group is given permissions by sharepoint groups, url: {0}, domain group display name: {1}, sharepoint group: {2}", $web.Url, $oldDomainGroup.DisplayName, $oldDomainGroupSpGroup.Name)

                        
                        #
                        # Locate target group in group info csv file 
                        #
                        $entry = $groupInfo | ? { $_.displayName -eq $oldDomainGroup.DisplayName }
                        try {
                            if ($null -eq $entry -or $entry.Count -gt 1) {
                                $log.Error("Zero or more than one same groups were found in group info csv file")
                                exit
                            }
                        }
                        catch {
                            # Only 1 entry is retrived, bad as expected 
                            $log.Info("Target group was found in group info csv file, group alias: {0}, group email: {1}, group display name: (2)", $entry.CN, $entry.mail, $entry.displayName)
                        }
                        $groupAlias = $entry.CN
                        $groupEmail = $entry.mail
                        $groupDisplayName = $entry.displayName
                        $sharepointGroupName = $oldDomainGroupSpGroup.Name

                        #
                        # Grant permissions 
                        #
                        New-SPUser -Web $web -UserAlias "$newDomainName\$groupAlias" -Email $groupEmail -Group $sharepointGroupName -DisplayName $groupDisplayName # that will be fine if the user already exists 
                        $log.Warn("Created a new domain group, url: {0}, domain name: {1}, group alias: {2}, display name: {3}, sharepoint group name: {4}", $web.Url, $newDomainName, $groupAlias, $groupDisplayName, $sharepointGroupName)
                    }
                }
            }
        }
    }

    $log.Info("Mission complete")
}
catch {
    $log.Fatal($_, "Something went wrong, pls check the log file")
    $log.Error($_.ScriptStackTrace)
}