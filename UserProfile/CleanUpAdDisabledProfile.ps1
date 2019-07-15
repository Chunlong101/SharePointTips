# 1. Trigger a full AD import. 
# 2. Set the flags for those users who were disabled in AD. 
# 3. Triger a full AD import again, the SELECT bDeleted FROM upa.UserProfile_Full where NTName like '%spuser%' will be set to 1 after this step. 
# 4. Trigger mysiteclearup timer job, so all the users with bDeleted = 1 will be removed from sharepoint user profile. 

Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

$Location = "C:\Users\Chunlong\desktop\SharePointClearUpAdDisabledProfile" # This variable represents where this script is, pls change the location as your preference but make sure it's not end with "\"

$ErrorActionPreference = "Stop"

$Date = Get-Date -Format "yyyy-MM-dd" 

$LogPath = $Location + "\Logs\" + $Date + ".txt"

if (!(Test-Path $LogPath)) 
{
    try
    {
        $Date >> $LogPath 
    }
    catch [System.Net.WebException],[System.Exception]
    {
        throw $_
    }
}

function SetDeletionFlagForAdDisabledUsers ($Upa, [int] $RetryCount)
{
    if ($RetryCount -eq 0) 
    {
        $RetryCount = 1 
    }

    try
    {
        WriteLog "Entering Set-SPProfileServiceApplication $Upa -GetNonImportedObjects $true"

        $t = Set-SPProfileServiceApplication $Upa -GetNonImportedObjects $true

        $t | % {WriteLog $_}

        WriteLog "Leave Set-SPProfileServiceApplication $Upa -GetNonImportedObjects $true"

        WriteLog "Entering Set-SPProfileServiceApplication $Upa -PurgeNonImportedObjects $true"

        Set-SPProfileServiceApplication $Upa -PurgeNonImportedObjects $true 

        WriteLog "Leave Set-SPProfileServiceApplication $Upa -PurgeNonImportedObjects $true"
    }
    catch [System.Net.WebException],[System.Exception]
    {
        WriteLog $_
        
        Start-Sleep -s 20 

        if ($RetryCount -lt 100) 
        {
            WriteLog "Retrying SetDeletionFlagForAdDisabledUsers, RetryCount is $RetryCount" 

            SetDeletionFlagForAdDisabledUsers -Upa $Upa -RetryCount ($RetryCount + 1)
        }
        else 
        {
            WriteLog "SetDeletionFlagForAdDisabledUsers cannot be done due to the RetryCount is more than 100"
            throw "SetDeletionFlagForAdDisabledUsers cannot be done due to the RetryCount is more than 100"
        }
    }
}

function StartFullAdImport ($Upa) 
{
    try
    {
        $jobAdImport = Get-SPTimerJob -Identity "User Profile Service Application_UserProfileADImportJob"
        $jobAdImportLastRunTime = $jobAdImport.LastRunTime

        $Upa.StartImport($true)
 
        # If last run time does not change, which means the import is still running, then wait for it to complete
 
        do 
        {
         
            Start-Sleep -s 20
 
            $newJobLastRunTime= $jobAdImport.LastRunTime
        
        } while ($newJobLastRunTime -eq $jobAdImportLastRunTime)
    }
    catch [System.Net.WebException],[System.Exception]
    {
        WriteLog $_
        throw $_
    }
}

function StartMySiteClearUp () 
{
    try
    {
        $jobMySiteClearUp = Get-SPTimerJob -Identity "mysitecleanup"

        $jobMySiteClearUpLastRunTime = $jobMySiteClearUp.LastRunTime

        $jobMySiteClearUp.RunNow()

        do 
        {
             
            Start-Sleep -s 20
 
            $newJobLastRunTime= $jobAdImport.LastRunTime
        
        } while ($newJobLastRunTime -eq $jobMySiteClearUpLastRunTime)

    }
    catch [System.Net.WebException],[System.Exception]
    {
        WriteLog $_
        throw $_
    }

}

function WriteLog ([Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [string]$Msg) 
{
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  

    $Msg

    try
    {
        "[$timeStamp] " + $Msg >> $LogPath
    }
    catch [System.Net.WebException],[System.Exception]
    {
        $_
    }
}

$upaSaType = "User Profile Service Application"
$upa = Get-SPServiceApplication | where-object {$_.TypeName -eq $upaSaType}

WriteLog "Starting full AdImport"
 
StartFullAdImport -Upa $upa
 
WriteLog "Full AdImport is complete"

WriteLog "Sleep for 60s to avoid potential conflict"
 
Start-Sleep -s 60

WriteLog "Setting deletion flag for AD disabled users"

SetDeletionFlagForAdDisabledUsers -Upa $upa

WriteLog "Setting deletion flag for AD disabled users is complete"

WriteLog "Starting full AdImport"

StartFullAdImport -Upa $upa

WriteLog "Full AdImport is complete"

WriteLog "Starting MySiteClearUp"

StartMySiteClearUp

WriteLog "MySiteClearUp is complete"
