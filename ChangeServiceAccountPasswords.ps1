# -----
# This scirpt aims to automatically update the passwords of a service account used in sharepoint, iis as well as windows services. Pls note, Microsoft doesn't provide production ready scripts, customers need to test/verify/extend this script by themselves. And this script is out of the support scope. 
# -----

Set-Executionpolicy -Scope CurrentUser -ExecutionPolicy UnRestricted -Force
Import-Module WebAdministration

$serviceAccount = Read-Host -Prompt "Please enter the user (in DOMAIN\username format)."
$securePass = Read-Host "Now, what is this user's password? Please enter (this field will be encrypted)." -AsSecureString
$plainTextPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
$applicationPools = Get-ChildItem IIS:\AppPools | where { $_.processModel.userName -eq $serviceAccount }

foreach($pool in $applicationPools)
{
    $pool.processModel.userName = $serviceAccount
    $pool.processModel.password = $plainTextPass
    $pool.processModel.identityType = 3
    $pool | Set-Item
}

$serverName = $env:computername
$shpServices = gwmi win32_service -computer $serverName | where {$_.StartName -eq $serviceAccount}

foreach($service in $shpServices)
{
   $service.change($null,$null,$null,$null,$null,$null,$null,$plainTextPass)
}

Add-PSSnapin Microsoft.SharePoint.PowerShell
$managedAccount = Get-SPManagedAccount | where { $_.UserName -eq $serviceAccount }
Set-SPManagedAccount -Identity $managedAccount -ExistingPassword $securePass –UseExistingPassword:$True -Confirm:$False

if((Get-SPFarm).DefaultServiceAccount.Name -eq $serviceAccount)
{
   stsadm.exe –o updatefarmcredentials –userlogin $serviceAccount –password $plainTextPass
}

iisreset /noforce
