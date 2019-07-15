# --
# This script will add an index replica to an existing index partition. You add an index replica to the search topology to achieve fault tolerance for an existing index partition. 
# This can also add an index partition if the value of parameter "IndexPartition" is different. 
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
$HostName = (Get-ChildItem env:computername).value
$HostName2 = "Search-2"
$SearchServiceApplicationName = "Search" 
$IndexLocation = "C:\SearchIndex-1”

#
# Start remote search service instance
#
# Write-host "Start remote search service instances...." -ForegroundColor Green
# Start-SPEnterpriseSearchServiceInstance $HostName -ErrorAction SilentlyContinue 
# Start-SPEnterpriseSearchServiceInstance $HostName2 -ErrorAction SilentlyContinue 

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

#
# "Index partition number" is the number of the existing index partition that you are creating a replica of. For example, to create an index replica of index partition 0, choose "0" as the parameter value, if "0" doesn't exist then it'll create a new index partition. 
#
Remove-Item -Recurse -Force -LiteralPath $IndexLocation -ErrorAction SilentlyContinue 
mkdir -Path $IndexLocation -Force
New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $HostName -IndexPartition 1 -RootDirectory $IndexLocation
New-SPEnterpriseSearchIndexComponent -SearchTopology $clone -SearchServiceInstance $HostName2 -IndexPartition 1 -RootDirectory $IndexLocation # Don't forget to check "IndexLocation" from target server

Set-SPEnterpriseSearchTopology -Identity $clone

# Verify that your new topology is active and that the index component representing the new index replica is added. At the Windows PowerShell command prompt, type the following command(s):
Get-SPEnterpriseSearchTopology -Active -SearchApplication $SearchServiceApplication

# Monitor the distribution of the existing index to the new replica. The added index replica will have the state Degraded until the distribution is finished. At the Windows PowerShell command prompt, type the following command(s). Repeat this command until all search components, including the new index component, output the state Active. For a large search index, this could take several hours.
Get-SPEnterpriseSearchStatus -SearchApplication $SearchServiceApplication -Text 
