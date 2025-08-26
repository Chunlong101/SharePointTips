<#
Script: GetSiteOwnerInfo.ps1
Purpose:
  Export SharePoint Online site ownership / membership related information
  (site admins, associated groups, M365 Group linkage, Teams linkage) into a CSV.

Reuse:
  Dot-source this file:
      . "$PSScriptRoot\GetSiteOwnerInfo.ps1"
  Then call for a single site e.g.:
      $rec = Get-SPOOwnerInfo -SiteUrl $SiteUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint
      Export-SPOOwnerInfoCsv -Record $rec -Path .\SiteOwnersReport.csv
  Or for all sites:
      Get-SPOOwnerInfoForAllSites -Tenant <tenant> -ClientId <id> -Thumbprint <thumb> -CvsPath .\AllSites.csv

Last Updated: 2025-08-24
#>

# NOTE: Deliberately not enabling Set-StrictMode to avoid breaking legacy calling scripts.
# If you want stricter runtime checks, uncomment the next line.
# Set-StrictMode -Version Latest

# -----------------------------
# Helper / Core Reusable Functions
# -----------------------------

function Connect-SPOWithCert {
    <#
    .SYNOPSIS
        Establishes a PnP Online connection using certificate authentication.
    .PARAMETER Url
        Target site or admin center URL.
    .PARAMETER ClientId
        Azure AD App (Client) ID.
    .PARAMETER Tenant
        Tenant name (e.g. contoso.onmicrosoft.com).
    .PARAMETER Thumbprint
        Certificate thumbprint in the local cert store.
    .NOTES
        Relies on Connect-PnPOnline being available (PnP.PowerShell module).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$Tenant,
        [Parameter(Mandatory)][string]$Thumbprint
    )
    Write-Verbose "[Connect-SPOWithCert] Connecting to $Url ..."
    Connect-PnPOnline -ClientId $ClientId -Url $Url -Tenant $Tenant -Thumbprint $Thumbprint
    Write-Verbose "[Connect-SPOWithCert] Connected to $Url."
}

function Get-SPOBasicSiteMetadata {
    <#
    .SYNOPSIS
        Retrieves basic tenant-level metadata for a site collection.
    .PARAMETER SiteUrl
        Absolute site collection URL.
    .OUTPUTS
        PSCustomObject with SiteUrl, OwnerEmail, GroupId (string), IsTeamsConnected.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SiteUrl
    )
    Write-Verbose "[Get-SPOBasicSiteMetadata] Retrieving metadata for $SiteUrl"
    $tenantSite = Get-PnPTenantSite -Identity $SiteUrl
    if (-not $tenantSite) {
        Write-Verbose "[Get-SPOBasicSiteMetadata] Site not found: $SiteUrl"
    }
    [pscustomobject]@{
        SiteUrl          = $SiteUrl
        OwnerEmail       = $tenantSite.OwnerEmail
        GroupId          = $tenantSite.GroupId.Guid   # string form used later for empty check
        IsTeamsConnected = $tenantSite.IsTeamsConnected
    }
}

