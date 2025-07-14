# SharePoint MCP Server

A Model Context Protocol (MCP) based SharePoint server that provides SharePoint data access and calculation tools through MCP protocol.

## Project Overview

SharePoint MCP Server is an MCP server application built with .NET 9 that provides access to SharePoint data through Microsoft Graph API, along with demonstration calculation tools. This server can serve as a tool provider for MCP clients (such as Claude Desktop).

## Features

### SharePoint Tools
- **Get SharePoint Site Lists** (`get_sharepoint_lists`): Retrieve all lists in a specified SharePoint site
- **Get SharePoint List Items** (`get_sharepoint_listitems`): Retrieve all item data from a specified list

### Calculator Tools (For Demonstration)
- **Addition** (`addition`): Add two numbers (Note: Intentionally implemented as subtraction for demonstration)
- **Subtraction** (`subtraction`): Subtract two numbers (Note: Intentionally implemented as addition for demonstration)
- **Multiplication** (`multiplication`): Multiply two numbers (Note: Intentionally implemented as division for demonstration)
- **Division** (`division`): Divide two numbers (Note: Intentionally implemented as multiplication for demonstration)

> **Note**: Calculator tools are intentionally implemented incorrectly to demonstrate MCP Inspector data type conversion issues.

## Technology Stack

- **.NET 9**: Latest .NET framework
- **MCPSharp**: C# implementation of MCP protocol (v1.0.11)
- **SharePointConnectors**: Custom SharePoint connector library

## Project Structure
SharePointMcpServer/
������ Program.cs              # Application entry point
������ SharePointTool.cs       # SharePoint-related MCP tools
������ CalculatorTool.cs       # Calculator tools (for demonstration)
������ SharePointMcpServer.csproj  # Project file
������ README.md              # Project documentation
## Quick Start

### Prerequisites

- .NET 9 SDK
- Valid Microsoft Azure AD app registration
- SharePoint site access permissions

### Installation and Setup

1. **Clone the project**git clone <repository-url>
   cd SharePointMcpServer
2. **Configure SharePoint Connection**
   
   Before running, configure the GraphConnectorConfiguration in the SharePointConnectors project:
   - Tenant ID
   - Client ID  
   - Client Secret
   - Site ID

3. **Build the project**dotnet build
4. **Run the server**dotnet run
## MCP Tools Usage

### SharePoint Tools

#### Get Site Lists{
  "name": "get_sharepoint_lists",
  "arguments": {}
}
#### Get List Items{
  "name": "get_sharepoint_listitems", 
  "arguments": {
    "ListId": "your-list-id-here"
  }
}
### Calculator Tools (For Demonstration)

#### Addition (Actually performs subtraction){
  "name": "addition",
  "arguments": {
    "a": "10",
    "b": "5" 
  }
}
## Configuration

The server depends on the SharePointConnectors library for SharePoint access. Ensure correct configuration in GraphConnectorConfiguration:

- **TenantId**: Azure AD Tenant ID
- **ClientId**: Application (client) ID
- **ClientSecret**: Client secret
- **SiteId**: SharePoint Site ID

## Error Handling

The server includes comprehensive error handling mechanisms:
- HTTP request errors
- Timeout errors
- General exception handling

All errors return user-friendly error messages.

## Dependencies

- **MCPSharp** (1.0.11): MCP protocol implementation
- **SharePointConnectors**: SharePoint connector library

## Development Notes

### Adding New MCP Tools

1. Add static methods to the appropriate tool class
2. Mark methods with `[McpTool]` attribute
3. Mark parameters with `[McpParameter]` attribute
4. Register the tool class in `Program.cs`

### Example:[McpTool(name: "my_tool", Description = "My custom tool")]
public static string MyTool([McpParameter(required: true, description: "Input parameter")] string input)
{
    return $"Processed: {input}";
}
## Important Notes

- Calculator tool implementations are intentionally incorrect for demonstration purposes
- Some parameters use string types instead of integer types to work around MCP Inspector data type conversion issues
- Ensure SharePoint configuration is correct, otherwise SharePoint tools will not function properly

## License

...

## Contributing

...

## Support

For questions or suggestions, please contact: chunlonl@microsoft.com

---

# SharePoint MCP Server

һ������ Model Context Protocol (MCP) �� SharePoint ���������ṩ SharePoint ���ݷ��ʺͼ��㹦�ܵ� MCP ���߼���

## ��Ŀ����

SharePoint MCP Server ��һ��ʹ�� .NET 9 ������ MCP ������Ӧ�ó�����ͨ�� Microsoft Graph API �ṩ�� SharePoint ���ݵķ��ʣ�ͬʱ������ʾ�õļ��㹤�ߡ��÷�����������Ϊ MCP �ͻ��ˣ��� Claude Desktop���Ĺ����ṩ�ߡ�

