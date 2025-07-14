# SharePointConnectors

一个用于连接和操作 Microsoft SharePoint 的 .NET 库，通过 Microsoft Graph API 提供 SharePoint 数据访问功能。

## 项目概述

SharePointConnectors 是一个专为 SharePoint 集成而设计的 .NET 类库，提供了简洁、高效、线程安全的 SharePoint 数据访问接口。该库封装了 Microsoft Graph API 的复杂性，提供了智能缓存、自动认证和错误处理等功能。

## 主要特性

### ?? 核心功能
- **Azure AD 身份验证**: OAuth 2.0 客户端凭据流认证
- **SharePoint 站点访问**: 获取站点列表和列表项
- **智能令牌缓存**: 自动管理访问令牌的缓存和刷新
- **线程安全**: 支持并发访问的线程安全设计
- **错误处理**: 详细的异常信息和错误处理机制

### ??? 安全特性
- 访问令牌自动缓存和刷新
- 提前 5 分钟的令牌过期缓冲时间
- 多租户和多应用支持

### ? 性能优化
- HTTP 客户端复用
- 延迟初始化 (Lazy Initialization)
- 智能缓存机制
- 可配置的请求超时

## 技术栈

- **.NET 9**: 最新的 .NET 框架
- **RestSharp** (v112.1.0): HTTP 客户端库
- **System.Text.Json**: JSON 序列化/反序列化

## 项目结构

```
SharePointConnectors/
├── GraphConnector.cs                    # 主要连接器类
├── SharePointConnectors.csproj          # 项目文件
└── README.md                           # 项目文档
```

## 快速开始

### 安装

添加项目引用：
```xml
<ProjectReference Include="path/to/SharePointConnectors.csproj" />
```

或作为 NuGet 包安装（如果已发布）：
```bash
dotnet add package SharePointConnectors
```

### 基本使用

#### 1. 配置连接器

```csharp
using SharePointConnectors;

// 配置连接参数
GraphConnector.Configure(config =>
{
    config.TenantId = "your-tenant-id";
    config.ClientId = "your-client-id";
    config.ClientSecret = "your-client-secret";
    config.SiteId = "your-site-id";
    config.RequestTimeout = TimeSpan.FromMinutes(2);
});
```

#### 2. 获取访问令牌

```csharp
// 使用默认配置获取令牌
string token = await GraphConnector.GetAccessTokenAsync();

// 或指定特定参数
string token = await GraphConnector.GetAccessTokenAsync(
    tenantId: "custom-tenant-id",
    clientId: "custom-client-id", 
    clientSecret: "custom-client-secret"
);
```

#### 3. 获取 SharePoint 站点列表

```csharp
// 使用默认配置
string listsJson = await GraphConnector.GetSiteListsAsync();

// 或指定参数
string listsJson = await GraphConnector.GetSiteListsAsync(
    accessToken: token,
    siteId: "specific-site-id"
);
```

#### 4. 获取列表项

```csharp
string listItemsJson = await GraphConnector.GetListItemsAsync("list-id");

// 带完整参数
string listItemsJson = await GraphConnector.GetListItemsAsync(
    listId: "your-list-id",
    accessToken: token,
    siteId: "your-site-id"
);
```

## API 参考

### GraphConnectorConfiguration

配置类，包含所有必要的连接参数：

```csharp
public class GraphConnectorConfiguration
{
    public string TenantId { get; set; }           // Azure AD 租户 ID
    public string ClientId { get; set; }           // 应用程序客户端 ID  
    public string ClientSecret { get; set; }       // 客户端密钥
    public string SiteId { get; set; }            // SharePoint 站点 ID
    public TimeSpan TokenCacheTimeout { get; set; } // 令牌缓存超时时间
    public TimeSpan RequestTimeout { get; set; }    // 请求超时时间
}
```

### GraphConnector 主要方法

#### Configure(Action\<GraphConnectorConfiguration\> configure)
配置连接器设置

#### GetAccessTokenAsync(string? tenantId, string? clientId, string? clientSecret)
获取或刷新 Azure AD 访问令牌
- 返回: `Task<string>` - 访问令牌

#### GetSiteListsAsync(string? accessToken, string? siteId)  
获取 SharePoint 站点中的所有列表
- 返回: `Task<string>` - 包含列表信息的 JSON 字符串

