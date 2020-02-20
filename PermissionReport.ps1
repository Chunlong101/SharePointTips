#
# This script is for getting permission report of a web/list/library/item
#

$siteUrl = "https://xia053.sharepoint.com/sites/ChunlongDeveloper"

$cred = Get-Credential

Connect-PnPOnline $siteUrl -Credentials $cred

$users = Get-PnPUser

$user = $users[0]

$web = Get-PnPWeb -Includes RoleAssignments

$list = Get-PnPList "Test" -Includes RoleAssignments

function GetPermissions ($Obj, [string] $UserLoginName) {
    $userEffectivePermissions = $Obj.GetUserEffectivePermissions($UserLoginName) # i:0#.f|membership|chunlonl_microsoft.com#ext#@xia053.onmicrosoft.com
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

    $results = @()
    for ($i = 0; $i -lt [system.enum]::GetValues($PermissionKindType).Count; $i++) {
        $has = $userEffectivePermissions.Value.Has([system.enum]::GetValues($PermissionKindType)[$i])
        if ($has) {
            [system.enum]::GetValues($PermissionKindType)[$i]
        }
    }
    return $results
}

function GetRoleAssignments ($Obj) {
    # PS C:\Users\chunlonl\source\repos\Test> $Obj.RoleAssignments
    # The collection has not been initialized. It has not been requested or the request has not been executed. It may need to be explicitly requested.
    $results = @()
    foreach ($ra in $Obj.RoleAssignments) {
        $member = $ra.Member
        $loginName = get-pnpproperty -ClientObject $member -Property LoginName
        $rolebindings = get-pnpproperty -ClientObject $ra -Property RoleDefinitionBindings

        $A = $loginName
        $B = $rolebindings.Name
        
        $wrapper = New-Object PSObject -Property @{ UserName = $A; Role = $B }
        $results += $wrapper
    } 
    return $results
}

GetPermissions -Obj $web -UserLoginName $user.LoginName

GetRoleAssignments -Obj $web