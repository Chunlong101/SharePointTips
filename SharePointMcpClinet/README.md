# SharePoint MCP Client

A console application that demonstrates MCP (Model Context Protocol) integration with SharePoint using the MCPSharp library.

## Features

- MCP client connection to SharePoint server
- Tool discovery and execution
- Mathematical operations (addition, subtraction, multiplication, division)
- SharePoint data access (lists and list items)
- Performance monitoring and error handling

## Prerequisites

- .NET 9.0
- SharePoint MCP Server running
- MCPSharp package (auto-installed)

## Quick Start

1. **Install dependencies:**dotnet restore
2. **Configure server path in `Program.cs`:**var serverPath = "path/to/SharePointMcpServer.exe";
3. **Run the application:**dotnet run

## Available Tools

- **Math Operations**: `addition`, `subtraction`, `multiplication`, `division`
- **SharePoint**: `get_sharepoint_lists`, `get_sharepoint_listitems`

## Example Output
=== SharePoint MCP Client Starting ===
? MCP Client initialized successfully in 125ms
? Found 6 tools in 45ms

?? Executing: Addition (Tool: addition)
   ??  Execution time: 23ms
   ?? Content[0]: 2
   ? Addition completed successfully
## Development

**Build:**dotnet build
**Add new tool demonstration:**ExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
## Dependencies

- MCPSharp (v1.0.11)
- .NET 9.0

---

# SharePoint MCP 客户端

一个演示如何使用 MCPSharp 库与 SharePoint 进行 MCP (模型上下文协议) 集成的控制台应用程序。

## 功能特性

- 与 SharePoint 服务器的 MCP 客户端连接
- 工具发现和执行
- 数学运算 (加法、减法、乘法、除法)
- SharePoint 数据访问 (列表和列表项)
- 性能监控和错误处理

## 系统要求

- .NET 9.0
- SharePoint MCP 服务器运行中
- MCPSharp 包 (自动安装)

## 快速开始

1. **安装依赖项:**dotnet restore
2. **在 `Program.cs` 中配置服务器路径:**var serverPath = "path/to/SharePointMcpServer.exe";
3. **运行应用程序:**dotnet run
## 可用工具

- **数学运算**: `addition`, `subtraction`, `multiplication`, `division`
- **SharePoint**: `get_sharepoint_lists`, `get_sharepoint_listitems`

## 示例输出
=== SharePoint MCP Client Starting ===
? MCP Client initialized successfully in 125ms
? Found 6 tools in 45ms

?? Executing: Addition (Tool: addition)
   ??  Execution time: 23ms
   ?? Content[0]: 2
   ? Addition completed successfully
## 开发

**构建:**dotnet build
**添加新的工具演示:**
ExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
## 依赖项

- MCPSharp (v1.0.11)
- .NET 9.0