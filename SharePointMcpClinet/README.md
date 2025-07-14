# SharePoint MCP Client

[![.NET Version](https://img.shields.io/badge/.NET-9.0-blue)](https://dotnet.microsoft.com/download/dotnet/9.0)
[![MCPSharp](https://img.shields.io/badge/MCPSharp-v1.0.11-green)](https://www.nuget.org/packages/MCPSharp)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A demonstration console application showcasing MCP (Model Context Protocol) integration with SharePoint using the MCPSharp library. This client connects to a SharePoint MCP server to execute various operations including mathematical calculations and SharePoint data access.

## 📑 Table of Contents

- [✨ Features](#-features)
- [📋 Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [🔧 Available Tools](#-available-tools)
- [📊 Example Output](#-example-output)
- [🛠️ Development](#️-development)
- [📦 Dependencies](#-dependencies)
- [🔍 Troubleshooting](#-troubleshooting)
- [🌏 中文说明](#-中文说明)

## ✨ Features

- 🔗 **MCP Client Connection** - Seamless connection to SharePoint MCP server
- 🔍 **Tool Discovery** - Automatic discovery and execution of available tools
- 🧮 **Mathematical Operations** - Support for basic arithmetic operations
- 📊 **SharePoint Integration** - Access to SharePoint lists and list items
- ⚡ **Performance Monitoring** - Built-in execution time tracking and error handling
- 📝 **Detailed Logging** - Comprehensive logging for debugging and monitoring

## 📋 Prerequisites

Before running the SharePoint MCP Client, ensure you have:

- **[.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)** or later
- **SharePoint MCP Server** - Must be built and available
- **MCPSharp Package** - Automatically installed via NuGet
- **Windows Environment** - Required for the current implementation

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Navigate to the project directory
cd SharePointMcpClient

# Restore dependencies
dotnet restore
```

### 2. Configure Server Path

Edit the `Program.cs` file to specify your SharePoint MCP Server executable path:

```csharp
var serverPath = @"C:\path\to\SharePointMcpServer\bin\Debug\net9.0\SharePointMcpServer.exe";
```

### 3. Run the Application

```bash
dotnet run
```

## 🔧 Available Tools

### 🧮 Mathematical Operations

| Tool Name | Description | Parameters |
|-----------|-------------|------------|
| `addition` | Adds two numbers | `a` (string), `b` (string) |
| `subtraction` | Subtracts two numbers | `a` (string), `b` (string) |
| `multiplication` | Multiplies two numbers | `a` (number), `b` (number) |
| `division` | Divides two numbers | `a` (number), `b` (number) |

### 📊 SharePoint Operations

| Tool Name | Description | Parameters |
|-----------|-------------|------------|
| `get_sharepoint_lists` | Retrieves all SharePoint lists | None |
| `get_sharepoint_listitems` | Retrieves items from a specific list | `ListId` (string) |

## 📊 Example Output

```
=== SharePoint MCP Client Starting ===
✅ MCP Client initialized successfully in 125ms
🔍 Found 6 tools in 45ms

🧮 Executing: Addition (Tool: addition)
   ⏱️  Execution time: 23ms
   📝 Content[0]: 2
   ✅ Addition completed successfully

📊 Executing: Get SharePoint Lists (Tool: get_sharepoint_lists)
   ⏱️  Execution time: 456ms
   📝 Content[0]: [{"id":"abc123","title":"Documents"}]
   ✅ SharePoint lists retrieved successfully
```

## 🛠️ Development

### Building the Project

```bash
# Debug build
dotnet build

# Release build
dotnet build --configuration Release
```

### Adding New Tool Demonstrations

To add a new tool demonstration, use the following pattern in `Program.cs`:

```csharp
await ExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
```

Example:
```csharp
await ExecuteToolWithLogging(
    client, 
    "get_sharepoint_lists", 
    new { }, 
    "Get SharePoint Lists"
);
```

### Project Structure

```
SharePointMcpClient/
├── Program.cs                    # Main application entry point
├── SharePointMcpClient.csproj    # Project configuration
├── README.md                     # Documentation (this file)
├── bin/                          # Compiled binaries
│   └── Debug/
│       └── net9.0/
└── obj/                          # Build artifacts
```

### Code Style Guidelines

- Use `async/await` for asynchronous operations
- Include proper error handling and logging
- Follow C# naming conventions
- Add XML documentation for public methods

## 📦 Dependencies

- **[MCPSharp](https://www.nuget.org/packages/MCPSharp)** (v1.0.11) - MCP client implementation
- **.NET 9.0** - Runtime framework
- **System.Text.Json** - JSON serialization (included in .NET)

## 🔍 Troubleshooting

### Common Issues

**❌ Server Connection Failed**
- Ensure the SharePoint MCP Server is built and the path in `Program.cs` is correct
- Verify the server executable has proper permissions

**❌ Tool Execution Failed**
- Check if the SharePoint MCP Server is responding
- Verify tool parameters are correctly formatted

**❌ .NET Version Issues**
- Ensure .NET 9.0 SDK is properly installed
- Run `dotnet --version` to verify installation

### Debug Mode

To enable detailed debugging, modify the logging level in `Program.cs`:

```csharp
// Add more detailed logging for troubleshooting
Console.WriteLine($"[DEBUG] Executing tool: {toolName}");
Console.WriteLine($"[DEBUG] Parameters: {JsonSerializer.Serialize(parameters)}");
```

---

## 🌏 中文说明

### SharePoint MCP 客户端

这是一个演示如何使用 MCPSharp 库与 SharePoint 进行 MCP (模型上下文协议) 集成的控制台应用程序。该客户端连接到 SharePoint MCP 服务器以执行各种操作，包括数学计算和 SharePoint 数据访问。

### ✨ 功能特性

- 🔗 **MCP 客户端连接** - 与 SharePoint MCP 服务器无缝连接
- 🔍 **工具发现** - 自动发现和执行可用工具
- 🧮 **数学运算** - 支持基本算术运算（加法、减法、乘法、除法）
- 📊 **SharePoint 集成** - 访问 SharePoint 列表和列表项
- ⚡ **性能监控** - 内置执行时间跟踪和错误处理
- 📝 **详细日志** - 用于调试和监控的综合日志记录

### 📋 系统要求

运行 SharePoint MCP 客户端之前，请确保您有：

- **[.NET 9.0 SDK](https://dotnet.microsoft.com/zh-cn/download/dotnet/9.0)** 或更高版本
- **SharePoint MCP 服务器** - 必须构建并可用
- **MCPSharp 包** - 通过 NuGet 自动安装
- **Windows 环境** - 当前实现所需

### 🚀 快速开始

#### 1. 克隆和设置

```bash
# 导航到项目目录
cd SharePointMcpClient

# 恢复依赖项
dotnet restore
```

#### 2. 配置服务器路径

编辑 `Program.cs` 文件以指定您的 SharePoint MCP 服务器可执行文件路径：

```csharp
var serverPath = @"C:\path\to\SharePointMcpServer\bin\Debug\net9.0\SharePointMcpServer.exe";
```

#### 3. 运行应用程序

```bash
dotnet run
```

### 🔧 可用工具

#### 🧮 数学运算

| 工具名称 | 描述 | 参数 |
|---------|------|------|
| `addition` | 加法运算 | `a` (字符串), `b` (字符串) |
| `subtraction` | 减法运算 | `a` (字符串), `b` (字符串) |
| `multiplication` | 乘法运算 | `a` (数字), `b` (数字) |
| `division` | 除法运算 | `a` (数字), `b` (数字) |

#### 📊 SharePoint 操作

| 工具名称 | 描述 | 参数 |
|---------|------|------|
| `get_sharepoint_lists` | 获取所有 SharePoint 列表 | 无 |
| `get_sharepoint_listitems` | 获取特定列表的项目 | `ListId` (字符串) |

### 📊 示例输出

```
=== SharePoint MCP Client Starting ===
✅ MCP Client initialized successfully in 125ms
🔍 Found 6 tools in 45ms

🧮 Executing: Addition (Tool: addition)
   ⏱️  Execution time: 23ms
   📝 Content[0]: 2
   ✅ Addition completed successfully

📊 Executing: Get SharePoint Lists (Tool: get_sharepoint_lists)
   ⏱️  Execution time: 456ms
   📝 Content[0]: [{"id":"abc123","title":"Documents"}]
   ✅ SharePoint lists retrieved successfully
```

### 🛠️ 开发

#### 构建项目

```bash
# 调试构建
dotnet build

# 发布构建
dotnet build --configuration Release
```

#### 添加新的工具演示

要添加新的工具演示，请在 `Program.cs` 中使用以下模式：

```csharp
await ExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
```

### 🔍 故障排除

#### 常见问题

**❌ 服务器连接失败**
- 确保 SharePoint MCP 服务器已构建，且 `Program.cs` 中的路径正确
- 验证服务器可执行文件具有适当的权限

**❌ 工具执行失败**
- 检查 SharePoint MCP 服务器是否正在响应
- 验证工具参数格式是否正确

**❌ .NET 版本问题**
- 确保正确安装了 .NET 9.0 SDK
- 运行 `dotnet --version` 验证安装

### 📦 依赖项

- **[MCPSharp](https://www.nuget.org/packages/MCPSharp)** (v1.0.11) - MCP 客户端实现
- **.NET 9.0** - 运行时框架
- **System.Text.Json** - JSON 序列化（.NET 中包含）
