# SharePoint Embedded 业务授权 Demo（世纪互联）

## 项目简介

本项目使用 ASP.NET Core 9 验证如何在**业务代码层**控制 SharePoint Embedded（SPE）Container 访问：

- 只允许指定世纪互联 Entra Tenant；
- 使用 Entra Group 映射 Reader、Writer、DemoAdmin 业务角色；
- 只允许中国大陆位置；
- 对比 delegated 用户访问与 app-only 应用访问的安全边界。

测试环境：

- Tenant ID：`4fdbc199-e726-43ec-93e2-67eb4a069ad1`
- App ID：`84ddb0d9-4d5f-4b0e-80b4-b3530e345f9b`
- Container：`SPEContainerTest`
- China Graph：`https://microsoftgraph.chinacloudapi.cn`

> 业务代码控制不是 Conditional Access。生产环境仍建议保留 Container 权限、Restricted Access Control 或 Conditional Access 等平台控制。

## 授权模型

```text
允许访问 = Tenant 匹配
        AND Entra Group/业务角色匹配
        AND 来源位置允许
        AND Container 用户权限允许（delegated 模式）
```

- **Delegated**：SPE 继续检查真实用户的 Container 权限。
- **App-only**：SPE 使用应用身份，不检查当前用户的 Container 角色，因此只开放给 DemoAdmin。

## 测试对象

新建了三个测试账号：

| 账号 | Group | Container 权限 |
|---|---|---|
| `SPEAuthDemo Reader` | `SPEAuthDemo-Readers` | `reader` |
| `SPEAuthDemo Writer` | `SPEAuthDemo-Writers` | `writer` |
| `SPEAuthDemo Outside` | 无允许组 | 无 |

另外使用已有管理员账号加入 `SPEAuthDemo-Admins`，验证 app-only。

创建了四个 Group：

- `SPEAuthDemo-Readers`（Security Group）
- `SPEAuthDemo-Writers`（Security Group）
- `SPEAuthDemo-Admins`（Security Group）
- `SPEAuthDemo-M365-Transitive`（Microsoft 365 Group，预留传递成员测试）

Security Group 用于业务代码判断；Reader/Writer 用户被直接授予 Container 权限，因此 SharePoint Admin Center 的成员页面显示用户，而不是这些 Group。

## 快速配置

### 1. App Registration

在 `portal.azure.cn` 为 App 配置：

- Web Redirect URI：`https://localhost:7155/signin-oidc`
- Delegated：`FileStorageContainer.Selected`、`GroupMember.Read.All`
- Application：`FileStorageContainer.Selected`
- 创建 Client Secret，并完成管理员同意

如需运行管理脚本，另配置 Mobile/Desktop Redirect URI `http://localhost` 和 public client flow。

### 2. 本地配置

```powershell
Copy-Item .\src\SpeAuthorizationDemo\appsettings.Local.example.json `
  .\src\SpeAuthorizationDemo\appsettings.Local.json
```

在本地文件填写 Tenant ID、Container ID 和三个业务 Group ID。该文件已被 Git 忽略。

将 Secret 保存到 User Secrets，不要写入配置文件：

```powershell
dotnet user-secrets set "AzureAd:ClientSecret" "<secret>" `
  --project .\src\SpeAuthorizationDemo\SpeAuthorizationDemo.csproj
```

### 3. 编译与启动

```powershell
dotnet build .\SPEBusinessAuthorizationDemo.sln -warnaserror
dotnet test .\SPEBusinessAuthorizationDemo.sln --no-build
dotnet dev-certs https --trust
dotnet run --project .\src\SpeAuthorizationDemo\SpeAuthorizationDemo.csproj `
  --launch-profile https
```

打开：`https://localhost:7155`

## 测试步骤

1. Reader 登录，选择“模拟大陆并访问”，验证列表、下载和上传限制。
2. Writer 登录，选择“模拟大陆并访问”，验证上传。
3. Reader 或 Writer 选择“模拟境外并验证拒绝”。
4. Outside 登录并模拟大陆，验证组外用户被拒绝。
5. DemoAdmin 登录并打开“App-only 对照”。

`US` 测试不是实际美国公网，而是 Development 环境下通过 `testLocation=US` 模拟位置判断。该参数仅在 `Development + localhost + EnableDevelopmentOverride=true` 时生效，Production 会忽略它。

## 测试结果

| 场景 | 结果 |
|---|---|
| Reader + CN：列表/下载 | 允许 |
| Reader + CN：上传 | 拒绝：`operation_not_allowed` |
| Reader/Writer + US | 拒绝：`location_not_allowed` |
| Writer + CN：上传 | 成功，上传 `writer-test.txt`（63 bytes） |
| Outside + CN | 拒绝：`group_not_allowed` |
| DemoAdmin + CN：app-only | 成功，应用身份读取 3 个根目录项目 |

自动验证：**45 项测试通过，0 失败**；PowerShell 脚本安全检查通过。

## 测试截图

管理员身份和位置模拟入口：

![管理员身份与位置模拟入口](docs/images/admin-identity-summary.png)

App-only 成功读取 Container：

![App-only 成功读取 SPE Container](docs/images/app-only-success.png)

## 清理

测试后可删除：

- 三个测试用户；
- 四个 `SPEAuthDemo-*` Group；
- Reader/Writer Container 权限；
- `writer-test.txt`；
- App 中的临时 Client Secret 和临时管理权限。

删除本机 Secret：

```powershell
dotnet user-secrets remove "AzureAd:ClientSecret" `
  --project .\src\SpeAuthorizationDemo\SpeAuthorizationDemo.csproj
```
