[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [Guid]$TenantId,
    [Parameter(Mandatory)] [string]$VerifiedDomain,
    [Guid]$GraphAdminClientId = "84ddb0d9-4d5f-4b0e-80b4-b3530e345f9b",
    [string]$Prefix = "SPEAuthDemo",
    [Guid]$AdminUserObjectId,
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
if (-not (Get-Module Microsoft.Graph.Authentication -ListAvailable) -or
    -not (Get-Module Microsoft.Graph.Users -ListAvailable) -or
    -not (Get-Module Microsoft.Graph.Groups -ListAvailable)) {
    throw "缺少 Microsoft.Graph Authentication/Users/Groups 模块。"
}
Import-Module Microsoft.Graph.Authentication -Force
Import-Module Microsoft.Graph.Users -Force
Import-Module Microsoft.Graph.Groups -Force

Connect-MgGraph -Environment China -TenantId $TenantId -ClientId $GraphAdminClientId `
    -Scopes "User.ReadWrite.All", "Group.ReadWrite.All" -ContextScope Process -NoWelcome

$spec = [ordered]@{
    SecurityGroups = @(
        @{ DisplayName = "$Prefix-Readers"; MailNickname = "$($Prefix.ToLower())-readers" },
        @{ DisplayName = "$Prefix-Writers"; MailNickname = "$($Prefix.ToLower())-writers" },
        @{ DisplayName = "$Prefix-Admins"; MailNickname = "$($Prefix.ToLower())-admins" }
    )
    Microsoft365Group = @{ DisplayName = "$Prefix-M365-Transitive"; MailNickname = "$($Prefix.ToLower())-m365" }
    Users = @(
        @{ Key = "Reader"; DisplayName = "$Prefix Reader"; UserPrincipalName = "$($Prefix.ToLower())-reader@$VerifiedDomain" },
        @{ Key = "Writer"; DisplayName = "$Prefix Writer"; UserPrincipalName = "$($Prefix.ToLower())-writer@$VerifiedDomain" },
        @{ Key = "Outside"; DisplayName = "$Prefix Outside"; UserPrincipalName = "$($Prefix.ToLower())-outside@$VerifiedDomain" }
    )
}

if (-not $Apply) {
    [pscustomobject]@{
        Mode = "PlanOnly"
        TenantId = $TenantId
        ProposedObjects = $spec
        Message = "未指定 -Apply；没有创建或修改任何对象。"
    } | ConvertTo-Json -Depth 8
    Disconnect-MgGraph | Out-Null
    return
}

if ($WhatIfPreference) {
    [pscustomobject]@{
        Mode = "WhatIf"
        TenantId = $TenantId
        ProposedObjects = $spec
        Message = "-WhatIf 模式不登录密码提示，也不创建或修改对象。"
    } | ConvertTo-Json -Depth 8
    Disconnect-MgGraph | Out-Null
    return
}

function Get-OrCreateSecurityGroup {
    param([hashtable]$Definition)
    $escaped = $Definition.DisplayName.Replace("'", "''")
    $existing = @(Get-MgGroup -Filter "displayName eq '$escaped'" -Property Id,DisplayName)
    if ($existing.Count -gt 1) { throw "发现多个同名组 $($Definition.DisplayName)。" }
    if ($existing.Count -eq 1) { return $existing[0] }
    if ($PSCmdlet.ShouldProcess($Definition.DisplayName, "Create security group")) {
        return New-MgGroup -DisplayName $Definition.DisplayName -MailEnabled:$false `
            -MailNickname $Definition.MailNickname -SecurityEnabled:$true
    }
}

function Get-OrCreateM365Group {
    param([hashtable]$Definition)
    $escaped = $Definition.DisplayName.Replace("'", "''")
    $existing = @(Get-MgGroup -Filter "displayName eq '$escaped'" -Property Id,DisplayName)
    if ($existing.Count -gt 1) { throw "发现多个同名组 $($Definition.DisplayName)。" }
    if ($existing.Count -eq 1) { return $existing[0] }
    if ($PSCmdlet.ShouldProcess($Definition.DisplayName, "Create Microsoft 365 group")) {
        return New-MgGroup -DisplayName $Definition.DisplayName -MailEnabled:$true `
            -MailNickname $Definition.MailNickname -SecurityEnabled:$false -GroupTypes @("Unified")
    }
}

function Get-OrCreateUser {
    param([hashtable]$Definition)
    $escaped = $Definition.UserPrincipalName.Replace("'", "''")
    $existing = @(Get-MgUser -Filter "userPrincipalName eq '$escaped'" -Property Id,DisplayName,UserPrincipalName)
    if ($existing.Count -gt 1) { throw "发现多个用户 $($Definition.UserPrincipalName)。" }
    if ($existing.Count -eq 1) { return $existing[0] }
    $securePassword = Read-Host "为 $($Definition.UserPrincipalName) 输入初始密码" -AsSecureString
    $plainPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
    try {
        if ($PSCmdlet.ShouldProcess($Definition.UserPrincipalName, "Create test user")) {
            return New-MgUser -AccountEnabled:$true -DisplayName $Definition.DisplayName `
                -MailNickname ($Definition.UserPrincipalName.Split('@')[0]) `
                -UserPrincipalName $Definition.UserPrincipalName `
                -PasswordProfile @{ Password = $plainPassword; ForceChangePasswordNextSignIn = $true }
        }
    }
    finally {
        $plainPassword = $null
        $securePassword.Dispose()
    }
}

$groups = @{}
foreach ($definition in $spec.SecurityGroups) {
    $groups[$definition.DisplayName] = Get-OrCreateSecurityGroup $definition
}
$m365 = Get-OrCreateM365Group $spec.Microsoft365Group
$users = @{}
foreach ($definition in $spec.Users) {
    $users[$definition.Key] = Get-OrCreateUser $definition
}

$memberships = @(
    @{ Group = $groups["$Prefix-Readers"]; User = $users.Reader },
    @{ Group = $groups["$Prefix-Writers"]; User = $users.Writer },
    @{ Group = $m365; User = $users.Reader }
)
if ($AdminUserObjectId -ne [Guid]::Empty) {
    $memberships += @{ Group = $groups["$Prefix-Admins"]; User = [pscustomobject]@{ Id = $AdminUserObjectId } }
}
foreach ($membership in $memberships) {
    $existingMember = Get-MgGroupMember -GroupId $membership.Group.Id -All | Where-Object Id -eq $membership.User.Id
    if (-not $existingMember -and $PSCmdlet.ShouldProcess($membership.Group.DisplayName, "Add member $($membership.User.Id)")) {
        New-MgGroupMemberByRef -GroupId $membership.Group.Id -BodyParameter @{
            "@odata.id" = "https://microsoftgraph.chinacloudapi.cn/v1.0/directoryObjects/$($membership.User.Id)"
        }
    }
}

[pscustomobject]@{
    Mode = "Applied"
    ReaderGroupId = $groups["$Prefix-Readers"].Id
    WriterGroupId = $groups["$Prefix-Writers"].Id
    AdminGroupId = $groups["$Prefix-Admins"].Id
    Microsoft365GroupId = $m365.Id
    ReaderUserId = $users.Reader.Id
    WriterUserId = $users.Writer.Id
    OutsideUserId = $users.Outside.Id
    Message = "对象准备完成。密码未输出；请把 Object ID 写入本地配置。"
} | ConvertTo-Json -Depth 5
Disconnect-MgGraph | Out-Null
