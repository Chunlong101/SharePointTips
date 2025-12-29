#region Parameters

# Azure AD / Entra ID Tenant
$TenantId = "xxx"

# App Registration
$ClientId = "xxx"
$ClientSecret = "xxx"

# SharePoint Site/Page info
$SiteId = "xxx"
$PageId = "xxx"

# Text content
$WebPartHtml = "&lt;p&gt;sample text in text web part&lt;/p&gt;"

# ----- Advanced parameters (keep defaults if you're not familiar) -----

# Graph China Cloud
$LoginBaseUrl = "https://login.partner.microsoftonline.cn"
$GraphBaseUrl = "https://microsoftgraph.chinacloudapi.cn"
$Scope = "$GraphBaseUrl/.default"

# WebPart settings
$WebPartId = "20a69b85-529c-41f3-850e-c93458aa74eb"

# Section settings
$SectionEmphasis = "soft"
$SectionId = "2"
$SectionLayout = "oneColumn"

# Column settings
$ColumnWidth = 12
$ColumnId = "1"

# API path (v1.0)
$HorizontalSectionsPath = "/v1.0/sites/$SiteId/pages/$PageId/microsoft.graph.sitePage/canvasLayout/horizontalSections"

#endregion Parameters

#region Helper Functions

function Get-GraphAccessToken {
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret,
        [Parameter(Mandatory)][string]$LoginBaseUrl,
        [Parameter(Mandatory)][string]$Scope
    )

    $tokenUrl = "$LoginBaseUrl/$TenantId/oauth2/v2.0/token"

    # Use -Form to automatically apply x-www-form-urlencoded encoding and avoid manual string building/escaping issues
    $form = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = $Scope
    }

    try {
        $resp = Invoke-RestMethod -Method POST -Uri $tokenUrl -Form $form -Headers @{
            "SdkVersion" = "postman-graph/v1.0"
        }
        return $resp.access_token
    }
    catch {
        throw "获取 Access Token 失败：$($_.Exception.Message)"
    }
}

function Invoke-GraphRequest {
    param(
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][ValidateSet("GET", "POST", "PATCH", "PUT", "DELETE")][string]$Method,
        [Parameter(Mandatory)][string]$Uri,      # Supports full URL or /v1.0/... style path
        [object]$Body
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Accept"        = "application/json"
    }

    $finalUri = if ($Uri -like "http*") { $Uri } else { "$GraphBaseUrl$Uri" }

    try {
        if ($null -ne $Body) {
            $json = $Body | ConvertTo-Json -Depth 20
            return Invoke-RestMethod -Method $Method -Uri $finalUri -Headers $headers -ContentType "application/json" -Body $json
        }
        else {
            return Invoke-RestMethod -Method $Method -Uri $finalUri -Headers $headers
        }
    }
    catch {
        $msg = $_.Exception.Message
        throw "Graph 请求失败：$Method $finalUri`n$msg"
    }
}

#endregion Helper Functions

#region Main

# 1) Get token
$accessToken = Get-GraphAccessToken `
    -TenantId $TenantId `
    -ClientId $ClientId `
    -ClientSecret $ClientSecret `
    -LoginBaseUrl $LoginBaseUrl `
    -Scope $Scope

# 2) Build section body (referencing the parameters defined at the top)
$sectionBody = @{
    emphasis = $SectionEmphasis
    layout   = $SectionLayout
    id       = $SectionId
    columns  = @(
        @{
            id       = $ColumnId
            width    = $ColumnWidth
            webparts = @(
                @{
                    id        = $WebPartId
                    innerHtml = $WebPartHtml
                }
            )
        }
    )
}

# 3) Call Graph
$response = Invoke-GraphRequest -AccessToken $accessToken -Method POST -Uri $HorizontalSectionsPath -Body $sectionBody

# 4) Output
$response | ConvertTo-Json -Depth 20

#endregion Main