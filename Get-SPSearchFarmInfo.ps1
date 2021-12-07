<# =====================================================================
## Title       : Get-SPSearchFarmInfo.ps1
## Description : This script will collect information regarding the Farm, Search, and the SSA's in the Farm.
## Contributors: Anthony Casillas | Brian Pendergrass | Josh Roark | PG
## Date        : 09-9-2021
## Input       : 
## Output      : 
## Usage       : .\Get-SPSearchFarmInfo.ps1
## Notes       : Scroll to bottom for change notes...
## Tag         : Search, Sharepoint, Powershell
## =====================================================================
#>

Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
Import-Module WebAdministration -ErrorAction SilentlyContinue

Write-Output "This script can take several mins to run."
Write-Host ""
Write-Output "If you have a single SSA or no SSA in your Farm, this will move along with no interaction"
Write-Host ""
Write-Output "If you have more than 1 SSA, then you will be prompted to select the SSA we will be focused on"
Write-Host ""

$timestamp = $(Get-Date -format "MM-dd-yyyy")
$output = Read-Host "Enter a location for the output file (For Example: C:\Temp)" 
$outputfilePrefix = $output + "\SPSearchFarmInfo_"

$global:farm = Get-SPFarm
$global:servers = Get-SPServer | Sort-Object -Property DisplayName, Role
$global:serviceInstances = Get-SPServiceInstance -All | Sort-Object -Property Server, TypeName
$spProduct = Get-SPProduct

Function WriteErrorAndExit($errorText)
{
    Write-Host -BackgroundColor Red -ForegroundColor Black $errorText
    Write-Host -BackgroundColor Red -ForegroundColor Black "Aborting script"
    exit
}

#-----------------------------------------------
# GetSSA: Get SSA reference 
#-----------------------------------------------
function GetSSA
{
    $ssas = @(Get-SPEnterpriseSearchServiceApplication)
    if($ssas.Length -eq 0)
    {
        Write-Host ""
        Write-Host "There is no SSA in this farm. We will still collect some basic information"
        Write-Host ""
        return NoSSA
    }
    elseif($ssas.Count -eq 1)
    {
        $global:ssa = $ssas[0]
    }
    else
    {
        $menu = @{}
        for($i=1;$i -le $ssas.count; $i++)
        {
            Write-Host "$i   $($ssas[$i-1].name)"
            $menu.Add($i,($ssas[$i-1].name))
        }
        ""
        $ans = Read-Host 'Enter SSA selection ( pick the number to the left of the SSA Name )' -ErrorAction SilentlyContinue
        $ans = $ans -as [int]
        if($null -eq $ans -or ($ans.gettype()).Name -eq "String")
        {
            Write-Warning ("-- Your selection must be an Integer value. Please enter the number to the left of the SSA Name as your selection.")
            return GetSSA
        }
        else
        {
            $selection = $menu.Item($ans)
            $global:ssa = Get-SPEnterpriseSearchServiceApplication $selection
        }
    }

    if ($global:ssa.Status -ne "Online")
    {
        $ssaStat = $global:ssa.Status
        Write-Warning ("Expected SSA to have status 'Online', found status: $ssaStat")
    }
    return $global:ssa
}


#-----------------------------------------------
# GetFarmBuild: Get Farm Build\Version 
#-----------------------------------------------
Function GetFarmBuild()
{
    Write-Host "Getting SP Farm Build"
    ""
    "[ SharePoint Farm Build: " + $farm.BuildVersion + " ]"
    ""
}

#-----------------------------------------------
## GetServersInFarm
#-----------------------------------------------
function GetServersInFarm()
{
    Write-Host "Getting Servers in the Farm"
    ""
    "#########################################################################################"
    "   Servers in the Farm "
    "#########################################################################################"

    foreach($svr in $global:servers)
    {
        if($svr.Role -ne "Invalid")
        {
            $productStatus = $null
            $productStatus = $spProduct.GetStatus($svr.DisplayName)
            $timeZone = $(Get-WMIObject -Class Win32_TimeZone -Computer $svr.address -ErrorAction SilentlyContinue).Description
            $svr.DisplayName + " || " + $svr.Id + " || " + $svr.Role + " || " + $svr.Status + " || " + $productStatus + " || " + $timeZone
        }
        else
        {
            $timeZone = $(Get-WMIObject -Class Win32_TimeZone -Computer $svr.address -ErrorAction SilentlyContinue).Description
            $svr.DisplayName + " || " + $svr.Id + " || " + $svr.Role + " || " + $svr.Status + " || " + $timeZone
        }

        
    }
    ""
}

#-----------------------------------------------
# Get Service Instances
#-----------------------------------------------
function GetServiceInstances()
{
    Write-Host "Getting Service Instances Information"
    ""
    "#########################################################################################"
    "   What Service Instances are running and on what Server? "
    "#########################################################################################"
    ""
     $serviceInstances = $global:serviceInstances | Where-Object{$_.Status -ne "Disabled"}
     foreach ($si in $serviceInstances)
     {
       $si.Server.Address + " -- "  + $si.TypeName + " -- " + $si.Status
     }
     ""
}

#-----------------------------------------------
## GetServiceApplications ##
#-----------------------------------------------
function GetServiceApplications()
{
   Write-Host "Getting Service Application Information that are in a state other than 'Disabled'"
    ""
    "#########################################################################################"
    "  Service Application Info " 
    "#########################################################################################"
    ""
    $serviceApps = Get-SPServiceApplication | ?{$_.Status -ne "Disabled"}
      "DisplayName"  + " -- "  + "Id" + " -- "  + "Status"
    ""
    foreach ($spserviceApp in $serviceApps)
    {
        $spserviceApp.DisplayName  + " -- " + $spserviceApp.Id.ToString() + " -- " + $spserviceApp.Status
    } 
}

#-----------------------------------------------
## CheckTimerServiceInstances ##
#-----------------------------------------------
function CheckTimerServiceInstances()
{
    
    Write-Host "Checking Timer Service Instances at the Farm Level. Disabled Service Instances can prevent timer jobs from executing...`n"
    ""
    "#########################################################################################"
    "  'Farm Level Timer Service Instances' Check "
    "#########################################################################################"
    $farmTimers = $farm.TimerService.Instances 
   "Server" + " -- "  + "Status" + " -- "  + "AllowServiceJobs" + " -- "  + "AllowContentDBJobs"
    ""
    foreach ($ft in $farmTimers)
    {
        $ft.Server.Name.ToString()  + " -- "  + $ft.status  + " -- " + $ft.AllowServiceJobs  + " -- " + $ft.AllowContentDatabaseJobs
    }

    $disabledTimers = $farm.TimerService.Instances | where {$_.Status -ne "Online"} 
    if ($disabledTimers -ne $null) 
    {
        foreach ($timer in $disabledTimers) 
        {
            Write-Host -ForegroundColor Red "   Timer service instance on server " $timer.Server.Name " is NOT Online. Current status:" $timer.Status 
            Write-Host -ForegroundColor Green "   Attempting to set the status of the service instance to online..." 
            $timer.Status = [Microsoft.SharePoint.Administration.SPObjectStatus]::Online 
            $timer.Update()
            ""
            $timer.Server.Name + "   Timer Instance was Disabled, but is now " + $timer.Status + ". You MUST now go restart the SharePoint timer service on server "  + $timer.Server.Name
            write-host -ForegroundColor Yellow "   You MUST now go restart the SharePoint timer service on server "  $timer.Server.Name
        }
    } 
    else
    {
        Write-Host ("   All Timer Service Instances in the farm are online. No problems found!") -ForegroundColor Green
     }
}

function CheckAdminServiceInstance()
{
    Write-Host ""
    Write-host "Now checking SharePoint ADMINISTRATION Service Instances...`n"
    ""
    "#########################################################################################"
    "  'Administration Service Instances' - Check "
    "#########################################################################################"
    $adminServiceInstances = $farm.servers.serviceinstances | ? {$_.TypeName  -eq "Microsoft SharePoint Foundation Administration"}
   "Server" + " -- "  + "Status" + " -- "  + "Id"
    ""
    $adminSiAllGood = $true
    foreach($adminSi in $adminServiceInstances)
    {
        $adminSi.Server.Name.ToString() + " -- "  + $adminSi.Status + " -- "  + $adminSi.Id
        if($adminSi.Status -eq "Disabled")
        {
            Write-Host -ForegroundColor Red "   Administration Service Instance on server " $adminSi.Server.Name " is NOT Online. Current status:" $adminSi.Status 
            Write-Host -ForegroundColor Green "   Attempting to set the status of the service instance to online..." 
            $adminSi.Status = [Microsoft.SharePoint.Administration.SPObjectStatus]::Online 
            $adminSi.Update()
            ""
            " ---Administration Service Instance was Disabled, but is now " + $adminSi.Status + ". You MUST now go restart the SharePoint Administration service (in services.msc) on server "  + $adminSi.Server.Name
            ""
            write-host -ForegroundColor Yellow "   You MUST now go restart the SharePoint Administration service (in services.msc) on server "  $adminSi.Server.Name
            $adminSiAllGood = $false
        }
    }
    if($adminSiAllGood)
    {
        Write-Host "   All Administration Service Instances in the farm are online. No problems found with SPAdminV4" -ForegroundColor Green
    }
}
#End Script

#-----------------------------------------------
## Check TimerJobHistory table size ##
#-----------------------------------------------

function CheckTimerJobHistory()
{
    Write-Host ""
    Write-Host "Checking the size of the 'timerjobhistory' table... "
    Write-Host ""
    Write-Host " --If there are millions of rows in this table, this can prevent jobs from running or cause timer jobs to time out. "
    Write-Host " --- As of April 2018 CU, for SP 2013 and 2016, there were changes implemented to limit the timer job history to 3 days"
    Write-Host " ---- https://blogs.technet.microsoft.com/stefan_gossner/2018/04/12/changes-in-the-timerjobhistory-table-maintenance-introduced-in-april-2018-cu-for-sharepoint-2013/"
    Write-Host ""

    ""
    "#########################################################################################"
    "  TimerJobHistory table "
    "#########################################################################################"

    $conn = New-Object System.Data.SqlClient.SqlConnection
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    
    $configDb = Get-SPDatabase | ?{$_.TypeName -match "Configuration Database"}
    $connectionString = $configDb.DatabaseConnectionString
    $conn.ConnectionString = $connectionString
    $conn.Open()
    $cmd.connection = $conn


    #Write-Host "Issuing Query on:  " $configDb.Name
    #""
    
    $cmd.CommandText = "select COUNT(*) from TimerJobHistory (nolock)"
    $rows = $cmd.ExecuteReader()
    
        if($rows.HasRows -eq $true)
                {
                while($rows.Read())
                            {
                                Write-Host("TimerJobHistory table contains: " + $rows[0]  + " rows")
                                Write-Host ""
                                ""
                                "TimerJobHistory table contains: " + $rows[0]  + " rows"
                                ""
                            }
                }
                $rows.Close()
        $conn.Close()
}

#-----------------------------------------------
## Check for Farm - SiteSubscriptions ##
#-----------------------------------------------

