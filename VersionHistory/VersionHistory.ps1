#
# The following scripts are going to list all version history of a library (before "TargetVersionModifiedDateTime" 2018-03-23 18:20:20)
#

$ScriptsLocation = 'C:\Users\xxx\Desktop\Script' # The location of this ps1 file
$Username = 'xxx@xxx.onmicrosoft.com' 
$Url = 'https://xxx-my.sharepoint.com/personal/xxx_xxx_onmicrosoft_com' 
$RootFolder = 'Documents'
$TargetVersionModifiedDateTime = [System.Convert]::ToDateTime('2018-03-23 18:20:20') # The problematic date
 
Import-Module ($ScriptsLocation + "\Microsoft.SharePoint.Client.dll")
Import-Module ($ScriptsLocation + "\Microsoft.SharePoint.Client.Runtime.dll")
Import-Module ($ScriptsLocation + "\SPOMod20170306.psm1")
 
Connect-SPOCSOM -Username $Username -Url $Url
 
$TargetList = Get-SPOList -IncludeAllProperties | ? { $_.Title -match $RootFolder } # This could return more than one list
 
$TargetItems = Get-SPOListItems -ListTitle $TargetList.Title -Recursive -IncludeAllProperties $true
 
$TargetUrl = @{ }
 
foreach ($item in $TargetItems) {
    $targetVersions = $null
 
    try {
        $targetVersions = Get-SPOListItemVersions -ItemID $item.ID -ListTitle $TargetList.Title -IncludeAllProperties $true
    }
    catch [System.Exception] {
        "No versioning was found for item " + $item.GUID + " under " + $TargetList.Title
        
        continue
    }
 
    if (!$targetVersions) {
        continue
    }
 
    $targetVersion = $null
 
    foreach ($version in $targetVersions) {
        $diff = $version.Created - $TargetVersionModifiedDateTime
            
        if ($diff.Days -le 0) {
            # Before $TargetVersionModifiedDateTime
            $targetVersion = $version
            break
        }
    }
 
    if ($TargetVersion) {
        $TargetUrl.Add($Url + '/' + $targetVersion.Url, $targetVersion.Url.Split('/')[-1]) 
    }
}
 
$TargetUrl | ogv

#
# The following scripts are going to list all version history of a library
#

$ScriptsLocation = 'C:\Users\xxx\Desktop\Script' # The location of this ps1 file
$Username = 'xxx@xxx.onmicrosoft.com' 
$Url = 'https://xxx.sharepoint.com' 
$RootFolder = 'Documents'
 
Import-Module ($ScriptsLocation + "\Microsoft.SharePoint.Client.dll")
Import-Module ($ScriptsLocation + "\Microsoft.SharePoint.Client.Runtime.dll")
Import-Module ($ScriptsLocation + "\SPOMod20170306.psm1")
 
Connect-SPOCSOM -Username $Username -Url $Url
 
$TargetList = Get-SPOList -IncludeAllProperties | ? { $_.Title -eq $RootFolder } 
 
$TargetItems = Get-SPOListItems -ListTitle $TargetList.Title -Recursive -IncludeAllProperties $true
 
$TargetUrl = @{ }
 
foreach ($item in $TargetItems) {
    $targetVersions = $null
 
    try {
        $targetVersions = Get-SPOListItemVersions -ItemID $item.ID -ListTitle $TargetList.Title -IncludeAllProperties $true
    }
    catch [System.Exception] {
        "No versioning was found for item " + $item.GUID + " under " + $TargetList.Title
        
        continue
    }
 
    if (!$targetVersions -or $targetVersions -eq 'No versions available') {
        continue
    }
    
    $targetVersions | % {
        $TargetUrl.Add($Url + '/' + $_.Url, $_.Url.Split('/')[-1]) 
    }
         
}
 
$TargetUrl | ogv

#
# If you're using sharepoint onprem server object model
#

Add-PSSnapin Microsoft.SharePoint.PowerShell
$web = Get-SPWeb http://xxx
$list = $web.Lists | ? { $_.title -match "Documents" }
$items = $list.Items
$item = $items | ? { $_.name -match "xxx.docx" }
$item.Versions | select * | ogv

#
# If you're using pnp powershell
#

Connect-PnPOnline -Url http://xxx 
$list = get-pnplist -Identity "Documents" -Includes EnableVersioning
$item = Get-PnPListItem -List $list -Id 1
$versions = Get-PnPProperty -ClientObject $item.File -Property Versions