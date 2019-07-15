# --
# This script will create a search service application with different customized topology
# --

$ErrorActionPreference = "Stop" # http://technet.microsoft.com/en-us/library/dd347731.aspx

trap 
{
    Write-Host "Sorry, something went wrong~" -ForegroundColor Red
}

$ver = $host | select version
if ($ver.Version.Major -gt 1) {$Host.Runspace.ThreadOptions = "ReuseThread"}
Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

#
# Settings 
#
$IndexLocation = "C:\SearchIndex” #Location must be empty, will be deleted during the process! 
$SearchServiceApplicationPoolName = "Search Pool" 
$SearchServiceApplicationPoolAccountName = "China\Chunlong" 
$SearchServerName = (Get-ChildItem env:computername).value 
$SearchServiceApplicationName = "Search" 
$SearchServiceApplicationProxyName = "Search Proxy" 
$DatabaseName = "Search" 
$ComputerName1 = "Search-1"
$ComputerName2 = "Search-2"
$ComputerName3 = "Search-3"
$ComputerName4 = "Search-4"

#
# Check application pool
#
Write-Host -ForegroundColor Yellow "Checking if Search Application Pool exists" 
$AppPool = Get-SPServiceApplicationPool -Identity $SearchServiceApplicationPoolName -ErrorAction SilentlyContinue
if (!$AppPool) 
{ 
    Write-Host -ForegroundColor Green "Creating Search Application Pool" 
    $AppPool = New-SPServiceApplicationPool -Name $SearchServiceApplicationPoolName -Account $SearchServiceApplicationPoolAccountName -Verbose 
}

#
# Start local search service instance 
#
Write-host "Start local search service instances...." -ForegroundColor Green
Start-SPEnterpriseSearchServiceInstance $SearchServerName -ErrorAction SilentlyContinue 
Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $SearchServerName -ErrorAction SilentlyContinue

#
# Start remote search service instance
#
Write-host "Start remote search service instances...." -ForegroundColor Green
Start-SPEnterpriseSearchServiceInstance $ComputerName2 -ErrorAction SilentlyContinue 
Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $ComputerName2 -ErrorAction SilentlyContinue
Start-SPEnterpriseSearchServiceInstance $ComputerName3 -ErrorAction SilentlyContinue 
Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $ComputerName3 -ErrorAction SilentlyContinue
Start-SPEnterpriseSearchServiceInstance $ComputerName4 -ErrorAction SilentlyContinue 
Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $ComputerName4 -ErrorAction SilentlyContinue

#
# Check SSA
#
Write-Host -ForegroundColor Yellow "Checking if Search Service Application exists" 
$SearchServiceApplication = Get-SPEnterpriseSearchServiceApplication -Identity $SearchServiceApplicationName -ErrorAction SilentlyContinue
if (!$SearchServiceApplication) 
{ 
    Write-Host -ForegroundColor Green "Creating Search Service Application" 
    $SearchServiceApplication = New-SPEnterpriseSearchServiceApplication -Name $SearchServiceApplicationName -ApplicationPool $AppPool.Name  -DatabaseName $DatabaseName
}

#
# Check application proxy
#
Write-Host -ForegroundColor Yellow "Checking if Search Service Application Proxy exists" 
$Proxy = Get-SPEnterpriseSearchServiceApplicationProxy -Identity $SearchServiceApplicationProxyName -ErrorAction SilentlyContinue
if (!$Proxy) 
{ 
    Write-Host -ForegroundColor Green "Creating Search Service Application Proxy" 
    New-SPEnterpriseSearchServiceApplicationProxy -Partitioned -Name $SearchServiceApplicationProxyName -SearchApplication $SearchServiceApplication 
}
$SearchServiceApplication.ActiveTopology 

# --- 
# We can also create SSA using CA first then set up the components using below
# ---

#
# Clone the default Topology (which is empty at the first begining) and create a new one then activate it 
#
Write-Host "Configuring Search Component Topology...." -ForegroundColor Yellow
$clone = $SearchServiceApplication.ActiveTopology.Clone() 
Remove-Item -Recurse -Force -LiteralPath $IndexLocation -ErrorAction SilentlyContinue 
mkdir -Path $IndexLocation -Force

#
# Search server 1: Query + Index
#
New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $clone -SearchServiceInstance $ComputerName1
New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $ComputerName1 -RootDirectory $IndexLocation

#
# Search server 2: Query + Index
#
New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $clone -SearchServiceInstance $ComputerName2
New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $ComputerName2 -RootDirectory $IndexLocation

#
# Search server 3: Crawl + CPC + Admin + APC
#
New-SPEnterpriseSearchCrawlComponent -SearchTopology $clone -SearchServiceInstance $ComputerName3
New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $clone -SearchServiceInstance $ComputerName3
New-SPEnterpriseSearchAdminComponent -SearchTopology $clone -SearchServiceInstance $ComputerName3
New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $clone -SearchServiceInstance $ComputerName3

#
# Search server 4: Crawl + CPC + Admin + APC
#
New-SPEnterpriseSearchCrawlComponent -SearchTopology $clone -SearchServiceInstance $ComputerName4
New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $clone -SearchServiceInstance $ComputerName4
New-SPEnterpriseSearchAdminComponent -SearchTopology $clone -SearchServiceInstance $ComputerName4
New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $clone -SearchServiceInstance $ComputerName4
$clone.GetComponents()

#
# Activate search topology clone
#
Write-Host "Activating search topology clone..." -ForegroundColor Green
$clone.Activate()
Write-host "Your search service application $SearchServiceApplicationName is now ready" -ForegroundColor Green