function CheckFarmSiteSubscriptions
{
    Write-Host "Checking for Site Subscription IDs in the farm."
    Write-Host ""
    if($global:farm.SiteSubscriptions -ne $null)
    {
        Write-Host("    We have detected potential SiteSubscriptions in this farm. If your site contains subscriptionId's and the SSA is not not Partitioned (' This is not common' ), then search results and usage\analytics can be impacted by this.") -ForegroundColor Cyan
        Write-Host  ""
        ""
        "#########################################################################################"
        "   Site Subscription Info "
        "#########################################################################################"
        ""
        "  We have detected SiteSubscriptions in this farm. If your site contains subscriptionId's and the SSA is not Partitioned (' This is not common' ), then search results and usage\analytics can be impacted by this. "
        "  Recommended that you execute the following to output those Subscriptions"
        ""
        "    get-spsite -limit All | Select Url, SiteSubscription "
        ""
        "  If any URL reports a subscription ID, these sites could fail to return search results or usage\analytics reports "

        #foreach($siteSubscription in $global:farm.SiteSubscriptions)
        #{
        #    if($siteSubscription.Sites -ne $null)
        #    {
        #        foreach($spSite in $siteSubscription.Sites)
        #        {
        #            $spSite.Url + " -- " + $siteSubscription.Id
        #        }
        #    }
        #}
    }
    else
    {
        Write-Host " -- No Site Subscriptions detected"
        "#########################################################################################"
        "   Site Subscription Info "
        "#########################################################################################"
        ""
        "  No Site Subscriptions detected"
    }
}

#-----------------------------------------------
# SSA Related Timer Jobs
#-----------------------------------------------
function GetSSARelatedTimerJobs
{
    Write-Host "Checking for SSA related timer jobs"
    ""
    "#########################################################################################"
    "  SSA Related Timer Jobs "
    "#########################################################################################"
    $ssaJobs = "Application " + $global:ssa.Id
    Get-SPTimerJob | ?{$_.Name -match $ssaJobs} | Select Name
    ""
$tjText = @"
    - SSAs should have several timer jobs associated with them
    -- SP 2013 should have 7 timer jobs
    -- SP 2016 should have 8 timer jobs
    -- SP 2019 should have 9 jobs

    - If there are any less than these ( respective of the SP Version), then the easiest course of action to get those timer jobs back in place would be to run: ( insert correct SSA name and remove space between $ and ssa )
    -- $ ssa = Get-SPEnterpriseSearchServiceApplication <your ssa name here>
    -- $ ssa.Status = "Disabled"
    -- $ ssa.Update()
    -- $ ssa.Provision()
"@
$tjText
Write-Host ("$tjText") -ForegroundColor Gray
Write-Host ""

}

#-----------------------------------------------
# SSA Full Object
#-----------------------------------------------
function GetSSAFullObject()
{
    Write-Host "Collecting some SSA object info.."
    Write-Host ""
    ""
    $fullSsaObject = New-Object PSObject
     "#########################################################################################"
    "   " + $global:ssa.Name + " Object  " 
    "#########################################################################################" 

    if($global:ssa.NeedsUpgradeIncludeChildren -eq $true -or $global:ssa.NeedsUpgrade -eq $true)
    {
        Write-Warning (" We have detected that your 'SSA' objects need to be upgraded. In order to perform this action, please run the following command: ")
        Write-Host ""
        Write-Host ("    --- 'Upgrade-SPEnterpriseSearchServiceApplication <your SSA Name>' ") -ForegroundColor Gray
        Write-Host ""

        ""
        "WARNING: We have detected that your 'SSA' objects need to be upgraded. In order to perform this action, please run the following command: "
        ""
        "   --- 'Upgrade-SPEnterpriseSearchServiceApplication <your SSA Name>' "
        ""
    }
    
    $fullSsaObject | Add-Member DisplayName $global:ssa.DisplayName
    $fullSsaObject | Add-Member Name $global:ssa.Name
    $fullSsaObject | Add-Member Id $global:ssa.Id
    $fullSsaObject | Add-Member ApplicationName $global:ssa.ApplicationName
    $fullSsaObject | Add-Member CloudIndex $global:ssa.CloudIndex
    $fullSsaObject | Add-Member ServiceName $global:ssa.ServiceName
    $fullSsaObject | Add-Member TypeName $global:ssa.TypeName
    $fullSsaObject | Add-Member DefaultSearchProvider $global:ssa.DefaultSearchProvider
    $fullSsaObject | Add-Member LocationConfigurations $global:ssa.LocationConfigurations
    $fullSsaObject | Add-Member AlertNotificationFormat $global:ssa.AlertNotificationFormat
    $fullSsaObject | Add-Member QueryLoggingEnabled $global:ssa.QueryLoggingEnabled
    $fullSsaObject | Add-Member QuerySuggestionsEnabled $global:ssa.QuerySuggestionsEnabled
    $fullSsaObject | Add-Member PersonalQuerySuggestionsEnabled $global:ssa.PersonalQuerySuggestionsEnabled
    $fullSsaObject | Add-Member SearchCenterUrl $global:ssa.SearchCenterUrl
    $fullSsaObject | Add-Member SharedSearchBoxSettings $global:ssa.SharedSearchBoxSettings
    $fullSsaObject | Add-Member UrlZoneOverride $global:ssa.UrlZoneOverride
    $fullSsaObject | Add-Member HeadQueryFrequencyThreshold $global:ssa.HeadQueryFrequencyThreshold
    $fullSsaObject | Add-Member NameNormalizationEnabled $global:ssa.NameNormalizationEnabled
    $fullSsaObject | Add-Member NameNormalizationPreferredNamePID $global:ssa.NameNormalizationPreferredNamePID
    $fullSsaObject | Add-Member QueryLogSettings $global:ssa.QueryLogSettings
    $fullSsaObject | Add-Member DiacriticSensitive $global:ssa.DiacriticSensitive
    $fullSsaObject | Add-Member VerboseQueryMonitoring $global:ssa.VerboseQueryMonitoring
    $fullSsaObject | Add-Member VerboseSubFlowTiming $global:ssa.VerboseSubFlowTiming
    $fullSsaObject | Add-Member SearchAdminDatabase $global:ssa.SearchAdminDatabase.Name
    $fullSsaObject | Add-Member CrawlStores $global:ssa.CrawlStores
    $fullSsaObject | Add-Member LinksStores $global:ssa.LinksStores
    $fullSsaObject | Add-Member AnalyticsReportingDatabases $global:ssa.AnalyticsReportingDatabases
    $fullSsaObject | Add-Member AnalyticsReportingStore $global:ssa.AnalyticsReportingStore
    $fullSsaObject | Add-Member CrawlLogCleanupIntervalInDays $global:ssa.CrawlLogCleanupIntervalInDays
    $fullSsaObject | Add-Member DefaultQueryTimeout $global:ssa.DefaultQueryTimeout
    $fullSsaObject | Add-Member MaxQueryTimeout $global:ssa.MaxQueryTimeout
    $fullSsaObject | Add-Member MaxKeywordQueryTextLength $global:ssa.MaxKeywordQueryTextLength
    $fullSsaObject | Add-Member DiscoveryMaxKeywordQueryTextLength $global:ssa.DiscoveryMaxKeywordQueryTextLength
    $fullSsaObject | Add-Member DiscoveryMaxRowLimit $global:ssa.DiscoveryMaxRowLimit
    $fullSsaObject | Add-Member MaxRowLimit $global:ssa.MaxRowLimit
    $fullSsaObject | Add-Member MaxRankingModels $global:ssa.MaxRankingModels
    $fullSsaObject | Add-Member AllowQueryDebugMode $global:ssa.AllowQueryDebugMode
    $fullSsaObject | Add-Member AllowPartialResults $global:ssa.AllowPartialResults
    $fullSsaObject | Add-Member AllowedMaxRowLimitSp14 $global:ssa.AllowedMaxRowLimitSp14
    $fullSsaObject | Add-Member AlertsEnabled $global:ssa.AlertsEnabled
    $fullSsaObject | Add-Member FarmIdsForAlerts $global:ssa.FarmIdsForAlerts
    $fullSsaObject | Add-Member AlertNotificationQuota $global:ssa.AlertNotificationQuota
    $fullSsaObject | Add-Member ResetAndEnableAlerts $global:ssa.ResetAndEnableAlerts
    $fullSsaObject | Add-Member SystemManagerLocations $global:ssa.SystemManagerLocations
    $fullSsaObject | Add-Member ApplicationClassId $global:ssa.ApplicationClassId
    $fullSsaObject | Add-Member ManageLink $global:ssa.ManageLink
    $fullSsaObject | Add-Member PropertiesLink $global:ssa.PropertiesLink
    $fullSsaObject | Add-Member MinimumReadyQueryComponentsPerPartition  $global:ssa.MinimumReadyQueryComponentsPerPartition 
    $fullSsaObject | Add-Member TimeBeforeAbandoningQueryComponent $global:ssa.TimeBeforeAbandoningQueryComponent
    $fullSsaObject | Add-Member EnableIMS $global:ssa.EnableIMS
    $fullSsaObject | Add-Member FASTAdminProxy $global:ssa.FASTAdminProxy
    $fullSsaObject | Add-Member UseSimpleSchemaUI $global:ssa.UseSimpleSchemaUI
    $fullSsaObject | Add-Member LatencyBasedQueryThrottling $global:ssa.LatencyBasedQueryThrottling
    $fullSsaObject | Add-Member CpuBasedQueryThrottling $global:ssa.CpuBasedQueryThrottling
    $fullSsaObject | Add-Member LoadBasedQueryThrottling $global:ssa.LoadBasedQueryThrottling
    $fullSsaObject | Add-Member IisVirtualDirectoryPath $global:ssa.IisVirtualDirectoryPath
    $fullSsaObject | Add-Member ApplicationPool $global:ssa.ApplicationPool.DisplayName
    $fullSsaObject | Add-Member PermissionsLink $global:ssa.PermissionsLink
    $fullSsaObject | Add-Member DefaultEndpoint $global:ssa.DefaultEndpoint
    $fullSsaObject | Add-Member Uri $global:ssa.Uri
    $fullSsaObject | Add-Member Shared $global:ssa.Shared
    $fullSsaObject | Add-Member Comments $global:ssa.Comments
    $fullSsaObject | Add-Member TermsOfServiceUri $global:ssa.TermsOfServiceUri
    $fullSsaObject | Add-Member Service $global:ssa.Service
    $fullSsaObject | Add-Member ServiceInstances $global:ssa.ServiceInstances
    $fullSsaObject | Add-Member ServiceApplicationProxyGroup $global:ssa.ServiceApplicationProxyGroup
    $fullSsaObject | Add-Member ApplicationVersion $global:ssa.ApplicationVersion
    $fullSsaObject | Add-Member CanUpgrade $global:ssa.CanUpgrade
    $fullSsaObject | Add-Member IsBackwardsCompatible $global:ssa.IsBackwardsCompatible
    $fullSsaObject | Add-Member NeedsUpgradeIncludeChildren $global:ssa.NeedsUpgradeIncludeChildren
    $fullSsaObject | Add-Member NeedsUpgrade $global:ssa.NeedsUpgrade
    $fullSsaObject | Add-Member UpgradeContext $global:ssa.UpgradeContext
    $fullSsaObject | Add-Member Status $global:ssa.Status
    $fullSsaObject | Add-Member Parent $global:ssa.Parent
    $fullSsaObject | Add-Member Version $global:ssa.Version
    $fullSsaObject | Add-Member Farm $global:ssa.Farm
    $fullSsaObject | Add-Member UpgradedPersistedProperties $global:ssa.UpgradedPersistedProperties
    $fullSsaObject | Add-Member CanSelectForBackup $global:ssa.CanSelectForBackup
    $fullSsaObject | Add-Member DiskSizeRequired $global:ssa.DiskSizeRequired
    $fullSsaObject | Add-Member CanSelectForRestore $global:ssa.CanSelectForRestore
    $fullSsaObject | Add-Member CanRenameOnRestore $global:ssa.CanRenameOnRestore

    $fullSsaObject | fl
}

