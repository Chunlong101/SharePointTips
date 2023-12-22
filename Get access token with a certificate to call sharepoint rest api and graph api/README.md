# Obtaining Access Token for SharePoint REST API and Microsoft Graph API with Certificates

This article demonstrates how to obtain an Access Token using certificates and use that Access Token to call SharePoint REST API and Microsoft Graph API.

## Step 1: Azure AD App Registration

Register your application in Azure AD App Registration and ensure that the application is assigned the appropriate permissions. Please note the following:

a. If you want to obtain an Access Token to call Microsoft Graph API, grant the corresponding Graph permissions to the application.

b. If you want to obtain an Access Token to call SharePoint REST API, grant the appropriate SharePoint permissions to the application.

c. You can also use `sites.selected` in a hybrid scenario; refer to [my other article](https://github.com/Chunlong101/SharePointTips/blob/master/Sites.Selected/README.md).

![Azure AD App Permissions](https://github.com/Chunlong101/SharePointTips/assets/9314578/350826ba-121a-45ca-807e-e71db6a9362a)

## Step 2: Upload Certificate

Upload your certificate to Azure AD app registration (you can refer to creating a self-assigned certificate [here](https://github.com/Chunlong101/SharePointTips/blob/master/NewSelfSignedCertificateEx.ps1)). Your certificate should have two formats, pfx and cer. Upload the cer and keep the pfx with the private key locally:

![Upload Certificate](https://github.com/Chunlong101/SharePointTips/assets/9314578/8ed628ea-8d26-4f43-878f-9f4f5543d151)

![Local Certificate](https://github.com/Chunlong101/SharePointTips/assets/9314578/ecd793c5-0621-4370-bde7-8d2f4fac8dc8)

## Step 3: Execute PowerShell Script to Obtain Access Token

```powershell
$password = (ConvertTo-SecureString -AsPlainText 'xxx' -Force)
Connect-PnPOnline -Url "https://5xxsz0.sharepoint.com/sites/test" -ClientId c4941f75-cc4f-4f84-b254-093937eb4b26 -CertificatePath 'C:\Users\chunlonl\Desktop\Tools\Cert\pnp.pfx' -CertificatePassword $password -Tenant '5xxsz0.onmicrosoft.com'
Get-PnPAccessToken -ResourceTypeName SharePoint # Use this token to call SharePoint REST API
Get-PnPAccessToken -ResourceTypeName Graph # Use this token to call Microsoft Graph API
```

-----

-----

-----

# 使用证书获取 SharePoint 和 Microsoft Graph API 的 Access Token

本文演示如何使用证书的方式获取 Access Token，并用该Access Token调用 SharePoint REST API 和 Microsoft Graph API。

## 第一步：Azure AD App 注册

在 Azure AD App 注册中注册应用程序，并确保为该应用程序分配相应的权限。请注意以下事项：

a. 如果您希望获取 Access Token 以调用 Microsoft Graph API，请为应用程序授予相应的 Graph 权限。
b. 如果您希望获取 Access Token 以调用 SharePoint REST API，请为应用程序授予相应的 SharePoint 权限。
c. 您还可以混合使用 `sites.selected`，请参考[我的另一篇文章](https://github.com/Chunlong101/SharePointTips/blob/master/Sites.Selected/README.md)。

![Azure AD App Permissions](https://github.com/Chunlong101/SharePointTips/assets/9314578/350826ba-121a-45ca-807e-e71db6a9362a)

## 第二步：上传证书

上传你的证书到azure ad app registration（可以参考这里自制证书：[here](https://github.com/Chunlong101/SharePointTips/blob/master/NewSelfSignedCertificateEx.ps1)）。你的证书应该有两个格式，pfx 和 cer，上传 cer 格式的证书，保留带有私钥的 pfx 证书在本地：

![Upload Certificate](https://github.com/Chunlong101/SharePointTips/assets/9314578/8ed628ea-8d26-4f43-878f-9f4f5543d151)

![Local Certificate](https://github.com/Chunlong101/SharePointTips/assets/9314578/ecd793c5-0621-4370-bde7-8d2f4fac8dc8)

## 第三步：执行 PowerShell 脚本获取 Access Token

```powershell
$password = (ConvertTo-SecureString -AsPlainText 'xxx' -Force)
Connect-PnPOnline -Url "https://5xxsz0.sharepoint.com/sites/test" -ClientId c4941f75-cc4f-4f84-b254-093937eb4b26 -CertificatePath 'C:\Users\chunlonl\Desktop\Tools\Cert\pnp.pfx' -CertificatePassword $password  -Tenant '5xxsz0.onmicrosoft.com'
Get-PnPAccessToken -ResourceTypeName SharePoint # 使用此令牌调用 SharePoint REST API
Get-PnPAccessToken -ResourceTypeName Graph # 使用此令牌调用 Microsoft Graph API
```
