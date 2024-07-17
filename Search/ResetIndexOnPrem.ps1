Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue

# ----- 
# Fully reset index for the SSA
# ----- 
(Get-SPEnterpriseSearchServiceApplication).reset($true, $true)

# ----- 
# Partially reset index for a specific content source in SharePoint onprem
# ----- 
$ssa = Get-SPEnterpriseSearchServiceApplication
$ContentSourceName = "xxx"
$ContentSource = Get-SPEnterpriseSearchCrawlContentSource -Identity $ContentSourceName -SearchApplication $SSA
$StartAddresses = $ContentSource.StartAddresses | ForEach-Object { $_.OriginalString } 
$ContentSource.StartAddresses.Clear()
ForEach ($Address in $StartAddresses ){ $ContentSource.StartAddresses.Add($Address) }

# ----- 
# Reset index for a site
# ----- 
 $SiteURL="http://allinone/sites/test"
 
#Iterate through each web in the site collection
Get-SPSite $SiteURL | Get-SPWeb -Limit All | ForEach-Object {
         
    [Int] $SearchVersion = 0
 
    #Get the existing search version number
    If($_.AllProperties.ContainsKey("vti_searchversion") -eq $True)
    {
        $SearchVersion = $_.AllProperties["vti_searchversion"]
    }
 
    #Increment Search version
    $SearchVersion++
  
    #Update the Search version number
    $_.AllProperties["vti_searchversion"] = $SearchVersion
    $_.Update()
 
    Write-host -f Green "Search Version has been increased to $SearchVersion on $($_.URL)"
}