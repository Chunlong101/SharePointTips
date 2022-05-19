# --- 
# This function returns RoleAssignment info from different kind of object (web/list/item(folder/file)) in sharepoint. RoleAssignment is like "User:Chunlong, Role:Full Control", a RoleAssignment object has two components: RoleDefinitionBindings and Member, a user can have multiple roles
# --- 
function GetRoleAssignments ($Obj) {
    $results = @()

    # When $Obj is a Web or List/ListItem, this kind of object has "RoleAssignments" property by default
    if ($Obj.GetType().Name -eq "Web" -or $Obj.GetType().Name -eq "List" -or $Obj.GetType().Name -eq "ListItem") {
        Get-PnPProperty -ClientObject $Obj -Property RoleAssignments | Out-Null
        foreach ($roleAssignment in $Obj.RoleAssignments) {
            Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member | Out-Null
            $loginName = $roleAssignment.Member.LoginName

            $A = $loginName
            $B = $roleAssignment.RoleDefinitionBindings.Name
                
            $wrapper = New-Object PSObject -Property @{ UserName = $A; Role = $B }
            $results += $wrapper
        }
        return $results
    }

    # When $Obj is a File, this kind of object itself doesn't have "RoleAssignments" property, in order to retrive that property we need to find out the corresponding listitem object and then its "RoleAssignments"
    if ($Obj.GetType().Name -eq "File") {
        Get-PnPProperty -ClientObject $Obj -Property ServerRelativeUrl | Out-Null
        $file = Get-PnPFile -AsListItem -Url $Obj.ServerRelativeUrl
        Get-PnPProperty -ClientObject $file -Property RoleAssignments | Out-Null
        foreach ($roleAssignment in $file.RoleAssignments) {
            Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member | Out-Null
            $loginName = $roleAssignment.Member.LoginName

            $A = $loginName
            $B = $roleAssignment.RoleDefinitionBindings.Name
                
            $wrapper = New-Object PSObject -Property @{ UserName = $A; Role = $B }
            $results += $wrapper
        }
        return $results
    }

    # When $Obj is a Folder, this kind of object itself doesn't have "RoleAssignments" property, in order to retrive that property we need to find out the corresponding "ListItemAllFields.RoleAssignments"
    if ($Obj.GetType().Name -eq "Folder") {
        $folder = Get-PnPFolder -Url $Obj.ServerRelativeUrl -Includes ListItemAllFields.RoleAssignments
        foreach ($roleAssignment in $folder.ListItemAllFields.RoleAssignments) {
            Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member | Out-Null
            $loginName = $roleAssignment.Member.LoginName

            $A = $loginName
            $B = $roleAssignment.RoleDefinitionBindings.Name
                
            $wrapper = New-Object PSObject -Property @{ UserName = $A; Role = $B }
            $results += $wrapper
        }
        return $results
    }

    # When $obj is not a folder/file/web/list/listitem then return null
    return $null
}

# --- 
# This function returns true of false to verify if a web/list/library/listitem/file/folder has unique permission or not
# --- 
Function CheckIfObjHasUniquePermission ($Obj) {
    $result = $false

    # If $Obj is a Web or List/ListItem, these kind of objects themselves by default have "HasUniqueRoleAssignments" property
    if ($Obj.GetType().Name -eq "Web" -or $Obj.GetType().Name -eq "List" -or $Obj.GetType().Name -eq "ListItem") {
        $result = Get-PnPProperty -ClientObject $Obj -Property HasUniqueRoleAssignments
    }    
    # If $Obj is a Folder or File, these kind of objects themselves don't have "HasUniqueRoleAssignments" property, in order to retrive that property we need to find out the corresponding listitem object
    elseif ($Obj.GetType().Name -eq "Folder" -or $Obj.GetType().Name -eq "File") {
        try {
            # Retry, I have to say this is a bug of pnp powershell, sometimes below line will fail with error: Get-PnPProperty : Cannot invoke method or retrieve property from null object. Object returned by the following call stack is null. "ListItemAllFields", but it can be workarounded by trying again the same command. 
            Get-PnPProperty -ClientObject $Obj -Property ListItemAllFields, ServerRelativePath | Out-Null
        }
        catch {
            Get-PnPProperty -ClientObject $Obj -Property ListItemAllFields, ServerRelativePath | Out-Null
        }
        Get-PnPProperty -ClientObject $Obj.ListItemAllFields -Property ParentList, Id | Out-Null
        $item = Get-PnPListItem -List $Obj.ListItemAllFields.ParentList -Id $Obj.ListItemAllFields.Id
        $result = Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments
    }

    # When $Obj is not a Web/List(library)/ListItem/Folder/File, return $false
    return $result
} 