#---------------------------------------------------
# Check if the SSA and its Proxy is Partitioned
#----------------------------------------------------
#---------------------------------------------------
# Check if the SSA and its Proxy is Partitioned
#----------------------------------------------------
function checkIfPartitioned
{
    ""
    ""
    "#########################################################################################"
    "   Is SSA Proxy and\or SSA 'Partitioned' ?"
    "#########################################################################################" 
    ""
    Write-host ""
    Write-Host "Checking the 'Properties' property of the SSA and Search Proxy"
    #Write-Host "Checking to see if the SSA Proxy.Properties is UnPartitioned. If it is partitioned ( this would have been done at creation time ), this can break contextual searches, especially on Web Apps that have been extended to another zone. URLMapping fails to happen if the Proxy is partitioned"
    #Write-Host "Also displaying the SSA's Properties to see if 'UnPartitioned'. If the SSA is partitioned, this can impact search results and analytics, if sites have SiteSubscriptions assigned ( this is not typical) "
    Write-host ""
    "By default, the SSA and SSA Proxy should have a value of 'UnPartitioned'. Anything other than that value, would indicate that the SSA would want to treat its 'data' as multi-tenant content ( like Office365 where it would partition tenants information so one tenant cannot see anothers ). "
    "If you 'Partition' the SSA, and you do **not** have SiteSubscriptions, set up (This is not common, and siteSubsctiptions are no longer supported in SP 2019), then search and analytics can be impacted."
    "If your SSA is 'UnPartitioned' and you do have SiteSubscriptions setup ( again, not common ) search results and analytics may not work as expected"
    ""
    "If the SSA Proxy is partitioned ( this would have been done at creation time ), URLMapping does not take place and will break contextual searches on Web Apps that have been extended to another zone"
    "If the Proxy is 'partitioned', you can easily resolve this by deleting the proxy within 'CA > Manage Service Apps'  and then recreate it with something like: "
    ""
    "    'New-SPEnterpriseSearchServiceApplicationProxy -SearchApplication 'SSA NAME' -Name 'Proxy Name' "
    ""
    "Simply Put... your SSA and SSA Proxy should not have anything other than 'UnPartitioned' "
    ""
    ""
   $proxyAppGuid = $global:ssa.id -replace "-", "" 
   $ssaProxy = Get-SPEnterpriseSearchServiceApplicationProxy | ?{$_.ServiceEndpointuri -like ("*$proxyAppGuid*")}
   $ssaProxyPropertiesProperty = $ssaProxy.Properties["Microsoft.Office.Server.Utilities.SPPartitionOptions"]
   $ssaPropertiesProperty = $global:ssa.Properties["Microsoft.Office.Server.Utilities.SPPartitionOptions"]
   if($ssaProxyPropertiesProperty -ne "UnPartitioned")
   {
    Write-Host -ForegroundColor Yellow "   The Search Proxy for this SSA is not set to 'UnPartitioned'. If the proxy is partitioned ( this would have been done at creation time ), URLMapping does not take place and will break contextual searches on Web Apps that have been extended to another zone"
    Write-Host ""
    "    Property for 'searchProxy.Properties' is set to:  '$ssaProxyPropertiesProperty' ( This can impact queries on extended zone URLs, among other search functions) "
   }
   else
   {
    Write-Host -ForegroundColor Green "   Your Search Proxy 'Properties' are set to expected values."
    Write-Host ""
    ""
    "    Your Search Proxy 'Properties' are set to expected values."
    ""
   }

   if($ssaPropertiesProperty -ne "UnPartitioned")
   {
    Write-Host -ForegroundColor Yellow " The SSA is not set to 'UnPartitioned'. If your SSA is 'Partitioned' and you do not have SiteSubscriptions set up (This is not common, and no longer supported in SP 2019), then search and analytics can be impacted by this."
    Write-Host ""
    "    Property for 'ssa.Properties' is set to:  '$ssaPropertiesProperty'  ( this can impact search\analytics) "
   }
   else
   {
    Write-Host -ForegroundColor Green "   Your SSA 'Properties' are set to expected values."
    Write-Host ""
    ""
    "    Your SSA 'Properties' are set to expected values."
    ""
   }

}

#-----------------------------------------------
# Legacy Admin
#-----------------------------------------------
function GetSSALegacyAdminComponent()
{
    Write-Host "Getting Legacy Admin Component Info"
    ""
    " -------------------------------------------------------------------"
    "   Legacy Admin Component"
    " -------------------------------------------------------------------"
    ""
    $global:ssa.AdminComponent
    ""
    " -------------------------------------------------------------------"
}

#-----------------------------------------------------------
## Check MSSConfiguration table for broken CPC ##
#-----------------------------------------------------------

function CheckCpcFromMssConfiguration
{
    Write-Host "Checking the Content Distributor Property from SSA Admin DB. If the property contains anything that reflects 'net.tcp:///' instead of 'net.tcp://<servername>/, then your crawls will hang. In the ULS, on the crawl servers, you should see this HResult being thrown:   0x80131537"
    Write-host ""
    $conn = New-Object System.Data.SqlClient.SqlConnection
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    
    $adminDb = Get-SPDatabase | ?{$_.Name -eq $ssa.SearchAdminDatabase.Name}
    $connectionString = $adminDb.DatabaseConnectionString
    $conn.ConnectionString = $connectionString
    $conn.Open()
    $cmd.connection = $conn


    #Write-Host "Issuing Query on:  " $configDb.Name
    #""
    
    $cmd.CommandText = "select top 5 Value from MSSConfiguration where name like '%FastConnector:ContentDistributor'"
    $rows = $cmd.ExecuteReader()
    
    if($rows.HasRows -eq $true)
    {
        while($rows.Read())
        {
                " -------------------------------------------------------------------"
                "   Content Distributor Property"
                " -------------------------------------------------------------------"
                ""
                "Checking the Content Distributor Property from SSA Admin DB. If the property contains anything that reflects 'net.tcp:///' instead of 'net.tcp://<servername>/, then your crawls will hang. In the ULS, on the crawl servers, you should see this HResult being thrown:   0x80131537"
                ""
                Write-Host("   ContentDistributor Property is: ") -ForegroundColor Gray; ([System.Environment]::NewLine); $rows[0]
                Write-Host "   " $rows[0] -ForegroundColor Gray
                Write-Host ""
            ""
            ""
        }
    }
    $rows.Close()
    $conn.Close()
}

#-----------------------------------------------
# Search Topology
#-----------------------------------------------
function GetSearchTopo()
{
    Write-Host "Getting Search Topology Info"
    ""
    
    $activeTopo = Get-SPEnterpriseSearchTopology -SearchApplication $global:ssa -Active
    "#################################################################################################################"
    " Search Topology ( ID: " + $global:ssa.ActiveTopology.TopologyId.Guid.ToString() + " ) for: " + "( " + $global:ssa.Name + " )"
    "#################################################################################################################"
    
    Get-SPEnterpriseSearchComponent -SearchTopology $activeTopo | Select * | Sort  -Property Name
}

#-----------------------------------------------
# Content Sources
#-----------------------------------------------
Function GetContentSources()
{
    Write-Host "Collecting Content Source Info"
    ""
    
      $crawlAccount = (New-Object Microsoft.Office.Server.Search.Administration.Content $global:ssa).DefaultGatheringAccount
      "#########################################################################################"
      "  *** Content Sources (" + $global:ssa.Name + ") *** " + " Crawl Account: " + $crawlAccount
      "#########################################################################################"
      $contentSources = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $global:ssa;
      foreach ($contentSrc in $contentSources) {
        ""
		"------------------------------------------------------------------------------------------------------- "
		$contentSrc.Name + " | ( ID:" + $contentSrc.ID + " TYPE:" + $contentSrc.Type + "  Behavior:" + $contentSrc.SharePointCrawlBehavior + ")"
		"------------------------------------------------------------------------------------------------------- "
        foreach ($startUri in $contentSrc.StartAddresses) 
        { 
          if ($contentSrc.Type.toString() -ieq "SharePoint")
          {
            $spSrc = @{}
            if ($startUri.Scheme.toString().toLower().startsWith("http")) 
            {
              $isRemoteFarm = $true ## Assume Remote Farm Until Proven Otherwise ##
              foreach ($altUrl in Get-SPAlternateUrl) {
                if ($startUri.AbsoluteUri.toString() -ieq $altUrl.Uri.toString()) 
                {
                  $isRemoteFarm = $false                
                  if ($altUrl.UrlZone -ieq "Default") 
                  {
                    "  Start Address: " + $startUri
                    "  AAM Zone: [" + $altUrl.UrlZone + "]" 
                    $inUserPolicy = $false;    #assume crawlAccount not inUserPolicy until verified
                    $webApp = Get-SPWebApplication $startUri.AbsoluteUri;
                    $IIS = $webApp.IisSettings[[Microsoft.SharePoint.Administration.SPUrlZone]::($altUrl.UrlZone)]
                    $isClaimsBased = $true
                    if ($webApp.UseClaimsAuthentication) 
                    { 
                        "  Authentication Type: [Claims]"
                        if (($IIS.ClaimsAuthenticationProviders).count -eq 1) 
                        {
                           "  Authentication Provider: " + ($IIS.ClaimsAuthenticationProviders[0]).DisplayName
                        } 
                        else 
                        {
                          "  Authentication Providers: "
                          foreach ($provider in ($IIS.ClaimsAuthenticationProviders)) 
                          {
                            "     - " + $provider.DisplayName
                          }
                        }
                    }
                    else {
                      $isClaimsBased = $false
                      "  Authentication Type: [Classic]"                  
                      if ($IIS.DisableKerberos) { "  Authentication Provider: [Windows:NTLM]" }
                      else { "  Authentication Provider:[Windows:Negotiate]" }
                    }
                    foreach ($userPolicy in $webApp.Policies) 
                    {
                      if($isClaimsBased)
                      {
                       $claimsPrefix = "i:0#.w|" 
                      }
                      if ($userPolicy.UserName.toLower().Equals(($claimsPrefix + $crawlAccount).toLower())) 
                      {
                        $inUserPolicy = $true;
                        "  Web App User Policy: {" + $userPolicy.PolicyRoleBindings.toString() + "}";
                      }
                    }
                    if (!$inUserPolicy) 
                    {
                      "  ---"  + $crawlAccount + " is NOT defined in the Web App's User Policy !!!";
                    }
                  }
                  else { 
                    "    [" + $altUrl.UrlZone + "] " + $startUri;
                    "  --- Non-Default zone may impact Contextual Scopes (e.g. This Site) and other search functionality"
                    "  ----- Check out https://www.ajcns.com/2021/02/problems-crawling-the-non-defaul-zone-for-a-sharepoint-web-application/ " 
                  }
                }
              }
          
              if($isRemoteFarm)
              {
                "  This Start Address is NOT local to the Farm"
                "  Start Address: " + $startUri
              } 
            
            } 
            else {
              if ($startUri.Scheme.toString().toLower().startsWith("sps")) { "  " + $startUri + " [Profile Crawl]" }
              else 
              {
                if ($startUri.Scheme.toString().toLower().startsWith("bdc")) { "  URL: " + $startUri + " [BDC Content]" }
                else { "    -" + $startUri; }
              }
            }
          }
          else { "  Web Address: " + $startUri; }
          "  ---------------------------------------------"
        }
        ""
      }
}

#-----------------------------------------------
# Server Name Mappings
#-----------------------------------------------
function GetServerNameMappings()
{
    Write-Host "Getting Server Name Mappings"
    ""
    "#########################################################################################"
    "  *** Server Name Mappings (" + $global:ssa.Name + ") ***"
    "#########################################################################################"
    "" 
    $global:ssa  | Get-SPEnterpriseSearchCrawlMapping
    ""

}

