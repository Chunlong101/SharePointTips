# SharePoint Embedded 业务层授权 Demo 设计

## 目标

在 `hello21v` 世纪互联测试租户中构建一个 ASP.NET Core Web Demo，通过业务代码验证以下访问规则：

- 只接受指定世纪互联 Entra 租户中的用户；
- 只允许指定 Entra 组成员访问；
- 只允许来自中国大陆允许位置的请求；
- Reader 只能列出和下载文件，Writer 可以额外上传文件；
- 同时提供 delegated 和 app-only 两种 SPE 调用模式，直观展示两者的安全边界差异。

本项目只创建代码、测试、配置模板和操作手册，不直接修改用户租户。Secret、用户密码和访问令牌不得写入仓库或聊天记录。

## 已知环境

- SharePoint Admin URL：`https://hello21v-admin.sharepoint.cn`
- 现有 Entra App ID：`84ddb0d9-4d5f-4b0e-80b4-b3530e345f9b`
- 目标 Container 显示名称：`SPEContainerTest`
- Microsoft Graph China：`https://microsoftgraph.chinacloudapi.cn`
- Microsoft Entra China authority：`https://login.chinacloudapi.cn`

Tenant ID、Container ID、Container Type ID、测试用户和测试组由准备脚本发现或创建后写入本地配置，不写入源代码。

## 实现方案

采用 ASP.NET Core Razor Pages 和 Microsoft.Identity.Web：

1. Web App 使用 OpenID Connect 在世纪互联 Entra 中登录。
2. 服务端统一授权服务验证 Tenant、组成员、来源位置和业务操作。
3. delegated 模式使用当前用户令牌调用 Microsoft Graph SPE API。
4. app-only 模式使用 Client Secret 获取应用令牌，作为安全边界对照。
5. 页面显示每项授权信号、最终决策和 SPE 调用结果，但不显示 Token 或 Secret。

不采用 SPA/Web API 双 App 架构，以避免本次验证引入额外的 CORS、两个 App Registration 和浏览器 Token 管理复杂度。

## 项目结构

项目位于 `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo`：

```text
SPEBusinessAuthorizationDemo/
├── src/SpeAuthorizationDemo/
│   ├── Authentication/
│   ├── Authorization/
│   ├── Graph/
│   ├── Location/
│   ├── Models/
│   ├── Pages/
│   ├── appsettings.json
│   └── Program.cs
├── tests/SpeAuthorizationDemo.Tests/
├── scripts/
│   ├── Discover-SpeEnvironment.ps1
│   └── Prepare-SpeTestIdentities.ps1
├── SPEBusinessAuthorizationDemo.sln
└── README.md
```

每个组件只承担一类职责：身份 Claim 解析、组检查、位置检查、授权决策、Graph Token/请求和 UI 分离，便于独立测试。

## 身份和组成员判断

授权输入只信任服务端验证后的身份：

- `tid` 必须等于配置的 Tenant ID；
- `oid` 必须存在；
- 组匹配使用 Group Object ID，不使用显示名称、邮箱域或用户自报属性；
- 优先读取 Token 的 `groups` Claim；
- 如果 Token 出现 group overage，则在已授权 `GroupMember.Read.All` 时通过 delegated Graph 查询传递成员关系；
- 如果组信息不完整且 Graph 回退不可用，默认拒绝并输出可操作的配置错误。

支持两类测试组：

- Entra Security Group：作为业务准入组；
- Microsoft 365 Group：验证 SPE 官方明确支持的传递 Container 成员模型。

准备脚本创建组内 Reader、组内 Writer 和组外用户，密码由管理员在交互式流程中设置，脚本和日志不输出密码。

## 位置判断

授权优先检查配置的大陆办公网/VPN 公网 CIDR，其次使用 GeoIP 国家代码 `CN`。未知、私有、回环或无法定位的地址默认拒绝。

Development 环境提供显式的测试位置选择器，用于在本机模拟 `CN` 和 `US`。该选择器必须同时满足以下条件才生效：

- ASP.NET Core Environment 为 `Development`；
- 配置 `LocationPolicy:EnableDevelopmentOverride` 为 `true`；
- 请求来自回环地址。

Production 环境完全忽略模拟值。反向代理 Header 只在明确配置 Known Proxies/Known Networks 时处理，不能无条件信任 `X-Forwarded-For`。

Azure China App Service 部署阶段使用平台转发信息获得公网来源地址，并通过大陆与境外网络各进行一次真实验证。

## 业务角色和操作

业务授权操作定义为：

- `ListFiles`
- `DownloadFile`
- `UploadFile`
- `RunAppOnlyComparison`

角色映射：

| 业务角色 | 允许操作 |
|---|---|
| Reader | ListFiles、DownloadFile |
| Writer | Reader 全部操作、UploadFile |
| DemoAdmin | Writer 全部操作、RunAppOnlyComparison |

组与角色通过配置中的 Group Object ID 映射。没有匹配角色时默认拒绝。app-only 对照页面只允许 DemoAdmin。

## SPE 调用模式

### Delegated

使用 Microsoft.Identity.Web 为当前用户获取 `FileStorageContainer.Selected` delegated Token。有效权限是以下三者交集：