#### GetListItemsAsync(string listId, string? accessToken, string? siteId)
获取 SharePoint 列表中的所有项目
- 参数: `listId` - 必需的列表 ID
- 返回: `Task<string>` - 包含列表项的 JSON 字符串

#### ClearTokenCache()
清除所有缓存的访问令牌

#### Dispose()
释放 HTTP 客户端资源

### 异常处理

#### GraphConnectorException
自定义异常类，提供详细的错误信息：

```csharp
public class GraphConnectorException : Exception
{
    public HttpStatusCode? StatusCode { get; }      // HTTP 状态码
    public string? ResponseContent { get; }         // HTTP 响应内容
}
```

## 高级用法

### 多租户支持

```csharp
// 为不同租户获取令牌
var tenant1Token = await GraphConnector.GetAccessTokenAsync("tenant1-id", "client1-id", "secret1");
var tenant2Token = await GraphConnector.GetAccessTokenAsync("tenant2-id", "client2-id", "secret2");
```

### 错误处理最佳实践

```csharp
try
{
    var lists = await GraphConnector.GetSiteListsAsync();
    // 处理成功响应
}
catch (GraphConnectorException ex)
{
    Console.WriteLine($"Graph API 错误: {ex.Message}");
    Console.WriteLine($"状态码: {ex.StatusCode}");
    Console.WriteLine($"响应内容: {ex.ResponseContent}");
}
catch (ArgumentException ex)
{
    Console.WriteLine($"参数错误: {ex.Message}");
}
```

### 性能优化建议

1. **复用连接器**: GraphConnector 是静态类，自动复用 HTTP 客户端
2. **适当的超时设置**: 根据网络情况调整 RequestTimeout
3. **令牌缓存**: 库自动缓存令牌，无需手动管理
4. **资源清理**: 应用程序结束时调用 `GraphConnector.Dispose()`

## 配置要求

### Azure AD 应用注册

1. 在 Azure Portal 中注册应用程序
2. 配置 API 权限：
   - `Sites.Read.All` - 读取站点
   - `Sites.ReadWrite.All` - 读写站点（如需要）
3. 生成客户端密钥
4. 记录租户 ID、客户端 ID 和客户端密钥

### SharePoint 权限

确保注册的应用程序具有访问目标 SharePoint 站点的权限。

## 线程安全

该库完全线程安全，可以在多线程环境中安全使用：
- 使用 `ConcurrentDictionary` 管理令牌缓存
- HTTP 客户端实例是线程安全的
- 所有公共方法都可以并发调用

## 缓存机制

### 令牌缓存
- 自动缓存访问令牌
- 缓存键格式：`"{tenantId}:{clientId}"`
- 支持多租户场景
- 提前 5 分钟过期以避免使用即将过期的令牌

### HTTP 客户端缓存
- 使用 `Lazy<RestClient>` 延迟初始化
- 分别缓存认证客户端和 Graph API 客户端
- 自动复用连接以提高性能

## 故障排除

### 常见问题

1. **认证失败**
   - 检查租户 ID、客户端 ID 和客户端密钥
   - 确认应用程序具有必要的 API 权限

2. **站点访问失败**
   - 验证站点 ID 是否正确
   - 确认应用程序对站点的访问权限

3. **超时错误**
   - 调整 `RequestTimeout` 设置
   - 检查网络连接

### 调试建议

启用详细日志记录以获取更多调试信息：

```csharp
try
{
    var result = await GraphConnector.GetSiteListsAsync();
}
catch (GraphConnectorException ex)
{
    // 记录完整的异常信息
    Console.WriteLine($"错误详情: {ex.Message}");
    Console.WriteLine($"HTTP 状态: {ex.StatusCode}");
    Console.WriteLine($"响应内容: {ex.ResponseContent}");
}
```

## 依赖项

- **RestSharp** (112.1.0): HTTP 客户端库
- **.NET 9**: 目标框架

## 版本历史

- **1.0.0**: 初始版本
  - 基本的 SharePoint 连接功能
  - 令牌缓存和管理
  - 错误处理机制

## 许可证

[添加许可证信息]

## 贡献

欢迎贡献代码！请遵循以下步骤：

1. Fork 该仓库
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 支持

如有问题或建议，请通过以下方式联系：
[添加联系信息]

---

**注意**: 请确保妥善保管您的客户端密钥和其他敏感信息，不要将其提交到版本控制系统中。