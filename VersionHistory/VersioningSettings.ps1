# This script enables you to configure versioning settings for SharePoint libraries in bulk, including the ability to set limits for major and minor versions, among other options. Pls just replace the parameters like $TenantName...$MinorVersionLimit with yours. 

# Initialize parameters
$TenantName = "xxx"
$MajorVersions = $true
$MinorVersions = $false
$NoVersioning = $false
$MajorVersionLimit = 100
$MinorVersionLimit = 10

# Connect to SharePoint Online, only connect once to get all site collections
Write-Host -ForegroundColor Cyan "Connecting to SharePoint Online..."
Connect-PnPOnline -Url $("https://$TenantName.sharepoint.com") -Interactive
Write-Host -ForegroundColor Cyan "Connected to SharePoint Online."

# Get all site collections
$Sites = Get-PnPTenantSite # -Filter "Url -like 'https://$TenantName.sharepoint.com/sites/xxx'"

# Define excluded system libraries
$SystemLibraries = @("Form Templates", "Pages", "Preservation Hold Library", "Site Assets", "Site Pages", "Images", "Site Collection Documents", "Site Collection Images", "Style Library")

# Loop through the site collections
foreach ($Site in $Sites) {
    Write-Host -ForegroundColor Cyan "Processing site: $($Site.URL)"
    try {
        # Connect to the current site
        Write-Host -ForegroundColor Cyan "Connecting to site: $($Site.URL)..."
        Connect-PnPOnline -Url $Site.URL -UseWebLogin # UseWebLogin avoids manual login every time
        Write-Host -ForegroundColor Cyan "Connected to site: $($Site.URL)."

        # Retrieve all document libraries
        Write-Host -ForegroundColor Cyan "Retrieving document libraries from site: $($Site.URL)..."
        $DocumentLibraries = Get-PnPList -Includes BaseType, Hidden, EnableVersioning | Where-Object {
            $_.BaseType -eq "DocumentLibrary" -and
            -not $_.Hidden -and
            $_.Title -notin $SystemLibraries
        }

        # Set version history limits
        foreach ($Library in $DocumentLibraries) {
            Write-Host -ForegroundColor Cyan "Updating version history settings for library: '$($Library.Title)'"
            if ($Library.EnableVersioning) {
                if ($NoVersioning) {
                    Set-PnPList -Identity $Library -EnableVersioning $false | Out-Null
                }
                elseif ($MajorVersions -and !$MinorVersions) {
                    Set-PnPList -Identity $Library -EnableVersioning $true -MajorVersions $MajorVersionLimit -EnableMinorVersions $false | Out-Null
                }
                elseif ($MinorVersions -and !$MajorVersions) {
                    Set-PnPList -Identity $Library -EnableVersioning $true -EnableMinorVersions $true -MinorVersions $MinorVersionLimit | Out-Null
                } 
                elseif ($MajorVersions -and $MinorVersions) {
                    Set-PnPList -Identity $Library -EnableVersioning $true -EnableMinorVersions $true -MajorVersions $MajorVersionLimit -MinorVersions $MinorVersionLimit | Out-Null # https://pnp.github.io/powershell/cmdlets/Set-PnPList.html#example-5
                }
                Write-Host -ForegroundColor Green "Version History Settings have been updated on '$($Library.Title)' of $($Site.URL)"
            }
            else {
                Write-Host -ForegroundColor Yellow "Version History is turned off at '$($Library.Title)'"
            }
        }
    }
    catch {
        Write-Host -ForegroundColor Red "Error in site '$($Site.URL)': $_"
    }
}

Write-Host -ForegroundColor Cyan "Script execution completed."
