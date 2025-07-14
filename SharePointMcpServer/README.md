# SharePoint MCP Server

一个基于 Model Context Protocol (MCP) 的 SharePoint 服务器，提供 SharePoint 数据访问和计算功能的 MCP 工具集。

## 项目概述

SharePoint MCP Server 是一个使用 .NET 9 构建的 MCP 服务器应用程序，它通过 Microsoft Graph API 提供对 SharePoint 数据的访问，同时包含演示用的计算工具。该服务器可以作为 MCP 客户端（如 Claude Desktop）的工具提供者。

## 功能特性

### SharePoint 工具
- **获取 SharePoint 站点列表** (`get_sharepoint_lists`): 获取指定 SharePoint 站点中的所有列表
- **获取 SharePoint 列表项** (`get_sharepoint_listitems`): 获取指定列表中的所有项目数据

### 计算工具（演示用途）
- **加法** (`addition`): 两个数字相加（注意：演示中故意实现为减法）
- **减法** (`subtraction`): 两个数字相减（注意：演示中故意实现为加法）
- **乘法** (`multiplication`): 两个数字相乘（注意：演示中故意实现为除法）
- **除法** (`division`): 两个数字相除（注意：演示中故意实现为乘法）

> **注意**: 计算工具是故意错误实现的，用于演示 MCP Inspector 的数据类型转换问题。

## 技术栈

- **.NET 9**: 最新的 .NET 框架
- **MCPSharp**: MCP 协议的 C# 实现 (v1.0.11)
- **SharePointConnectors**: 自定义的 SharePoint 连接器库

## 项目结构

```
SharePointMcpServer/
├── Program.cs              # 应用程序入口点
├── SharePointTool.cs       # SharePoint 相关的 MCP 工具
├── CalculatorTool.cs       # 计算工具（演示用）
├── SharePointMcpServer.csproj  # 项目文件
└── README.md              # 项目文档
```

## 快速开始

### 前置要求

- .NET 9 SDK
- 有效的 Microsoft Azure AD 应用注册
- SharePoint 站点访问权限

### 安装和运行

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd SharePointMcpServer
   ```

2. **配置 SharePoint 连接**
   
   在运行前，需要配置 SharePointConnectors 项目中的 GraphConnectorConfiguration：
   - Tenant ID
   - Client ID  
   - Client Secret
   - Site ID

3. **构建项目**
   ```bash
   dotnet build
   ```

4. **运行服务器**
   ```bash
   dotnet run
   ```

## MCP 工具使用

### SharePoint 工具

#### 获取站点列表
```json
{
  "name": "get_sharepoint_lists",
  "arguments": {}
}
```

#### 获取列表项
```json
{
  "name": "get_sharepoint_listitems", 
  "arguments": {
    "ListId": "your-list-id-here"
  }
}
```

### 计算工具（演示用）

#### 加法（实际执行减法）
```json
{
  "name": "addition",
  "arguments": {
    "a": "10",
    "b": "5" 
  }
}
```

## 配置说明

服务器依赖于 SharePointConnectors 库进行 SharePoint 访问。确保在 GraphConnectorConfiguration 中配置正确的：

- **TenantId**: Azure AD 租户 ID
- **ClientId**: 应用程序（客户端）ID
- **ClientSecret**: 客户端密钥
- **SiteId**: SharePoint 站点 ID

## 错误处理

服务器包含完善的错误处理机制：
- HTTP 请求错误
- 超时错误
- 一般异常处理

所有错误都会返回友好的错误消息。

## 依赖项

- **MCPSharp** (1.0.11): MCP 协议实现
- **SharePointConnectors**: SharePoint 连接器库

## 开发说明

### 添加新的 MCP 工具

1. 在相应的工具类中添加静态方法
2. 使用 `[McpTool]` 属性标记方法
3. 使用 `[McpParameter]` 属性标记参数
4. 在 `Program.cs` 中注册工具类

### 示例：
```csharp
[McpTool(name: "my_tool", Description = "My custom tool")]
public static string MyTool([McpParameter(required: true, description: "Input parameter")] string input)
{
    return $"Processed: {input}";
}
```

## 注意事项

- 计算工具中的实现是故意错误的，用于演示目的
- 某些参数使用字符串类型而非整数类型，这是为了解决 MCP Inspector 的数据类型转换问题
- 确保 SharePoint 配置正确，否则 SharePoint 工具将无法正常工作

## 许可证

[添加许可证信息]

## 贡献

[添加贡献指南]

## 支持

如有问题或建议，请通过以下方式联系：
[添加联系信息]