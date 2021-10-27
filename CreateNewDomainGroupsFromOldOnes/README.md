## Issue 

Your organization is replicating all the Users and Groups from domainA to domainB, and will disconnect from domainA, you want to make sure all the users can keep their access to sharepoint. (Some users were given permissions by security group)

## Assessments 

1.	For those who were given permissions to sharepoint via security group, my test result confirmed that disconnecting from the old domain will make the old domain security group no longer work for sharepoint, which means the permissions will be lost. 
2.	The following command is to grant permissions to the security group for a sharepoint site: 
New-SPUser -Web <SiteUrl> -UserAlias "Domain\SecurityGroupName" -PermissionLevel "Contribute"

## More details 

I have a test user dev\chunlong in dev\chunlongdevgroup (“old domain security group”) below: 

In sharepoint I granted the permissions to the test user via that group, then I can use that test user to access sharepoint successfully: 

After disconnecting the dev domain that test user cannot access sharepoint any more, keep seeing below 401 pop-up: 

Pls note, my environment cannot be the same as yours, I am just simulating the situations to prove the theory. 

After testing, I found the following commands that may help you to grant permissions to security group for a sharepoint site: 

New-SPUser -Web <SiteUrl> -UserAlias "Domain\SecurityGroupName" -PermissionLevel "Contribute"

Or

New-SPUser -Web <SiteUrl> -UserAlias "Domain\SecurityGroupName" -Group "SharePointGroupName"

For example: 

New-SPUser -Web http://wfe -UserAlias "shanghai\chunlongshanghaigroup" -PermissionLevel "Contribute"

New-SPUser -Web http://wfe -UserAlias "shanghai\chunlongshanghaigroup" -Group "Home Members"

And you can use remove-spuser to delete a security group from the sharepoint site, below is an example: 

Remove-SPUser -Web http://wfe -Identity "c:0+.w|s-1-5-21-2308128033-1519083678-247854422-1117" -Confirm:$false

That “Identity” can be retrieved from “UserLogin”: 

Get-SPUser -Web http://wfe | ? {$_.DisplayName -match "chunlongshanghaigroup"} | ft -AutoSize

## Pls note 

Microsoft doesn't provide production ready scripts, customers need to test/verify/extend this script by themselves. And this script is out of the support scope. 

## Additionally, move-spuser can also help migrate users/groups from domainA to domainB. 
