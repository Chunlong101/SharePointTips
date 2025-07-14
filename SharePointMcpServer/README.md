# SharePoint MCP Server

基于模型上下文协议 (MCP) 的 SharePoint 服务器，通过 MCP 协议提供 SharePoint 数据访问和计算工具。

## 📚 目录

- [项目概述](#项目概述)
- [功能特性](#功能特性)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [配置说明](#配置说明)
- [MCP 工具使用](#mcp-工具使用)
- [开发指南](#开发指南)
- [错误处理](#错误处理)
- [依赖项](#依赖项)
- [重要说明](#重要说明)
- [贡献指南](#贡献指南)
- [支持](#支持)

## 📋 项目概述

SharePoint MCP Server 是一个基于 .NET 9 构建的 MCP 服务器应用程序，通过 Microsoft Graph API 提供对 SharePoint 数据的访问，同时包含演示用的计算工具。该服务器可以作为 MCP 客户端（如 Claude Desktop）的工具提供者。

## ✨ 功能特性

### 📊 SharePoint 工具
- **获取 SharePoint 站点列表** (`get_sharepoint_lists`): 检索指定 SharePoint 站点中的所有列表
- **获取 SharePoint 列表项** (`get_sharepoint_listitems`): 检索指定列表中的所有项目数据

### 🧮 计算器工具（演示用）
- **加法** (`addition`): 两个数字相加（注意：为了演示目的，故意实现为减法）
- **减法** (`subtraction`): 两个数字相减（注意：为了演示目的，故意实现为加法）
- **乘法** (`multiplication`): 两个数字相乘（注意：为了演示目的，故意实现为除法）
- **除法** (`division`): 两个数字相除（注意：为了演示目的，故意实现为乘法）

> **⚠️ 注意**: 计算器工具故意实现错误，用于演示 MCP Inspector 数据类型转换问题。

## 🛠 技术栈

- **.NET 9**: 最新的 .NET 框架
- **MCPSharp** (v1.0.11): MCP 协议的 C# 实现
- **SharePointConnectors**: 自定义 SharePoint 连接器库
- **Microsoft Graph API**: 用于 SharePoint 数据访问

## 📁 项目结构

```
SharePointMcpServer/
├── Program.cs                    # 应用程序入口点
├── SharePointTool.cs             # SharePoint 相关的 MCP 工具
├── CalculatorTool.cs             # 计算器工具（演示用）
├── SharePointMcpServer.csproj    # 项目文件
└── README.md                     # 项目文档
```

## 🚀 快速开始

### 先决条件

- .NET 9 SDK
- 有效的 Microsoft Azure AD 应用程序注册
- SharePoint 站点访问权限

### 安装和设置

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd SharePointMcpServer
   ```

2. **配置 SharePoint 连接**
   
   运行前，需要在 SharePointConnectors 项目中配置 GraphConnectorConfiguration：
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

## ⚙️ 配置说明

服务器依赖 SharePointConnectors 库来访问 SharePoint。请确保在 GraphConnectorConfiguration 中正确配置以下参数：

| 参数 | 描述 | 示例 |
|------|------|------|
| **TenantId** | Azure AD 租户 ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **ClientId** | 应用程序（客户端）ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **ClientSecret** | 客户端密钥 | `xxxxxxxxxxxxxxxxxxxxxxxxxx` |
| **SiteId** | SharePoint 站点 ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |

### Azure AD 应用配置步骤

1. 在 Azure 门户中注册新应用程序
2. 配置 API 权限：
   - `Sites.Read.All` 或 `Sites.ReadWrite.All`
   - `User.Read`
3. 创建客户端密钥
4. 获取租户 ID 和应用程序 ID

## 🔧 MCP 工具使用

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

### 计算器工具（演示用）

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

#### 减法（实际执行加法）
```json
{
  "name": "subtraction",
  "arguments": {
    "a": "10",
    "b": "5"
  }
}
```

#### 乘法（实际执行除法）
```json
{
  "name": "multiplication",
  "arguments": {
    "a": 10,
    "b": 5
  }
}
```

#### 除法（实际执行乘法）
```json
{
  "name": "division",
  "arguments": {
    "a": 10,
    "b": 5
  }
}
```

## 👨‍💻 开发指南

### 添加新的 MCP 工具

1. 在相应的工具类中添加静态方法
2. 使用 `[McpTool]` 特性标记方法
3. 使用 `[McpParameter]` 特性标记参数
4. 在 `Program.cs` 中注册工具类

### 示例代码

```csharp
[McpTool("your_tool_name", "工具描述")]
public static async Task<string> YourToolMethod(
    [McpParameter("parameter_name", "参数描述")] string parameterName)
{
    // 工具实现逻辑
    return "结果";
}
```

### 调试和测试

1. 使用 MCP Inspector 测试工具功能
2. 检查日志输出以诊断问题
3. 验证 SharePoint 连接配置

## ❌ 错误处理

常见错误及解决方案：

### 身份验证错误
- **问题**: `401 Unauthorized`
- **解决方案**: 检查 Azure AD 应用配置和权限设置

### 站点访问错误
- **问题**: `403 Forbidden`
- **解决方案**: 确保应用程序具有访问指定 SharePoint 站点的权限

### 配置错误
- **问题**: `Configuration not found`
- **解决方案**: 验证 GraphConnectorConfiguration 中的所有必需参数

## 📦 依赖项

主要 NuGet 包：

```xml
<PackageReference Include="MCPSharp" Version="1.0.11" />
<PackageReference Include="Microsoft.Graph" Version="5.x.x" />
<PackageReference Include="Microsoft.Graph.Auth" Version="1.x.x" />
```

## ⚠️ 重要说明

1. **安全性**: 请确保在生产环境中妥善保护客户端密钥
2. **权限**: 仅授予应用程序所需的最小权限
3. **演示工具**: 计算器工具仅用于演示目的，不应在生产环境中使用
4. **版本兼容性**: 此项目需要 .NET 9 或更高版本

## 🤝 贡献指南

欢迎贡献！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 遵循 C# 编码约定
- 添加适当的注释和文档
- 编写单元测试
- 确保代码通过所有现有测试

## 📞 支持

如需帮助或报告问题：

- 📧 邮箱: [your-email@example.com]
- 🐛 问题报告: [GitHub Issues](https://github.com/your-repo/SharePointMcpServer/issues)
- 📖 文档: [项目 Wiki](https://github.com/your-repo/SharePointMcpServer/wiki)

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

**注意**: 这是一个演示项目，用于展示如何构建 MCP 服务器。在生产环境中使用前，请确保进行适当的安全审查和测试。
