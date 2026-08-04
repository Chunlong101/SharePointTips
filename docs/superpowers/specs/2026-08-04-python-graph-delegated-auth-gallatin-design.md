# Python 在 21V Gallatin 中通过 Delegated Authentication 操作 SharePoint Online 文件：设计说明

## 1. 背景与目标

本项目提供一个可运行、可教学、可排障的 Python Demo，演示如何在世纪互联运营的 Microsoft 365（21V Gallatin）环境中：

1. 使用 OAuth 2.0 Authorization Code Flow with PKCE 让用户通过浏览器交互登录；
2. 不使用 Client Secret，不持久化 Access Token 或 Refresh Token；
3. 调用中国区 Microsoft Graph API；
4. 解析指定 SharePoint Online 站点的默认文档库；
5. 列出文件、上传小文件和下载文件。

Demo 面向 Windows 上的 Python 命令行场景，文档使用中文。实现必须明确展示 Gallatin 与全球版 Microsoft 365 的 Endpoint 差异。

## 2. 范围

### 2.1 包含

- 手动创建 Gallatin Entra ID 应用的完整步骤；
- 公共客户端、localhost Redirect URI 和 Delegated Permissions 配置；
- 自行实现 PKCE、授权 URL、localhost 回调和 Token 兑换；
- 使用原始 Microsoft Graph HTTP 请求操作指定站点的默认文档库；
- `login`、`list`、`upload`、`download` CLI 子命令；
- 中文错误信息、有限重试和安全日志；
- 不依赖真实租户的自动化测试；
- 使用真实 Gallatin 租户的手工验收步骤。

### 2.2 不包含

- Client Credentials Flow；
- Client Secret 或证书认证；
- Device Code Flow；
- Token 持久化或静默跨进程登录；
- SharePoint REST API；
- 非默认文档库选择；
- 文件删除、移动、复制或重命名；
- 大文件分片上传；
- Web UI 或常驻 Web 服务；
- Global、US Government 或其他 Microsoft 365 云环境。

## 3. 已选方案

采用“纯 OAuth/PKCE + Requests”方案：

- Python 标准库负责随机数、SHA-256、URL 构造、浏览器启动和 localhost HTTP 回调；
- `requests` 负责 Token Endpoint 和 Microsoft Graph HTTP 请求；
- `python-dotenv` 负责读取本地 `.env`；
- `argparse` 提供 CLI；
- `pytest` 和 HTTP Mock 用于测试。

不使用 MSAL 或 Microsoft Graph Python SDK。这样可以完整展示协议细节与 Gallatin Endpoint，并减少 SDK 中国云配置差异带来的干扰。

## 4. Gallatin Endpoint 与 OAuth 参数

固定使用以下中国区 Endpoint：

- Authorization Endpoint：`https://login.partner.microsoftonline.cn/{tenant_id}/oauth2/v2.0/authorize`
- Token Endpoint：`https://login.partner.microsoftonline.cn/{tenant_id}/oauth2/v2.0/token`
- Microsoft Graph Base URL：`https://microsoftgraph.chinacloudapi.cn/v1.0`

OAuth 请求采用：

- `response_type=code`
- `response_mode=query`
- `code_challenge_method=S256`
- 租户专属 Authority，不使用 `common`；
- Scope：`openid profile User.Read Sites.Read.All Files.ReadWrite.All`；
- 不请求 `offline_access`；
- 不发送 `client_secret`。

## 5. Entra ID 应用注册设计

README 必须给出以下手动配置步骤：

1. 登录 `https://portal.azure.cn`；
2. 进入 **Microsoft Entra ID > 应用注册 > 新注册**；
3. 账户类型选择“仅此组织目录中的账户”；
4. 在 **身份验证**中添加“移动和桌面应用程序”平台；
5. 添加与 Demo 配置一致的 localhost Redirect URI；
6. 将“允许公共客户端流”设置为“是”；
7. 添加 Microsoft Graph Delegated Permissions：
   - `User.Read`；
   - `Sites.Read.All`；
   - `Files.ReadWrite.All`；
8. 根据租户同意策略代表组织授予管理员同意；
9. 从概述页复制目录（租户）ID 和应用程序（客户端）ID；
10. 验证 Manifest 中应用被识别为公共客户端，且 localhost Redirect URI 不位于 Web 平台下。

不创建 Client Secret。README 必须说明误将 Redirect URI 配置为 Web 平台可能导致 `AADSTS7000218`。

## 6. 架构与组件

项目目录名称为 `Python Graph Delegated Auth in 21V Gallatin`，组件边界如下。

### 6.1 `main.py`

CLI 入口，仅负责：

- 定义和解析参数；
- 调用配置、认证和 Graph 组件；
- 将领域异常转换为中文用户消息及稳定退出码。

### 6.2 `src/config.py`

负责：

- 从 `.env` 和进程环境读取配置；
- 验证 `TENANT_ID`、`CLIENT_ID`、`SHAREPOINT_SITE_URL` 和 `REDIRECT_URI`；
- 要求站点 URL 使用 HTTPS 且主机名以 `.sharepoint.cn` 结尾；
- 要求 Redirect URI 使用 localhost 回环地址；
- 从站点 URL 提取 hostname 和 server-relative site path。