function Get-SPOSiteMembership {
    <#
    .SYNOPSIS
        Retrieves membership-related emails for the 4 associated SharePoint groups + site collection admins.
    .DESCRIPTION
        - Gathers Site Collection Administrators (Get-PnPSiteCollectionAdmin).
        - Retrieves Owners, Members, Visitors associated groups and enumerates members.
        - Attempts to include any principal with Title including 'Everyone' (captures special auth constructs).
    .PARAMETER SiteUrl
        Site collection URL (used only for logging context; association calls operate on current connection).
    .OUTPUTS
        PSCustomObject with email arrays: SiteAdminsEmails, SiteOwnersEmails, SiteMembersEmails, SiteVisitorsEmails.
    .NOTES
        Caller must already be connected to the target site.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SiteUrl
    )

    Write-Verbose "[Get-SPOSiteMembership] Enumerating membership for $SiteUrl"

    # Site Collection Admins
    $siteAdminsEmails        = @()
    $siteAdminsDisplayNames  = @()
    $siteAdmins              = Get-PnPSiteCollectionAdmin
    if ($siteAdmins) {
        Write-Verbose "[Get-SPOSiteMembership] Found $($siteAdmins.Count) site collection admin entries."
    } else {
        Write-Verbose "[Get-SPOSiteMembership] No site collection admins returned."
    }
    $siteAdmins | Select-Object -ExpandProperty Email | ForEach-Object {
        if ($_.Trim() -ne "") { $siteAdminsEmails += $_.Trim() }
    }
    $everyoneAdmin = $siteAdmins | Where-Object { $_.Title -like "*Everyone*" }
    if ($everyoneAdmin) {
        Write-Verbose "[Get-SPOSiteMembership] Added 'Everyone*' principal(s) to SiteAdmins list."
        $siteAdminsEmails += $everyoneAdmin.Title
    }

    # Owners
    $siteOwnersEmails        = @()
    $siteOwnersDisplayNames  = @()
    $siteOwnersGroup  = Get-PnPGroup -AssociatedOwnerGroup
    Write-Verbose "[Get-SPOSiteMembership] Owners group: $($siteOwnersGroup.Title)"
    $siteOwners       = Get-PnPGroupMember -Group $siteOwnersGroup
    Write-Verbose "[Get-SPOSiteMembership] Owners group member count: $($siteOwners.Count)"
    $siteOwners | Select-Object -ExpandProperty Email | ForEach-Object {
        if ($_.Trim() -ne "") { $siteOwnersEmails += $_.Trim() }
    }
    $everyoneOwner = $siteOwners | Where-Object { $_.Title -like "*Everyone*" }
    if ($everyoneOwner) {
        Write-Verbose "[Get-SPOSiteMembership] Added 'Everyone*' principal(s) to Owners list."
        $siteOwnersEmails += $everyoneOwner.Title
    }

    # Members
    $siteMembersEmails        = @()
    $siteMembersDisplayNames  = @()
    $siteMembersGroup  = Get-PnPGroup -AssociatedMemberGroup
    Write-Verbose "[Get-SPOSiteMembership] Members group: $($siteMembersGroup.Title)"
    $siteMembers       = Get-PnPGroupMember -Group $siteMembersGroup
    Write-Verbose "[Get-SPOSiteMembership] Members group member count: $($siteMembers.Count)"
    $siteMembers | Select-Object -ExpandProperty Email | ForEach-Object {
        if ($_.Trim() -ne "") { $siteMembersEmails += $_.Trim() }
    }
    $everyoneMember = $siteMembers | Where-Object { $_.Title -like "*Everyone*" }
    if ($everyoneMember) {
        Write-Verbose "[Get-SPOSiteMembership] Added 'Everyone*' principal(s) to Members list."
        $siteMembersEmails += $everyoneMember.Title
    }

    # Visitors
    $siteVisitorsEmails        = @()
    $siteVisitorsDisplayNames  = @()
    $siteVisitorsGroup  = Get-PnPGroup -AssociatedVisitorGroup
    Write-Verbose "[Get-SPOSiteMembership] Visitors group: $($siteVisitorsGroup.Title)"
    $siteVisitors       = Get-PnPGroupMember -Group $siteVisitorsGroup
    Write-Verbose "[Get-SPOSiteMembership] Visitors group member count: $($siteVisitors.Count)"
    $siteVisitors | Select-Object -ExpandProperty Email | ForEach-Object {
        if ($_.Trim() -ne "") { $siteVisitorsEmails += $_.Trim() }
    }
    $everyoneVisitor = $siteVisitors | Where-Object { $_.Title -like "*Everyone*" }
    if ($everyoneVisitor) {
        Write-Verbose "[Get-SPOSiteMembership] Added 'Everyone*' principal(s) to Visitors list."
        $siteVisitorsEmails += $everyoneVisitor.Title
    }

    # Collect display names (Titles) for each principal list
    $siteAdmins  | ForEach-Object { if ($_.Title -and $_.Title.Trim() -ne "") { $siteAdminsDisplayNames   += $_.Title.Trim() } }
    $siteOwners  | ForEach-Object { if ($_.Title -and $_.Title.Trim() -ne "") { $siteOwnersDisplayNames   += $_.Title.Trim() } }
    $siteMembers | ForEach-Object { if ($_.Title -and $_.Title.Trim() -ne "") { $siteMembersDisplayNames  += $_.Title.Trim() } }
    $siteVisitors| ForEach-Object { if ($_.Title -and $_.Title.Trim() -ne "") { $siteVisitorsDisplayNames += $_.Title.Trim() } }

    [pscustomobject]@{
        SiteAdminsEmails        = $siteAdminsEmails
        SiteAdminsDisplayName   = $siteAdminsDisplayNames
        SiteOwnersEmails        = $siteOwnersEmails
        SiteOwnersDisplayName   = $siteOwnersDisplayNames
        SiteMembersEmails       = $siteMembersEmails
        SiteMembersDisplayName  = $siteMembersDisplayNames
        SiteVisitorsEmails      = $siteVisitorsEmails
        SiteVisitorsDisplayName = $siteVisitorsDisplayNames
    }
}

