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
- [����˵��](#-����˵��)

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
������ Program.cs              # Main application entry point
������ SharePointMcpClient.csproj  # Project file
������ README.md              # This file
## ?? Dependencies

- [MCPSharp](https://www.nuget.org/packages/MCPSharp) (v1.0.11)
- .NET 9.0

---

## ???? ����˵��

### SharePoint MCP �ͻ���

һ����ʾ���ʹ�� MCPSharp ���� SharePoint ���� MCP (ģ��������Э��) ���ɵĿ���̨Ӧ�ó���

### ��������

- ?? �� SharePoint �������� MCP �ͻ�������
- ?? ���߷��ֺ�ִ��
- ?? ��ѧ���� (�ӷ����������˷�������)
- ?? SharePoint ���ݷ��� (�б���б���)
- ? ���ܼ�غʹ�����

### ϵͳҪ��

- [.NET 9.0](https://dotnet.microsoft.com/zh-cn/download/dotnet/9.0)
- SharePoint MCP ������������
- MCPSharp �� (�Զ���װ)

### ���ٿ�ʼ

1. **��װ������:**dotnet restore
2. **�� `Program.cs` �����÷�����·��:**var serverPath = "path/to/SharePointMcpServer.exe";
3. **����Ӧ�ó���:**dotnet run
### ���ù���

#### ��ѧ����
- `addition` - �ӷ�����
- `subtraction` - ��������
- `multiplication` - �˷�����
- `division` - ��������

#### SharePoint ����
- `get_sharepoint_lists` - ��ȡ SharePoint �б�
- `get_sharepoint_listitems` - ��ȡ�ض� SharePoint �б���

### ʾ�����
=== SharePoint MCP Client Starting ===
? MCP Client initialized successfully in 125ms
? Found 6 tools in 45ms

?? Executing: Addition (Tool: addition)
   ??  Execution time: 23ms
   ?? Content[0]: 2
   ? Addition completed successfully
### ����

**������Ŀ:**dotnet build
**����µĹ�����ʾ:**
ExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
### ������

- [MCPSharp](https://www.nuget.org/packages/MCPSharp) (v1.0.11)
- .NET 9.0