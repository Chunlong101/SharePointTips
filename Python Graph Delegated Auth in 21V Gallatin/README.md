# Python 世纪互联 Gallatin Microsoft Graph 委托身份验证 Demo

## 1. 目标、支持范围与明确排除项

本 Demo 演示如何在 **Microsoft 365 由世纪互联运营（21V Gallatin）** 环境中，使用 Python 直接实现 OAuth 2.0 Authorization Code Flow with PKCE，并通过 Microsoft Graph 操作一个 SharePoint Online 站点的**默认文档库**。

支持的操作：

- 交互登录并读取当前用户的显示名称和用户主体名称；
- 列出默认文档库根目录或已有文件夹中的项目；
- 简单上传一个本地文件；
- 流式下载一个远程文件；
- 通过显式 `--overwrite` 控制上传和下载覆盖。

明确不支持：

- Global、GCC、GCC High 或 DoD 云；
- `.sharepoint.com` 站点、多个站点、非默认文档库或自动创建远程文件夹；
- MSAL、Microsoft Graph SDK、客户端密码、证书、Device Code Flow 或 Client Credentials Flow；
- 应用权限、无人值守运行、刷新令牌或令牌缓存；
- 大文件上传会话、断点续传、文件夹上传或同步。

## 2. 架构与身份验证顺序

CLI 使用 Python 标准库、`requests` 和 `python-dotenv`。流程如下：

1. 从当前目录的 `.env` 和进程环境变量读取并验证四项配置；进程环境变量优先。
2. 在打开浏览器前绑定配置的 localhost 回调端口。
3. 为本次命令生成一次性的 PKCE verifier、S256 challenge 和 OAuth state。
4. 浏览器访问 Gallatin `/authorize` 端点，请求且只请求 `openid profile User.Read Sites.Read.All Files.ReadWrite.All`。
5. 本地回调仅接受配置路径，校验 state 后把授权码及 PKCE verifier 发送到 Gallatin `/token` 端点。
6. 访问令牌只保存在本次 Python 进程内。`login` 调用 `/me`；其余命令解析配置站点及其默认 drive 后执行文件操作。
7. 命令结束时关闭 HTTP session 并丢弃访问令牌；下一个命令会再次交互登录。

授权码、state 和 PKCE verifier 都是单次使用。回调等待上限为 180 秒。

## 3. Gallatin 与 Global 端点

| 用途 | 21V Gallatin（本 Demo） | Global（不要用于本 Demo） |
| --- | --- | --- |
| Azure 门户 | `https://portal.azure.cn` | `https://portal.azure.com` |
| OAuth authorize | `https://login.partner.microsoftonline.cn/{TENANT_ID}/oauth2/v2.0/authorize` | `https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/authorize` |
| OAuth token | `https://login.partner.microsoftonline.cn/{TENANT_ID}/oauth2/v2.0/token` | `https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token` |
| Microsoft Graph v1.0 | `https://microsoftgraph.chinacloudapi.cn/v1.0` | `https://graph.microsoft.com/v1.0` |
| SharePoint 域 | `https://<tenant>.sharepoint.cn` | `https://<tenant>.sharepoint.com` |

不要混用任意一列中的主机名。应用注册、用户、租户、SharePoint 站点、登录端点和 Graph 端点必须全部属于 Gallatin。

## 4. 前置条件

- Windows 10/11 或 Windows Server，能够启动系统默认浏览器并监听 localhost；
- Python 3.10 或更高版本；
- 可访问 `https://portal.azure.cn` 的 Gallatin 租户管理员或应用管理员；
- Gallatin 租户 ID、一个可交互登录的 Gallatin 用户，以及该用户对目标站点的访问权限；
- 一个 HTTPS、主机名全小写且以 `.sharepoint.cn` 结尾的目标站点 URL；
- 管理员能够同意 `Sites.Read.All` 和 `Files.ReadWrite.All` 委托权限；
- 目标站点存在默认文档库，上传目标的远程父文件夹已经存在。

## 5. 在 Gallatin 手工注册应用

以下操作必须在中国区门户完成。

1. 打开 `https://portal.azure.cn`，登录正确的 Gallatin 租户。
2. 进入 **Microsoft Entra ID** > **应用注册（App registrations）** > **新注册（New registration）**。
3. 输入名称，例如 `Python Graph Delegated Auth Demo`。
4. “支持的帐户类型”选择 **仅此组织目录中的帐户（单租户 / Accounts in this organizational directory only）**。
5. 注册页的重定向 URI 可以先留空，然后选择 **注册（Register）**。
6. 在应用“概述”页复制：
   - **目录（租户）ID**，稍后填入 `TENANT_ID`；
   - **应用程序（客户端）ID**，稍后填入 `CLIENT_ID`。
