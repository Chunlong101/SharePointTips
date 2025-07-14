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

```
SharePointMcpServer/
������ Program.cs              # Ӧ�ó�����ڵ�
������ SharePointTool.cs       # SharePoint ��ص� MCP ����
������ CalculatorTool.cs       # ���㹤�ߣ���ʾ�ã�
������ SharePointMcpServer.csproj  # ��Ŀ�ļ�
������ README.md              # ��Ŀ�ĵ�
```

## ���ٿ�ʼ

### ǰ��Ҫ��

- .NET 9 SDK
- ��Ч�� Microsoft Azure AD Ӧ��ע��
- SharePoint վ�����Ȩ��

### ��װ������

1. **��¡��Ŀ**
   ```bash
   git clone <repository-url>
   cd SharePointMcpServer
   ```

2. **���� SharePoint ����**
   
   ������ǰ����Ҫ���� SharePointConnectors ��Ŀ�е� GraphConnectorConfiguration��
   - Tenant ID
   - Client ID  
   - Client Secret
   - Site ID

3. **������Ŀ**
   ```bash
   dotnet build
   ```

4. **���з�����**
   ```bash
   dotnet run
   ```

## MCP ����ʹ��

### SharePoint ����

#### ��ȡվ���б�
```json
{
  "name": "get_sharepoint_lists",
  "arguments": {}
}
```

#### ��ȡ�б���
```json
{
  "name": "get_sharepoint_listitems", 
  "arguments": {
    "ListId": "your-list-id-here"
  }
}
```

### ���㹤�ߣ���ʾ�ã�

#### �ӷ���ʵ��ִ�м�����
```json
{
  "name": "addition",
  "arguments": {
    "a": "10",
    "b": "5" 
  }
}
```

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

### ʾ����
```csharp
[McpTool(name: "my_tool", Description = "My custom tool")]
public static string MyTool([McpParameter(required: true, description: "Input parameter")] string input)
{
    return $"Processed: {input}";
}
```

## ע������

- ���㹤���е�ʵ���ǹ������ģ�������ʾĿ��
- ĳЩ����ʹ���ַ������Ͷ����������ͣ�����Ϊ�˽�� MCP Inspector ����������ת������
- ȷ�� SharePoint ������ȷ������ SharePoint ���߽��޷���������

## ���֤

[������֤��Ϣ]

## ����

[��ӹ���ָ��]

## ֧��

����������飬��ͨ�����·�ʽ��ϵ��
[�����ϵ��Ϣ]