function Get-SPOM365GroupInfo {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 Group ownership/membership details based on associated GroupId.
    .PARAMETER GroupIdString
        The GUID string from site metadata; ignored if empty or all zeros.
    .OUTPUTS
        PSCustomObject with flags and email arrays.
    .NOTES
        Uses PnP cmdlets: Get-PnPMicrosoft365Group & Get-PnPMicrosoft365GroupMember.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$GroupIdString
    )
    $isM365GroupConnected      = $false
    $m365GroupDisplayName      = $null
    $m365GroupOwnersEmails     = @()
    $m365GroupOwnersDisplayName= @()
    $m365GroupMembersEmails    = @()
    $m365GroupMembersDisplayName = @()

    if ($GroupIdString -and $GroupIdString -ne "00000000-0000-0000-0000-000000000000") {
        Write-Verbose "[Get-SPOM365GroupInfo] Group detected ($GroupIdString). Retrieving owners and members..."
        $isM365GroupConnected = $true
        $m365Group = Get-PnPMicrosoft365Group -Identity $GroupIdString -IncludeOwners
        $m365GroupDisplayName = $m365Group.DisplayName
        Write-Verbose "[Get-SPOM365GroupInfo] Group display name: $m365GroupDisplayName"
        $m365Group.Owners | Select-Object -ExpandProperty Email | ForEach-Object {
            $m365GroupOwnersEmails += $_.Trim()
        }
        $m365Group.Owners | ForEach-Object {
            if ($_.DisplayName -and $_.DisplayName.Trim() -ne "") { $m365GroupOwnersDisplayName += $_.DisplayName.Trim() }
        }
        Write-Verbose "[Get-SPOM365GroupInfo] Owner count: $($m365GroupOwnersEmails.Count)"
        $m365GroupMembers = Get-PnPMicrosoft365GroupMember -Identity $GroupIdString
        $m365GroupMembers | Select-Object -ExpandProperty Email | ForEach-Object {
            $m365GroupMembersEmails += $_.Trim()
        }
        $m365GroupMembers | ForEach-Object {
            if ($_.DisplayName -and $_.DisplayName.Trim() -ne "") { $m365GroupMembersDisplayName += $_.DisplayName.Trim() }
        }
        Write-Verbose "[Get-SPOM365GroupInfo] Member count: $($m365GroupMembersEmails.Count)"
    } else {
        Write-Verbose "[Get-SPOM365GroupInfo] No connected M365 Group."
    }

    [pscustomobject]@{
        IsM365GroupConnected       = $isM365GroupConnected
        M365GroupDisplayName       = $m365GroupDisplayName
        M365GroupOwnersEmails      = $m365GroupOwnersEmails
        M365GroupOwnersDisplayName = $m365GroupOwnersDisplayName
        M365GroupMembersEmails     = $m365GroupMembersEmails
        M365GroupMembersDisplayName= $m365GroupMembersDisplayName
    }
}

