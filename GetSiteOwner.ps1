Connect-PnPOnline -Url $SiteUrl -Credentials $Global:Connection.PSCredential
$site = Get-PnPSite -Includes Owner
$membersGroup = Get-PnPGroup -AssociatedMemberGroup
$members = Get-PnPGroupMember -Group $membersGroup
$ownersGroup = Get-PnPGroup -AssociatedOwnerGroup
$owners = Get-PnPGroupMember -Group $ownersGroup