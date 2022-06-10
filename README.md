# SharePointScripts
This repository aims at sharepoint related scripts both for onprem and online. 

## Some scripts in this repository are using sharepoint pnp powershell, here isn how to install sharepoint pnp powershell, both for online and onprem

A. If your machine has internet connection: 

Install-Module -Name "PnP.PowerShell" # This is for sharepoint online

Install-Module -Name SharePointPnPPowerShell2013

Install-Module -Name SharePointPnPPowerShell2016

Install-Module -Name SharePointPnPPowerShell2019

https://www.powershellgallery.com/packages/SharePointPnPPowerShell2019/3.29.2101.0

https://www.powershellgallery.com/packages?q=pnp+sharepoint

B. If your machine doesn't have internet connection: 

0. Download appropriate version from https://www.powershellgallery.com/packages?q=pnp+sharepoint
1. Unblock the Internet-downloaded NuGet package (.nupkg) file, for example using Unblock-File -Path C:\Downloads\module.nupkg cmdlet.
2. Extract the contents of the NuGet package to a local folder.
3. Delete the NuGet-specific elements from the folder.
4. Rename the folder. The default folder name is usually name.version. The version can include -prerelease if the module is tagged as a prerelease version. Rename the folder to just the module name. For example, azurerm.storage.5.0.4-preview becomes azurerm.storage.
5. Copy the folder to one of the folders in the $env:PSModulePath value. $env:PSModulePath is a semicolon-delimited set of paths in which PowerShell should look for modules.

See more: 
![image](https://user-images.githubusercontent.com/9314578/167997685-7d0a4dab-ecb5-46c2-a651-f4f615630bf2.png)