function New-SPOOwnerInfoRecord {
    <#
    .SYNOPSIS
        Normalizes and merges site, membership and group info into a single flat record for CSV output.
    .PARAMETER BasicMeta
        Output object from Get-SPOBasicSiteMetadata.
    .PARAMETER AssociatedGroups
        Output object from Get-SPOSiteMembership.
    .PARAMETER GroupInfo
        Output object from Get-SPOM365GroupInfo.
    .OUTPUTS
        PSCustomObject ready for Export-Csv.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$BasicMeta,
        [Parameter(Mandatory)]$AssociatedGroups,
        [Parameter(Mandatory)]$GroupInfo
    )
    Write-Verbose "[New-SPOOwnerInfoRecord] Building output record for $($BasicMeta.SiteUrl)"
    [pscustomobject]@{
        SiteUrl                     = $BasicMeta.SiteUrl
        OwnerEmail                  = $BasicMeta.OwnerEmail
        IsM365GroupConnected        = $GroupInfo.IsM365GroupConnected
        M365GroupDisplayName        = $GroupInfo.M365GroupDisplayName
        M365GroupOwnersEmails       = $GroupInfo.M365GroupOwnersEmails -join "; "
        M365GroupOwnersDisplayName  = $GroupInfo.M365GroupOwnersDisplayName -join "; "
        M365GroupMembersEmails      = $GroupInfo.M365GroupMembersEmails -join "; "
        M365GroupMembersDisplayName = $GroupInfo.M365GroupMembersDisplayName -join "; "
        SiteAdminsEmails            = $AssociatedGroups.SiteAdminsEmails -join "; "
        SiteAdminsDisplayName       = $AssociatedGroups.SiteAdminsDisplayName -join "; "
        SiteOwnersEmails            = $AssociatedGroups.SiteOwnersEmails -join "; "
        SiteOwnersDisplayName       = $AssociatedGroups.SiteOwnersDisplayName -join "; "
        SiteMembersEmails           = $AssociatedGroups.SiteMembersEmails -join "; "
        SiteMembersDisplayName      = $AssociatedGroups.SiteMembersDisplayName -join "; "
        SiteVisitorsEmails          = $AssociatedGroups.SiteVisitorsEmails -join "; "
        SiteVisitorsDisplayName     = $AssociatedGroups.SiteVisitorsDisplayName -join "; "
        IsTeamsConnected            = $BasicMeta.IsTeamsConnected
    }
}

function Export-SPOOwnerInfoCsv {
    <#
    .SYNOPSIS
        Appends (or creates) CSV with owner info records.
    .PARAMETER Record
        One or more PSCustomObjects as produced by New-SPOOwnerInfoRecord (or Get-SPOOwnerInfo).
    .PARAMETER Path
        Destination CSV path. Created if absent.
    .NOTES
        Uses -Append to preserve prior data; adjust if you need header handling resets.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Record,
        [Parameter(Mandatory)][string]$Path
    )
    Write-Verbose "[Export-SPOOwnerInfoCsv] Writing $(($Record | Measure-Object).Count) record(s) to $Path"
    $Record | Export-Csv -Path $Path -NoTypeInformation -Append
    Write-Verbose "[Export-SPOOwnerInfoCsv] Write complete."
}

function Get-SPOOwnerInfo {
    <#
    .SYNOPSIS
        Orchestrates retrieval for a single site: basic metadata, membership, group info.
    .PARAMETER SiteUrl
        Site collection URL.
    .PARAMETER ClientId
        Azure AD App (Client) ID.
    .PARAMETER Tenant
        Tenant (contoso.onmicrosoft.com).
    .PARAMETER Thumbprint
        Certificate thumbprint for auth.
    .OUTPUTS
        PSCustomObject ready for CSV export.
    .NOTES
        Connection is established per-site to ensure correct context (could be optimized if required).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SiteUrl,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$Tenant,
        [Parameter(Mandatory)][string]$Thumbprint
    )
    Write-Host "Processing site: $SiteUrl"
    Write-Verbose "[Get-SPOOwnerInfo] Establishing site connection..."
    Connect-SPOWithCert -Url $SiteUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint

    $basic    = Get-SPOBasicSiteMetadata -SiteUrl $SiteUrl
    $assoc    = Get-SPOSiteMembership -SiteUrl $SiteUrl
    $groupInf = Get-SPOM365GroupInfo -GroupIdString $basic.GroupId
    Write-Verbose "[Get-SPOOwnerInfo] Record assembly complete."
    New-SPOOwnerInfoRecord -BasicMeta $basic -AssociatedGroups $assoc -GroupInfo $groupInf
}

