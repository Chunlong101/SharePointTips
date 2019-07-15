$ErrorActionPreference = "Continue"; # Continue even if there are errors 

# Settings for Email
$users = @("chunlonl@microsoft.com", "jolinner@126.com"); # Who will get the email notification, separated by ","
$sendFrom = "admin@China.YourMemory.MS" 
$smtpServer = "" 
$msgBody = "This is an alert, pls find attachment for more details"

# Settings for workspace, where the script and report are stored on hard drive
$workSpace = "C:\DiskspaceRunner"
$reportFolder = "$workSpace\lOGS\"; 
Add-Type -Path "$workSpace\ClassLibrary1.dll"

# Settings for target objects that will be monitored
$computers = 'localhost'; 
$diskName = 'C:';
$targetFolder = 'C:\Code'; # Should be search index folder in our case

# Settings for thresholds 
$percentWarning = 25; 
$percentCritcal = 15; 
$diffSearchFolderSpaceThreshold = 0.1 # GB, to identify the big jump of search index folder size

# Settings for report
$reportName = "DiskSpaceRpt_$(get-date -format yyyyMMdd).csv"; 
$reportFullName = $reportFolder + $reportName 
$titleDate = get-date -uformat "%m-%d-%Y - %A" 

# Settings for cleaning up old reports
$Daysback = "-7"  # Set to clean the reports which are older than 7 days
$CurrentDate = Get-Date; 
$DateToDelete = $CurrentDate.AddDays($Daysback); 
Get-ChildItem $reportFolder | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item; 

function CreateReportHeader () 
{
    # Create and write HTML Header of report 
    $header = "Daily Morning Report for $titledate" 
    Add-Content $reportFullName $header 
 
    # Create and write Table header for report 
     $tableHeader = "Server, Drive, Drive Label, Total Capacity(GB), Used Space (GB), Freespace (GB), Free, RAM, CPU, SearchIndexFolderSpace (GB), TimeStamp" 
     Add-Content $reportFullName $tableHeader 
}

function CheckDisk () 
{
    # Start processing disk space 
      foreach($computer in $computers) 
     {  
         $disks = Get-WmiObject -ComputerName $computer -Class Win32_LogicalDisk -Filter "DriveType = 3" | ? {$_.DeviceID -eq $diskName}
         $computer = $computer.toupper() 
          foreach($disk in $disks) 
         {         
              $deviceID = $disk.DeviceID; 
              $volName = $disk.VolumeName; 
              [float]$size = $disk.Size; 
              [float]$freespace = $disk.FreeSpace;  
              $percentFree = [Math]::Round(($freespace / $size) * 100); 
              $sizeGB = [Math]::Round($size / 1073741824, 2); 
              $freeSpaceGB = [Math]::Round($freespace / 1073741824, 2); 
              $usedSpaceGB = $sizeGB - $freeSpaceGB; 
              $color = $whiteColor; 
              # Start processing RAM 		
              $RAM = Get-WmiObject -ComputerName $computer -Class Win32_OperatingSystem
	          $RAMtotal = $RAM.TotalVisibleMemorySize;
	          $RAMAvail = $RAM.FreePhysicalMemory;
		      $RAMpercent = [Math]::Round(($RAMavail / $RAMTotal) * 100);
              $CPUpercent = Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average | % {$_.Average};
              $SearchIndexFolderSpace = "{0:N2}" -f ( ( Get-ChildItem $targetFolder -Recurse -Force | Measure-Object -Property Length -Sum ).Sum / 1GB );
              $TimeStamp = [System.DateTime]::Now
  
             # Create table data rows  
              $dataRow = "$computer, $deviceID, $volName, $sizeGB, $usedSpaceGB, $freeSpaceGB, $percentFree%, $RAMpercent%, $CPUpercent%, $SearchIndexFolderSpace, $TimeStamp"

              $dataRow >> $reportFullName

              Write-Host -ForegroundColor DarkYellow "$computer $deviceID percentage free space = $percentFree"; 
              
              $SearchIndexFolderSpace = [System.Convert]::ToDecimal($SearchIndexFolderSpace)

              if ($smtpServer) 
              {

                  if ([System.Math]::Abs($SearchIndexFolderSpace - (GetPreviousSearchIndexFolderSpace)) -ge $diffSearchFolderSpaceThreshold) 
                  {
                    SendEmail
                  }

                  if ($percentFree -lt $percentWarning) 
                  {
                    SendEmail
                  }

                  if ($percentFree -lt $percentCritcal) 
                  {
                    SendEmail
                  }

              }

              GetPreviousSearchIndexFolderSpace
              SetPreviousSearchIndexFolderSpace $SearchIndexFolderSpace
         } 
    } 
}

function GetPreviousSearchIndexFolderSpace () 
{
    return [ClassLibrary1.Class1]::GetTargetFolderSize(); 
}

function SetPreviousSearchIndexFolderSpace ([Parameter(Mandatory=$True)] [float] $Size)
{
    [ClassLibrary1.Class1]::SetTrgetFolderSize($Size); 
}

function SendEmail () 
{
        foreach ($user in $users) 
        {
            Write-Host "Sending Email notification to $user" 

            $smtp = New-Object Net.Mail.SmtpClient($smtpServer) 
            $msg = New-Object Net.Mail.MailMessage 
            $att = new-object Net.Mail.Attachment($reportFullName)
            $msg.To.Add($user) 
            $msg.From = $sendFrom 
            $msg.Subject = "DiskSpace Report for $titledate" 
            $msg.IsBodyHTML = $true 
            $msg.Body = $msgBody 
            $msg.Attachments.Add($att)
            $smtp.Send($msg) 
        } 
}

if (!(Test-Path $reportFullName)) 
{
    CreateReportHeader
}

CheckDisk