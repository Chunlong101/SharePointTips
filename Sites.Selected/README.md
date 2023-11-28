# Supplementary Information about Microsoft Graph API `Sites.Selected`

## 1. Getting Started Guide

The following two technical documents will help you quickly get started with Sites.Selected:

- [Develop Applications that Use Sites.Selected Permissions for SharePoint](https://techcommunity.microsoft.com/t5/microsoft-sharepoint-blog/develop-applications-that-use-sites-selected-permissions-for-spo/ba-p/3790476)
- [Updates on Controlling App-Specific Access on Specific SharePoint Sites (Sites.Selected)](https://devblogs.microsoft.com/microsoft365dev/updates-on-controlling-app-specific-access-on-specific-sharepoint-sites-sites-selected/)

## 2. Streamlining the Process

In summary, the entire process of using Sites.Selected includes the following steps:

   a. Register an application in Azure app registration.

   b. Grant the `Sites.Selected` permission to the application in Azure app registration (requires Global Admin Consent).

   c. Bind the application to one or more sites and grant it access to the target site (Read/Write/Manage/FullControl, choose one). This step can be completed in various ways:

       - Register another application in Azure app registration with `Sites.FullControl.All` permission, then use Graph API (`https://graph.microsoft.com/v1.0/sites/{sitesId}/permissions`) or PnP PowerShell + certificate connection (`Connect-PnPOnline -CertificatePat xxx -CertificatePassword xxx`, `Grant-PnPAzureADAppSitePermission`) to accomplish it. (Currently if we're using `Connect-PnPOnline -ClientId xxx -ClientSecret xxx` then it will go to ACS, azure access control service, not what we want, and that's the reason why we use `Connect-PnPOnline -CertificatePat xxx -CertificatePassword xxx`) 

       - Use `Connect-PnPOnline -Url $targetSiteUrl -Interactive + Global Admin` to connect to the target site, then use PnP PowerShell `Grant-PnPAzureADAppSitePermission` to complete the process.

       - Use `Connect-PnPOnline -Url $targetSiteUrl -Interactive + Target Site Collection Admin` to connect to the target site, then use PnP PowerShell `Grant-PnPAzureADAppSitePermission` to complete the process.

   d. Use Graph API (`https://graph.microsoft.com/v1.0/sites/{sitesId}/permissions`) or PnP PowerShell `Get-PnPAzureADAppSitePermission` to view the permissions of the target site.

   e. Use the application to access the target site, either through Graph API or PnP PowerShell.

## 3. Frequently Asked Questions

People asked me some common questions, and I'd like to share the answers:

   a. Is it necessary to have Global Admin involvement when using `Sites.Selected`?

      Answer: Yes, at least Global Admin consent is required to use `Sites.Selected`:

![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/4d48492d-64c4-40ca-b735-22dc54ffacd9)

      Without Global Admin consent, the Access Token will not contain claims about the permissions:

        {
        "aud": "https://graph.microsoft.com",
        "iss": "https://sts.windows.net/311ca363-cc76-4086-93a7-94f6b8f4ae2a/",
        "iat": 1701147706,
        "nbf": 1701147706,
        "exp": 1701151606,
        "aio": "E2VgYBCrs6htYuG73vd97faIfe4VAA==",
        "app_displayname": "SitesSelected",
        "appid": "27ad23b0-54a1-4668-8c00-ff2b7e9cd7eb",
        "appidacr": "1",
        "idp": "https://sts.windows.net/311ca363-cc76-4086-93a7-94f6b8f4ae2a/",
        "idtyp": "app",
        "oid": "91cd7dcc-2d71-479e-a437-f0a957ef896c",
        "rh": "0.AUoAY6McMXbMhkCTp5T2uPSuKgMAAAAAAAAAwAAAAAAAAACJAAA.",
        "roles": [
            "Sites.Selected" // This part will be missing
        ],
        "sub": "91cd7dcc-2d71-479e-a437-f0a957ef896c",
        "tenant_region_scope": "AS",
        "tid": "311ca363-cc76-4086-93a7-94f6b8f4ae2a",
        "uti": "6tkUj2oDYk2m3nKcqrt2Ag",
        "ver": "1.0",
        "wids": [
            "0997a1d0-0d1d-4acb-b408-d5ca73121e90"
        ],
        "xms_tcdt": 1671416148
        }

   b. Do I need to register two applications on Azure?

      Answer: It's not mandatory. Please refer to the above "Step c" and the screenshot below:

![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/9401aa9f-5316-42b9-9586-a7d15af7cb2e)

   c. When granting `Sites.Selected` permission on Azure, what is the difference between Microsoft Graph and SharePoint in the following image?

![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/ee87a8be-75ad-4f66-ac34-43bfa317ad87)

      Answer: One can use Graph API, and the other can use SharePoint Rest API. The fundamental difference lies in the scope parameter when obtaining the Access Token. The former's parameter is `https://graph.microsoft.com/.default`, while the latter is `https://xxx.sharepoint.com/.default`. They generate tokens with different audiences (aud), where one can only call Graph API, and the other can only call SharePoint Rest API. Note that to call SharePoint Rest API, you must use the certificate method when obtaining the token.

# 关于Microsoft Graph API Sites.Selected的一些补充

## 1. 上手指南

以下两篇技术文档将帮助你快速地入门Sites.Selected：

- [Develop Applications that Use Sites.Selected Permissions for SharePoint](https://techcommunity.microsoft.com/t5/microsoft-sharepoint-blog/develop-applications-that-use-sites-selected-permissions-for-spo/ba-p/3790476)
- [Updates on Controlling App-Specific Access on Specific SharePoint Sites (Sites.Selected)](https://devblogs.microsoft.com/microsoft365dev/updates-on-controlling-app-specific-access-on-specific-sharepoint-sites-sites-selected/)

## 2. 流程简化

概括地说，整个Sites.Selected使用流程包括以下几个步骤：

   a. 在 Azure app registration 中注册一个应用程序。
   
   b. 在 Azure app registration 中为该应用程序授予 `Sites.Selected` 权限（需要Global Admin Consent）。
   
   c. 将该应用程序绑定到一个或多个站点，并授予该应用程序访问目标站点的权限（Read/Write/Manage/FullControl，四选一）。这一步骤可以通过多种方式完成：
   
       - 在 Azure app registration 中注册另一个具有 `Sites.FullControl.All` 权限的应用程序，然后通过 Graph API（`https://graph.microsoft.com/v1.0/sites/{sitesId}/permissions`）或者 PnP PowerShell + 证书的连接方式 (`Connect-PnPOnline -CertificatePat xxx -CertificatePassword xxx，Grant-PnPAzureADAppSitePermission`) 完成。(Currently if we're using `Connect-PnPOnline -ClientId xxx -ClientSecret xxx` then it will go to ACS, azure access control service, not what we want, and that's the reason why we use `Connect-PnPOnline -CertificatePat xxx -CertificatePassword xxx`) 
       
       - 使用 `Connect-PnPOnline -Url $targetSiteUrl -Interactive + Global Admin` 连接到目标站点，然后使用 PnP PowerShell `Grant-PnPAzureADAppSitePermission` 完成。
       
       - 使用 `Connect-PnPOnline -Url $targetSiteUrl -Interactive + 目标站点 Site Collection Admin` 连接到目标站点，然后使用 PnP PowerShell `Grant-PnPAzureADAppSitePermission` 完成。
   
   d. 使用 Graph API (`https://graph.microsoft.com/v1.0/sites/{sitesId}/permissions`) 或者 PnP PowerShell `Get-PnPAzureADAppSitePermission` 查看目标站点的权限。
   
   e. 使用该应用程序访问目标站点，可以使用 Graph API 或者 PnP PowerShell。

## 3. 常见问题解答

很多人问过我一些常见问题，这里分享给大家：

   a. 在使用 `Sites.Selected` 时，是否必须要有Global Admin的介入？

      答：是的，至少需要全局管理员同意才能使用 `Sites.Selected`：

![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/4d48492d-64c4-40ca-b735-22dc54ffacd9)

      在没有全局管理员同意的情况下，Access Token将不包含有关权限的声明：

        {
        "aud": "https://graph.microsoft.com",
        "iss": "https://sts.windows.net/311ca363-cc76-4086-93a7-94f6b8f4ae2a/",
        "iat": 1701147706,
        "nbf": 1701147706,
        "exp": 1701151606,
        "aio": "E2VgYBCrs6htYuG73vd97faIfe4VAA==",
        "app_displayname": "SitesSelected",
        "appid": "27ad23b0-54a1-4668-8c00-ff2b7e9cd7eb",
        "appidacr": "1",
        "idp": "https://sts.windows.net/311ca363-cc76-4086-93a7-94f6b8f4ae2a/",
        "idtyp": "app",
        "oid": "91cd7dcc-2d71-479e-a437-f0a957ef896c",
        "rh": "0.AUoAY6McMXbMhkCTp5T2uPSuKgMAAAAAAAAAwAAAAAAAAACJAAA.",
        "roles": [
            "Sites.Selected" // 这部分会缺失
        ],
        "sub": "91cd7dcc-2d71-479e-a437-f0a957ef896c",
        "tenant_region_scope": "AS",
        "tid": "311ca363-cc76-4086-93a7-94f6b8f4ae2a",
        "uti": "6tkUj2oDYk2m3nKcqrt2Ag",
        "ver": "1.0",
        "wids": [
            "0997a1d0-0d1d-4acb-b408-d5ca73121e90"
        ],
        "xms_tcdt": 1671416148
        }

   b. 我必须在 Azure 上注册两个应用程序吗？

      答：不是必须的，请参考上述 "步骤 c" 和以下截图信息：

![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/9401aa9f-5316-42b9-9586-a7d15af7cb2e)

   c. 在 Azure 上授予 `Sites.Selected` 权限时，下图的 Microsoft Graph 和 SharePoint 有什么区别？

<img width="1916" alt="image" src="https://github.com/Chunlong101/SharePointScripts/assets/9314578/ee87a8be-75ad-4f66-ac34-43bfa317ad87">

      答：一个可以使用 Graph API，一个可以使用 SharePoint Rest API。两者的本质区别在于：在获取 Access Token 时，scope 参数不同。前者的参数是 `https://graph.microsoft.com/.default`，后者是 `https://xxx.sharepoint.com/.default`。它们分别生成具有不同 aud（受众）的令牌，一个只能调用 Graph API，一个只能调用 SharePoint Rest API。注意，想要调用 SharePoint Rest API，在获取令牌时必须使用证书的方式。
