function CalculateSiteLibrarySize {
    param (
        $siteUrl, 
        $libraryName, 
        $reportPath
    )
    Connect-PnPOnline -Url $siteUrl -UseWebLogin
    $files = $null
    
    try {
        # There's gonna be an error if target library doesn't exist in current site 
        $files = Get-PnPListItem -List $libraryName -Fields "FileLeafRef", "FileSize" -PageSize 1000
    }
    catch {
        return
    }
    
    $results = @()

    foreach ($file in $files) {
        $fileUrl = $file.FieldValues.FileRef
        $file = Get-PnPFile -Url $fileUrl -AsListItem
    
        $fileSize = $null

        if ($null -ne $file) {
            $fileSize = $file["File_x0020_Size"]
        }

        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)

        $results += [pscustomobject]@{
            "Url"       = "https://" + $siteUrl.Split('/')[2] + $fileUrl
            "Size (MB)" = $fileSizeMB
        }
    }

    $results | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8 -Delimiter ',' -Append
}

function CalculateTenantLevelLibrarySize {
    param (
        $tenantUrl, 
        $libraryName, 
        $reportPath
    )
    Connect-PnPOnline -Url $("https://" + $tenantUrl.Split('/')[2].Split('.')[0] + "-admin.sharepoint.com") -UseWebLogin
    $sites = Get-PnPTenantSite 

    foreach ($site in $sites) {
        CalculateSiteLibrarySize $site.Url $libraryName $reportPath
    }
}

$siteUrl = "https://xxx.sharepoint.com/sites/xxx"
$libraryName = "Documents"
$reportPath = "File_Sizes.csv"

CalculateSiteLibrarySize $siteUrl $libraryName $reportPath

$tenantUrl = "https://xxx.sharepoint.com"

CalculateTenantLevelLibrarySize $tenantUrl $libraryName $reportPath