7. 进入 **身份验证（Authentication）** > **添加平台（Add a platform）** > **移动和桌面应用程序（Mobile and desktop applications）**。
8. 添加自定义重定向 URI：`http://localhost:8400/callback`，然后保存。URI 的协议、主机、端口、路径和大小写必须与 `.env` 完全一致；不要把它配置到 Web 平台。
9. 在“高级设置”中将 **允许公共客户端流（Allow public client flows）** 设置为 **是（Yes）**，然后保存。
10. 进入 **API 权限（API permissions）** > **添加权限（Add a permission）** > **Microsoft Graph** > **委托的权限（Delegated permissions）**，只添加以下三个 Graph 委托权限：
    - `User.Read`
    - `Sites.Read.All`
    - `Files.ReadWrite.All`
11. 选择 **代表组织授予管理员同意（Grant admin consent）**，确认三项权限显示已同意。`openid` 和 `profile` 是登录请求中的 OpenID Connect scope，不要因此添加其他 Graph API 权限。
12. 不要进入“证书和密码”创建客户端密码。本 Demo 是带 S256 PKCE 的 public client，配置和代码均不需要 secret。

### 5.1 Manifest 核验

进入 **应用注册** > 此应用 > **清单（Manifest）**。在完整清单中核对下列字段；这是核验片段，不要用片段替换整份清单：

```json
{
  "signInAudience": "AzureADMyOrg",
  "isFallbackPublicClient": true,
  "publicClient": {
    "redirectUris": [
      "http://localhost:8400/callback"
    ]
  },
  "web": {
    "redirectUris": []
  }
}
```

要求：

- `signInAudience` 为 `AzureADMyOrg`，对应单租户；
- `isFallbackPublicClient: true`；
- `http://localhost:8400/callback` 只出现在 `publicClient.redirectUris`；
- `web.redirectUris` 是空列表；
- 清单中不需要 password credential。

如果不一致，优先回到“身份验证”页删除错误平台、添加 Mobile and desktop platform、启用 public client flow 并保存；也可以谨慎编辑对应清单字段并选择 **保存（Save）**。保存后重新打开清单复核。

## 6. 本地安装与配置

在 PowerShell 中进入本项目目录后执行：

```powershell
py -3.10 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
Copy-Item .env.example .env
notepad .env
```

如果已安装更高版本 Python，可把 `py -3.10` 换成对应启动命令。若 PowerShell 阻止激活脚本，可不激活环境，直接使用 `.\.venv\Scripts\python.exe` 替代下文的 `python`。

把 `.env` 修改为真实的**非机密公共配置**：

```dotenv
TENANT_ID=<目录（租户）ID GUID>
CLIENT_ID=<应用程序（客户端）ID GUID>
SHAREPOINT_SITE_URL=https://contoso.sharepoint.cn/sites/Demo
REDIRECT_URI=http://localhost:8400/callback
```

配置约束：

- `TENANT_ID`、`CLIENT_ID` 必须是 GUID；
- `SHAREPOINT_SITE_URL` 必须是 HTTPS `.sharepoint.cn` URL，主机名必须小写，不允许 query 或 fragment；末尾 `/` 会被移除；
- `REDIRECT_URI` 必须是带显式端口和非根路径的 HTTP loopback URI，仅支持 `localhost` 或 `127.0.0.1`，不允许 query 或 fragment；
- 应用注册 URI 与 `.env` 必须逐字符一致；若改端口或路径，两处必须一起修改；
- 从包含 `main.py` 的项目目录运行命令，以便默认读取该目录的 `.env`。

`.env` 已被项目 `.gitignore` 排除。不要提交真实租户配置。

## 7. 命令参考

每条有效命令都会先打开浏览器并交互登录一次。远程路径相对于默认文档库根目录，不要以 `/` 开头；不允许空路径段、`.` 或 `..`。

查看总帮助或子命令帮助不会加载配置、打开浏览器或访问网络：

```powershell
python main.py --help
python main.py login --help
python main.py list --help
python main.py upload --help
python main.py download --help
```

### 7.1 登录验证

```powershell
python main.py login
```

