# SharePoint MCP Client

[![.NET Version](https://img.shields.io/badge/.NET-9.0-blue)](https://dotnet.microsoft.com/download/dotnet/9.0)
[![MCPSharp](https://img.shields.io/badge/MCPSharp-v1.0.11-green)](https://www.nuget.org/packages/MCPSharp)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A console application that demonstrates MCP (Model Context Protocol) integration with SharePoint using the MCPSharp library.

## ?? Table of Contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Available Tools](#-available-tools)
- [Example Output](#-example-output)
- [Development](#-development)
- [Dependencies](#-dependencies)
- [中文说明](#-中文说明)

## ? Features

- ?? MCP client connection to SharePoint server
- ?? Tool discovery and execution
- ?? Mathematical operations (addition, subtraction, multiplication, division)
- ?? SharePoint data access (lists and list items)
- ? Performance monitoring and error handling

## ?? Prerequisites

- [.NET 9.0](https://dotnet.microsoft.com/download/dotnet/9.0)
- SharePoint MCP Server running
- MCPSharp package (auto-installed)

## ?? Quick Start

1. **Install dependencies:**dotnet restore
2. **Configure server path in `Program.cs`:**var serverPath = "path/to/SharePointMcpServer.exe";
3. **Run the application:**dotnet run
## ??? Available Tools

### Math Operations
- `addition` - Adds two numbers
- `subtraction` - Subtracts two numbers
- `multiplication` - Multiplies two numbers
- `division` - Divides two numbers

### SharePoint Operations
- `get_sharepoint_lists` - Retrieves SharePoint lists
- `get_sharepoint_listitems` - Retrieves items from a specific SharePoint list

## ?? Example Output
=== SharePoint MCP Client Starting ===
? MCP Client initialized successfully in 125ms
? Found 6 tools in 45ms

?? Executing: Addition (Tool: addition)
   ??  Execution time: 23ms
   ?? Content[0]: 2
   ? Addition completed successfully
## ?? Development

### Build the projectdotnet build
### Add new tool demonstrationExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
### Project StructureSharePointMcpClient/
├── Program.cs              # Main application entry point
├── SharePointMcpClient.csproj  # Project file
└── README.md              # This file
## ?? Dependencies

- [MCPSharp](https://www.nuget.org/packages/MCPSharp) (v1.0.11)
- .NET 9.0

---

## ???? 中文说明

### SharePoint MCP 客户端

一个演示如何使用 MCPSharp 库与 SharePoint 进行 MCP (模型上下文协议) 集成的控制台应用程序。

### 功能特性

- ?? 与 SharePoint 服务器的 MCP 客户端连接
- ?? 工具发现和执行
- ?? 数学运算 (加法、减法、乘法、除法)
- ?? SharePoint 数据访问 (列表和列表项)
- ? 性能监控和错误处理

### 系统要求

- [.NET 9.0](https://dotnet.microsoft.com/zh-cn/download/dotnet/9.0)
- SharePoint MCP 服务器运行中
- MCPSharp 包 (自动安装)

### 快速开始

1. **安装依赖项:**dotnet restore
2. **在 `Program.cs` 中配置服务器路径:**var serverPath = "path/to/SharePointMcpServer.exe";
3. **运行应用程序:**dotnet run
### 可用工具

#### 数学运算
- `addition` - 加法运算
- `subtraction` - 减法运算
- `multiplication` - 乘法运算
- `division` - 除法运算

#### SharePoint 操作
- `get_sharepoint_lists` - 获取 SharePoint 列表
- `get_sharepoint_listitems` - 获取特定 SharePoint 列表项

### 示例输出
=== SharePoint MCP Client Starting ===
? MCP Client initialized successfully in 125ms
? Found 6 tools in 45ms

?? Executing: Addition (Tool: addition)
   ??  Execution time: 23ms
   ?? Content[0]: 2
   ? Addition completed successfully
### 开发

**构建项目:**dotnet build
**添加新的工具演示:**
ExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
### 依赖项

- [MCPSharp](https://www.nuget.org/packages/MCPSharp) (v1.0.11)
- .NET 9.0