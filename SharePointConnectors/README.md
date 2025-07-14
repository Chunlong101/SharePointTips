# SharePointConnectors

һ���������ӺͲ��� Microsoft SharePoint �� .NET �⣬ͨ�� Microsoft Graph API �ṩ SharePoint ���ݷ��ʹ��ܡ�

## ��Ŀ����

SharePointConnectors ��һ��רΪ SharePoint ���ɶ���Ƶ� .NET ��⣬�ṩ�˼�ࡢ��Ч���̰߳�ȫ�� SharePoint ���ݷ��ʽӿڡ��ÿ��װ�� Microsoft Graph API �ĸ����ԣ��ṩ�����ܻ��桢�Զ���֤�ʹ�����ȹ��ܡ�

## ��Ҫ����

### ?? ���Ĺ���
- **Azure AD �����֤**: OAuth 2.0 �ͻ���ƾ������֤
- **SharePoint վ�����**: ��ȡվ���б���б���
- **�������ƻ���**: �Զ�����������ƵĻ����ˢ��
- **�̰߳�ȫ**: ֧�ֲ������ʵ��̰߳�ȫ���
- **������**: ��ϸ���쳣��Ϣ�ʹ��������

### ??? ��ȫ����
- ���������Զ������ˢ��
- ��ǰ 5 ���ӵ����ƹ��ڻ���ʱ��
- ���⻧�Ͷ�Ӧ��֧��

### ? �����Ż�
- HTTP �ͻ��˸���
- �ӳٳ�ʼ�� (Lazy Initialization)
- ���ܻ������
- �����õ�����ʱ

## ����ջ

- **.NET 9**: ���µ� .NET ���
- **RestSharp** (v112.1.0): HTTP �ͻ��˿�
- **System.Text.Json**: JSON ���л�/�����л�

## ��Ŀ�ṹ

```
SharePointConnectors/
������ GraphConnector.cs                    # ��Ҫ��������
������ SharePointConnectors.csproj          # ��Ŀ�ļ�
������ README.md                           # ��Ŀ�ĵ�
```

## ���ٿ�ʼ

### ��װ

�����Ŀ���ã�
```xml
<ProjectReference Include="path/to/SharePointConnectors.csproj" />
```

����Ϊ NuGet ����װ������ѷ�������
```bash
dotnet add package SharePointConnectors
```

### ����ʹ��

#### 1. ����������

```csharp
using SharePointConnectors;

// �������Ӳ���
GraphConnector.Configure(config =>
{
    config.TenantId = "your-tenant-id";
    config.ClientId = "your-client-id";
    config.ClientSecret = "your-client-secret";
    config.SiteId = "your-site-id";
    config.RequestTimeout = TimeSpan.FromMinutes(2);
});
```

#### 2. ��ȡ��������

```csharp
// ʹ��Ĭ�����û�ȡ����
string token = await GraphConnector.GetAccessTokenAsync();

// ��ָ���ض�����
string token = await GraphConnector.GetAccessTokenAsync(
    tenantId: "custom-tenant-id",
    clientId: "custom-client-id", 
    clientSecret: "custom-client-secret"
);
```

#### 3. ��ȡ SharePoint վ���б�

```csharp
// ʹ��Ĭ������
string listsJson = await GraphConnector.GetSiteListsAsync();

// ��ָ������
string listsJson = await GraphConnector.GetSiteListsAsync(
    accessToken: token,
    siteId: "specific-site-id"
);
```

#### 4. ��ȡ�б���

```csharp
string listItemsJson = await GraphConnector.GetListItemsAsync("list-id");

// ����������
string listItemsJson = await GraphConnector.GetListItemsAsync(
    listId: "your-list-id",
    accessToken: token,
    siteId: "your-site-id"
);
```

## API �ο�

### GraphConnectorConfiguration

�����࣬�������б�Ҫ�����Ӳ�����

```csharp
public class GraphConnectorConfiguration
{
    public string TenantId { get; set; }           // Azure AD �⻧ ID
    public string ClientId { get; set; }           // Ӧ�ó���ͻ��� ID  
    public string ClientSecret { get; set; }       // �ͻ�����Կ
    public string SiteId { get; set; }            // SharePoint վ�� ID
    public TimeSpan TokenCacheTimeout { get; set; } // ���ƻ��泬ʱʱ��
    public TimeSpan RequestTimeout { get; set; }    // ����ʱʱ��
}
```

### GraphConnector ��Ҫ����

#### Configure(Action\<GraphConnectorConfiguration\> configure)
��������������

#### GetAccessTokenAsync(string? tenantId, string? clientId, string? clientSecret)
��ȡ��ˢ�� Azure AD ��������
- ����: `Task<string>` - ��������

#### GetSiteListsAsync(string? accessToken, string? siteId)  
��ȡ SharePoint վ���е������б�
- ����: `Task<string>` - �����б���Ϣ�� JSON �ַ���

