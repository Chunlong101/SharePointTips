# How to connect your SharePoint with PnP PowerShell

***

## 🚀 Automatically Create an App Registration (Azure AD/Entra Id) for PnP PowerShell to connect with your SharePoint Online

Using **PnP PowerShell** with Entra ID, you can quickly create an app registration for interactive login using a built-in cmdlet. See more details here: https://pnp.github.io/powershell/articles/registerapplication.html#automatically-create-an-app-registration-for-interactive-login

***

## ✅ Prerequisites

*   [Install-Module PnP.PowerShell](https://pnp.github.io/powershell/articles/installation.html)
*   You must have permission to create **App registrations** in Entra ID.
*   Required roles:
    *   **Application Developer** (usually sufficient), or
    *   **Global Administrator** (may be needed to grant consent).

***

## 🛠️ Steps

### 1. Run the Cmdlet

```powershell
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP.PowerShell" -Tenant [yourtenant].onmicrosoft.com
```

*   Replace `[yourtenant]` with your actual tenant name.
*   Example: `contoso.onmicrosoft.com`.

***

### 2. Authenticate

*   You’ll be prompted to log in with your **username, password**, and possibly **multi-factor authentication (MFA)**.
*   This ensures compliance with your organization’s conditional access policies.

***

### 3. App Registration Creation

*   A new **Entra ID Application** is automatically created.
*   By default, it includes a **limited set of permission scopes**.

***

### 4. (Optional) Specify Permissions

You can add custom permission scopes using parameters such as:

*   `-GraphApplicationPermissions`
*   `-GraphDelegatePermissions`
*   `-SharePointApplicationPermissions`
*   `-SharePointDelegatePermissions`

Example:

```powershell
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP.PowerShell" `
  -Tenant contoso.onmicrosoft.com `
  -GraphDelegatePermissions "User.Read.All","Sites.Read.All"
```

***

### 5. Grant Consent

*   After registration, you’ll need to **grant consent** for the application.
*   If you don’t have rights to grant consent, an administrator must do this in the **Entra ID portal**.

***

## 🌍 Special Case: National Cloud Environments

If you’re in **US Government, Germany, or China** environments, add the `-AzureEnvironment` parameter:

```powershell
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP.PowerShell" `
  -Tenant contoso.onmicrosoft.com `
  -AzureEnvironment USGovernment
```

***

This is the **easiest and fastest** way to enable interactive login with PnP PowerShell. After steps above, you're good to use [Connect-PnPOnline](https://pnp.github.io/powershell/cmdlets/Connect-PnPOnline.html) to connect with your sharepoint online.

***

## 🔧 Installing SharePoint PnP PowerShell for SharePoint On-Prem

> Starting from PnP PowerShell version 2.2, PowerShell 7 is required, and Visual Studio Code is recommended.

### 1. Online Installation (Machine with Internet Access)

```powershell
Install-Module -Name SharePointPnPPowerShell2013
Install-Module -Name SharePointPnPPowerShell2016
Install-Module -Name SharePointPnPPowerShell2019
```

These commands install PnP PowerShell from the PowerShell Gallery:

*   <https://www.powershellgallery.com/packages/SharePointPnPPowerShell2019/3.29.2101.0>
*   <https://www.powershellgallery.com/packages?q=pnp+sharepoint>

***

### 2. Offline Installation (Machine without Internet Access)

1.  Download the appropriate version from <https://www.powershellgallery.com/packages?q=pnp+sharepoint>.
2.  Unblock the downloaded NuGet package (.nupkg) using:
    ```powershell
    Unblock-File -Path C:\Downloads\module.nupkg
    ```
3.  Extract the contents of the NuGet package to a local folder.
4.  Remove NuGet-specific elements from the folder.
5.  Rename the folder to the module name (remove version info). Example:  
    `azurerm.storage.5.0.4-preview` → `azurerm.storage`.
6.  Copy the folder to one of the directories in `$env:PSModulePath`.
7.  Open a new PowerShell window, and PnP PowerShell commands should be ready.

***

⚠️ **Note**: Microsoft does not provide production-ready scripts. Customers must test, validate, and develop scripts themselves. These scripts are outside Microsoft support scope.