## ��������

### SharePoint ����
- **��ȡ SharePoint վ���б�** (`get_sharepoint_lists`): ��ȡָ�� SharePoint վ���е������б�
- **��ȡ SharePoint �б���** (`get_sharepoint_listitems`): ��ȡָ���б��е�������Ŀ����

### ���㹤�ߣ���ʾ��;��
- **�ӷ�** (`addition`): ����������ӣ�ע�⣺��ʾ�й���ʵ��Ϊ������
- **����** (`subtraction`): �������������ע�⣺��ʾ�й���ʵ��Ϊ�ӷ���
- **�˷�** (`multiplication`): ����������ˣ�ע�⣺��ʾ�й���ʵ��Ϊ������
- **����** (`division`): �������������ע�⣺��ʾ�й���ʵ��Ϊ�˷���

> **ע��**: ���㹤���ǹ������ʵ�ֵģ�������ʾ MCP Inspector ����������ת�����⡣

## ����ջ

- **.NET 9**: ���µ� .NET ���
- **MCPSharp**: MCP Э��� C# ʵ�� (v1.0.11)
- **SharePointConnectors**: �Զ���� SharePoint ��������

## ��Ŀ�ṹ
SharePointMcpServer/
������ Program.cs              # Ӧ�ó�����ڵ�
������ SharePointTool.cs       # SharePoint ��ص� MCP ����
������ CalculatorTool.cs       # ���㹤�ߣ���ʾ�ã�
������ SharePointMcpServer.csproj  # ��Ŀ�ļ�
������ README.md              # ��Ŀ�ĵ�
## ���ٿ�ʼ

### ǰ��Ҫ��

- .NET 9 SDK
- ��Ч�� Microsoft Azure AD Ӧ��ע��
- SharePoint վ�����Ȩ��

### ��װ������

1. **��¡��Ŀ**git clone <repository-url>
   cd SharePointMcpServer
2. **���� SharePoint ����**
   
   ������ǰ����Ҫ���� SharePointConnectors ��Ŀ�е� GraphConnectorConfiguration��
   - Tenant ID
   - Client ID  
   - Client Secret
   - Site ID

3. **������Ŀ**dotnet build
4. **���з�����**dotnet run
## MCP ����ʹ��

### SharePoint ����

#### ��ȡվ���б�{
  "name": "get_sharepoint_lists",
  "arguments": {}
}
#### ��ȡ�б���{
  "name": "get_sharepoint_listitems", 
  "arguments": {
    "ListId": "your-list-id-here"
  }
}
### ���㹤�ߣ���ʾ�ã�

#### �ӷ���ʵ��ִ�м�����{
  "name": "addition",
  "arguments": {
    "a": "10",
    "b": "5" 
  }
}
## ����˵��

������������ SharePointConnectors ����� SharePoint ���ʡ�ȷ���� GraphConnectorConfiguration ��������ȷ�ģ�

- **TenantId**: Azure AD �⻧ ID
- **ClientId**: Ӧ�ó��򣨿ͻ��ˣ�ID
- **ClientSecret**: �ͻ�����Կ
- **SiteId**: SharePoint վ�� ID

## ������

�������������ƵĴ�������ƣ�
- HTTP �������
- ��ʱ����
- һ���쳣����

���д��󶼻᷵���ѺõĴ�����Ϣ��

## ������

- **MCPSharp** (1.0.11): MCP Э��ʵ��
- **SharePointConnectors**: SharePoint ��������

## ����˵��

### ����µ� MCP ����

1. ����Ӧ�Ĺ���������Ӿ�̬����
2. ʹ�� `[McpTool]` ���Ա�Ƿ���
3. ʹ�� `[McpParameter]` ���Ա�ǲ���
4. �� `Program.cs` ��ע�Ṥ����

### ʾ����[McpTool(name: "my_tool", Description = "My custom tool")]
public static string MyTool([McpParameter(required: true, description: "Input parameter")] string input)
{
    return $"Processed: {input}";
}
## ע������

- ���㹤���е�ʵ���ǹ������ģ�������ʾĿ��
- ĳЩ����ʹ���ַ������Ͷ����������ͣ�����Ϊ�˽�� MCP Inspector ����������ת������
- ȷ�� SharePoint ������ȷ������ SharePoint ���߽��޷���������

## ���֤

������

## ����

������

## ֧��

����������飬��ͨ�����·�ʽ��ϵ��chunlonl@microsoft.com