只输出“显示名称”和“用户主体名称”，不会解析文档库。

### 7.2 列出根目录或已有文件夹

```powershell
python main.py list
python main.py list --folder "Folder/Sub Folder"
```

### 7.3 上传

默认拒绝覆盖：

```powershell
python main.py upload --source ".\samples\hello.txt" --destination "Demo/hello.txt"
```

显式允许覆盖远程文件：

```powershell
python main.py upload --source ".\samples\hello.txt" --destination "Demo/hello.txt" --overwrite
```

上传只支持不超过 250 MiB 的普通文件，精确上限为 `250 * 1024 * 1024` 字节。远程父文件夹必须已经存在。

### 7.4 下载

默认拒绝覆盖：

```powershell
python main.py download --source "Demo/hello.txt" --destination ".\downloads\hello.txt"
```

显式允许覆盖本地文件：

```powershell
python main.py download --source "Demo/hello.txt" --destination ".\downloads\hello.txt" --overwrite
```

下载会自动创建本地父目录。

## 8. 输出字段和覆盖语义

`list` 首行及每项均为制表符分隔：

| 字段 | 含义 |
| --- | --- |
| 类型 | `DIR` 表示文件夹，`FILE` 表示文件 |
| 名称 | Graph 返回的项目名称 |
| 大小 | 字节数；缺失时显示 `-` |
| 修改时间 | Graph `lastModifiedDateTime`；缺失时显示 `-` |
| Web URL | 浏览器 URL；缺失时显示 `-` |

成功上传和下载分别输出目标路径。Graph 错误只暴露经过约束的 HTTP status、Graph code 和 request-id，便于排错而不显示响应正文。

覆盖保护采用存在性预检和防御性条件请求。上传条件头的限制如下：

- **上传不带 `--overwrite`**：先检查远程目标，并在唯一一次、不会自动重试的 PUT 上发送 `If-None-Match: *`。这是防御性条件请求；Microsoft Graph 官方简单上传文档没有明确保证此 Gallatin 端点支持该条件头。必须先进行真实 Gallatin 租户验证；在完成验证前，预检加条件头不构成硬性并发保证。409/412 的映射仅在服务遵守条件头时适用：此时，另一个进程在预检后抢先创建文件会使 PUT 返回 409/412，并由 Demo 转换为“目标已存在”而不覆盖并发胜者；如果服务忽略该条件头，仍可能发生覆盖。
- **上传带 `--overwrite`**：跳过存在性预检和条件头，明确允许 Graph 替换远程目标；调用者接受并发写入的最后完成者结果。
- **下载不带 `--overwrite`**：先流式写入目标同目录临时文件，完整成功后通过 `os.link()` 原子地提交新目标。若另一个进程抢先创建目标，并发胜者会保留，本次临时文件会清理并返回本地文件错误。目标文件系统必须支持同卷 hard link；不支持时会安全失败，而不会退化为覆盖。
- **下载带 `--overwrite`**：完整下载到同目录临时文件后才调用 `os.replace()` 原子替换目标；下载中断不会留下部分目标。该开关明确授权替换在提交时存在的文件。

## 9. 手工 Gallatin 验收与 SHA256 比较

自动测试不连接真实租户。应用注册和本地配置完成后，在测试站点执行以下手工验收：

1. 准备一个小型、非敏感文件，并记录哈希：

   ```powershell
   New-Item -ItemType Directory -Force .\samples | Out-Null
   Set-Content -Encoding utf8 .\samples\gallatin-acceptance.txt "Gallatin acceptance"
   Get-FileHash .\samples\gallatin-acceptance.txt -Algorithm SHA256
   ```

2. 验证登录；在 Gallatin 浏览器页用目标用户完成登录：

   ```powershell
   python main.py login
   ```

3. 验证根目录和已存在的验收文件夹（以下假设默认文档库已创建 `Demo`）：

   ```powershell
   python main.py list
   python main.py list --folder "Demo"
   ```

4. 上传后再次列出：

   ```powershell
   python main.py upload --source ".\samples\gallatin-acceptance.txt" --destination "Demo/gallatin-acceptance.txt"
   python main.py list --folder "Demo"
   ```

   如果测试目标已存在，先人工确认可替换，再在上传命令末尾加 `--overwrite`。

5. 下载到新的本地路径：

   ```powershell
   python main.py download --source "Demo/gallatin-acceptance.txt" --destination ".\downloads\gallatin-acceptance.txt"
   ```