### 6.3 `src/oauth_pkce.py`

负责：

- 生成符合 PKCE 要求的 `code_verifier`；
- 计算 Base64URL（无填充）的 SHA-256 `code_challenge`；
- 生成密码学安全的 `state`；
- 构造 Authorization URL；
- 启动仅监听回环地址的临时 HTTP 服务；
- 打开默认浏览器并接收一次回调；
- 校验回调 `state`、OAuth 错误和 Authorization Code；
- 使用 Authorization Code 和 `code_verifier` 兑换 Access Token；
- Token 仅作为内存值返回，不写磁盘、不输出完整内容。

回调服务在成功、失败或超时后立即停止。它只接受预期回调路径，并向浏览器返回不包含 Token 或 Authorization Code 的简单成功/失败页面。

### 6.4 `src/graph_client.py`

负责：

- 为请求设置 Bearer Token、超时和统一 Header；
- 解析 SharePoint Site；
- 获取默认 Drive；
- 列出根目录或指定文件夹；
- 上传小文件；
- 流式下载文件；
- 处理 Graph JSON 错误与下载重定向；
- 对 `429` 和临时性 `5xx` 执行有限重试；
- 从响应中提取 `request-id` 和错误代码供排障。

### 6.5 `src/errors.py`

定义配置、认证、Graph、本地文件和 CLI 领域异常。异常消息不得包含 Access Token、Authorization Code 或完整 Token 响应。

## 7. 数据流

每个 CLI 子命令运行在独立进程中，流程如下：

1. 读取并验证配置；
2. 生成新的 PKCE 和 `state`；
3. 启动 localhost 回调；
4. 打开 Gallatin 登录页面；
5. 用户登录并同意权限；
6. 验证回调并兑换 Access Token；
7. 调用 Graph；
8. 输出结果；
9. 清理回调服务和内存引用后退出。

因为不持久化 Token，每次执行 `login`、`list`、`upload` 或 `download` 都会重新发起浏览器交互登录。`login` 命令只验证认证配置并调用 `/me`，不会为后续进程保存登录状态。

## 8. Graph API 操作

### 8.1 当前用户

`login` 调用：

- `GET /me?$select=id,displayName,userPrincipalName`

只显示用户名称和 UPN，不输出 Token。

### 8.2 解析站点与默认文档库

从 `SHAREPOINT_SITE_URL` 得到 hostname 和 server-relative path，然后调用：

1. `GET /sites/{hostname}:/{server-relative-path}`；
2. `GET /sites/{site-id}/drive`。

后续文件操作使用返回的 Drive ID，不依赖文档库的显示名称或语言。

### 8.3 列出文件

- 根目录：`GET /drives/{drive-id}/root/children`
- 指定目录：`GET /drives/{drive-id}/root:/{encoded-folder-path}:/children`

输出名称、类型、大小、最后修改时间和 Web URL。若响应存在 `@odata.nextLink`，客户端继续分页，避免只显示第一页。

### 8.4 上传文件

使用简单上传：

- `PUT /drives/{drive-id}/root:/{encoded-remote-path}:/content`

约束：

- 本地源必须是普通文件；
- 文件大小不得超过 250 MB；
- 默认先检查目标是否存在，存在则拒绝覆盖；
- 只有指定 `--overwrite` 时才允许替换；
- 本 Demo 不自动创建远程父目录。

### 8.5 下载文件

使用：

- `GET /drives/{drive-id}/root:/{encoded-remote-path}:/content`

约束：

- 使用流式写入；
- 自动跟随 Graph 下载重定向；
- 自动创建本地父目录；
- 本地目标存在时默认拒绝，只有指定 `--overwrite` 才替换；
- 先写入同目录临时文件，成功后原子替换目标，失败时删除临时文件，避免留下不完整下载。

## 9. CLI 设计

命令示例：

```text
python main.py login
python main.py list
python main.py list --folder "Folder/Subfolder"
python main.py upload --source ".\sample.txt" --destination "Demo/sample.txt"
python main.py upload --source ".\sample.txt" --destination "Demo/sample.txt" --overwrite
python main.py download --source "Demo/sample.txt" --destination ".\downloads\sample.txt"
python main.py download --source "Demo/sample.txt" --destination ".\downloads\sample.txt" --overwrite
```

远程路径规则：

- 接受 `/` 作为层级分隔符；
- 对每个路径段分别进行 URL 编码，保留层级分隔符；
- 支持空格、中文和嵌套目录；
- 拒绝空文件路径、绝对路径、`.`、`..` 和空路径段；
- `list` 未提供 `--folder` 时表示根目录。

## 10. 配置文件

`.env.example` 包含非真实示例：

```text
TENANT_ID=00000000-0000-0000-0000-000000000000
CLIENT_ID=11111111-1111-1111-1111-111111111111
SHAREPOINT_SITE_URL=https://contoso.sharepoint.cn/sites/Demo
REDIRECT_URI=http://localhost:8400/callback
```