# --- 
# This function returns permissions, it helps you check what kind of permissions a user has over a object like web/list/library/listitem/folder/file
# --- 
function GetUserPermissions ($Obj, [string] $UserLoginName) {
    $results = @()

    if ($Obj.GetType().Name -eq "Web" -or $Obj.GetType().Name -eq "List" -or $Obj.GetType().Name -eq "ListItem") {
        $userEffectivePermissions = $Obj.GetUserEffectivePermissions($UserLoginName) # GetUserEffectivePermissions is like "Check Permission" on UI (e.g. https://chunlong.sharepoint.com/sites/Test/_layouts/15/user.aspx), user login name goes like i:0#.f|membership|chunlonl_microsoft.com#ext#@xia053.onmicrosoft.com
        Invoke-PnPQuery
    
        $permissionKind = New-Object Microsoft.SharePoint.Client.PermissionKind
        $permissionKindType = $PermissionKind.getType()
    
        # $permissionKindType.GetEnumValues() # 37 kinds of permissions
        # EmptyMask
        # ViewListItems
        # AddListItems
        # EditListItems
        # DeleteListItems
        # ApproveItems
        # OpenItems
        # ViewVersions
        # DeleteVersions
        # CancelCheckout
        # ManagePersonalViews
        # ManageLists
        # ViewFormPages
        # AnonymousSearchAccessList
        # Open
        # ViewPages
        # AddAndCustomizePages
        # ApplyThemeAndBorder
        # ApplyStyleSheets
        # ViewUsageData
        # CreateSSCSite
        # ManageSubwebs
        # CreateGroups
        # ManagePermissions
        # BrowseDirectories
        # BrowseUserInfo
        # AddDelPrivateWebParts
        # UpdatePersonalWebParts
        # ManageWeb
        # AnonymousSearchAccessWebLists
        # UseClientIntegration
        # UseRemoteAPIs
        # ManageAlerts
        # CreateAlerts
        # EditMyUserInfo
        # EnumeratePermissions
        # FullMask
    
        for ($i = 0; $i -lt [system.enum]::GetValues($PermissionKindType).Count; $i++) {
            $has = $userEffectivePermissions.Value.Has([system.enum]::GetValues($PermissionKindType)[$i])
            if ($has) {
                $results += [system.enum]::GetValues($PermissionKindType)[$i]
            }
        }
        return $results
    }

    if ($Obj.GetType().Name -eq "File" -or $Obj.GetType().Name -eq "Folder") {
        try {
            # Retry, I have to say this is a bug of pnp powershell, sometimes below line will fail with error: Get-PnPProperty : Cannot invoke method or retrieve property from null object. Object returned by the following call stack is null. "ListItemAllFields", but it can be workarounded by trying again the same command. 
            Get-PnPProperty -ClientObject $Obj -Property ListItemAllFields, ServerRelativePath | Out-Null
        }
        catch {
            Get-PnPProperty -ClientObject $Obj -Property ListItemAllFields, ServerRelativePath | Out-Null
        }
        Get-PnPProperty -ClientObject $Obj.ListItemAllFields -Property ParentList, Id | Out-Null
        $item = Get-PnPListItem -List $Obj.ListItemAllFields.ParentList -Id $Obj.ListItemAllFields.Id

        $userEffectivePermissions = $item.GetUserEffectivePermissions($UserLoginName)
        Invoke-PnPQuery
        
        $permissionKind = New-Object Microsoft.SharePoint.Client.PermissionKind
        $permissionKindType = $PermissionKind.getType()
    
        for ($i = 0; $i -lt [system.enum]::GetValues($PermissionKindType).Count; $i++) {
            $has = $userEffectivePermissions.Value.Has([system.enum]::GetValues($PermissionKindType)[$i])
            if ($has) {
                $results += [system.enum]::GetValues($PermissionKindType)[$i]
            }
        }
        return $results
    }

    # When $Obj is not Web/List/ListItem/Folder/File then return null
    return $null
}

