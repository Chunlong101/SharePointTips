# SharePointTips

Here I will share some commonly used SharePoint tips and experiences, hoping to help you save time. 

#### Installing SharePoint PnP PowerShell

Some scripts in this repository utilize SharePoint PnP PowerShell. Here's how to install SharePoint PnP PowerShell for both online and on-premises environments:

(By the way, starting from PnP PowerShell version 2.2, it requires PowerShell 7, and Visual Studio Code is recommended)

#### 1. Online Installation (Machine with Internet Connection)

```powershell
Install-Module -Name "PnP.PowerShell" # For SharePoint Online

Install-Module -Name SharePointPnPPowerShell2013

Install-Module -Name SharePointPnPPowerShell2016

Install-Module -Name SharePointPnPPowerShell2019
```

These commands install PnP PowerShell from the PowerShell Gallery:

- [SharePointPnPPowerShell2019](https://www.powershellgallery.com/packages/SharePointPnPPowerShell2019/3.29.2101.0)
- [Search for PnP SharePoint Modules](https://www.powershellgallery.com/packages?q=pnp+sharepoint)

#### 2. Offline Installation (Machine without Internet Connection)

1. Download the appropriate version from [PnP PowerShell Modules on PowerShell Gallery](https://www.powershellgallery.com/packages?q=pnp+sharepoint).
2. Unblock the Internet-downloaded NuGet package (.nupkg) file using the `Unblock-File -Path C:\Downloads\module.nupkg` cmdlet.
3. Extract the contents of the NuGet package to a local folder.
4. Delete the NuGet-specific elements from the folder.
5. Rename the folder to the module name (remove version information). For example, `azurerm.storage.5.0.4-preview` becomes `azurerm.storage`.
6. Copy the folder to one of the folders in the `$env:PSModulePath` value.
7. Open a new PowerShell window, and PnP PowerShell commands should be ready.

Please note that Microsoft doesn't provide production-ready scripts. Customers need to test, verify, and develop scripts themselves. These scripts are outside the Microsoft support scope.