6. 比较 SHA256：

   ```powershell
   $sourceHash = (Get-FileHash .\samples\gallatin-acceptance.txt -Algorithm SHA256).Hash
   $downloadHash = (Get-FileHash .\downloads\gallatin-acceptance.txt -Algorithm SHA256).Hash
   $sourceHash
   $downloadHash
   if ($sourceHash -ne $downloadHash) { throw "SHA256 mismatch" }
   ```

验收标准：上述实际操作命令退出码均为 `0`；上传项目可列出；两个 SHA256 字符串完全相同。验收后按站点的数据保留规则删除测试文件。

## 10. 稳定退出码

| 退出码 | 含义 | 常见原因 |
| ---: | --- | --- |
| `0` | 成功 | 命令完成 |
| `1` | 未预期错误 | 未分类异常；终端不会显示 traceback 或异常细节 |
| `2` | 命令行用法错误 | 缺少必填参数、未知命令或参数；由 argparse 返回 |
| `10` | 配置错误 | 缺少配置、GUID 或 URL 无效 |
| `20` | 身份验证错误 | 浏览器无法打开、回调超时/state 错误、token 交换失败 |
| `30` | Graph 或远程文件错误 | 权限、站点、远程路径、限流或 Graph 响应错误 |
| `40` | 本地文件错误 | 源文件无效、超过上限、目标已存在或本地 I/O 失败 |

PowerShell 可在命令后用 `$LASTEXITCODE` 查看退出码。

## 11. 故障排除

### 11.1 Global/Gallatin 端点混用

现象包括登录页找不到租户、token audience 不正确、Graph 返回 401/404。确认门户是 `https://portal.azure.cn`，OAuth 主机仅为 `login.partner.microsoftonline.cn`，Graph 主机仅为 `microsoftgraph.chinacloudapi.cn`，站点仅为 `.sharepoint.cn`。不要把 Global 注册的客户端 ID 用于 Gallatin。

### 11.2 `AADSTS700016`：找不到应用

通常是 `CLIENT_ID`/`TENANT_ID` 复制错误、登录了错误租户，或应用注册在 Global/另一个 Gallatin 租户。回到 Gallatin 应用“概述”页重新复制两个 ID，确认单租户应用与登录用户属于同一目录。不要切换到 Global 登录主机。

### 11.3 `AADSTS7000218`：请求需要 client secret/assertion

应用被当作 confidential client。确认回调位于 **Mobile and desktop applications**，**Allow public client flows = Yes**，Manifest 中 `isFallbackPublicClient: true`。不要通过创建客户端密码“修复”此错误；本 Demo 的 token 请求故意没有 secret。

### 11.4 重定向 URI 不匹配

常见服务端错误为 `AADSTS50011`。确保应用注册、Manifest 和 `.env` 都是完全相同的 `http://localhost:8400/callback`。不要使用 HTTPS、尾随 `/`、Web 平台或不同端口。如果改为 `127.0.0.1` 或其他端口，也必须同时更新 public client redirect URI 和 `.env`。

### 11.5 `403 Forbidden`

确认三项委托权限均已管理员同意，当前用户有目标站点访问权，且 Conditional Access 条件已满足。Graph delegated permission 不会绕过用户本身的 SharePoint 权限。记录终端显示的 request-id 和发生时间交给租户管理员；不要粘贴 token。

### 11.6 `404 Not Found`

确认 `SHAREPOINT_SITE_URL` 是站点根 URL，而不是文档库或文件 URL，站点有默认文档库，远程路径相对于该库根目录且大小写/名称正确。上传不会创建远程文件夹，先在 SharePoint 中创建目标父文件夹。若终端显示“目标已存在”，这是条件上传的安全冲突，不是 404。

### 11.7 localhost 端口被占用或回调超时

程序在打开浏览器前绑定端口；占用时通常返回退出码 `1` 的安全通用错误。关闭占用 `8400` 的进程，或在应用 public client URI 与 `.env` 中同时改用另一个未占用端口。登录必须在 180 秒内完成；防火墙或代理不应拦截本机 loopback。

可用以下命令查找端口占用：

```powershell
Get-NetTCPConnection -LocalPort 8400 -ErrorAction SilentlyContinue
```

### 11.8 浏览器未出现或被隐藏

