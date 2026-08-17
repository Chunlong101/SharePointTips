[CmdletBinding()]
param(
    [string]$SharePointAdminUrl = "https://hello21v-admin.sharepoint.cn",
    [Guid]$TenantId,
    [Guid]$OwningApplicationId = "84ddb0d9-4d5f-4b0e-80b4-b3530e345f9b",
    [string]$ContainerDisplayName = "SPEContainerTest",
    [Guid]$GraphAdminClientId = "84ddb0d9-4d5f-4b0e-80b4-b3530e345f9b"
)

$ErrorActionPreference = "Stop"

function Get-PropertyValue {
    param([object]$InputObject, [string[]]$Names)
    foreach ($name in $Names) {
        $property = $InputObject.PSObject.Properties[$name]
        if ($property -and $null -ne $property.Value -and [string]$property.Value) {
            return [string]$property.Value
        }
    }
    return $null
}

function Get-SharePointTenantId {
    param([string]$AdminUrl)
    $resourceUrl = $AdminUrl -replace '-admin\.sharepoint\.cn', '.sharepoint.cn'
    try {
        Invoke-WebRequest -Uri "$resourceUrl/_vti_bin/client.svc" -Method Get -UseBasicParsing | Out-Null
    }
    catch {
        $header = $_.Exception.Response.Headers.WwwAuthenticate.ToString()
        if ($header -match 'realm="(?<tenant>[0-9a-fA-F-]{36})"') {
            return [Guid]$Matches.tenant
        }
        throw "无法从 SharePoint WWW-Authenticate realm 发现 Tenant ID。请确认 URL 可访问。"
    }
    throw "SharePoint 未返回预期的身份验证质询。"
}

$requiredModules = @(
    "Microsoft.Online.SharePoint.PowerShell",
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Applications"
)
foreach ($module in $requiredModules) {
    if (-not (Get-Module $module -ListAvailable)) {
        throw "缺少模块 $module。请按 README 安装后重试。"
    }
    Import-Module $module -Force
}

if ($TenantId -eq [Guid]::Empty) {
    $TenantId = Get-SharePointTenantId -AdminUrl $SharePointAdminUrl
}
Connect-SPOService -Url $SharePointAdminUrl -Region China
$containers = @(Get-SPOContainer -OwningApplicationId $OwningApplicationId)
$matches = @($containers | Where-Object {
    (Get-PropertyValue $_ @("ContainerName", "DisplayName", "Name")) -eq $ContainerDisplayName
})
if ($matches.Count -ne 1) {
    throw "预期找到 1 个名为 $ContainerDisplayName 的 Container，实际为 $($matches.Count)。"
}

$container = $matches[0]
$containerId = Get-PropertyValue $container @("ContainerId", "Id", "Identity")
if (-not $containerId) { throw "Container 对象未返回 Container ID。" }
$containerDetail = Get-SPOContainer -Identity $containerId
$containerUrl = Get-PropertyValue $containerDetail @("ContainerSiteUrl", "SiteUrl", "Url", "ContainerUrl")
$containerTypes = @(Get-SPOContainerType | Where-Object OwningApplicationId -eq $OwningApplicationId)
$containerTypeId = if ($containerTypes.Count -eq 1) { [string]$containerTypes[0].ContainerTypeId } else { $null }

Connect-MgGraph -Environment China -TenantId $TenantId -ClientId $GraphAdminClientId `
    -Scopes "Application.Read.All" -ContextScope Process -NoWelcome
$app = Get-MgApplication -Filter "appId eq '$OwningApplicationId'" -Property Id,AppId,DisplayName,Web,RequiredResourceAccess
if (-not $app) { throw "未在当前 Tenant 找到 App Registration $OwningApplicationId。" }

$redirectUris = @($app.Web.RedirectUris)
$result = [ordered]@{
    TenantId = $TenantId.ToString()
    OwningApplicationId = $OwningApplicationId.ToString()
    ApplicationObjectId = $app.Id
    ApplicationDisplayName = $app.DisplayName
    ContainerDisplayName = $ContainerDisplayName
    ContainerId = $containerId
    ContainerUrl = $containerUrl
    ContainerTypeId = $containerTypeId
    ContainerTypeDiscoveryNote = if ($containerTypes.Count -eq 1) { "Owning App 下唯一 Container Type。" } else { "Owning App 下有 $($containerTypes.Count) 个 Container Type，不能仅凭 Container 列表对象唯一推断。" }
    HasLocalhostRedirect = [bool]($redirectUris -contains "https://localhost:7155/signin-oidc")
    RedirectUris = $redirectUris
    Note = "只读发现完成；未修改租户。请在门户核对 FileStorageContainer.Selected delegated/application 权限。"
}
$result | ConvertTo-Json -Depth 8
Disconnect-MgGraph | Out-Null