function Get-SPOOwnerInfoForAllSites {
    <#
    .SYNOPSIS
        Iterates all tenant site collections and exports ownership info to CSV.
    .PARAMETER Tenant
        Tenant (e.g. contoso.onmicrosoft.com).
    .PARAMETER ClientId
        Azure AD App (Client) ID.
    .PARAMETER Thumbprint
        Certificate thumbprint for auth.
    .PARAMETER CvsPath
        Output CSV path (will be appended to).
    .NOTES
        - Fails gracefully per site; continues enumeration.
        - Consider filtering $allSites if you only need specific templates / classifications (optimization).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Tenant,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$Thumbprint,
        [Parameter(Mandatory)][string]$CvsPath
    )
    $adminUrl = "https://{0}-admin.sharepoint.com" -f $Tenant.Split('.')[0]
    Write-Host "Connecting to SharePoint Admin Center at $adminUrl..."
    Write-Verbose "[Get-SPOOwnerInfoForAllSites] Connecting to admin portal..."
    Connect-SPOWithCert -Url $adminUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint

    Write-Host "Retrieving all site collections..."
    Write-Verbose "[Get-SPOOwnerInfoForAllSites] Executing Get-PnPTenantSite..."
    $allSites = Get-PnPTenantSite
    Write-Verbose "[Get-SPOOwnerInfoForAllSites] Retrieved $($allSites.Count) site(s)."

    $processed = 0
    foreach ($site in $allSites) {
        $processed++
        Write-Verbose "[Get-SPOOwnerInfoForAllSites] ($processed/$($allSites.Count)) Processing $($site.Url)"
        try {
            $record = Get-SPOOwnerInfo -SiteUrl $site.Url -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint -Verbose:$VerbosePreference
            Export-SPOOwnerInfoCsv -Record $record -Path $CvsPath
        }
        catch {
            Write-Warning "Failed to process site $($site.Url). Error: $($_.Exception.Message)"
        }
    }
    Write-Host "Completed processing $processed site(s). Output: $CvsPath"
}