# --- 
# This function will export the permission report to a csv file, $Obj can be a web/list(library)/listitem/folder/file
# --- 
function ExportRoleAssignments ($Obj, $CsvFilePath) {
    $ResourceUrl = ""
    if ($Obj.GetType().Name -eq "Web") {
        $ResourceUrl = $Obj.ServerRelativeUrl
    }
    elseif ($Obj.GetType().Name -eq "List") {
        $ResourceUrl = $Obj.RootFolder.ServerRelativeUrl
    }
    elseif ($Obj.GetType().Name -eq "ListItem") {
        $ResourceUrl = $Obj.FieldValues.FileRef
    }
    elseif ($Obj.GetType().Name -eq "Folder" -or $Obj.GetType().Name -eq "File") {
        Get-PnPProperty -ClientObject $Obj -Property ServerRelativeUrl | Out-Null
        $ResourceUrl = $Obj.ServerRelativeUrl
    }

    $HasUniquePermission = CheckIfObjHasUniquePermission $Obj
    if ($HasUniquePermission) {
        $RoleAssignments = GetRoleAssignments -obj $Obj
        foreach ($ra in $RoleAssignments) {
            $UserName = $ra.UserName
            $Role = ""
            $ra.Role | foreach {
                $Role += $_ + ", "
            }
            $Role = $Role.TrimEnd(", ")
            
            $wrapper = New-Object PSObject -Property @{ ResourceUrl = $ResourceUrl; HasUniquePermission = $HasUniquePermission; Role = $Role; UserName = $UserName }
            Export-Csv -InputObject $wrapper -Path $CsvFilePath -Append -NoTypeInformation
        }
    }
    else {
        $wrapper = New-Object PSObject -Property @{ ResourceUrl = $ResourceUrl; HasUniquePermission = "False"; Role = ""; UserName = "" }
        Export-Csv -InputObject $wrapper -Path $CsvFilePath -Append -NoTypeInformation
    }
}

# Now let's take a look on some examples below of how to use this script: 

$ErrorActionPreference = "Continue"

# $siteUrl = "http://allinone/test/Communication"
# $cred = Get-Credential
# Connect-PnPOnline -Url $siteUrl -Credentials $cred

$siteUrl = "https://chunlong.sharepoint.com/sites/Test"
Connect-PnPOnline -Url $siteUrl -Interactive

# --- 
# Export the permission report to a csv file 
# --- 

$reportPath = ".\PermissionReport.csv"

# Web
$web = Get-PnPWeb
ExportRoleAssignments -Obj $web -CsvFilePath $reportPath

# List
$list = Get-PnPList "ListA"
ExportRoleAssignments -Obj $list -CsvFilePath $reportPath

# ListItem
$listItem1 = Get-PnPListItem -List "ListA" -Id 1
ExportRoleAssignments -Obj $listItem1 -CsvFilePath $reportPath

# Library
$library = Get-PnPList "Shared Documents"
ExportRoleAssignments -Obj $library -CsvFilePath $reportPath

# File
$filePath = "Shared Documents/FolderA/FileA.docx"
$file = Get-PnPFile -Url $filePath
ExportRoleAssignments -Obj $file -CsvFilePath $reportPath

# Folder
$FolderPath = "Shared Documents/FolderA"
$folder = Get-PnPFolder $FolderPath
ExportRoleAssignments -Obj $folder -CsvFilePath $reportPath

# All folders and files inside the library
$allLibraryItems = Get-PnPListItem -List "Shared Documents" -PageSize 50
foreach ($item in $allLibraryItems) {
    ExportRoleAssignments -Obj $item -CsvFilePath $reportPath
}

# --- 
# Check user permissions 
# --- 

$user = Get-PnPUser | ? { $_.LoginName -contains 'i:0#.w|chunlong\chunlong' }

# Web
$web = Get-PnPWeb
$permissions = GetUserPermissions -Obj $web -UserLoginName $user.LoginName
Write-Host "On this object: $($web.ServerRelativeUrl), this user: $($user.Title) has below permissions:" -ForegroundColor Green
$permissions | ft -a

# List
$list = Get-PnPList "ListA"
$permissions = GetUserPermissions -Obj $list -UserLoginName $user.LoginName
Write-Host "On this object: $($list.RootFolder.ServerRelativeUrl), this user: $($user.Title) has below permissions:" -ForegroundColor Green
$permissions | ft -a

# ListItem
$listItem1 = Get-PnPListItem -List "ListA" -Id 1
$permissions = GetUserPermissions -Obj $listItem1 -UserLoginName $user.LoginName
Write-Host "On this object: $($listItem1.FieldValues.FileRef), this user: $($user.Title) has below permissions:" -ForegroundColor Green
$permissions | ft -a

# Library
$library = Get-PnPList "Shared Documents"
$permissions = GetUserPermissions -Obj $library -UserLoginName $user.LoginName
Write-Host "On this object: $($library.RootFolder.ServerRelativeUrl), this user: $($user.Title) has below permissions:" -ForegroundColor Green
$permissions | ft -a

# File
$filePath = "Shared Documents/FolderA/FileA.docx"
$file = Get-PnPFile $filePath
$permissions = GetUserPermissions -Obj $file -UserLoginName $user.LoginName
Get-PnPProperty -ClientObject $file -Property ServerRelativeUrl
Write-Host "On this object: $($file.ServerRelativeUrl), this user: $($user.Title) has below permissions:" -ForegroundColor Green
$permissions | ft -a