`.env` 不进入版本控制。Redirect URI 必须与 Entra ID 应用注册允许的 localhost URI 匹配。实现使用固定配置端口；端口已占用时明确报错，而不是静默改用未注册端口。

## 11. 错误处理与重试

### 11.1 认证错误

覆盖：

- 浏览器无法启动；
- 回调端口占用；
- 回调超时；
- 用户拒绝授权；
- `state` 缺失或不匹配；
- Authorization Code 缺失；
- Token Endpoint 返回 OAuth 错误；
- Token 响应缺少 `access_token`。

### 11.2 Graph 错误

统一解析：

- HTTP 状态码；
- Graph `error.code`；
- Graph `error.message`；
- `request-id` 或 `client-request-id`。

`401`、`403`、`404` 和 `409` 给出针对性的中文建议。`429` 尊重 `Retry-After`；网络异常、`429` 和临时性 `5xx` 进行有限次数重试，并设置最大等待时间。上传和其他非幂等风险操作只在请求可安全重放时重试。

### 11.3 退出码

- `0`：成功；
- `2`：CLI 参数错误；
- `10`：配置错误；
- `20`：认证错误；
- `30`：Graph/API 错误；
- `40`：本地文件错误；
- `1`：未分类错误。

## 12. 安全要求

- 使用 `secrets` 生成 `state` 和 PKCE verifier；
- 仅支持 S256，不允许 `plain` PKCE；
- 回调仅监听回环地址；
- 严格校验 `state`；
- 不使用 Client Secret；
- 不记录 Token、Authorization Code、PKCE verifier 或完整 Token 响应；
- `.env`、虚拟环境、Python 缓存、测试缓存和下载产物进入 `.gitignore`；
- HTTP 请求必须设置连接和读取超时；
- 不关闭 TLS 证书验证。

## 13. 项目文件

```text
Python Graph Delegated Auth in 21V Gallatin/
├── .env.example
├── .gitignore
├── README.md
├── main.py
├── requirements.txt
├── src/
│   ├── __init__.py
│   ├── config.py
│   ├── errors.py
│   ├── graph_client.py
│   └── oauth_pkce.py
└── tests/
    ├── test_cli.py
    ├── test_config.py
    ├── test_graph_client.py
    └── test_oauth_pkce.py
```

## 14. 测试策略

自动化测试不访问真实 Gallatin 租户，覆盖：

- PKCE verifier 的长度、字符集、随机性和 challenge 计算；
- Authorization URL 使用中国区 Endpoint 和正确参数；
- 正确、缺失和不匹配的 `state`；
- OAuth 成功、拒绝和畸形 Token 响应；
- SharePoint URL 验证与 site path 提取；
- Graph 路径对空格、中文和嵌套层级的编码；
- Site、Drive、分页列表、上传和下载请求；
- 上传与下载的默认覆盖保护；
- 下载失败时临时文件清理；
- `429`、临时性 `5xx` 和超出重试限制；
- 异常与日志中不包含敏感认证值；
- CLI 参数和退出码。

测试通过依赖注入或 HTTP Mock 隔离网络、浏览器和回调行为，避免依赖真实登录。

## 15. 手工验收标准

在已配置的 Gallatin 租户中完成以下步骤即视为 Demo 跑通：

1. 按 README 创建公共客户端应用并配置 Delegated Permissions；
2. 复制 `.env.example` 为 `.env` 并填写 Tenant ID、Client ID 和测试站点 URL；
3. `login` 打开 `login.partner.microsoftonline.cn`，登录成功后显示当前用户；
4. `list` 通过 `microsoftgraph.chinacloudapi.cn` 返回默认文档库内容；
5. `upload` 将本地测试文件上传到已存在的目标文件夹；
6. `download` 将该文件下载到新的本地路径；
7. 比较源文件与下载文件的 SHA-256，结果一致；
8. 不带 `--overwrite` 重复上传或下载时被安全拒绝；
9. 程序输出和磁盘文件中不存在 Access Token 或 Refresh Token。

## 16. README 排错范围

README 至少说明：

- 全球版和 Gallatin Endpoint 混用导致的 audience、issuer 或资源错误；
- `AADSTS700016`：应用不在当前 Gallatin 租户；
- `AADSTS7000218`：应用被识别为机密客户端或 Redirect URI 平台配置错误；
- Redirect URI mismatch；
- 管理员同意或用户权限不足导致的 `403`；
- 站点 URL 错误导致的 `404`；
- localhost 端口被占用；
- 浏览器登录窗口未出现；
- Conditional Access 或租户策略阻止登录；
- `429` 节流与重试行为。

## 17. 实现原则

- 优先保证认证协议正确、安全边界明确和 Gallatin Endpoint 可见；
- 模块职责单一，OAuth 和 Graph 可独立测试；
- 只实现本次选择的最小文件流程，避免加入大文件上传、删除等额外能力；
- 示例代码保持直观，不用框架隐藏 OAuth 或 HTTP 细节；
- 所有真实环境配置由用户本地填写，不向仓库写入租户标识或凭据。