#-----------------------------------------------
# Crawl Rules
#-----------------------------------------------
function GetCrawlRules()
{
    Write-Host "Getting first 20 Crawl Rules"
    ""
    "#########################################################################################"
    "  *** Crawl Rules (" + $global:ssa.Name + ") ***"
    "#########################################################################################"
    ""
    $Rules = $global:ssa | Get-SPEnterpriseSearchCrawlRule 
    if ($Rules.count -lt 20) { $Rules }
    else 
    {
    ""
    "Top 20 (of " + $Rules.count + ") Crawl Rules"
    "---------------------------------------------"
    for ($i = 0; $i -le 21; $i++) { $Rules[$i]; }
    }
    ""
}


#-----------------------------------------------
# Global Search Service
#-----------------------------------------------
function displayGlobalSearchService
{

$searchServiceObjText = @"

- If the 'Search Service' Object\Instance is "Disabled", this will prevent new SSA's from fully creating and can cause other search related issues. To set it back online, do the following: ( remove space between $ and searchServiceObj)
-- $ searchServiceObj = Get-SPEnterpriseSearchService
-- $ searchServiceObj.Status = "Online"
-- $ searchServiceObj.Update()
"@
    Write-Host "Getting Search Service Info"
    ""
    "#########################################################################################"
    "  Search Service "
    "#########################################################################################"
    $searchServiceObj = Get-SPEnterpriseSearchService
    if($searchServiceObj.Status -ne "Online")
    {
        Write-Warning (" -- You 'Search Service Object' Instances is not Online. It's current status is:  " + $searchServiceObj.Status)
        "WARNING:  -- You 'Search Service Object' Instances is not Online. It's current status is:  " + $searchServiceObj.Status
        ""
        $searchServiceObjText
        Write-Host ("$searchServiceObjText") -ForegroundColor Gray
        Write-Host ""
    }

    $searchServiceObj
    $searchAdminProxy = $searchServiceObj.WebProxy

    if($searchAdminProxy.Address -ne $null)
    {
        " The Search Service has a Web Proxy defined. This will impact ALL SSA's and route crawl traffic to the Proxy regardless if the IE settings are set to NO PROXY"
        $searchAdminProxy
    }
}

#-----------------------------------------------
# SQSS Info
#-----------------------------------------------
Function GetSQSS()
{
    Write-Host "Getting SQSS Information"
    ""
    "#########################################################################################"
    "  Search Query and Site Settings (SQSS) - These should Only be running on your QPCs"
    "#########################################################################################"
    ""
    $instances = Get-SPServiceInstance | where {$_.TypeName -like "Search Query*"} | where {$_.Status -eq "Online"}
    if ($instances -ne $null) 
    {
      foreach($instance in $instances)
      {
          $instance.Server.Address.ToString() + " -- " + $instance.ID.ToString() + " -- " + $instance.Status.ToString()
      }
    }
}

#-----------------------------------------------
# Service Endpoints
#-----------------------------------------------

function VerifyServiceEndpoints
{
    Write-Host "Checking to see if the Search EndPoints are accessible.."
    ""
     "#########################################################################################"
     "   " + $global:ssa.Name + " - EndPoint Verification " 
      "#########################################################################################"
      ""
    try
    {
        foreach($sqssPt in $global:ssa.Endpoints)
        {
            foreach($sqssEndPoint in $sqssPt.ListenUris)
            {
                $sqssUri = $sqssEndPoint.AbsoluteUri
                
                $request = $null
                $request = [System.Net.WebRequest]::Create($sqssUri)
                $request.UseDefaultCredentials = $true
                $response = $request.GetResponse()
                $sqssUri.ToString() + " -- " + $response.StatusDescription.ToString()
            }
        }
    }
    catch
    {
        
    Write-Host("   There was a problem reaching $sqssuri  : "  + $_.Exception.Message) -ForegroundColor Yellow
    
    }

    $searchAdminWs = Get-SPServiceApplication | ?{$_.Name -eq $global:ssa.Id}
    try
    {
        foreach($searchAdminpt in $searchAdminWs.Endpoints)
        {        
            foreach($saEndPoint in $searchAdminpt.ListenUris)
            {
                $searchAdminUri = $saEndPoint.AbsoluteUri
            
                $request = $null
                $request = [System.Net.WebRequest]::Create($searchAdminUri)
                $request.UseDefaultCredentials = $true
                $response = $request.GetResponse()
                $searchAdminUri.ToString() + " -- " + $response.StatusDescription.ToString()

            }
        }
    }
    catch
    {
    Write-Host("   There was a problem reaching $searchAdminUri  : "  + $_.Exception.Message) -ForegroundColor DarkBlue
    }
}

#-----------------------------------------------
# Search Service Instances
#-----------------------------------------------
Function GetSSIs
{

    Write-Host "Getting Search Service Instances Info"
    ""
    "#########################################################################################"
    "  Are there any Disabled Search Instances..? "
    "#########################################################################################"
    ""
    $at = Get-SPEnterpriseSearchTopology -SearchApplication $global:ssa -Active
    $topoCompList = Get-SPEnterpriseSearchComponent -SearchTopology $at
    $components = $topoCompList | select ServerName -Unique

    $allGood = $true
    foreach($searchServer in $components)
    {
        
        $ssi = $global:serviceInstances | ?{$_.TypeName -eq "SharePoint Server Search" -and $_.Server.Address -eq $searchServer.ServerName}
        $hcsi= $global:serviceInstances | ?{$_.TypeName -match "Search Host Controller Service" -and $_.Server.Address -eq $searchServer.ServerName}
        if($ssi.Status -ne "Online")
        {
            Write-Host ""
            Write-Host ("   The '" + $ssi.TypeName +"' is not online on server: " + $searchServer.ServerName + ".  This instance should be Online. When this object is Disabled, health check jobs will shut down the 'mssearch.exe' service") -ForegroundColor Red
            Write-Host ("   Enable this instance again by running 'Start-SPEnterpriseSearchServiceInstance " + $searchServer.ServerName + "'") -ForegroundColor Yellow
            Write-Host ""
            "The '" + $ssi.TypeName +"' is not online on server: " + $searchServer.ServerName + ".  This instance should be Online. When this object is Disabled, health check jobs will shut down the 'mssearch.exe' service"
            ""
            " Enable this instance again by running 'Start-SPEnterpriseSearchServiceInstance " + $searchServer.ServerName + "'"
            
            $allGood = $false;
        }
    
        elseif($hcsi.Status -ne "Online")
        {
            Write-Host ""
            Write-Host ("   The '" + $hcsi.TypeName +"' is not online on server: " + $searchServer.ServerName + ".  This instance should be Online. When this object is Disabled, health check jobs will shut down the 'hostcontrollerservice.exe' service") -ForegroundColor Red
            Write-Host ("   Enable this instance again by running 'Start-SPEnterpriseSearchServiceInstance " + $searchServer.ServerName + "'") -ForegroundColor Yellow
            Write-Host ""
            "The '" + $hcsi.TypeName +"' is not online on server: " + $searchServer.ServerName + ".  This instance should be Online. When this object is Disabled, health check jobs will shut down the 'hostcontrollerservice.exe' service"
            ""
            " Enable this instance again by running 'Start-SPEnterpriseSearchServiceInstance " + $searchServer.ServerName + "'"
    
            $allGood = $false;
        }
    }
    if($allGood)
    {
        Write-Host ""
        Write-Host ("   All Search Instances are Online") -ForegroundColor Green
        Write-Host ""
        ""
        "   All Search Instances are Online"
    }
}

#-----------------------------------------------
# Alternate Access Mappings
#-----------------------------------------------
Function GetAAMs
{
    Write-Host "Getting Alternate Access Mappings"
    ""
	"###############################################################"
	" Alternate Access Mappings" 
	"###############################################################"
    ""
    "  IncomingUrl  --  Zone  --  PublicUrl "
     ""
     foreach($altUrl in $farm.AlternateUrlCollections)
    {
    
        ""
        "----------------------------------------------"
        $altUrl.Name
        "----------------------------------------------"

        $altUrl | %{$_.incomingUrl + " -- " + $_.Zone + " -- " + $_.PublicUrl}
    }
}

##########################################
# SP 2010 Function to get SSA Info
##########################################