1. App 的 Graph 权限及 Container Type Registration 权限；
2. 用户在目标 Container 中的权限；
3. 本 Demo 的 Tenant、Group、Location 和业务角色策略。

该模式用于正式的允许/拒绝测试，并保留真实用户审计身份。

### App-only

使用同一 App 的 Client Secret 和 `FileStorageContainer.Selected` application 权限获取应用 Token。业务授权仍在调用前执行，但 SPE 不检查当前用户的 Container 角色。

页面必须明确标注此模式是对照实验。任何 Token 均不得返回浏览器。Container Type Registration 应使用最小权限，避免 `full`。

## Graph 操作

Demo 支持：

- 列出 Container 根目录文件；
- 下载指定文件；
- 上传受限大小的小文件；
- app-only 模式执行只读列表作为对照。

Container ID 只能来自服务端配置，不能由请求参数覆盖。下载和上传路径必须拒绝目录穿越、控制字符和非法文件名。上传大小上限由配置决定，默认 4 MB。

## 配置和 Secret

非敏感默认配置放入 `appsettings.json`；租户特定 Object ID 可放在不提交的开发配置或环境变量中。Client Secret 只能通过以下方式提供：

- 本机：.NET User Secrets；
- Azure China：App Service Application Settings，后续可迁移到 Key Vault。

仓库提供 `appsettings.Local.example.json`，但 `.gitignore` 排除真实本地配置。

## UI 和日志

Razor Pages 提供：

- 登录/注销；
- 当前身份、Tenant、组、位置和角色信号摘要；
- delegated 文件列表、上传和下载；
- DemoAdmin 专用 app-only 对照；
- 403 页面，逐项说明拒绝原因。

结构化日志记录时间、用户 Object ID、Tenant ID、来源 IP、国家代码、Container ID、操作和决策原因。日志不得记录访问令牌、Client Secret、密码或文件内容。

## 错误处理

- 身份 Claim 缺失：拒绝并要求重新登录；
- 租户不匹配：403；
- 组检查失败或不完整：默认拒绝并记录原因；
- 地址无法识别：默认拒绝；
- Graph 401：清理会话并要求重新登录；
- Graph 403：区分 App/Container Type 权限不足与用户 Container 权限不足；
- CA claims challenge：保留响应信息并提示客户端/管理员处理；
- Graph 429/5xx：只对幂等读取进行有限退避重试，上传不自动重复；
- app-only 凭据错误：不回显服务端错误中的敏感数据。

## 脚本职责

`Discover-SpeEnvironment.ps1`：

- 检查 SPO 和 Graph PowerShell 模块；
- 连接 China 环境；
- 输出 Tenant ID；
- 按 App ID 和显示名称定位唯一 Container；
- 输出 Container ID、Container URL 和 Container Type ID；
- 检查 App 所需 API 权限和 Redirect URI；
- 默认只读，不修改租户。

`Prepare-SpeTestIdentities.ps1`：

- 创建或复用 Security Group 和 Microsoft 365 Group；
- 创建或复用 Reader、Writer 和 Outside 测试用户；
- 添加组成员；
- 输出 Object ID 配置摘要；
- 变更前要求显式 `-Apply`；
- 不创建或输出固定明文密码。

Container 权限和 Container Type Registration 使用单独、明确的管理员步骤配置，避免身份准备脚本隐式授予广泛 SPE 权限。

## 测试策略

单元测试覆盖：

- Tenant 匹配与拒绝；
- Token groups Claim 与 group overage；
- Reader、Writer、DemoAdmin 操作矩阵；
- CN、非 CN、CIDR、未知 IP 和开发模拟；
- Production 忽略模拟值；
- Container ID 不可由客户端覆盖；
- 非管理员无法进入 app-only 对照；
- 文件名和上传大小校验。

本机集成验证矩阵：

| 用户 | 模拟位置 | 预期 |
|---|---|---|
| Reader 组内 | CN | 列出/下载成功，上传拒绝 |
| Writer 组内 | CN | 列出/下载/上传成功 |
| 任一组内 | US | 全部拒绝 |
| 组外 | CN | 全部拒绝 |

Azure China 验证使用真实大陆与境外公网重复矩阵。每次网络切换使用新的 InPrivate 会话，避免旧 Token 和会话缓存影响结果。

## 验收标准

- 解决方案可使用本机已安装的受支持 .NET SDK 编译；
- 所有单元测试通过；
- Secret 和租户敏感数据未进入 Git；
- 准备脚本默认只读或要求 `-Apply`；
- 本地模拟矩阵的四类决策符合预期；
- delegated 模式可对 `SPEContainerTest` 完成列表、下载和按角色上传；
- app-only 对照明确显示其与用户 Container 权限的差异；
- README 包含 App Registration、管理员同意、Container 权限、本机运行、Azure China 部署、真实网络验证和回滚步骤；
- 任何无法由本地环境验证的租户行为都明确标注为待用户执行的在线验证，不宣称已经跑通。

## 非目标

- 不把业务层判断描述为 Conditional Access 或 Container 原生安全边界；
- 不实现生产级用户生命周期同步系统；
- 不实现大文件分片上传；
- 不实现匿名链接或外部分享；
- 不自动启用生产 Conditional Access；
- 不在本次任务中修改现有 Container 内容或权限。
