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
$HostName = (Get-ChildItem env:computername).value
$SearchServiceApplicationName = "Search" 
$IndexLocation = "C:\SearchIndexReplica-0”

#
# Start remote search service instance
#
Write-host "Start remote search service instances...." -ForegroundColor Green
Start-SPEnterpriseSearchServiceInstance $HostName -ErrorAction SilentlyContinue 

#
# Check SSA
#
Write-Host -ForegroundColor Yellow "Checking if Search Service Application exists" 
$SearchServiceApplication = Get-SPEnterpriseSearchServiceApplication -Identity $SearchServiceName -ErrorAction SilentlyContinue

if (!$SearchServiceApplication) 
{ 
    Write-Host -ForegroundColor Red "There's no SSA available~" 
    return
}

#
# Clone the default Topology (which is empty at the first begining) and create a new one then activate it 
#
Write-Host "Configuring Search Component Topology...." 
$clone = $SearchServiceApplication.ActiveTopology.Clone() 

$clone.GetComponents() | select -property name,servername

$t = $clone.GetComponents() | select -index 0 # Select the one you want to delete

$clone.RemoveComponent($t)

Set-SPEnterpriseSearchTopology -Identity $clone

