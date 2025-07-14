# SharePointConnectors

[![.NET](https://img.shields.io/badge/.NET-9.0-blue.svg)](https://dotnet.microsoft.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![RestSharp](https://img.shields.io/badge/RestSharp-112.1.0-orange.svg)](https://restsharp.dev/)

一个高性能、线程安全的 .NET 库，通过 Microsoft Graph API 提供 SharePoint 数据访问功能。支持智能缓存、自动认证和完善的错误处理机制。

A high-performance, thread-safe .NET library for accessing SharePoint data through Microsoft Graph API, featuring intelligent caching, automatic authentication, and comprehensive error handling.

## 📋 目录 | Table of Contents

**[🇨🇳 中文文档](#中文文档)**
- [项目概述](#项目概述)
- [主要特性](#主要特性)
- [快速开始](#快速开始-1)
- [API 参考](#api-参考)
- [配置要求](#配置要求)
- [故障排除](#故障排除)

**[🇺🇸 English Documentation](#english-documentation)**
- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Configuration Requirements](#configuration-requirements)
- [Troubleshooting](#troubleshooting)

---

## 🇺🇸 English Documentation

## 🎯 Project Overview

SharePointConnectors is a modern .NET class library designed specifically for seamless SharePoint integration. It provides a clean, efficient, and thread-safe interface for accessing SharePoint data through Microsoft Graph API.

### Why Choose SharePointConnectors?

- **🚀 Performance First**: Optimized with intelligent caching and HTTP client reuse
- **🔒 Security Built-in**: OAuth 2.0 authentication with automatic token management
- **🧵 Thread-Safe**: Designed for concurrent access in multi-threaded applications
- **📝 Developer Friendly**: Clean API with comprehensive error handling
- **🔧 Production Ready**: Battle-tested with robust retry mechanisms

## ✨ Key Features

### 🚀 Core Capabilities
| Feature | Description | Benefit |
|---------|-------------|---------|
| **Azure AD Authentication** | OAuth 2.0 client credentials flow | Secure, enterprise-grade authentication |
| **SharePoint Data Access** | Retrieve sites, lists, and list items | Comprehensive SharePoint integration |
| **Smart Token Management** | Automatic caching and refresh with 5-min buffer | Zero maintenance authentication |
| **Thread-Safe Operations** | Concurrent access support | Perfect for multi-threaded applications |
| **Comprehensive Error Handling** | Detailed exception information | Easy debugging and monitoring |

### 🛡️ Security & Reliability
- ✅ **Multi-tenant Support**: Handle multiple Azure AD tenants simultaneously
- ✅ **Token Security**: Automatic token refresh with expiration buffering
- ✅ **Error Recovery**: Intelligent retry mechanisms for transient failures
- ✅ **Resource Management**: Proper disposal of HTTP resources

### ⚡ Performance Optimizations
- 🔄 **HTTP Client Pooling**: Reuse connections for better performance
- 💾 **Intelligent Caching**: Memory-efficient token and client caching
- ⏱️ **Lazy Initialization**: Resources created only when needed
- 🎛️ **Configurable Timeouts**: Fine-tune for your network conditions

## 🛠️ Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **.NET** | 9.0 | Latest .NET framework with performance improvements |
| **RestSharp** | 112.1.0 | Modern HTTP client library |
| **System.Text.Json** | Built-in | High-performance JSON serialization |
| **Microsoft Graph API** | v1.0 | SharePoint data access endpoint |

## 📁 Project Architecture

```
SharePointConnectors/
├── 📄 GraphConnector.cs                 # Core connector implementation
├── 📄 GraphConnectorConfiguration.cs    # Configuration model
├── 📄 GraphConnectorException.cs        # Custom exception handling
├── 📦 SharePointConnectors.csproj       # Project configuration
├── 📚 README.md                        # This documentation
└── 🧪 Tests/                          # Unit and integration tests
    ├── GraphConnectorTests.cs
    └── TestConfiguration.json
```
## 🚀 Quick Start

### 📦 Installation

Choose your preferred installation method:

#### Option 1: Project Reference (Recommended for development)
```xml
<ProjectReference Include="path/to/SharePointConnectors/SharePointConnectors.csproj" />
```

#### Option 2: NuGet Package (Coming soon)
```bash
# Install via Package Manager Console
Install-Package SharePointConnectors

# Or via .NET CLI
dotnet add package SharePointConnectors
```

#### Option 3: Direct Download
1. Clone or download the source code
2. Build the project: `dotnet build`
3. Reference the compiled DLL

### ⚡ Basic Usage

Follow these simple steps to get started:

#### Step 1: Configure the Connector
```csharp
using SharePointConnectors;

// One-time configuration (typically in Startup.cs or Program.cs)
GraphConnector.Configure(config =>
{
    config.TenantId = "your-tenant-id";           // Azure AD Tenant ID
    config.ClientId = "your-client-id";           // App Registration Client ID
    config.ClientSecret = "your-client-secret";   // App Registration Secret
    config.SiteId = "your-site-id";              // SharePoint Site ID
    config.RequestTimeout = TimeSpan.FromMinutes(2); // Optional: Custom timeout
});
```

#### Step 2: Get Access Token
```csharp
try
{
    // Using default configuration
    string token = await GraphConnector.GetAccessTokenAsync();
    
    // Or with custom parameters for multi-tenant scenarios
    string customToken = await GraphConnector.GetAccessTokenAsync(
        tenantId: "another-tenant-id",
        clientId: "another-client-id", 
        clientSecret: "another-client-secret"
    );
}
catch (GraphConnectorException ex)
{
    Console.WriteLine($"Authentication failed: {ex.Message}");
}
```

#### Step 3: Retrieve SharePoint Data
```csharp
try
{
    // Get all lists in the configured site
    string listsJson = await GraphConnector.GetSiteListsAsync();
    
    // Get specific list items
    string listItemsJson = await GraphConnector.GetListItemsAsync("your-list-id");
    
    // Process the JSON response
    var lists = JsonSerializer.Deserialize<dynamic>(listsJson);
    Console.WriteLine($"Found {lists.value.Count} lists");
}
catch (GraphConnectorException ex)
{
    Console.WriteLine($"Data retrieval failed: {ex.StatusCode} - {ex.Message}");
}
```

#### Step 4: Complete Example
```csharp
using SharePointConnectors;
using System.Text.Json;

public class SharePointService
{
    public async Task<List<string>> GetAllListNamesAsync()
    {
        try
        {
            // Configure once per application lifecycle
            GraphConnector.Configure(config =>
            {
                config.TenantId = Environment.GetEnvironmentVariable("TENANT_ID");
                config.ClientId = Environment.GetEnvironmentVariable("CLIENT_ID");
                config.ClientSecret = Environment.GetEnvironmentVariable("CLIENT_SECRET");
                config.SiteId = Environment.GetEnvironmentVariable("SITE_ID");
            });

            // Retrieve lists
            string listsJson = await GraphConnector.GetSiteListsAsync();
            var listsResponse = JsonSerializer.Deserialize<JsonElement>(listsJson);
            
            var listNames = new List<string>();
            foreach (var list in listsResponse.GetProperty("value").EnumerateArray())
            {
                listNames.Add(list.GetProperty("displayName").GetString());
            }
            
            return listNames;
        }
        catch (GraphConnectorException ex)
        {
            // Log and handle specific Graph API errors
            Console.WriteLine($"SharePoint API Error: {ex.StatusCode} - {ex.ResponseContent}");
            throw;
        }
    }
}
```
## 📚 API Reference

### GraphConnectorConfiguration

Configuration class containing all necessary connection parameters:
public class GraphConnectorConfiguration
{
    public string TenantId { get; set; }           // Azure AD Tenant ID
    public string ClientId { get; set; }           // Application Client ID  
    public string ClientSecret { get; set; }       // Client Secret
    public string SiteId { get; set; }            // SharePoint Site ID
    public TimeSpan TokenCacheTimeout { get; set; } // Token cache timeout
    public TimeSpan RequestTimeout { get; set; }    // Request timeout
}
### GraphConnector Main Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `Configure(Action<GraphConnectorConfiguration>)` | Configure connector settings | `void` |
| `GetAccessTokenAsync(string?, string?, string?)` | Get or refresh Azure AD access token | `Task<string>` |
| `GetSiteListsAsync(string?, string?)` | Get all lists in SharePoint site | `Task<string>` |
| `GetListItemsAsync(string, string?, string?)` | Get all items in SharePoint list | `Task<string>` |
| `ClearTokenCache()` | Clear all cached access tokens | `void` |
| `Dispose()` | Release HTTP client resources | `void` |

### Exception Handling

#### GraphConnectorException
Custom exception class providing detailed error information:
public class GraphConnectorException : Exception
{
    public HttpStatusCode? StatusCode { get; }      // HTTP Status Code
    public string? ResponseContent { get; }         // HTTP Response Content
}
## 🔧 Advanced Usage

### Multi-Tenant Support// Get tokens for different tenants
var tenant1Token = await GraphConnector.GetAccessTokenAsync("tenant1-id", "client1-id", "secret1");
var tenant2Token = await GraphConnector.GetAccessTokenAsync("tenant2-id", "client2-id", "secret2");
### Error Handling Best Practicestry
{
    var lists = await GraphConnector.GetSiteListsAsync();
    // Handle successful response
}
catch (GraphConnectorException ex)
{
    Console.WriteLine($"Graph API Error: {ex.Message}");
    Console.WriteLine($"Status Code: {ex.StatusCode}");
    Console.WriteLine($"Response Content: {ex.ResponseContent}");
}
catch (ArgumentException ex)
{
    Console.WriteLine($"Parameter Error: {ex.Message}");
}
### Performance Optimization Tips

1. **Reuse Connector**: GraphConnector is a static class that automatically reuses HTTP clients
2. **Appropriate Timeout Settings**: Adjust RequestTimeout based on network conditions
3. **Token Caching**: Library automatically caches tokens, no manual management needed
4. **Resource Cleanup**: Call `GraphConnector.Dispose()` when application ends

## ⚙️ Configuration Requirements

### Azure AD App Registration

1. Register application in Azure Portal
2. Configure API permissions:
   - `Sites.Read.All` - Read sites
   - `Sites.ReadWrite.All` - Read and write sites (if needed)
3. Generate client secret
4. Record Tenant ID, Client ID, and Client Secret

### SharePoint Permissions

Ensure the registered application has permission to access the target SharePoint site.

## 🔐 Thread Safety

This library is completely thread-safe and can be used safely in multi-threaded environments:
- Uses `ConcurrentDictionary` to manage token cache
- HTTP client instances are thread-safe
- All public methods can be called concurrently

## 💾 Caching Mechanism

### Token Caching
- Automatically cache access tokens
- Cache key format: `"{tenantId}:{clientId}"`
- Support multi-tenant scenarios
- Expire 5 minutes early to avoid using tokens about to expire

### HTTP Client Caching
- Use `Lazy<RestClient>` for lazy initialization
- Separately cache authentication client and Graph API client
- Automatically reuse connections for better performance

## 🔍 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Authentication Failure** | Check Tenant ID, Client ID, and Client Secret. Confirm application has necessary API permissions |
| **Site Access Failure** | Verify Site ID is correct. Confirm application has access permissions to the site |
| **Timeout Errors** | Adjust `RequestTimeout` settings. Check network connectivity |

### Debugging Tips

Enable detailed logging for more debugging information:
try
{
    var result = await GraphConnector.GetSiteListsAsync();
}
catch (GraphConnectorException ex)
{
    // Log complete exception information
    Console.WriteLine($"Error Details: {ex.Message}");
    Console.WriteLine($"HTTP Status: {ex.StatusCode}");
    Console.WriteLine($"Response Content: {ex.ResponseContent}");
}
## 📦 Dependencies

- **RestSharp** (112.1.0): HTTP client library
- **.NET 9**: Target framework

## 📝 Version History

- **1.0.0**: Initial version
  - Basic SharePoint connectivity features
  - Token caching and management
  - Error handling mechanisms

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Create a Pull Request

## 📞 Support

For questions or suggestions, please contact: chunlonl@microsoft.com

---

## 中文文档

# SharePointConnectors

一个用于连接和操作 Microsoft SharePoint 的 .NET 库，通过 Microsoft Graph API 提供 SharePoint 数据访问功能。

## 📋 目录

- [项目概述](#项目概述)
- [主要特性](#主要特性)
- [技术栈](#技术栈-1)
- [项目结构](#项目结构-1)
- [快速开始](#快速开始-1)
- [API 参考](#api-参考)
- [高级用法](#高级用法)
- [配置要求](#配置要求)
- [线程安全](#线程安全)
- [缓存机制](#缓存机制)
- [故障排除](#故障排除)
- [依赖项](#依赖项-1)
- [版本历史](#版本历史)
- [贡献](#贡献-1)
- [支持](#支持-1)

## 🎯 项目概述

SharePointConnectors 是一个专为 SharePoint 集成而设计的 .NET 类库，提供了简洁、高效、线程安全的 SharePoint 数据访问接口。该库封装了 Microsoft Graph API 的复杂性，提供了智能缓存、自动认证和错误处理等功能。

## ✨ 主要特性

### 🚀 核心功能
- **Azure AD 身份验证**: OAuth 2.0 客户端凭据流认证
- **SharePoint 站点访问**: 获取站点列表和列表项
- **智能令牌缓存**: 自动管理访问令牌的缓存和刷新
- **线程安全**: 支持并发访问的线程安全设计
- **错误处理**: 详细的异常信息和错误处理机制

### 🛡️ 安全特性
- 访问令牌自动缓存和刷新
- 提前 5 分钟的令牌过期缓冲时间
- 多租户和多应用支持

### ⚡ 性能优化
- HTTP 客户端复用
- 延迟初始化 (Lazy Initialization)
- 智能缓存机制
- 可配置的请求超时

## 🛠️ 技术栈

- **.NET 9**: 最新的 .NET 框架
- **RestSharp** (v112.1.0): HTTP 客户端库
- **System.Text.Json**: JSON 序列化/反序列化

## 📁 项目结构
SharePointConnectors/
├── GraphConnector.cs                    # 主要连接器类
├── SharePointConnectors.csproj          # 项目文件
└── README.md                           # 项目文档
## 🚀 快速开始

### 安装

**添加项目引用：**<ProjectReference Include="path/to/SharePointConnectors.csproj" />
**或作为 NuGet 包安装（如果已发布）：**dotnet add package SharePointConnectors
### 基本使用

#### 1. 配置连接器
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
#### 2. 获取访问令牌
// 使用默认配置获取令牌
string token = await GraphConnector.GetAccessTokenAsync();

// 或指定特定参数
string token = await GraphConnector.GetAccessTokenAsync(
    tenantId: "custom-tenant-id",
    clientId: "custom-client-id", 
    clientSecret: "custom-client-secret"
);
#### 3. 获取 SharePoint 站点列表
// 使用默认配置
string listsJson = await GraphConnector.GetSiteListsAsync();

// 或指定参数
string listsJson = await GraphConnector.GetSiteListsAsync(
    accessToken: token,
    siteId: "specific-site-id"
);
#### 4. 获取列表项
string listItemsJson = await GraphConnector.GetListItemsAsync("list-id");

// 带完整参数
string listItemsJson = await GraphConnector.GetListItemsAsync(
    listId: "your-list-id",
    accessToken: token,
    siteId: "your-site-id"
);
## 📚 API 参考

### GraphConnectorConfiguration

配置类，包含所有必要的连接参数：
public class GraphConnectorConfiguration
{
    public string TenantId { get; set; }           // Azure AD 租户 ID
    public string ClientId { get; set; }           // 应用程序客户端 ID  
    public string ClientSecret { get; set; }       // 客户端密钥
    public string SiteId { get; set; }            // SharePoint 站点 ID
    public TimeSpan TokenCacheTimeout { get; set; } // 令牌缓存超时时间
    public TimeSpan RequestTimeout { get; set; }    // 请求超时时间
}
### GraphConnector 主要方法

| 方法 | 描述 | 返回值 |
|------|------|--------|
| `Configure(Action<GraphConnectorConfiguration>)` | 配置连接器设置 | `void` |
| `GetAccessTokenAsync(string?, string?, string?)` | 获取或刷新 Azure AD 访问令牌 | `Task<string>` |
| `GetSiteListsAsync(string?, string?)` | 获取 SharePoint 站点中的所有列表 | `Task<string>` |
| `GetListItemsAsync(string, string?, string?)` | 获取 SharePoint 列表中的所有项目 | `Task<string>` |
| `ClearTokenCache()` | 清除所有缓存的访问令牌 | `void` |
| `Dispose()` | 释放 HTTP 客户端资源 | `void` |

### 异常处理

#### GraphConnectorException
自定义异常类，提供详细的错误信息：
public class GraphConnectorException : Exception
{
    public HttpStatusCode? StatusCode { get; }      // HTTP 状态码
    public string? ResponseContent { get; }         // HTTP 响应内容
}
## 🔧 高级用法

### 多租户支持
// 为不同租户获取令牌
var tenant1Token = await GraphConnector.GetAccessTokenAsync("tenant1-id", "client1-id", "secret1");
var tenant2Token = await GraphConnector.GetAccessTokenAsync("tenant2-id", "client2-id", "secret2");
### 错误处理最佳实践
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
### 性能优化建议

1. **复用连接器**: GraphConnector 是静态类，自动复用 HTTP 客户端
2. **适当的超时设置**: 根据网络情况调整 RequestTimeout
3. **令牌缓存**: 库自动缓存令牌，无需手动管理
4. **资源清理**: 应用程序结束时调用 `GraphConnector.Dispose()`

## ⚙️ 配置要求

### Azure AD 应用注册

1. 在 Azure Portal 中注册应用程序
2. 配置 API 权限：
   - `Sites.Read.All` - 读取站点
   - `Sites.ReadWrite.All` - 读写站点（如需要）
3. 生成客户端密钥
4. 记录租户 ID、客户端 ID 和客户端密钥

### SharePoint 权限

确保注册的应用程序具有访问目标 SharePoint 站点的权限。

## 🔐 线程安全

该库完全线程安全，可以在多线程环境中安全使用：
- 使用 `ConcurrentDictionary` 管理令牌缓存
- HTTP 客户端实例是线程安全的
- 所有公共方法都可以并发调用

## 💾 缓存机制

### 令牌缓存
- 自动缓存访问令牌
- 缓存键格式：`"{tenantId}:{clientId}"`
- 支持多租户场景
- 提前 5 分钟过期以避免使用即将过期的令牌

### HTTP 客户端缓存
- 使用 `Lazy<RestClient>` 延迟初始化
- 分别缓存认证客户端和 Graph API 客户端
- 自动复用连接以提高性能

## 🔍 故障排除

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| **认证失败** | 检查租户 ID、客户端 ID 和客户端密钥。确认应用程序具有必要的 API 权限 |
| **站点访问失败** | 验证站点 ID 是否正确。确认应用程序对站点的访问权限 |
| **超时错误** | 调整 `RequestTimeout` 设置。检查网络连接 |

### 调试建议

启用详细日志记录以获取更多调试信息：
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
## 📦 依赖项

- **RestSharp** (112.1.0): HTTP 客户端库
- **.NET 9**: 目标框架

## 📝 版本历史

- **1.0.0**: 初始版本
  - 基本的 SharePoint 连接功能
  - 令牌缓存和管理
  - 错误处理机制

## 🤝 贡献

欢迎贡献代码！请遵循以下步骤：

1. Fork 该仓库
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 📞 支持

如有问题或建议，请通过以下方式联系：chunlonl@microsoft.com

---

**注意**: 请确保妥善保管您的客户端密钥和其他敏感信息，不要将其提交到版本控制系统中。
