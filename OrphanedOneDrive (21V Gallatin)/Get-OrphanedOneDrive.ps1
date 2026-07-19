# ===================================================================
# 配置区域：运行前只需修改这里
# ===================================================================

$SharePointAdminUrl = "https://gallatintrialtenant48-admin.sharepoint.cn"
$GraphTenantId = "7213db34-ca6c-4e4a-acb6-e34e9c6551bd"
$GraphClientId = "4c8efd61-1e87-42f3-b3de-c1e0f052e385"
$OutputFolder = Join-Path $PSScriptRoot "OneDrive-Audit"

# ===================================================================
# 正式脚本
# ===================================================================

$ErrorActionPreference = "Stop"

# 加载 SharePoint Online 模块
if (-not (Get-Module Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
    Write-Host "正在安装 Microsoft.Online.SharePoint.PowerShell 模块..."
    Install-Module Microsoft.Online.SharePoint.PowerShell `
        -Scope CurrentUser `
        -Repository PSGallery `
        -Force
}

if ($PSVersionTable.PSEdition -eq "Core") {
    Import-Module Microsoft.Online.SharePoint.PowerShell `
        -UseWindowsPowerShell
}
else {
    Import-Module Microsoft.Online.SharePoint.PowerShell
}

# 检查 Microsoft Graph Users 模块
if (-not (Get-Module Microsoft.Graph.Users -ListAvailable)) {
    Write-Host "正在安装 Microsoft.Graph.Users 模块..."
    Install-Module Microsoft.Graph.Users `
        -Scope CurrentUser `
        -Repository PSGallery `
        -Force
}

Import-Module Microsoft.Graph.Users

# 创建输出目录
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $OutputFolder = Join-Path (Get-Location) "OneDrive-Audit"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $OutputFolder $timestamp

New-Item -Path $outputPath -ItemType Directory -Force |
    Out-Null

$allSitesCsv = Join-Path $outputPath "All-Active-OneDrive-Sites.csv"
$orphanedCsv = Join-Path $outputPath "OneDrive-With-Deleted-Owner.csv"
$deletedCsv = Join-Path $outputPath "Deleted-OneDrive-Sites.csv"

# 连接 Gallatin SharePoint Online
Write-Host "正在连接：$SharePointAdminUrl" -ForegroundColor Cyan

Connect-SPOService `
    -Url $SharePointAdminUrl `
    -ModernAuth $true `
    -AuthenticationUrl "https://login.chinacloudapi.cn/organizations"

# 连接 Gallatin Microsoft Graph
Write-Host "正在连接世纪互联版 Microsoft Graph..." -ForegroundColor Cyan

if ($GraphClientId -like "<*") {
    throw "请先在 Gallatin 租户中注册公共客户端应用，并在脚本开头填写 GraphClientId。"
}

# 禁用 WAM，改用独立浏览器窗口进行管理员交互登录
Set-MgGraphOption -DisableLoginByWAM $true

# 清除旧的 Graph 身份记录，确保使用当前 Gallatin 应用重新登录
$graphAuthRecordPath = Join-Path $HOME ".mg\mg.authrecord.json"
if (Test-Path $graphAuthRecordPath) {
    Remove-Item $graphAuthRecordPath -Force
}

try {
    Connect-MgGraph `
        -ClientId $GraphClientId `
        -TenantId $GraphTenantId `
        -Environment China `
        -Scopes "User.Read.All" `
        -ContextScope Process `
        -NoWelcome
}
catch {
    Write-Host "Microsoft Graph 登录失败，完整错误如下：" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red

    $innerException = $_.Exception.InnerException
    while ($null -ne $innerException) {
        Write-Host "Inner exception: $($innerException.ToString())" -ForegroundColor Red
        $innerException = $innerException.InnerException
    }

    throw
}

if (-not (Get-MgContext)) {
    throw "Microsoft Graph 连接失败。"
}

# 获取当前 Entra ID 用户
Write-Host "正在读取 Entra ID 用户..." -ForegroundColor Cyan

$entraUsers = @(
    Get-MgUser `
        -All `
        -Property Id,UserPrincipalName,DisplayName,AccountEnabled
)

$existingUpns = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($user in $entraUsers) {
    if (-not [string]::IsNullOrWhiteSpace($user.UserPrincipalName)) {
        $null = $existingUpns.Add($user.UserPrincipalName.Trim())
    }
}

# 获取当前仍存在的 OneDrive 站点
Write-Host "正在读取 OneDrive 站点..." -ForegroundColor Cyan

$oneDriveSites = @(
    Get-SPOSite `
        -IncludePersonalSite $true `
        -Limit All |
    Where-Object {
        $_.Template -like "SPSPERS*" -or
        $_.Url -match "/personal/"
    }
)

# 将 OneDrive Owner 与 Entra ID 用户进行比对
$allOneDriveResults = @(
    foreach ($site in $oneDriveSites) {
        $recordedOwner = [string]$site.Owner
        $ownerUpn = $null
        $finding = "OwnerExistsInEntraID"

        if (-not [string]::IsNullOrWhiteSpace($recordedOwner)) {
            $ownerUpn = ($recordedOwner -split "\|")[-1].Trim()
        }

        if ([string]::IsNullOrWhiteSpace($ownerUpn)) {
            $finding = "OwnerMissing"
        }
        elseif ($ownerUpn -notmatch "@") {
            $finding = "OwnerCannotBeResolved"
        }
        elseif (-not $existingUpns.Contains($ownerUpn)) {
            $finding = "OwnerNotFoundInEntraID"
        }

        [PSCustomObject]@{
            OneDriveUrl       = $site.Url
            Title             = $site.Title
            RecordedOwner     = $recordedOwner
            NormalizedOwner   = $ownerUpn
            Finding           = $finding
            SiteStatus        = $site.Status
            LockState         = $site.LockState
            StorageUsedMB     = $site.StorageUsageCurrent
            StorageQuotaMB    = $site.StorageQuota
            LastContentChange = $site.LastContentModifiedDate
            Template          = $site.Template
        }
    }
)

# 导出全部当前 OneDrive
$allOneDriveResults |
    Sort-Object OneDriveUrl |
    Export-Csv $allSitesCsv `
        -NoTypeInformation `
        -Encoding UTF8

# 导出疑似用户已删除的 OneDrive
$orphanedOneDrives = @(
    $allOneDriveResults |
    Where-Object {
        $_.Finding -in @(
            "OwnerNotFoundInEntraID",
            "OwnerMissing",
            "OwnerCannotBeResolved"
        )
    }
)

$orphanedOneDrives |
    Sort-Object Finding, OneDriveUrl |
    Export-Csv $orphanedCsv `
        -NoTypeInformation `
        -Encoding UTF8

# 导出已进入 SharePoint 站点回收站的 OneDrive
Write-Host "正在读取已删除的 OneDrive..." -ForegroundColor Cyan

$deletedOneDrives = @(
    Get-SPODeletedSite `
        -IncludeOnlyPersonalSite `
        -Limit All |
    Select-Object @{
        Name = "OneDriveUrl"
        Expression = { $_.Url }
    }, @{
        Name = "RecordedOwner"
        Expression = { $_.Owner }
    }, DeletionTime, StorageQuota, Status
)

$deletedOneDrives |
    Sort-Object DeletionTime -Descending |
    Export-Csv $deletedCsv `
        -NoTypeInformation `
        -Encoding UTF8

Disconnect-MgGraph | Out-Null

Write-Host ""
Write-Host "查询完成。" -ForegroundColor Green
Write-Host "当前 OneDrive 总数：$($allOneDriveResults.Count)"
Write-Host "疑似所属用户已删除：$($orphanedOneDrives.Count)"
Write-Host "已进入站点回收站：$($deletedOneDrives.Count)"
Write-Host ""
Write-Host "主要结果：$orphanedCsv" -ForegroundColor Yellow
Write-Host "全部站点：$allSitesCsv"
Write-Host "回收站站点：$deletedCsv"
