$workSpace = "C:\Users\Chunlong.CHINA\Desktop\21651008" # Where this script is stored
$siteUrl = "http://wfe"
$oldDomainName = "Dev"
$newDomainName = "Shanghai"

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

    Add-PSSnapin Microsoft.SharePoint.PowerShell
    
    $site = Get-SPSite $siteUrl
    
    $webs = $site.AllWebs

    $log.Info("Webs were loaded, webs count: {0}", $webs.Count)
    
    foreach ($web in $webs) {
        if (!$web.HasUniqueRoleAssignments) 
        {
            $log.Info("Current web doesn't have unique permissions, url: {0}", $web.Url)
            continue
        }

        $log.Info("Current web has unique permissions, url: {0}", $web.Url)
        $regEx = $oldDomainName + "\\"
        $oldDomainGroups = Get-SPUser -Web $web -Limit all | ? {$_.DisplayName -match $regEx}
        $log.Info("Domain groups were loaded, groups count: {0}", $oldDomainGroups.Count)

        foreach ($oldDomainGroup in $oldDomainGroups) {
            #
            # If the user is given permissions directly then it should have "Roles" 
            #
            if ($oldDomainGroup.Roles.Count -ne 0) 
            {
                $log.Info("Domain group {0} has {1} role(s) for {2}", $oldDomainGroup.DisplayName, $oldDomainGroup.Roles.Count, $web.Url)
                foreach ($role in $oldDomainGroup.Roles) 
                {
                    $log.Info("Domain group {0} is given permissions directly, url: {1}, permission level: {2}", $oldDomainGroup.DisplayName, $web.Url, $role.Name)
                    $permissionLevel = $role.Name
                    $groupName = $oldDomainGroup.DisplayName.Split('\')[1]
                    New-SPUser -Web $web -UserAlias "$newDomainName\$groupName" -PermissionLevel $permissionLevel # that will be fine if the user already exists 
                    $log.Warn("Created a new domain group, url: {0}, domain group display name: {1}\{2}, permissions: {3}", $web.Url, $newDomainName, $groupName, $permissionLevel)
                }
            }
    
            #
            # If the user is given permissions by sharepoint groups then it should have "Groups" 
            #
            if ($oldDomainGroup.Groups.Count -ne 0) 
            {
                #
                # Check if the group is in a unique permission web/sub site, for example, if current group is in "Unique Members" (sub site sharepoint group), 
                # but current web only has "Home Members", Home Owners", "Home Visitors" (root site sharepoint groups), 
                # then which means the current group is in a unique permission sub site (who has a sharepoint group "Unique Members") 
                #
                $webGroups = @()
                foreach ($webGroup in $web.Groups) 
                {
                    $webGroups += ($webGroup.Name)
                }
                foreach ($oldDomainGroupSpGroup in $oldDomainGroup.Groups) # Now it's O(n*n) but as an alternative we can use another hash table to make it O(n) 
                {
                    if ($oldDomainGroupSpGroup.Name -in $webGroups) 
                    {
                        $log.Info("Current domain group is given permissions by sharepoint groups, url: {0}, domain group display name: {1}, sharepoint group: {2}", $web.Url, $oldDomainGroup.DisplayName, $oldDomainGroupSpGroup.Name)
                        $sharepointGroupName = $oldDomainGroupSpGroup.Name
                        $domainGroupName = $oldDomainGroup.DisplayName.Split('\')[1]
                        New-SPUser -Web $web -UserAlias "$newDomainName\$domainGroupName" -Group $sharepointGroupName # that will be fine if the user already exists 
                        $log.Warn("Created a new domain group, url: {0}, domain group display name: {1}\{2}, sharepoint group name: {3}", $web.Url, $newDomainName, $domainGroupName, $sharepointGroupName)
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
