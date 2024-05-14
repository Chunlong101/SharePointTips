# Pls replace the tenantId, clientId, clientSecret and reportPath with your own values, this script will update the SharePoint site URL in the SharePoint site usage detail report, the updated report will be saved as a new file with "_Updated" appended to the original file name, e.g. SharePointSiteUsageDetail5_14_2024 6_41_34 AM_Updated.csv, this script can be run in PowerShell
$tenantId = 'xxx'
$clientId = 'xxx'
$clientSecret = 'xxx'
$reportPath = 'C:\Users\chunlonl\Downloads\SharePointSiteUsageDetail5_14_2024 6_41_34 AM.csv'

function Get-AccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$tenantId,
        [Parameter(Mandatory = $true)]
        [string]$clientId,
        [Parameter(Mandatory = $true)]
        [string]$clientSecret,
        [Parameter(Mandatory = $false)]
        [string]$scope = "https://graph.microsoft.com/.default"
    )

    $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $tokenRequest = @{
        client_id     = $clientId
        scope         = $scope
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }

    $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $tokenRequest
    return $tokenResponse.access_token
}

$cache = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'

Write-Host "Getting information for all the sites..." -ForegroundColor Cyan

$uri = "https://graph.microsoft.com/v1.0/sites/getAllSites?`$select=sharepointIds&`$top=10000"
while ($uri -ne $null) {

    Write-Host $uri

    $isSuccess = $false
    while (-not $isSuccess) {
        try {
            $accessToken = Get-AccessToken -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret
            $restParams = @{Headers = @{Authorization = "Bearer $accessToken" } }
        }
        catch {
            Write-Host "Retrying...  $($_.Exception.Message)" -ForegroundColor Yellow
            continue
        }
        try {
            $sites = Invoke-RestMethod $uri @restParams
            $isSuccess = $true
        }
        catch {
            if ($_.Exception.Response -and $_.Exception.Response.Headers['Retry-After']) {
                $retryAfter = [int]$_.Exception.Response.Headers['Retry-After']
                Write-Output "Waiting for $retryAfter seconds before retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds $retryAfter
            }
            Write-Host "Retrying...  $($_.Exception.Message)" -ForegroundColor Yellow
            continue
        }
    }

    $sites.value | ForEach-Object {
        $cache[$_.sharepointIds.siteId] = $_.sharepointIds.siteUrl
    }

    $uri = $sites."@odata.nextLink"

    Write-Host "Total sites received: $($cache.Count)"
}

Write-Host
Write-Host "Updating report $($reportPath) ..." -ForegroundColor Cyan
  
$outputPath = $reportPath -replace "\.csv$", "_Updated.csv"
$writer = [System.IO.StreamWriter]::new($outputPath)
$reader = [System.IO.StreamReader]::new($reportPath)
$rowCount = 0
  
while ($null -ne ($line = $reader.ReadLine())) {
    $rowCount++
  
    $columns = $line.Split(",")
    $siteId = $columns[1]
  
    $_guid = New-Object System.Guid
    if ([System.Guid]::TryParse($siteId, [ref]$_guid)) {
        $siteUrl = $cache[$siteId]
        $columns[2] = $siteUrl
        $line = $columns -join ","
    }
        
    $writer.WriteLine($line)
  
    if ($rowCount % 1000 -eq 0) {
        Write-Host "Processed $($rowCount) rows"
    }
}
$writer.Close()
$reader.Close()
  
Write-Host "Processed $($rowCount) rows"
Write-Host "Report updated: $($outputPath)" -ForegroundColor Cyan