# Folder
$FolderPath = "Shared Documents/FolderA"
$folder = Get-PnPFolder $FolderPath
$permissions = GetUserPermissions -Obj $folder -UserLoginName $user.LoginName
Get-PnPProperty -ClientObject $folder -Property ServerRelativeUrl
Write-Host "On this object: $($folder.ServerRelativeUrl), this user: $($user.Title) has below permissions:" -ForegroundColor Green
$permissions | ft -a

# --- 
# Get role assignments
# --- 

# Web
$web = Get-PnPWeb
Write-Host "Checking permissions on this Web now: $($web.Url)" -ForegroundColor Green
$output = CheckIfObjHasUniquePermission $web
Write-Host "Does it have unique permission: $output" -ForegroundColor Green
$output = GetRoleAssignments $web
Write-Host "Here are roleassignments:" -ForegroundColor Green
$output | ft -a

# List
$list = Get-PnPList "ListA"
Write-Host "Checking permissions on this List now: $($list.RootFolder.ServerRelativeUrl)" -ForegroundColor Green
$output = CheckIfObjHasUniquePermission $list
Write-Host "Does it have unique permission: $output" -ForegroundColor Green
$output = GetRoleAssignments $list
Write-Host "Here are roleassignments:" -ForegroundColor Green
$output | ft -a

# All Lists
$lists = Get-PnPList
foreach ($list in $lists) {
    Write-Host "Checking permissions on this List now: $($list.RootFolder.ServerRelativeUrl)" -ForegroundColor Green
    $output = CheckIfObjHasUniquePermission $list
    Write-Host "Does it have unique permission: $output" -ForegroundColor Green
    $output = GetRoleAssignments $list
    Write-Host "Here are roleassignments:" -ForegroundColor Green
    $output | ft -a
}

# ListItem
$listItem1 = Get-PnPListItem -List "ListA" -Id 1
Write-Host "Checking permissions on this ListItem now: $($listItem1.FieldValues.FileRef)" -ForegroundColor Green
$output = CheckIfObjHasUniquePermission $listItem1
Write-Host "Does it have unique permission: $output" -ForegroundColor Green
$output = GetRoleAssignments -Obj $listItem1
Write-Host "Here are roleassignments" -ForegroundColor Green
$output | ft -a

# Library
$library = Get-PnPList "Shared Documents"
Write-Host "Checking permissions on this Library now: $($library.RootFolder.ServerRelativeUrl)" -ForegroundColor Green
$output = CheckIfObjHasUniquePermission $library
Write-Host "Does it have unique permission: $output" -ForegroundColor Green
$output = GetRoleAssignments $library
Write-Host "Here are roleassignments:" -ForegroundColor Green
$output | ft -a

# File
$filePath = "Shared Documents/FolderA/FileA.docx"
$file = Get-PnPFile $filePath
Get-PnPProperty -ClientObject $file -Property ServerRelativeUrl
Write-Host "Checking permissions on this File now: $($file.ServerRelativeUrl)" -ForegroundColor Green
$output = CheckIfObjHasUniquePermission $file
Write-Host "Does it have unique permission: $output" -ForegroundColor Green
$output = GetRoleAssignments $file
Write-Host "Here are roleassignments:" -ForegroundColor Green
$output | ft -a

# Folder
$FolderPath = "Shared Documents/FolderA"
$folder = Get-PnPFolder $FolderPath
Get-PnPProperty -ClientObject $folder -Property ServerRelativeUrl
Write-Host "Checking permissions on this Folder now: $($folder.ServerRelativeUrl)" -ForegroundColor Green
$output = CheckIfObjHasUniquePermission $folder
Write-Host "Does it have unique permission: $output" -ForegroundColor Green
$output = GetRoleAssignments $folder
Write-Host "Here are roleassignments:" -ForegroundColor Green
$output | ft -a

# All folders and files inside the library
$libraryName = "Shared Documents"
$allLibraryItems = Get-PnPFolderItem -Recursive -FolderSiteRelativeUrl $libraryName # we can use "shared documents/foldername" to specify a folder under the library
Write-Host "Checking permissions on all items inside this Library now: $libraryName" -ForegroundColor Green
foreach ($item in $allLibraryItems) {
    try {
        Write-Host "Checking permissions on this item now: $($item.Name) " -ForegroundColor Green
        $output = CheckIfObjHasUniquePermission $item
        Write-Host "Does it have unique permission: $output" -ForegroundColor Green
        $output = GetRoleAssignments $item
        Write-Host "Here are roleassignments:" -ForegroundColor Green
        $output | ft -a
    }
    catch {
        Write-Host 'Skipping this one as it may cause some errors (e.g. the item is "Forms", a system hide folder/file under library, we do not necessarily need info on this one)' -ForegroundColor Yellow
    } 
}