# Optional extended owners function
function Get-SPOM365GroupOwnersExpanded {
<#
.SYNOPSIS
  Retrieve Microsoft 365 Group owners via PnP then hydrate each owner with Graph user properties.

.DESCRIPTION
  1. Uses Get-PnPMicrosoft365Group -IncludeOwners to obtain owner references (IDs).
  2. For each owner id calls Graph: users/{id}?$select=...
  3. Returns objects including common identity fields (DisplayName, Email, UPN, JobTitle, etc.).
  4. Email resolution fallback order: mail -> otherMails[0] -> userPrincipalName.
  5. Optionally includes non-user directory objects (e.g. servicePrincipal) if requested.
  6. Can return raw Graph objects (no formatting) for debugging.
  7. Optional throttle delay between Graph requests to mitigate rate limiting.
.NOTES
  This helper is not used by the core CSV export but can support deeper owner audits.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupId,

        [string[]]$Properties = @(
            'id','displayName','mail','userPrincipalName','givenName','surname',
            'jobTitle','mobilePhone','businessPhones','preferredLanguage','otherMails'
        ),

        [switch]$IncludeNonUser,
        [switch]$Raw,
        [int]$ThrottleMs = 0
    )

    try {
        $null = Get-PnPConnection -ErrorAction Stop
    } catch {
        throw "Not connected. Run Connect-PnPOnline first (needs Group.Read.All + Directory.Read.All)."
    }

    try {
        Write-Verbose "[Get-SPOM365GroupOwnersExpanded] Retrieving M365 Group owners (GroupId=$GroupId)"
        $group = Get-PnPMicrosoft365Group -Identity $GroupId -IncludeOwners -ErrorAction Stop
    } catch {
        throw "Unable to get group ($GroupId). Check permissions and GroupId. `n$($_.Exception.Message)"
    }

    if (-not $group.Owners -or $group.Owners.Count -eq 0) {
        Write-Verbose "[Get-SPOM365GroupOwnersExpanded] Group ($($group.DisplayName) / $GroupId) has no Owners or not accessible."
        return @()
    }

    $result = New-Object System.Collections.Generic.List[object]
    $select = ($Properties | Where-Object { $_ } | Select-Object -Unique) -join ','

    foreach ($ownerRef in $group.Owners) {
        if (-not $ownerRef.Id) { continue }
        $userUrl = "users/$($ownerRef.Id)?`$select=$select"

        $u = $null
        try {
            $u = Invoke-PnPGraphMethod -Url $userUrl -Method Get -ErrorAction Stop
        } catch {
            if ($IncludeNonUser) {
                try {
                    $dirObj = Invoke-PnPGraphMethod -Url "directoryObjects/$($ownerRef.Id)" -Method Get -ErrorAction Stop
                    $result.Add([pscustomobject]@{
                        GroupId     = $group.Id
                        OwnerId     = $dirObj.id
                        ObjectType  = $dirObj.'@odata.type'
                        DisplayName = $dirObj.displayName
                        UPN         = $dirObj.userPrincipalName
                        Email       = $dirObj.mail
                    })
                } catch {
                    Write-Verbose "[Get-SPOM365GroupOwnersExpanded] Failed non-user read: $($ownerRef.Id) -> $($_.Exception.Message)"
                }
            } else {
                Write-Verbose "[Get-SPOM365GroupOwnersExpanded] Skipped non-user or inaccessible: $($ownerRef.Id)"
            }
            continue
        }

        if ($Raw) {
            $result.Add($u)
        } else {
            if ($u.'@odata.type' -like '*user') {
                $email =
                    if ($u.mail) { $u.mail }
                    elseif ($u.otherMails -and $u.otherMails.Count -gt 0) { $u.otherMails[0] }
                    else { $u.userPrincipalName }

                $result.Add([pscustomobject]@{
                    GroupId           = $group.Id
                    OwnerId           = $u.id
                    ObjectType        = $u.'@odata.type'
                    DisplayName       = $u.displayName
                    UPN               = $u.userPrincipalName
                    Email             = $email
                    GivenName         = $u.givenName
                    Surname           = $u.surname
                    JobTitle          = $u.jobTitle
                    MobilePhone       = $u.mobilePhone
                    BusinessPhones    = if ($u.businessPhones) { ($u.businessPhones -join ';') } else { $null }
                    PreferredLanguage = $u.preferredLanguage
                })
            } else {
                if ($IncludeNonUser) {
                    $result.Add([pscustomobject]@{
                        GroupId     = $group.Id
                        OwnerId     = $u.id
                        ObjectType  = $u.'@odata.type'
                        DisplayName = $u.displayName
                        UPN         = $u.userPrincipalName
                        Email       = $u.mail
                    })
                } else {
                    Write-Verbose "[Get-SPOM365GroupOwnersExpanded] Owner not user object; skipped: $($ownerRef.Id) [$($u.'@odata.type')]"
                }
            }
        }

        if ($ThrottleMs -gt 0) {
            Write-Verbose "[Get-SPOM365GroupOwnersExpanded] Throttling for $ThrottleMs ms"
            Start-Sleep -Milliseconds $ThrottleMs
        }
    }

    return $result
}

# -------------------------------------------
# Backward Compatibility Wrapper
# -------------------------------------------
function GetSiteOwnerInfo {
    <#
    .SYNOPSIS
        Backward-compatible name wrapper that both gathers info and exports a single row to CSV.
    .DESCRIPTION
        Mirrors legacy behavior expected by older scripts referencing GetSiteOwnerInfo directly.
    .PARAMETER SiteUrl
        Target site collection URL.
    .PARAMETER CvsPath
        CSV output path.
    .PARAMETER ClientId
        Azure AD App (Client) ID.
    .PARAMETER Tenant
        Tenant domain.
    .PARAMETER Thumbprint
        Certificate thumbprint.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SiteUrl,
        [Parameter(Mandatory)][string]$CvsPath,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$Tenant,
        [Parameter(Mandatory)][string]$Thumbprint
    )
    Write-Verbose "[GetSiteOwnerInfo] Wrapper invoked for $SiteUrl"
    $record = Get-SPOOwnerInfo -SiteUrl $SiteUrl -ClientId $ClientId -Tenant $Tenant -Thumbprint $Thumbprint -Verbose:$VerbosePreference
    Export-SPOOwnerInfoCsv -Record $record -Path $CvsPath
    Write-Verbose "[GetSiteOwnerInfo] Export complete for $SiteUrl"
}
