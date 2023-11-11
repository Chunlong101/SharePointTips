# ----- 
# How to fix PUID mismatch issue? 
# Option #1 - If you already know which site has the PUID mismatch issue then pls use self-diagnosis tool to fix it, see steps here: 
# https://learn.microsoft.com/en-us/sharepoint/troubleshoot/sharing-and-permissions/fix-site-user-id-mismatch, 
# this option will not lose existing permissions for the user. 
# Option #2 - Or we can directly remove the user from userinfo list, see steps here: 
# https://learn.microsoft.com/en-us/sharepoint/remove-users#remove-people-from-the-userinfo-list, 
# but this option will remove all permissions for the user. 
# Option #3 - This script is for the scenario where you want to find out all the sites that have the PUID issue and fix them from the backend
# ----- 

$upn = "xxx"
$tenantUrl = "https://xxx.sharepoint.com"

Get-Module Merlin -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 | Import-Module -DisableNameChecking

.\ctsinfo.ps1 $tenantUrl

# Get the list of content databases for the customer
$dbName = (Get-GridTenantDB -Identity $ctsinfo_tenantID -Role DedicatedContent).Name

# Find PUID mismtaches for a given UPN on a specific database using Compare-TenantUserData, Compare-TenantUserData no longer logs test results that pass to the screen. The data is still available in the DataAnalysis object. However, the information is PIIed and we cannot see the impact site url
$compareTenantUserData = @()
$dbName | % { $compareTenantUserData += Compare-TenantUserData -Tenant $ctsinfo_tenantID -UserPrincipalName $upn -Database $_ -CaseId 12345678 }
$dataAnalysisResults = $compareTenantUserData | % { $_.DataAnalysis.Results | ? { $_.Summary -match 'Detected a potential PUIDMismatch between SPODS and Sit' } } 

# For each PUID Mismatch found, you will see something similar to the following (once for each site where a PUID mismatch is found)
<#
>>-------------------------------------------------------->
ID:            xxx
Name:           Test Sites Puidmismatch
Description:    User account PUID in site collection matches PUID in SPODS
Documentation: http:\\aka.ms\xxxxxxxx
TestRun:        True
Status:         Fail
Severity:       Error
Category:       UserProfile
Summary:       
Content Database: [DedicatedContent_xxx]
Detected a potential PUIDMismatch between SPODS and SiteID: [xxx] SiteUrl: https://xxx.sharepoint.com/xxx]
Remedy:       
GridJobResults: Get-GridJobResult xxx
>>-------------------------------------------------------->
#>

# Get the impacted site url from the data analysis result
$urlList = @()
foreach ($dataAnalysisResult in $dataAnalysisResults) {
    # $dataAnalysisResult.Summary may contains a url like https://xxx.sharepoint.com/xxx, we need to extract the url with regex
    $m = [regex]::Match($dataAnalysisResult.Summary, "https://(.*)")
    $urlList += $m.Groups[1].Value
}

# Update the PUID for each site
$count = 0
foreach ($site in $urlList) {
    $count++
    Write-Host "$count/$($urlList.Count)..."
    # Update-TenantUserPuidForSite -Tenant $ctsinfo_tenantID -Url $site -UserPrincipalName $upn -Fix # Doesn't work now because of the PII issue
}

# Update the PUID for a specific site
Update-TenantUserPuidForSite -Tenant $ctsinfo_tenantID -Url "https://xxx.sharepoint.com/personal/xxx" -UserPrincipalName "xxx" -Fix
# User UPN: [xxx] ID: tp_systemId (PUID) has been updated to [i:0h.f|membership|xxx@live.com] for site Id: [xxx]