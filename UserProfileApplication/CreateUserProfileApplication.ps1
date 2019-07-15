##
#This script will Create the User Profile Service Application
#This script also ensures all dependent services are started
#
#Domain level settings may need to be changed, follow this documentation prior to running this script:
#http://technet.microsoft.com/en-us/library/hh296982.aspx
#
#Current configuration of this script requires you to log onto the server using the farm account, and run the script in PowerShell
#To work around this limitation, see the following blog
#http://www.harbar.net/archive/2010/10/30/avoiding-the-default-schema-issue-when-creating-the-user-profile.aspx
##

$ver = $host | select version
if ($ver.Version.Major -gt 1) {$Host.Runspace.ThreadOptions = "ReuseThread"}
Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

##
#Load Functions
##

function PollService
{
    sleep 5
}

##
#Set Script Variables
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Creating Script Variables"

#This is the server where the user profile sync service runs
$ProfileSyncServer = "PC_Name"

#This is the display name of the User Profile Database
$UserProfileDB = "UserProfile"

#This is the display name of the User Profile Sync Database
$UserProfileSyncDB = "UserProfile_Sync"

#This is the display name of the User Profile Social Database
$UserProfileSocialDB = "UserProfile_Social"

#This is the User Name of the User Profile Service Application App Pool
$UserProfileApplicationPoolManagedAccount = "China\Chunlong"

#This is the Password of the User Profile Service Application App Pool Account
$UserProfileApplicationPoolPassword = "***."

#This is the User Name of the Server Farm Account
$SPFarmAccount = "China\Chunlong"

#This Is the Password of the Server Farm Account
$FarmAccountPassword = "***."

#This Is the Display name for the User Profile Service Application, The Application Pool Name has been set to match, for simplicity purposes
$UserProfileServiceApplicationName = "User Profile"

##
#Begin Script
##

##
#Convert the UserNames and Passwords ProvidedIinto Credentials
##
$UserProfileAppPoolCredential = New-Object System.Management.Automation.PSCredential $UserProfileApplicationPoolManagedAccount, (ConvertTo-SecureString $UserProfileApplicationPoolPassword -AsPlainText -Force)

##
#Create A Managed Account For The User Profile Account, if it does not exist
#Retrieve the SharePoint Farm Account for the User Profile Sync Account
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Creating Managed Account if Required"
#Check to see if the User Profile Service Application App Pool Account is alrady a managed account.  If not, create it.
if (get-spmanagedaccount $UserProfileApplicationPoolManagedAccount -EA 0)
  {
  Write-Host "Managed Account Exists, No Need to Create a Managed Account" -foregroundcolor "Yellow"
  $UserProfileServiceAccount = Get-SPManagedAccount $UserProfileApplicationPoolManagedAccount
  }
else
  {
  $UserProfileServiceAccount = New-SPManagedAccount -Credential $UserProfileAppPoolCredential
  }
  
#Retrieve the SP Farm account, use that for the User Profile Synchronization  
$UserProfileSyncAccount = Get-SPManagedAccount $SPFarmAccount

##
#Create The Service Application Application Pool
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Creating Application Pool"

$UserProfileServiceApplicationPool = New-SPServiceApplicationPool -Name ($UserProfileServiceApplicationName + " Pool") -Account $UserProfileServiceAccount

##
#Retrieve the Service Instances You Wish to Start, Start the User Profile Service Instance
#The User Profile Synchrinization Service cannot be started until a User Profile Service Application has been created and associated with the service instance.
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Starting User Profile Service"

$UPSI = get-spserviceinstance | where {$_.server -like "*" + $ProfileSyncServer -and $_.Typename -eq "User Profile Service"} | Start-SPServiceInstance # Pls check the service instance first
$UserProfileSyncServiceInstance = get-spserviceinstance | where {$_.server -like "*" + $ProfileSyncServer -and $_.Typename -eq "User Profile Synchronization Service"}

##
#Create the User Profile Service Application
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Creating User Profile Service Application"
$UserProfileSA = New-SPProfileServiceApplication -Name $UserProfileServiceApplicationName -ApplicationPool $UserProfileServiceApplicationPool -ProfileDBName $UserProfileDB -ProfileSyncDBName $UserProfileSyncDB -SocialDBName $UserProfileSocialDB

##
#Set Some of the User Profile Service Application Properties
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Setting User Profile Service Application Properties"
$SPUserprofileMachine = get-spserver $ProfileSyncServer
$UserProfileSA.SetSynchronizationMachine($ProfileSyncServer, $UserProfileSyncServiceInstance.id, $UserProfileSyncAccount.username, $FarmAccountPassword)

##
#Create the User Profile Service Application Proxy
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Creating User Profile Service Application Proxy"

New-SPProfileServiceApplicationProxy -Name ($UserProfileServiceApplicationName + " Proxy") -ServiceApplication $UserProfileSA -DefaultProxyGroup

##
#Start the User Profile Synchronization Service
##

Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Starting User Profile Synchronization Service"

Start-SPServiceInstance $UserProfileSyncServiceInstance

##
#Perform an IISReset.  Skipping this step may result in not being able to manage your User Profile Service Application through SharePoint Central Administration
##

while ($UserProfileSyncServiceInstance.status -ne "online")
{
    pollservice
    Write-Progress -Activity "Provisioning User Profile Service Application" -Status "Waiting for User Profile Synchronization Service to Start"
    $UserProfileSyncServiceInstance = get-spserviceinstance | where {$_.server -like "*" + $ProfileSyncServer -and $_.Typename -eq "User Profile Synchronization Service"}
}

Write-Host "Resetting IIS"
cmd.exe /c "iisreset $ProfileSyncServer /noforce"