#### GetListItemsAsync(string listId, string? accessToken, string? siteId)
��ȡ SharePoint �б��е�������Ŀ
- ����: `listId` - ������б� ID
- ����: `Task<string>` - �����б���� JSON �ַ���

#### ClearTokenCache()
������л���ķ�������

#### Dispose()
�ͷ� HTTP �ͻ�����Դ

### �쳣����

#### GraphConnectorException
�Զ����쳣�࣬�ṩ��ϸ�Ĵ�����Ϣ��

```csharp
public class GraphConnectorException : Exception
{
    public HttpStatusCode? StatusCode { get; }      // HTTP ״̬��
    public string? ResponseContent { get; }         // HTTP ��Ӧ����
}
```

## �߼��÷�

### ���⻧֧��

```csharp
// Ϊ��ͬ�⻧��ȡ����
var tenant1Token = await GraphConnector.GetAccessTokenAsync("tenant1-id", "client1-id", "secret1");
var tenant2Token = await GraphConnector.GetAccessTokenAsync("tenant2-id", "client2-id", "secret2");
```

### ���������ʵ��

```csharp
try
{
    var lists = await GraphConnector.GetSiteListsAsync();
    // ����ɹ���Ӧ
}
catch (GraphConnectorException ex)
{
    Console.WriteLine($"Graph API ����: {ex.Message}");
    Console.WriteLine($"״̬��: {ex.StatusCode}");
    Console.WriteLine($"��Ӧ����: {ex.ResponseContent}");
}
catch (ArgumentException ex)
{
    Console.WriteLine($"��������: {ex.Message}");
}
```

### �����Ż�����

1. **����������**: GraphConnector �Ǿ�̬�࣬�Զ����� HTTP �ͻ���
2. **�ʵ��ĳ�ʱ����**: ��������������� RequestTimeout
3. **���ƻ���**: ���Զ��������ƣ������ֶ�����
4. **��Դ����**: Ӧ�ó������ʱ���� `GraphConnector.Dispose()`

## ����Ҫ��

### Azure AD Ӧ��ע��

1. �� Azure Portal ��ע��Ӧ�ó���
2. ���� API Ȩ�ޣ�
   - `Sites.Read.All` - ��ȡվ��
   - `Sites.ReadWrite.All` - ��дվ�㣨����Ҫ��
3. ���ɿͻ�����Կ
4. ��¼�⻧ ID���ͻ��� ID �Ϳͻ�����Կ

### SharePoint Ȩ��

ȷ��ע���Ӧ�ó�����з���Ŀ�� SharePoint վ���Ȩ�ޡ�

## �̰߳�ȫ

�ÿ���ȫ�̰߳�ȫ�������ڶ��̻߳����а�ȫʹ�ã�
- ʹ�� `ConcurrentDictionary` �������ƻ���
- HTTP �ͻ���ʵ�����̰߳�ȫ��
- ���й������������Բ�������

## �������

### ���ƻ���
- �Զ������������
- �������ʽ��`"{tenantId}:{clientId}"`
- ֧�ֶ��⻧����
- ��ǰ 5 ���ӹ����Ա���ʹ�ü������ڵ�����

### HTTP �ͻ��˻���
- ʹ�� `Lazy<RestClient>` �ӳٳ�ʼ��
- �ֱ𻺴���֤�ͻ��˺� Graph API �ͻ���
- �Զ������������������

## �����ų�

### ��������

1. **��֤ʧ��**
   - ����⻧ ID���ͻ��� ID �Ϳͻ�����Կ
   - ȷ��Ӧ�ó�����б�Ҫ�� API Ȩ��

2. **վ�����ʧ��**
   - ��֤վ�� ID �Ƿ���ȷ
   - ȷ��Ӧ�ó����վ��ķ���Ȩ��

3. **��ʱ����**
   - ���� `RequestTimeout` ����
   - �����������

### ���Խ���

������ϸ��־��¼�Ի�ȡ���������Ϣ��

```csharp
try
{
    var result = await GraphConnector.GetSiteListsAsync();
}
catch (GraphConnectorException ex)
{
    // ��¼�������쳣��Ϣ
    Console.WriteLine($"��������: {ex.Message}");
    Console.WriteLine($"HTTP ״̬: {ex.StatusCode}");
    Console.WriteLine($"��Ӧ����: {ex.ResponseContent}");
}
```

## ������

- **RestSharp** (112.1.0): HTTP �ͻ��˿�
- **.NET 9**: Ŀ����

## �汾��ʷ

- **1.0.0**: ��ʼ�汾
  - ������ SharePoint ���ӹ���
  - ���ƻ���͹���
  - ���������

## ���֤

[������֤��Ϣ]

## ����

��ӭ���״��룡����ѭ���²��裺

1. Fork �òֿ�
2. �������ܷ�֧
3. �ύ����
4. ���� Pull Request

## ֧��

����������飬��ͨ�����·�ʽ��ϵ��
[�����ϵ��Ϣ]

---

**ע��**: ��ȷ�����Ʊ������Ŀͻ�����Կ������������Ϣ����Ҫ�����ύ���汾����ϵͳ�С