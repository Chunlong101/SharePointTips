<#
Test Script: TestGetSiteOwnerInfoFunctions.ps1
Purpose:
  Exercise each reusable function from GetSiteOwnerInfo.ps1 with provided parameters.

Parameters Under Test:
  $ClientId  = "efec52de-b554-40e0-8596-27a895cb4589"
  $Thumbprint = "xxx"
  $SiteUrl  = "https://5xxsz0.sharepoint.com/sites/TestM365Group"
  $Tenant   = "5xxsz0.onmicrosoft.com"
  $CvsPath  = ".\SiteOwnersReport.csv"

Prerequisites:
  - PnP.PowerShell module installed
  - App registration + certificate with appropriate SPO/Graph permissions
  - Run in PowerShell 7+ (recommended) with network access

Usage:
  PS> .\TestGetSiteOwnerInfoFunctions.ps1
  (Adjust execution policy if needed: Set-ExecutionPolicy -Scope Process RemoteSigned)

Notes:
  - The test for Get-SPOOwnerInfoForAllSites is commented out by default (potentially large / slow).
  - CSV output is appended; delete the file first if you need a clean run.
  - Verbose output enabled for deeper inspection.
#>

# Test Parameters (as requested)
$ClientId  = "efec52de-b554-40e0-8596-27a895cb4589"
$Thumbprint = "xxx"
$SiteUrl  = "https://5xxsz0.sharepoint.com/sites/TestM365Group"
$Tenant   = "5xxsz0.onmicrosoft.com"
$CvsPath  = ".\SiteOwnersReport.csv"

# Increase verbosity for the test
$VerbosePreference = "Continue"

# Dot-source main script to load functions
$mainScript = Join-Path $PSScriptRoot "GetSiteOwnerInfo.ps1"
if (-not (Test-Path $mainScript)) {
    Write-Error "Cannot find GetSiteOwnerInfo.ps1 at $mainScript"
    return
}
. $mainScript

Write-Host "============================================================"
Write-Host "1. Test Get-SPOOwnerInfo (end-to-end single site pipeline)"
Write-Host "============================================================"
try {
    $record = Get-SPOOwnerInfo -SiteUrl $SiteUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint
    Write-Host "[OK] Retrieved single site record."
    $record | Format-List
} catch {
    Write-Error "Get-SPOOwnerInfo failed: $($_.Exception.Message)"
}

Write-Host "`n============================================================"
Write-Host "2. Test Export-SPOOwnerInfoCsv (append record to CSV)"
Write-Host "============================================================"
try {
    Export-SPOOwnerInfoCsv -Record $record -Path $CvsPath
    Write-Host "[OK] Record appended to $CvsPath"
} catch {
    Write-Error "Export-SPOOwnerInfoCsv failed: $($_.Exception.Message)"
}

Write-Host "`n============================================================"
Write-Host "3. Test granular building blocks"
Write-Host "   (Connect-SPOWithCert, Get-SPOBasicSiteMetadata,"
Write-Host "    Get-SPOAssociatedGroupMembers, Get-SPOM365GroupInfo,"
Write-Host "    New-SPOOwnerInfoRecord)"
Write-Host "============================================================"
try {
    Connect-SPOWithCert -Url $SiteUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint
    Write-Host "[OK] Connected to site."

    $basic = Get-SPOBasicSiteMetadata -SiteUrl $SiteUrl
    Write-Host "[OK] Basic metadata:"
    $basic | Format-List

    $assoc = Get-SPOAssociatedGroupMembers -SiteUrl $SiteUrl
    Write-Host "[OK] Associated group members counts:"
    [pscustomobject]@{
        Admins   = $assoc.SiteAdminsEmails.Count
        Owners   = $assoc.SiteOwnersEmails.Count
        Members  = $assoc.SiteMembersEmails.Count
        Visitors = $assoc.SiteVisitorsEmails.Count
    } | Format-Table -AutoSize

    $groupInfo = Get-SPOM365GroupInfo -GroupIdString $basic.GroupId
    Write-Host "[OK] M365 group info:"
    $groupInfo | Format-List

    $rebuilt = New-SPOOwnerInfoRecord -BasicMeta $basic -AssociatedGroups $assoc -GroupInfo $groupInfo
    Write-Host "[OK] Rebuilt final record (should match initial record fields):"
    $rebuilt | Format-List
} catch {
    Write-Error "Granular test failed: $($_.Exception.Message)"
}

Write-Host "`n============================================================"
Write-Host "4. Optional: Test Get-SPOOwnerInfoForAllSites (COMMENTED OUT)"
Write-Host "   WARNING: Enumerates all tenant sites and appends to CSV."
Write-Host "   Uncomment the following lines to run."
Write-Host "============================================================"
<#
try {
    Get-SPOOwnerInfoForAllSites -Tenant $Tenant -ClientId $ClientId -Thumbprint $Thumbprint -CvsPath $CvsPath
    Write-Host "[OK] All sites processed."
} catch {
    Write-Error "Get-SPOOwnerInfoForAllSites failed: $($_.Exception.Message)"
}
#>

Write-Host "`n============================================================"
Write-Host "5. Optional: Test Get-SPOM365GroupOwnersExpanded (Only if Group connected)"
Write-Host "============================================================"
try {
    if ($basic -and $basic.GroupId -and $basic.GroupId -ne "00000000-0000-0000-0000-000000000000") {
        $ownersExpanded = Get-SPOM365GroupOwnersExpanded -GroupId $basic.GroupId -ThrottleMs 0
        if ($ownersExpanded) {
            Write-Host "[OK] Expanded M365 Group owners:"
            $ownersExpanded | Select-Object DisplayName,Email,JobTitle,UPN | Format-Table -AutoSize
        } else {
            Write-Host "[INFO] No expanded owners returned."
        }
    } else {
        Write-Host "[INFO] Site not connected to an M365 Group or GroupId empty."
    }
} catch {
    Write-Warning "Get-SPOM365GroupOwnersExpanded test failed: $($_.Exception.Message)"
}

Write-Host "`n============================================================"
Write-Host "Test Execution Completed."
Write-Host "CSV Path: $CvsPath"
Write-Host "============================================================"