function displaySSAInfo ($global:ssa)
{
  $crawlAccount = (New-Object Microsoft.Office.Server.Search.Administration.Content $global:ssa).DefaultGatheringAccount;
  "###################################################################################### "
  "  *** " + $global:ssa.Name + " ***" + "  | " + "  (Crawl Account: " + $crawlAccount + ")"
  "###################################################################################### "
  $global:ssa.ApplicationName
  $global:ssa
  "";
  "====================================================================================== "
  "  *** Admin Component (" + $global:ssa.Name + ") ***"
  "====================================================================================== "
  $global:ssa.AdminComponent; ""; 
  foreach ($ct in $global:ssa.CrawlTopologies) {
    "====================================================================================== "
    "  *** Crawl Topology (" + $global:ssa.Name + ") ***"
    "====================================================================================== "
    $ct; "";
    foreach ($cc in $ct.CrawlComponents){
      "---------------------------------------------------------------------------------- "
      "  *** Crawl Component (" + $cc.Name + ") ***"
      "---------------------------------------------------------------------------------- "
      $cc; "";
	  $farmServerId = $(Get-SPServer $cc.ServerName).Id;
	  if ($farmServerId -eq $null) {
		"******************************************************************"
		"[" + $cc.Name + "] ServerId mismatch found"; 
		"    - " + $cc.ServerName + " was removed from the farm"
		"******************************************************************"; "";	  	
	  } 
	  else { 
	  	if ($cc.ServerId -ne $farmServerId) {
			"******************************************************************"
			"[" + $cc.Name + "] ServerId mismatch found"; 
			"    - ServerId Per the Farm: " + $farmServerId 
			"    - And per the Component: " + $cc.ServerId 
			"******************************************************************"; "";
		}
	  }	
    }
  }
  foreach ($qt in $global:ssa.QueryTopologies){
    "====================================================================================== "
    "  *** Query Topology (" + $global:ssa.Name + ") ***"
    "====================================================================================== "
    $qt; "";
    foreach ($qc in $qt.QueryComponents){
      "---------------------------------------------------------------------------------- "
      "  *** Query Component (" + $qc.Name + ") ***"
      "---------------------------------------------------------------------------------- "
      $qc; "";
	  $farmServerId = $(Get-SPServer $qc.ServerName).Id;
	  if ($farmServerId -eq $null) {
		"******************************************************************"
		"[" + $qc.Name + "] ServerId mismatch found"; 
		"    - " + $qc.ServerName + " was removed from the farm"
		"******************************************************************"; "";	  	
	  } 
	  else { 
	  	if ($qc.ServerId -ne $farmServerId) {
			"******************************************************************"
			"[" + $qc.Name + "] ServerId mismatch found"; 
			"    - ServerId Per the Farm: " + $farmServerId 
			"    - And per the Component: " + $qc.ServerId 
			"******************************************************************"; "";
		}
	  } 
    }
  }; "";
  
  #"====================================================================================== "
  #"  *** Web Service EndPoints (" + $global:ssa.Name + ") ***"
  #"====================================================================================== "
  #"" 
  
    #VerifyServiceEndpoints
    #$adminSvc = (Get-SPServiceApplication) | where {$_.DisplayName -like "Search Admin*"+$global:ssa.Name}
    #$adminSvc.DisplayName; 
    #"---------------------------------------------------------------------------------- "
    #foreach ($endPt in $adminSvc.Endpoints) { 
    #  foreach ($listenUri in $endPt.listenUris) {
    #    "  Uri: " + $listenUri.AbsoluteUri
    #  } 
    #  ""
    #} 
    #"";
    #$global:ssa.Name
    #"---------------------------------------------------------------------------------- "
    #foreach ($endPt in $global:ssa.Endpoints) { 
    #  foreach ($listenUri in $endPt.listenUris) {
    #    "  Uri: " + $listenUri.AbsoluteUri
    #  } 
    #  ""
    #} 
  "";
  "====================================================================================== "
  "  *** Databases (" + $global:ssa.Name + ") ***"
  "====================================================================================== "
  ""
  "Admin Database" 
  "---------------------------"
  $global:ssa.SearchAdminDatabase | select Name, Id, Server, DatabaseConnectionString
  ""
  "Crawl Store Database(s)" 
  "---------------------------"
  $global:ssa.CrawlStores
  ""
  "Property Store Database(s)" 
  "---------------------------"
  $global:ssa.PropertyStores
  ""
  "====================================================================================== "
  "  *** Server Name Mappings (" + $global:ssa.Name + ") ***"
  "====================================================================================== "  
  $global:ssa | Get-SPEnterpriseSearchCrawlMapping

  "====================================================================================== "
  "  *** Crawl Rules (" + $global:ssa.Name + ") ***"
  "====================================================================================== "  
  $Rules = $global:ssa | Get-SPEnterpriseSearchCrawlRule 
  if ($Rules.count -lt 20) { $Rules }
  else {
    ""
    "Top 10 (of " + $Rules.count + ") Crawl Rules"
    "---------------------------------------------"
    for ($i = 0; $i -le 11; $i++) { $Rules[$i]; }
  }

  "====================================================================================== "
  "  *** Content Sources (" + $global:ssa.Name + ") ***"
  "====================================================================================== "
  $contentSources = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $global:ssa;
  foreach ($contentSrc in $contentSources) {
    ""
		"------------------------------------------------------------------------ "
		$contentSrc.Name + " | ( ID:" + $contentSrc.ID + " TYPE:" + $contentSrc.Type + "  Behavior:" + $contentSrc.SharePointCrawlBehavior + ")"
		"------------------------------------------------------------------------ "
    foreach ($startUri in $contentSrc.StartAddresses) { 
      if ($contentSrc.Type.toString() -ieq "SharePoint") {
        $spSrc = @{}
        if ($startUri.Scheme.toString().toLower().startsWith("http")) {
          $isRemoteFarm = $true ## Assume Remote Farm Until Proven Otherwise ##
          foreach ($altUrl in Get-SPAlternateUrl) {
            if ($startUri.AbsoluteUri.toString() -ieq $altUrl.Uri.toString()) {
              $isRemoteFarm = $false                
              if ($altUrl.UrlZone -ieq "Default") {
                "  Start Address: " + $startUri
                "  AAM Zone: [" + $altUrl.UrlZone + "]" 
                $inUserPolicy = $false;    #assume crawlAccount not inUserPolicy until verified
                $webApp = Get-SPWebApplication $startUri.AbsoluteUri;
                $IIS = $webApp.IisSettings[[Microsoft.SharePoint.Administration.SPUrlZone]::($altUrl.UrlZone)]
                $isClaimsBased = $true
                if ($webApp.UseClaimsAuthentication) { 
                    "  Authentication Type: [Claims]"
                    if (($IIS.ClaimsAuthenticationProviders).count -eq 1) {
                       "  Authentication Provider: " + ($IIS.ClaimsAuthenticationProviders[0]).DisplayName
                    } else {
                      "  Authentication Providers: "
                      foreach ($provider in ($IIS.ClaimsAuthenticationProviders)) {
                        "     - " + $provider.DisplayName
                      }
                    }
                }
                else {
                  $isClaimsBased = $false
                  "  Authentication Type: [Classic]"                  
                  if ($IIS.DisableKerberos) { "  Authentication Provider: [Windows:NTLM]" }
                  else { "  Authentication Provider:[Windows:Negotiate]" }
                }
                foreach ($userPolicy in $webApp.Policies) {
                  if($isClaimsBased){
                   $claimsPrefix = "i:0#.w|" 
                  }
                  if ($userPolicy.UserName.toLower().Equals(($claimsPrefix + $crawlAccount).toLower())) {
                    $inUserPolicy = $true;
                    "  Web App User Policy: {" + $userPolicy.PolicyRoleBindings.toString() + "}";
                  }
                }
                if (!$inUserPolicy) {
                  "  ---"  + $crawlAccount + " is NOT defined in the Web App's User Policy !!!";
                }
              }
              else { 
                "    [" + $altUrl.UrlZone + "] " + $startUri;
                "  --- Non-Default zone may impact Contextual Scopes (e.g. This Site)" 
              }
            }
          }
          
          if($isRemoteFarm)
          {
            "  This Start Address is NOT local to the Farm"
            "  Start Address: " + $startUri
          } 
            
        } 
        else {
          if ($startUri.Scheme.toString().toLower().startsWith("sps")) { "  " + $startUri + " [Profile Crawl]" }
          else {
            if ($startUri.Scheme.toString().toLower().startsWith("bdc")) { "  URL: " + $startUri + " [BDC Content]" }
            else { "    -" + $startUri; }
          }
        }
      }
      else { "  Web Address: " + $startUri; }
      "  ---------------------------------------------"
    }
    ""
  }
  $queryString = "SELECT TOP 10 CrawlID,ProjectID,CrawlType,ContentSourceID,Status,SubStatus,Request,StartTime,EndTime FROM MSSCrawlHistory WHERE ( [CrawlID] NOT IN (SELECT [CrawlID] FROM MSSCrawlHistory WHERE ((Status = 11) OR ((Status = 4) AND (SubStatus = 1))))) ORDER BY CrawlID DESC"
  $dataSet = New-Object System.Data.DataSet "CrawlHistory"
  if ((New-Object System.Data.SqlClient.SqlDataAdapter($queryString, $global:ssa.SearchAdminDatabase.DatabaseConnectionString)).Fill($dataSet)) {
    "====================================================================================== "
    " *** Incomplete Crawl History ***"  
    "====================================================================================== "
    $dataSet.Tables[0] | SELECT *
  }
  "====================================================================================== "
  "";
}

#---added by bspender--------------------------------------------------------------------------------------------------
# VerifyApplicationServerSyncJobsEnabled: Verify that Application Server Admin Service Timer Jobs are running
# ---------------------------------------------------------------------------------------------------------------------
function VerifyApplicationServerSyncJobsEnabled
{
    Write-Host "Checking timer job functionality for job:  'job-application-server*'"
    ""
	"###############################################################"
	" Are these Critical Jobs and Service Instances running..? " 
	"###############################################################"
    ""

    $timeThresholdInMin = 5
	
	$sspJob = $farm.Services | where {$_.TypeName -like "SSP Job Control*"}
	if ($sspJob.Status -ne "Online")
    { 
		Write-Warning (" -- Farm Level: SSP Job Control Service is " + $sspJob.Status)
        ""
        " -- Farm Level: SSP Job Control Service is " + $sspJob.Status
        ""
		$global:serviceDegraded = $true
	}
    else
    {
        Write-Host ""
        Write-Host (" -- Farm Level: SSP Job Control Service is " + $sspJob.Status) -ForegroundColor Green
        " -- Farm Level: SSP Job Control Service is " + $sspJob.Status
        ""
    }

	$serverNames = $($servers | Where {$_.Role -ne "Invalid"}).Name
	foreach ($server in $serverNames) 
    {
		$sspJobServiceInstance = $farm.Servers[$server].ServiceInstances | where {$_.TypeName -like "SSP Job Control*"}
		if ($sspJobServiceInstance.Status -ne "Online")
        { 
			Write-Warning (" -- SSP Job Control Service Instance is " + $sspJobServiceInstance.Status + " on " + $server)
            ""
            " -- SSP Job Control Service Instance is " + $sspJobServiceInstance.Status + " on " + $server
            ""
			$global:SSPJobInstancesOffline.Add($sspJobServiceInstance) | Out-Null
			$global:serviceDegraded = $true
		}
        else
        {
            Write-Host ""
            Write-Host (" -- SSP Job Control Service Instance is " + $sspJobServiceInstance.Status + " on " + $server) -ForegroundColor Green
            " -- SSP Job Control Service Instance is " + $sspJobServiceInstance.Status + " on " + $server
            ""
        }
	}

    if ($serverNames.count -eq 1) 
    {
		$jobs = Get-SPTimerJob | where {$_.Name -like "job-application-*"}
    } 
    else 
    {
		$jobs = Get-SPTimerJob | where {$_.Name -eq "job-application-server-admin-service"}
	}

	foreach ($j in $jobs) { 
		Write-OutPut ($j.Name)
		Write-OutPut ("-------------------------------------------------------")
		if (($j.Status -ne "Online") -or ($j.isDisabled)) { 
			if ($j.Status -ne "Online") { Write-Warning ($j.Name + " timer job is " + $j.Status) }
			if ($j.isDisabled) { Write-Warning ($j.Name + " timer job is DISABLED") }
			$global:ApplicationServerSyncTimerJobsOffline.Add($j) | Out-Null 
			$global:serviceDegraded = $true
		} else {
			$mostRecent = $j.HistoryEntries | select -first ($serverNames.count * $timeThresholdInMin) 
			foreach ($server in $serverNames) { 
				$displayShorthand = $server+": "+$($j.Name)
				$mostRecentOnServer = $mostRecent | Where {$_.ServerName -ieq $server} | SELECT -First 1
				if ($mostRecentOnServer -eq $null) {
					Write-Warning ($displayShorthand + " timer job does not appear to be running")
					#and add this server to the list
					$global:ApplicationServerSyncNotRunning.Add($displayShorthand) | Out-Null
					$global:serviceDegraded = $true
				} else {
					$spanSinceLastRun = [int]$(New-TimeSpan $mostRecentOnServer.EndTime $(Get-Date).ToUniversalTime()).TotalSeconds
					if ($spanSinceLastRun -lt ($timeThresholdInMin * 60)) {
						Write-OutPut ($displayShorthand + " recently ran " + $spanSinceLastRun + " seconds ago")
					} else {
						Write-Warning ($displayShorthand + " last ran " + $spanSinceLastRun + " seconds ago")
						$global:ApplicationServerSyncNotRunning.Add($displayShorthand) | Out-Null
						$global:serviceDegraded = $true
					}
					#(For added verbosity, uncomment the following line to report the last successful run for this server) 
					#$mostRecentOnServer		
				}		
			}	
		}
	}
}

#################################################################################################################
#################################################################################################################

