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

# SharePoint MCP �ͻ���

һ����ʾ���ʹ�� MCPSharp ���� SharePoint ���� MCP (ģ��������Э��) ���ɵĿ���̨Ӧ�ó���

## ��������

- �� SharePoint �������� MCP �ͻ�������
- ���߷��ֺ�ִ��
- ��ѧ���� (�ӷ����������˷�������)
- SharePoint ���ݷ��� (�б���б���)
- ���ܼ�غʹ�����

## ϵͳҪ��

- .NET 9.0
- SharePoint MCP ������������
- MCPSharp �� (�Զ���װ)

## ���ٿ�ʼ

1. **��װ������:**dotnet restore
2. **�� `Program.cs` �����÷�����·��:**var serverPath = "path/to/SharePointMcpServer.exe";
3. **����Ӧ�ó���:**dotnet run
## ���ù���

- **��ѧ����**: `addition`, `subtraction`, `multiplication`, `division`
- **SharePoint**: `get_sharepoint_lists`, `get_sharepoint_listitems`

## ʾ�����
=== SharePoint MCP Client Starting ===
? MCP Client initialized successfully in 125ms
? Found 6 tools in 45ms

?? Executing: Addition (Tool: addition)
   ??  Execution time: 23ms
   ?? Content[0]: 2
   ? Addition completed successfully
## ����

**����:**dotnet build
**����µĹ�����ʾ:**
ExecuteToolWithLogging(client, "tool_name", parameters, "Display Name");
## ������

- MCPSharp (v1.0.11)
- .NET 9.0