确认 Windows 已配置默认 HTTPS 浏览器，当前会话允许启动桌面程序，并检查浏览器是否在其他虚拟桌面、后台窗口或被策略阻止。重新运行命令会生成新的 state/PKCE 值；不要复用旧回调。如果浏览器启动失败，命令返回身份验证错误，而不是在终端打印登录 URL。

### 11.9 Conditional Access

交互浏览器会执行租户的 MFA、设备合规、位置或使用条款策略。按页面提示完成要求；如果策略禁止 public client 或 loopback redirect，请由安全管理员评估例外或停止使用本 Demo，不要降级为密码流、关闭 PKCE 或绕过策略。

### 11.10 `429 Too Many Requests`

普通 Graph JSON 请求会尊重有效的 `Retry-After`，采用有界退避，最多重试 3 次且单次等待最多 30 秒。仍失败时降低调用频率，等待服务恢复后重新运行命令。上传 PUT 不自动重试，以避免请求已部分发送后的不确定重复写入。

### 11.11 TLS、代理和下载

所有请求都启用 TLS 证书验证并设置连接/读取超时。不要通过修改代码关闭 `verify`。下载最多跟随一次 Graph 返回的绝对 HTTPS 预认证重定向。重定向下载故意使用全新的凭据隔离 session，设置 `trust_env=False`；它不会继承环境代理、cookie 或 auth，也不会继承原 Graph session 的代理、cookies、auth、证书和默认请求参数。Graph bearer token 不会发送到下载主机。

因此，运行环境必须能够直接 HTTPS 连接到服务选择的下载主机。仅在代理设备上允许或加入该主机并不足以解决连接问题，因为此重定向 session 不会读取环境代理配置。如果组织网络是强制代理环境，本 Demo 当前无法完成重定向下载；必须先增加经过单独安全评审的显式代理支持，并保持凭据隔离，避免把 Graph bearer token、cookies 或其他认证信息发送给下载主机或不应接收它们的代理目标。

## 12. 安全说明

- 永远不打印或持久化 access token、authorization code、PKCE verifier 或完整 token response；
- 不使用 refresh token，也不请求 `offline_access`；每条命令重新登录并在退出时丢弃 token；
- 不创建、读取或要求客户端密码；`.env` 只包含租户/客户端公共 ID 和 URL；
- 不把 bearer token 发送给非 Gallatin Graph 主机；预认证下载重定向使用无凭据 session；
- 所有 HTTP 请求启用 TLS 验证和 connect/read timeout；
- 错误消息经过清理，不输出响应正文、transport 细节、traceback 或秘密；
- 不把 `.env`、下载文件、测试数据、token、浏览器地址栏内容或终端敏感输出提交到 Git/工单；
- 仅在非生产测试站点使用最小必要数据，并遵循组织的数据分类、审计和清理要求。

## 13. 限制汇总

- 仅支持一个配置的 `.sharepoint.cn` 站点及其默认文档库；
- 每次调用都交互登录，不适用于计划任务、服务或 CI；
- 仅支持简单上传，最大 250 MiB；无 upload session、断点续传和自动重试；
- 远程目录必须预先存在；不支持创建、移动、删除或重命名；
- 下载重定向最多一次；目标文件系统需支持同卷 hard link 才能提供不覆盖的原子提交；
- 自动化测试均为本地 fake/mock，不证明租户配置、管理员同意或 Conditional Access 可用；
- 实际权限效果由租户策略、用户站点权限和 Microsoft 365 服务共同决定。

## 14. 参考资料

- [Microsoft Graph national cloud deployments](https://learn.microsoft.com/graph/deployments)
- [Microsoft identity platform OAuth 2.0 authorization code flow（含 PKCE）](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Redirect URI restrictions and limitations](https://learn.microsoft.com/entra/identity-platform/reply-url)
- [Get a SharePoint site by path](https://learn.microsoft.com/graph/api/site-getbypath?view=graph-rest-1.0)
- [Get a drive](https://learn.microsoft.com/graph/api/drive-get?view=graph-rest-1.0)
- [List children of a driveItem](https://learn.microsoft.com/graph/api/driveitem-list-children?view=graph-rest-1.0)
- [Upload or replace the contents of a driveItem](https://learn.microsoft.com/graph/api/driveitem-put-content?view=graph-rest-1.0)
- [Download driveItem content](https://learn.microsoft.com/graph/api/driveitem-get-content?view=graph-rest-1.0)
- [仓库现有 Gallatin 参考文章](../Microsoft%20Graph%20Api%20in%2021V%20Gallatin/README.md)