function HealthCheck ()
{
    Write-Host ""
    Write-Host "Running Search Health Check, this can take several mins"
    ""

# ------------------------------------------------------------------------------------------------------------------
# GetCrawlStatus: Get crawl status
# ------------------------------------------------------------------------------------------------------------------
Function GetCrawlStatus
{
    if ($global:ssa.Ispaused())
    {
        switch ($global:ssa.Ispaused()) 
        { 
            1       { $pauseReason = "ongoing search topology operation" } 
            2       { $pauseReason = "backup/restore" } 
            4       { $pauseReason = "backup/restore" } 
            32      { $pauseReason = "crawl DB re-factoring" } 
            64      { $pauseReason = "link DB re-factoring" } 
            128     { $pauseReason = "external reason (user initiated)" } 
            256     { $pauseReason = "index reset" } 
            512     { $pauseReason = "index re-partitioning (query is also paused)" } 
            default { $pauseReason = "multiple reasons ($($global:ssa.Ispaused()))" } 
        }
        Write-Output "$($global:ssa.Name): Paused for $pauseReason"
    }
    else
    {
        $crawling = $false
        $contentSources = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $global:ssa
        if ($contentSources) 
        {
            foreach ($source in $contentSources)
            {
                if ($source.CrawlState -ne "Idle")
                {
                    Write-Output "Crawling $($source.Name) : $($source.CrawlState)"
                    $crawling = $true
                }
            }
            if (! $crawling)
            {
                Write-Output "Crawler is idle"
            }
        }
        else
        {
            Write-Output "Crawler: No content sources found"
        }
    }
}

# ------------------------------------------------------------------------------------------------------------------
# GetTopologyInfo: Get basic topology info and component health status
# ------------------------------------------------------------------------------------------------------------------
Function GetTopologyInfo
{
    $at = Get-SPEnterpriseSearchTopology -SearchApplication $global:ssa -Active
    $global:topologyCompList = Get-SPEnterpriseSearchComponent -SearchTopology $at

    # Check if topology is prepared for HA
    $adminFound = $false
    foreach ($searchComp in ($global:topologyCompList))
    {
        if ($searchComp.Name -match "Admin")
        { 
            if ($adminFound) 
            { 
                $global:haTopology = $true 
            } 
            else
            {
                $adminFound = $true
            }
        }
    }    

    #
    # Get topology component state:
    #
    $global:componentStateList=Get-SPEnterpriseSearchStatus -SearchApplication $global:ssa

    # Find the primary admin component:
    foreach ($component in ($global:componentStateList))
    {
        if ( ($component.Name -match "Admin") -and ($component.State -ne "Unknown") )
        {
            if (Get-SPEnterpriseSearchStatus -SearchApplication $global:ssa -Primary -Component $($component.Name))
            {
                $global:primaryAdmin = $component.Name
            }
        }
    }    
    if (! $global:primaryAdmin)
    {
        Write-Output ""
        Write-Output "-----------------------------------------------------------------------------"
        Write-Output "Error: Not able to obtain health state information."
        Write-Output "Recommended action: Ensure that at least one admin component is operational."
        Write-Output "This state may also indicate that an admin component failover is in progress."
        Write-Output "-----------------------------------------------------------------------------"
        Write-Output ""
        throw "Search component health state check failed"
    }
}

# ------------------------------------------------------------------------------------------------------------------
# PopulateHostHaList: For each component, determine properties and update $global:hostArray / $global:haArray
# ------------------------------------------------------------------------------------------------------------------
Function PopulateHostHaList($searchComp)
{
    if ($searchComp.ServerName)
    {
        $hostName = $searchComp.ServerName
    }
    else
    {
        $hostName = "Unknown server"
    }
    $partition = $searchComp.IndexPartitionOrdinal
    $newHostFound = $true
    $newHaFound = $true
    $entity = $null

    foreach ($searchHost in ($global:hostArray))
    {
        if ($searchHost.hostName -eq $hostName)
        {
            $newHostFound = $false
        }
    }
    if ($newHostFound)
    {
        # Add the host to $global:hostArray
        $hostTemp = $global:hostTemplate | Select-Object *
        $hostTemp.hostName = $hostName
        $global:hostArray += $hostTemp
        $global:searchHosts += 1
    }

    # Fill in component specific data in $global:hostArray
    foreach ($searchHost in ($global:hostArray))
    {
        if ($searchHost.hostName -eq $hostName)
        {
            $partition = -1
            if ($searchComp.Name -match "Query") 
            { 
                $entity = "QueryProcessingComponent" 
                $searchHost.qpc = "QueryProcessing "
                $searchHost.components += 1
            }
            elseif ($searchComp.Name -match "Content") 
            { 
                $entity = "ContentProcessingComponent" 
                $searchHost.cpc = "ContentProcessing "
                $searchHost.components += 1
            }
            elseif ($searchComp.Name -match "Analytics") 
            { 
                $entity = "AnalyticsProcessingComponent" 
                $searchHost.apc = "AnalyticsProcessing "
                $searchHost.components += 1
            }
            elseif ($searchComp.Name -match "Admin") 
            { 
                $entity = "AdminComponent" 
                if ($searchComp.Name -eq $global:primaryAdmin)
                {
                    $searchHost.pAdmin = "Admin(Primary) "
                }
                else
                {
                    $searchHost.sAdmin = "Admin "
                }
                $searchHost.components += 1
            }
            elseif ($searchComp.Name -match "Crawl") 
            { 
                $entity = "CrawlComponent" 
                $searchHost.crawler = "Crawler "
                $searchHost.components += 1
            }
            elseif ($searchComp.Name -match "Index") 
            { 
                $entity = "IndexComponent"
                $partition = $searchComp.IndexPartitionOrdinal
                $searchHost.index = "IndexPartition($partition) "
                $searchHost.components += 1
            }
        }
    }

    # Fill in component specific data in $global:haArray
    foreach ($haEntity in ($global:haArray))
    {
        if ($haEntity.entity -eq $entity)
        {
            if ($entity -eq "IndexComponent")
            {
                if ($haEntity.partition -eq $partition)
                {
                    $newHaFound = $false
                }
            }
            else 
            { 
                $newHaFound = $false
            }
        }
    }
    if ($newHaFound)
    {
        # Add the HA entities to $global:haArray
        $haTemp = $global:haTemplate | Select-Object *
        $haTemp.entity = $entity
        $haTemp.components = 1
        if ($partition -ne -1) 
        { 
            $haTemp.partition = $partition 
        }
        $global:haArray += $haTemp
    }
    else
    {
        foreach ($haEntity in ($global:haArray))
        {
            if ($haEntity.entity -eq $entity) 
            {
                if (($entity -eq "IndexComponent") )
                {
                    if ($haEntity.partition -eq $partition)
                    {
                        $haEntity.components += 1
                    }
                }
                else
                {
                    $haEntity.components += 1
                    if (($haEntity.entity -eq "AdminComponent") -and ($searchComp.Name -eq $global:primaryAdmin))
                    {
                        $haEntity.primary = $global:primaryAdmin
                    }
                }
            }
        }
    }
}

# ------------------------------------------------------------------------------------------------------------------
# AnalyticsStatus: Output status of analytics jobs
# ------------------------------------------------------------------------------------------------------------------
Function AnalyticsStatus
{
    Write-Output "Analytics Processing Job Status:"
    $analyticsStatus = Get-SPEnterpriseSearchStatus -SearchApplication $global:ssa -JobStatus

    foreach ($analyticsEntry in $analyticsStatus)
    {
        if ($analyticsEntry.Name -ne "Not available")     
        {
            foreach ($de in ($analyticsEntry.Details))
            {
                if ($de.Key -eq "Status")
                {
                    $status = $de.Value
                }
            }
            Write-Output "    $($analyticsEntry.Name) : $status"
        }
        # Output additional diagnostics from the dictionary
        foreach ($de in ($analyticsEntry.Details))
        {
            # Skip entries that is listed as Not Available
            if ( ($de.Value -ne "Not available") -and ($de.Key -ne "Activity") -and ($de.Key -ne "Status") )
            {
                Write-Output "        $($de.Key): $($de.Value)"
                if ($de.Key -match "Last successful start time")
                {
                    $dLast = Get-Date $de.Value
                    $dNow = Get-Date
                    $daysSinceLastSuccess = $dNow.DayOfYear - $dLast.DayOfYear
                    if ($daysSinceLastSuccess -gt 3)
                    {
                        Write-Output "        Warning: More than three days since last successful run"
                        $global:serviceDegraded = $true                        
                    }
                }
            }
        }
    }
    Write-Output ""
}

# ------------------------------------------------------------------------------------------------------------------
# SearchComponentStatus: Analyze the component status for one component
# ------------------------------------------------------------------------------------------------------------------
Function SearchComponentStatus($component)
{
    # Find host name
    foreach($searchComp in ($global:topologyCompList))
    {
        if ($searchComp.Name -eq $component.Name)
        {
            if ($searchComp.ServerName)
            {
                $hostName = $searchComp.ServerName
            }
            else
            {
                $hostName = "No server associated with this component. The server may have been removed from the farm."
            }
        }
    }
    if ($component.State -ne "Active")
    {
        # String with all components that is not active:
        if ($component.State -eq "Unknown")
        {
            $global:unknownComponents += "$($component.Name):$($component.State)"
        }
        elseif ($component.State -eq "Degraded")
        {
            $global:degradedComponents += "$($component.Name):$($component.State)"
        }
        else
        {
            $global:failedComponents += "$($component.Name):$($component.State)"
        }
        $global:serviceDegraded = $true
    }
    
    # Skip unnecessary info about cells and partitions if everything is fine
    $outputEntry = $true
    
    # Indent the cell info, logically belongs to the component. 
    if ($component.Name -match "Cell")
    {
        if ($component.State -eq "Active")
        {
            $outputEntry = $false
        }
        else
        {
            Write-Output "    $($component.Name)"
        }
    }
    elseif ($component.Name -match "Partition")
    {
        if ($component.State -eq "Active")
        {
            $outputEntry = $false
        }
        else
        {
            Write-Output "Index $($component.Name)"
        }
    }
    else
    {
        # State for search components
        $primaryString = ""
        if ($component.Name -match "Query") { $entity = "QueryProcessingComponent" }
        elseif ($component.Name -match "Content") { $entity = "ContentProcessingComponent" }
        elseif ($component.Name -match "Analytics") { $entity = "AnalyticsProcessingComponent" }
        elseif ($component.Name -match "Crawl") { $entity = "CrawlComponent" }
        elseif ($component.Name -match "Admin") 
        { 
            $entity = "AdminComponent" 
            if ($global:haTopology)
            {
                if ($component.Name -eq $global:primaryAdmin)
                {
                    $primaryString = " (Primary)"
                }
            }
        }
        elseif ($component.Name -match "Index") 
        { 
            $entity = "IndexComponent"
            foreach ($searchComp in ($global:topologyCompList))
            {
                if ($searchComp.Name -eq $component.Name) 
                {
                    $partition = $searchComp.IndexPartitionOrdinal
                }
            }
            # find info about primary role
            foreach ($de in ($component.Details))
            {
                if ($de.Key -eq "Primary")
                {
                    if ($de.Value -eq "True")
                    {
                        $primaryString = " (Primary)"
                        foreach ($haEntity in ($global:haArray))
                        {
                            if (($haEntity.entity -eq $entity) -and ($haEntity.partition -eq $partition))
                            {
                                $haEntity.primary = $component.Name

                            }
                        }                        
                    }
                }
            }
        }
        foreach ($haEntity in ($global:haArray))
        {
            if ( ($haEntity.entity -eq $entity) -and ($component.State -eq "Active") )
            {
                if ($entity -eq "IndexComponent")
                {
                    if ($haEntity.partition -eq $partition)
                    {
                        $haEntity.componentsOk += 1
                    }
                }
                else 
                { 
                    $haEntity.componentsOk += 1
                }
            }
        }
        # Add the component entities to $global:compArray for output formatting
        $compTemp = $global:compTemplate | Select-Object *
        $compTemp.Component = "$($component.Name)$primaryString"
        $compTemp.Server = $hostName
        $compTemp.State = $component.State
        if ($partition -ne -1) 
        { 
            $compTemp.Partition = $partition 
        }
        $global:compArray += $compTemp

        if ($component.State -eq "Active")
        {
            $outputEntry = $false
        }
        else
        {
            Write-Output "$($component.Name)"
        }
    }
    if ($outputEntry)
    {
        if ($component.State)
        {
            Write-Output "    State: $($component.State)"
        }
        if ($hostName)
        {
            Write-Output "    Server: $hostName"
        }
        if ($component.Message)
        {
            Write-Output "    Details: $($component.Message)"
        }
    
        # Output additional diagnostics from the dictionary
        foreach ($de in ($component.Details))
        {
            if ($de.Key -ne "Host")
            {
                Write-Output "    $($de.Key): $($de.Value)"
            }
        }
        if ($global:haTopology)
        {
            if ($component.Name -eq $global:primaryAdmin)
            {
                Write-Output "    Primary: True"            
            }
            elseif ($component.Name -match "Admin")
            {
                Write-Output "    Primary: False"            
            }
        }
    }
}

# ------------------------------------------------------------------------------------------------------------------
# DetailedIndexerDiag: Output selected info from detailed component diag
# ------------------------------------------------------------------------------------------------------------------
Function DetailedIndexerDiag
{
    $indexerInfo = @()
    $generationInfo = @()
    $generation = 0

    foreach ($searchComp in ($global:componentStateList))
    {
        $component = $searchComp.Name
        if ( (($component -match "Index") -or ($component -match "Content") -or ($component -match "Admin")) -and ($component -notmatch "Cell") -and ($searchComp.State -notmatch "Unknown") -and ($searchComp.State -notmatch "Registering"))
        {
            $pl=Get-SPEnterpriseSearchStatus -SearchApplication $global:ssa -HealthReport -Component $component
            foreach ($entry in ($pl))
            {
                if ($entry.Name -match "plugin: number of documents") 
                { 
                    foreach ($haEntity in ($global:haArray))
                    {
                        if (($haEntity.entity -eq "IndexComponent") -and ($haEntity.primary -eq $component))
                        {
                            # Count indexed documents from all index partitions:
                            $global:indexedDocs += $entry.Message
                            $haEntity.docs = $entry.Message
                        }
                    }
                }
                if ($entry.Name -match "repartition")
                    { $indexerInfo += "Index re-partitioning state: $($entry.Message)" }
                elseif (($entry.Name -match "splitting") -and ($entry.Name -match "fusion")) 
                    { $indexerInfo += "$component : Splitting index partition (appr. $($entry.Message) % finished)" }
                elseif (($entry.Name -match "master merge running") -and ($entry.Message -match "true")) 
                { 
                    $indexerInfo += "$component : Index Master Merge (de-fragment index files) in progress" 
                    $global:masterMerge = $true
                }
                elseif ($global:degradedComponents -and ($entry.Name -match "plugin: newest generation id"))
                {
                    # If at least one index component is left behind, we want to output the generation number.  
                    $generationInfo += "$component : Index generation: $($entry.Message)" 
                    $gen = [int] $entry.Message
                    if ($generation -and ($generation -ne $gen))
                    {
                        # Verify if there are different generation IDs for the indexers
                        $global:generationDifference = $true
                    }
                    $generation = $gen
                }
                elseif (($entry.Level -eq "Error") -or ($entry.Level -eq "Warning"))
                {
                    $global:serviceDegraded = $true
                    if ($entry.Name -match "fastserver")
                        { $indexerInfo += "$component ($($entry.Level)) : Indexer plugin error ($($entry.Name):$($entry.Message))" }
                    elseif ($entry.Message -match "fragments")
                        { $indexerInfo += "$component ($($entry.Level)) : Missing index partition" }
                    elseif (($entry.Name -match "active") -and ($entry.Message -match "not active"))
                        { $indexerInfo += "$component ($($entry.Level)) : Indexer generation controller is not running. Potential reason: All index partitions are not available" }
                    elseif ( ($entry.Name -match "in_sync") -or ($entry.Name -match "left_behind") )
                    { 
                        # Indicates replicas are out of sync, catching up. Redundant info in this script
                        $global:indexLeftBehind = $true
                    }                
                    elseif ($entry.Name -match "full_queue")
                        { $indexerInfo += "$component : Items queuing up in feeding ($($entry.Message))" }                                
                    elseif ($entry.Message -notmatch "No primary")
                    {
                        $indexerInfo += "$component ($($entry.Level)) : $($entry.Name):$($entry.Message)"
                    }
                }
            }
        }
    } 

    if ($indexerInfo)
    {
        Write-Output ""
        Write-Output "Indexer related additional status information:"
        foreach ($indexerInfoEntry in ($indexerInfo))
        {        
            Write-Output "    $indexerInfoEntry"
        }
        if ($global:indexLeftBehind -and $global:generationDifference)
        {
            # Output generation number for indexers in case any of them have been reported as left behind, and reported generation IDs are different.
            foreach ($generationInfoEntry in ($generationInfo))
            {        
                Write-Output "    $generationInfoEntry"
            }
        }
        Write-Output ""
    }
}

# ------------------------------------------------------------------------------------------------------------------
# VerifyHaLimits: Verify HA status for topology and index size limits
# ------------------------------------------------------------------------------------------------------------------
Function VerifyHaLimits
{
    $hacl = @()
    $haNotOk = $false
    $ixcwl = @()
    $ixcel = @()
    $docsExceeded = $false
    $docsHigh = $false
    foreach ($hac in $global:haArray)
    {
        if ([int] $hac.componentsOk -lt 2)
        {
            if ([int] $hac.componentsOk -eq 0)
            {
                # Service is down
                $global:serviceFailed = $true
                $haNotOk = $true   
            }
            elseif ($global:haTopology)
            {
                # Only relevant to output if we have a HA topology in the first place
                $haNotOk = $true   
            }

            if ($hac.partition -ne -1)
            {
                $hacl += "$($hac.componentsOk)($($hac.components)) : Index partition $($hac.partition)"
            }
            else
            {
                $hacl += "$($hac.componentsOk)($($hac.components)) : $($hac.entity)"
            }
        }
        if($is2016)
        {
            if ([int] $hac.docs -gt 20000000)
            {
                $docsExceeded = $true 
                $ixcel += "$($hac.entity) (partition $($hac.partition)): $($hac.docs)"
            }
            elseif ([int] $hac.docs -gt 19000000)
            {
                $docsHigh = $true   
                $ixcwl += "$($hac.entity) (partition $($hac.partition)): $($hac.docs)"
            }
        }
        elseif($is2013)
        {
            if ([int] $hac.docs -gt 10000000)
            {
                $docsExceeded = $true 
                $ixcel += "$($hac.entity) (partition $($hac.partition)): $($hac.docs)"
            }
            elseif ([int] $hac.docs -gt 9000000)
            {
                $docsHigh = $true   
                $ixcwl += "$($hac.entity) (partition $($hac.partition)): $($hac.docs)"
            }
        }
    }
    if ($haNotOk)
    {
        $hacl = $hacl | sort
        if ($global:serviceFailed)
        {
            Write-Output "Critical: Service down due to components not active:"
        }
        else
        {
            Write-Output "Warning: No High Availability for one or more components:"
        }
        foreach ($hc in $hacl)
        {
            Write-Output "    $hc"
        }
        Write-Output ""
    }
    if ($docsExceeded)
    {
        $global:serviceDegraded = $true
        Write-Output "Warning: One or more index component exceeds document limit:"
        foreach ($hc in $ixcel)
        {
            Write-Output "    $hc"
        }
        Write-Output ""
    }
    if ($docsHigh)
    {
        Write-Output "Warning: One or more index component is close to document limit:"
        foreach ($hc in $ixcwl)
        {
            Write-Output "    $hc"
        }
        Write-Output ""
    }
}

# ------------------------------------------------------------------------------------------------------------------
# VerifyHostControllerRepository: Verify that Host Controller HA (for dictionary repository) is OK
# ------------------------------------------------------------------------------------------------------------------
Function VerifyHostControllerRepository
{
    $highestRepVer = 0
    $hostControllers = 0
    $primaryRepVer = -1
    $hcStat = @()
    $hcs = Get-SPEnterpriseSearchHostController
    foreach ($hc in $hcs)
    {
        $hostControllers += 1
        $repVer = $hc.RepositoryVersion
        $serverName = $hc.Server.Name
        if ($repVer -gt $highestRepVer)
        {
            $highestRepVer = $repVer
        }
        if ($hc.PrimaryHostController)
        {
            $primaryHC = $serverName
            $primaryRepVer = $repVer
        }
        if ($repVer -ne -1)
        {
            $hcStat += "        $serverName : $repVer"
        }
    }
    if ($hostControllers -gt 1)
    {
        Write-Output "Primary search host controller (for dictionary repository): $primaryHC"
        if ($primaryRepVer -eq -1)
        {
            $global:serviceDegraded = $true
            Write-Output "Warning: Primary host controller is not available."
            Write-Output "    Recommended action: Restart server or set new primary host controller using Set-SPEnterpriseSearchPrimaryHostController."
            Write-Output "    Repository version for existing host controllers:"
            foreach ($hcs in $hcStat)
            {
                Write-Output $hcs
            }
        }
        elseif ($primaryRepVer -lt $highestRepVer)
        {
            $global:serviceDegraded = $true
            Write-Output "Warning: Primary host controller does not have the latest repository version."
            Write-Output "    Primary host controller repository version: $primaryRepVer"
            Write-Output "    Latest repository version: $highestRepVer"
            Write-Output "    Recommended action: Set new primary host controller using Set-SPEnterpriseSearchPrimaryHostController."
            Write-Output "    Repository version for existing host controllers:"
            foreach ($hcs in $hcStat)
            {
                Write-Output $hcs
            }
        }
        Write-Output ""
    }
}

#---added by bspender--------------------------------------------------------------------------------------------------
# VerifyApplicationServerSyncJobsEnabled: Verify that Application Server Admin Service Timer Jobs are running
# ---------------------------------------------------------------------------------------------------------------------
function VerifyRunningProcesses
{
	$components = $global:ssa.ActiveTopology.GetComponents() | Sort ServerName | SELECT ServerName, Name

	foreach ($hostname in $global:hostArray.Hostname) {
	    Write-OutPut ("---[$hostname]---") -ForegroundColor Cyan

	    Write-OutPut ("Components deployed to this server...") 
	    $crawler = $components | Where {($_.Servername -ieq $hostname) -and ($_.Name -match "Crawl") } 
	    if ($crawler -ne $null) {
	        Write-OutPut ("    " + $crawler.Name + ":") -ForegroundColor White
	        $mssearch = (Get-Process mssearch -ComputerName $hostname -ErrorAction SilentlyContinue)
	        Write-OutPut ("        " + $mssearch.ProcessName + "[PID: " + $mssearch.Id + "]")
	        $mssdmn = (Get-Process mssdmn -ComputerName $hostname -ErrorAction SilentlyContinue)
	        $mssdmn | ForEach {
	            Write-OutPut ("        " + $_.ProcessName + "[PID: " + $_.Id + "]")
	        }
	    }

	    $junoComponents = $components | Where {($_.Servername -ieq $hostname) -and ($_.Name -notMatch "Crawl") }     
	    $noderunnerProcesses = (Get-Process noderunner -ComputerName $hostname -ErrorAction SilentlyContinue)

	    foreach ($node in $noderunnerProcesses) {
	        $node | Add-Member -Force -MemberType NoteProperty -Name _ProcessCommandLine -Value $(
			    (Get-WmiObject Win32_Process -ComputerName $hostname -Filter $("processId=" + $node.id)).CommandLine
		    )

	        $junoComponents | Where {$_.Servername -ieq $hostname} | ForEach {
	            $component = $($_).Name
	            if ($node._ProcessCommandLine -like $("*" + $component + "*")) {
	                Write-OutPut ("    " + $component + ":") -ForegroundColor White
	                Write-OutPut ("        " + $node.ProcessName + "[PID: " + $node.Id + "]")
	            }
	        }
	    }

	    #if this is a custom object, wrap it in an array object so we can get a count in the step below
	    if ($junoComponents -is [PSCustomObject]) { $junoComponents = @($junoComponents) } 

	    if ($junoComponents.Count  -gt $noderunnerProcesses.Count) {
	        Write-OutPut ("One or more noderunner processes is not running for components") -ForegroundColor Yellow 
	    }

	    Write-OutPut
	    $services = Get-Service -ComputerName $hostname -Name SPTimerV4, SPAdminV4, OSearch15, SPSearchHostController 
	    $running = $services | Where {$_.Status -eq "Running"}
	    if ($running) {
	        Write-OutPut ("Service Instances...") -ForegroundColor Green
	        $running | ft -AutoSize
	    }
	    $stopped = $services | Where {$_.Status -eq "Stopped"}
	    if ($stopped) {
	        Write-OutPut ("`"Stopped`" Services...") -ForegroundColor Red
	        $stopped | ft -AutoSize
	    }
	    $other   = $services | Where {($_.Status -ne "Running") -and ($_.Status -ne "Stopped")}
	    if ($other) {
	        Write-OutPut ("Service in an abnormal or transient state...") -ForegroundColor Yellow
	        $other | ft -AutoSize
	    }

	}
}




# ------------------------------------------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------------------------------------------

Write-Output ""
Write-Output "###############################################"
Write-Output "Search Topology health check"
Write-Output "###############################################"
Write-Output ""
# ------------------------------------------------------------------------------------------------------------------
# Global variables:
# ------------------------------------------------------------------------------------------------------------------

$global:serviceDegraded = $false
$global:serviceFailed = $false
$global:unknownComponents = @()
$global:degradedComponents = @()
$global:failedComponents = @()
$global:generationDifference = $false
$global:indexLeftBehind = $false
$global:searchHosts = 0
#$global:ssa = $null
$global:componentStateList = $null
$global:topologyCompList = $null
$global:haTopology = $false
$global:primaryAdmin = $null
$global:indexedDocs = 0
$global:masterMerge = $false

#---added by bspender------------------------
$global:SSPJobInstancesOffline = $(New-Object System.Collections.ArrayList)
$global:ApplicationServerSyncTimerJobsOffline = $(New-Object System.Collections.ArrayList)
$global:ApplicationServerSyncNotRunning = $(New-Object System.Collections.ArrayList)
#--------------------------------------------
$global:UnreachableSearchServiceSvc = $(New-Object System.Collections.ArrayList)
$global:UnreachableSearchAdminSvc = $(New-Object System.Collections.ArrayList)
#--------------------------------------------

# Template object for the host array:
$global:hostTemplate = New-Object psobject
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name hostName -Value $null
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name components -Value 0
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name cpc -Value $null
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name qpc -Value $null
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name pAdmin -Value $null
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name sAdmin -Value $null
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name apc -Value $null
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name crawler -Value $null
$global:hostTemplate | Add-Member -MemberType NoteProperty -Name index -Value $null

# Create the empty host array:
$global:hostArray = @()

# Template object for the HA group array:
$global:haTemplate = New-Object psobject
$global:haTemplate | Add-Member -MemberType NoteProperty -Name entity -Value $null
$global:haTemplate | Add-Member -MemberType NoteProperty -Name partition -Value -1
$global:haTemplate | Add-Member -MemberType NoteProperty -Name primary -Value $null
$global:haTemplate | Add-Member -MemberType NoteProperty -Name docs -Value 0
$global:haTemplate | Add-Member -MemberType NoteProperty -Name components -Value 0
$global:haTemplate | Add-Member -MemberType NoteProperty -Name componentsOk -Value 0

# Create the empty HA group array:
$global:haArray = @()

# Template object for the component/server table:
$global:compTemplate = New-Object psobject
$global:compTemplate | Add-Member -MemberType NoteProperty -Name Component -Value $null
$global:compTemplate | Add-Member -MemberType NoteProperty -Name Server -Value $null
$global:compTemplate | Add-Member -MemberType NoteProperty -Name Partition -Value $null
$global:compTemplate | Add-Member -MemberType NoteProperty -Name State -Value $null

# Create the empty component/server table:
$global:compArray = @()

# Get the SSA object and print SSA name:
$global:ssa.Name

# Get basic topology info and component health status
GetTopologyInfo

#---added by bspender------------------------
#VerifyRunningProcesses
#VerifyApplicationServerSyncJobsEnabled


# Traverse list of components, determine properties and update $global:hostArray / $global:haArray
foreach ($searchComp in ($global:topologyCompList))
{
    PopulateHostHaList($searchComp)
}

# Analyze the component status:
foreach ($component in ($global:componentStateList))
{
    SearchComponentStatus($component)
}

# Look for selected info from detailed indexer diagnostics:
DetailedIndexerDiag

# Output list of components with state OK:
if ($global:compArray)
{
    $global:compArray | Sort-Object -Property Component | Format-Table -AutoSize
}
Write-Output ""

# Verify HA status for topology and index size limits:
VerifyHaLimits

# Verify that Host Controller HA (for dictionary repository) is OK:
VerifyHostControllerRepository

# Output components by server (for servers with multiple search components):
if ($global:haTopology -and ($global:searchHosts -gt 2))
{
    $componentsByServer = $false
    foreach ($hostInfo in $global:hostArray)
    {
        if ([int] $hostInfo.components -gt 1)
        {
            $componentsByServer = $true
        }
    }
    if ($componentsByServer)
    {
        Write-Output "Servers with multiple search components:"
        foreach ($hostInfo in $global:hostArray)
        {
            if ([int] $hostInfo.components -gt 1)
            {
                Write-Output "    $($hostInfo.hostName): $($hostInfo.pAdmin)$($hostInfo.sAdmin)$($hostInfo.index)$($hostInfo.qpc)$($hostInfo.cpc)$($hostInfo.apc)$($hostInfo.crawler)"
            }
        }
        Write-Output ""
    }
}

# Analytics Processing Job Status:
AnalyticsStatus

if ($global:masterMerge)
{
    Write-Output "Index Master Merge (de-fragment index files) in progress on one or more index components."
}

if ($global:serviceFailed -eq $false)
{
    Write-Output "Searchable items: $global:indexedDocs"
}

GetCrawlStatus
Write-Output ""
    
if ($global:unknownComponents)
{
    Write-Output "The following components are not reachable:"
    foreach ($uc in ($global:unknownComponents))
    {
        Write-Output "    $uc"
    }
    Write-Output "Recommended action: Restart or replace the associated server(s)"
    Write-Output ""
}

if ($global:degradedComponents)
{
    Write-Output "The following components are degraded:"
    foreach ($dc in ($global:degradedComponents))
    {
        Write-Output "    $dc"
    }
    Write-Output "Recommended action for degraded components:"
    Write-Output "    Component registering or resolving:"
    Write-Output "        This is normally a transient state during component restart or re-configuration. Re-run the script."

    if ($global:indexLeftBehind)
    {
        Write-Output "    Index component left behind:"
        if ($global:generationDifference)
        {
            Write-Output "        This is normal after adding an index component or index component/server recovery."
            Write-Output "        Indicates that the replica is being updated from the primary replica."
        }
        else
        {
            Write-Output "        Index replicas listed as degraded but index generation is OK."
            Write-Output "        Will get out of degraded state as soon as new/changed items are being idexed."
        }
    }
    Write-Output ""
}

if ($global:failedComponents)
{
    Write-Output "The following components are reported in error:"
    foreach ($fc in ($global:failedComponents))
    {
        Write-Output "    $fc"
    }
    Write-Output "Recommended action: Restart the associated server(s)"
    Write-Output ""
}

if ($global:serviceFailed)
{
    Write-OutPut -BackgroundColor Red -ForegroundColor Black "Search service overall state: Failed (no queries served)"
}
elseif ($global:serviceDegraded)
{
    Write-OutPut "Search service overall state: Degraded"
}
else
{
    Write-OutPut "Search service overall state: OK"
}
Write-Output ""
}
#################################################################################################################

#-----------------------------------------------
#  Check SP Version
#-----------------------------------------------

function GetSPVersion()
{
    If($farm.BuildVersion.Major -eq 16 -or $farm.BuildVersion.Major -eq 15)
    {
        if($farm.BuildVersion.Major -eq 16)
        {
            if($farm.BuildVersion.Build -gt 10000)
            {
                $is2016 = $true
                $outputfile = $outputfilePrefix + "2019_" + $timestamp +".txt"
                Write-Output ""
                Write-Output "We will collect some SharePoint and Search Info and write the output to $outputfile"
                Write-Output ""
            }
            else
            {
                $is2016 = $true
                $outputfile = $outputfilePrefix + "2016_" + $timestamp +".txt"
                Write-Output ""
                Write-Output "We will collect some SharePoint and Search Info and write the output to $outputfile"
                Write-Output ""
            }
        }
        else
        {
            $is2013 = $true
            $outputfile = $outputfilePrefix + "2013_" + $timestamp +".txt"
            Write-Output ""
            Write-Output "We will collect some SharePoint and Search Info and write the output to $outputfile"
            Write-Output ""
        }

        GetSSA
        GetFarmBuild | Out-File $outputfile -Append
        "" | Out-File $outputfile  -Append
        Get-Date | Out-File $outputfile -Append
        GetServersInFarm |  ft -auto | Out-File $outputfile -Append
        GetServiceInstances | Out-File $outputfile -Append
        GetServiceApplications | Out-File $outputfile -Append
        CheckTimerServiceInstances | Out-File $outputfile -Append
        CheckAdminServiceInstance | Out-File $outputfile -Append
        CheckTimerJobHistory | Out-File $outputfile -Append
        CheckFarmSiteSubscriptions | Out-File $outputfile -Append
        checkIfPartitioned | Out-File $outputfile -Append
        GetSSARelatedTimerJobs | Out-File $outputfile -Append
        GetSSAFullObject | Out-File $outputfile -Append
        GetSSALegacyAdminComponent | Out-File $outputfile -Append
        CheckCpcFromMssConfiguration |  Out-File $outputfile -Append
        GetSearchTopo | Out-File $outputfile -Append
        GetContentSources | Out-File $outputfile -Append
        GetServerNameMappings | Out-File $outputfile -Append
        GetCrawlRules | fl | Out-File $outputfile -Append
        displayGlobalSearchService | Out-File $outputfile -Append
        GetSSIs | Out-File $outputfile -Append
        GetSQSS | Out-File $outputfile -Append
        VerifyServiceEndpoints | Out-File $outputfile -Append
        GetAAMs | Out-File $outputfile -Append
        VerifyApplicationServerSyncJobsEnabled | Out-File $outputfile -Append
        HealthCheck | Out-File $outputfile -Append
        ""
        Write-Host("The script is complete. Please send the file, $outputfile, to Microsoft support") -ForegroundColor Green

    }
    elseIf($farm.BuildVersion.Major -eq 14)
    {
        Write-Warning "The support for SharePoint 2010 has ended, please update this farm to a newer version of SharePoint.. Aborting Script"
        exit
    }
    else
    {
        Write-Warning "Unsupported Version of SP... Aborting script"
        exit
    }
}

function NoSSA()
{
    GetFarmBuild | Out-File $outputfile -Append
    "" | Out-File $outputfile  -Append
    Get-Date | Out-File $outputfile -Append
    GetServersInFarm |  ft -auto | Out-File $outputfile -Append
    GetServiceInstances | Out-File $outputfile -Append
    GetServiceApplications | Out-File $outputfile -Append
    CheckTimerServiceInstances | Out-File $outputfile -Append
    CheckAdminServiceInstance | Out-File $outputfile -Append
    CheckTimerJobHistory | Out-File $outputfile -Append
    #GetSSIs | Out-File $outputfile -Append
    GetAAMs | Out-File $outputfile -Append
    exit
}

GetSPVersion