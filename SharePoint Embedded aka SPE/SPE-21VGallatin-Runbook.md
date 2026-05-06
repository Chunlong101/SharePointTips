# 跑通 SharePoint Embedded（21Vianet / Gallatin）实操记录

## 1. 注册 App

`portal.azure.cn` → App registrations → New registration。

API permissions 里加（application/delegated 权限）：
- `FileStorageContainer.Selected`
- `FileStorageContainerTypeReg.Selected`

记录 `ClientId` / `TenantId` / `ClientSecret`。

进入 Entra 门户的 App registrations 列表页，点击右上角的 New registration 开始新建应用：

![Entra 门户 → App registrations 列表页，点击 New registration](image.png)

在 New registration 表单中填写应用名称，然后点击 Register：

![New registration 表单：填名称、选 Single tenant](image-1.png)

添加权限：

![添加权限](image-2.png)

切到 API permissions 页面，点击 Add a permission，选择 Microsoft Graph：

![API permissions → Add a permission → 选 Microsoft Graph](image-3.png)

Admin Consent 刚才添加的4个权限：

![Admin Consent 刚才添加的4个权限](image-4.png)

创建Client Secret：

![创建 Client Secret](image-5.png)

请记住Client Secret的过期时间：

![请记住Client Secret的过期时间](image-6.png)

请记录Client Secret的值，页面刷新后无法再次查看：

![请记录Client Secret的值](image-7.png)

请记录 Client Id 以及 Tenant Id，后续步骤会用到：

![请记录 Client Id 以及 Tenant Id](image-8.png)

## 2. 创建 Container Type

```powershell
Connect-SPOService -Url https://xxx-admin.sharepoint.cn -Region China

$ct = New-SPOContainerType `
    -ContainerTypeName "TestContainerTypeName" `
    -OwningApplicationId "{{SPEClientId}}" `
    -TrialContainerType

$ct.ContainerTypeId

Guid
----
{{SPEContainerTypeId}}
```

## 3. Admin Consent

全局管理员浏览器打开：

```
https://login.partner.microsoftonline.cn/{{SPETenantId}}/v2.0/adminconsent
  ?client_id={{SPEClientId}}
  &scope=https://microsoftgraph.chinacloudapi.cn/.default
  &redirect_uri=http://localhost
```

## 4. Get Access Token

```http
POST https://login.partner.microsoftonline.cn/{{SPETenantId}}/oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={{SPEClientId}}
&client_secret={{SPEClientSecret}}
&scope=https://microsoftgraph.chinacloudapi.cn/.default
```

使用 Postman 通过 client_credentials flow 调用 token 端点，成功后会返回 access_token。

![Postman 调用 token 端点示例（client_credentials flow）](image-9.png)

## 5. 注册 Container Type 权限

```http
PUT {{21VGraphBase}}/beta/storage/fileStorage/containerTypeRegistrations/{{SPEContainerTypeId}}

{
  "applicationPermissionGrants": [
    {
      "appId": "{{SPEClientId}}",
      "delegatedPermissions":  ["full"],
      "applicationPermissions": ["full"]
    }
  ]
}
```

## 6. 创建 Container

```http
POST {{21VGraphBase}}/v1.0/storage/fileStorage/containers

{
  "displayName": "SPEContainerTest",
  "containerTypeId": "{{SPEContainerTypeId}}"
}
```

## 7. Upload the file to container

```http
PUT {{21VGraphBase}}/v1.0/drives/{{SPEContainerId}}/root:/SPETest.txt:/content
Content-Type: application/octet-stream

Body includes the <binary>
```

## 8. 验证 — Get Container Files

```http
GET {{21VGraphBase}}/v1.0/drives/{{SPEContainerId}}/root/children
```

查看 GET children 返回的 JSON 响应，列表里能看到 SPETest.txt 即表示上传成功。

![GET children 返回的 JSON 响应，能看到 SPETest.txt 即成功](image-10.png)

---

## 变量速查

| 变量 | 说明 |
|---|---|
| `21VGraphBase` | `https://microsoftgraph.chinacloudapi.cn` |
| `SPETenantId` | Owning / Consuming SPE 的 Tenant ID |
| `SPEClientId` | 第 1 步注册的 App 的 Client ID |
| `SPEClientSecret` | 第 1 步生成的 Client Secret |
| `SPEContainerTypeId` | 第 2 步 `$ct.ContainerTypeId` 返回的 GUID |
| `SPEContainerId` | 第 6 步返回的 `id` |