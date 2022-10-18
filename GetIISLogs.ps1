<# =====================================================================
## Title       : GetIISLogs
## Description : This script will collect Individual IIS logs from specified servers or all servers in the farm. It will compress them into <servername>.zip files
## Authors      :  Anthony Casillas | Mike Lee | Lenny Vaznis
## Date        : 11-03-2021
## Input       : 
## Output      : 
## Usage       : .\GetIISLogs.ps1 -startDate "10/31/2021" -endDate "11/01/2021" -Url http://v7.ajcns.com
## Notes       :  If no '-Servers' switch is passed, it will grab IIS from all SP servers in the farm that have an Online SharePoint Web App Service Instance
## Tag         :  IIS, Logging, Sharepoint, Powershell
## 
## =====================================================================
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)][AllowNull()]
    [string[]]$Servers,
 
    # name of list
    [Parameter(Mandatory = $true, HelpMessage = 'Enter time format like: "01/01/2019" ')]
    [string] $startDate,
 
    # name of field
    [Parameter(Mandatory = $true, HelpMessage = 'Enter time format like: "01/01/2019" ')]
    [string] $endDate,

    [Parameter(Mandatory = $true, HelpMessage = 'Enter URL like http://sp.foo.com ')]
    [string] $Url
)

[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )
Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue
Start-SPAssignment -Global

#########################################

function grabIISLogs($serv) {
    $logFilePath = "\\" + $serv + "\" + $logFileDirectory + "\w3svc" + $iisSiteId
    "Getting ready to copy logs from: " + $logFilePath
    ""
    # setting the startDate variable 
    $startDate = $startDate.Replace('"', "")
    $startDate = $startDate.Replace("'", "")
    $sDate = (Get-Date $startDate).ToString("yyMMdd")

    # setting the endDate variable
    $endDate = $endDate.Replace('"', "")
    $endDate = $endDate.Replace("'", "")
    $eDate = (Get-Date $endDate).ToString("yyMMdd")
    
    $files = get-childitem -path $logFilePath | ? { $_.Extension -eq ".log" }
    $specfiles = $files | ? { ($_ -match 'u_ex(\d+)\.log' -or $_ -match 'u_ex(\d+)_x\.log' ) -and [int]$matches[1] -ge $sDate -and [int]$matches[1] -le $eDate }
    if ($specfiles.Length -eq 0) {
        " We did not find any IIS logs for server, " + $serv + ", within the given time range"
        $rmvDir = $outputdir + "\" + $serv
        rmdir $rmvDir -Recurse -Force
        return;
    }
    foreach ($file in $specfiles) {
        $filename = $file.name
        $destFileName = $serv + "_" + $filename
        "Copying file:  " + $filename
        copy-item "$logFilePath\$filename" $outputdir\$serv\$destFileName
    }

    $timestamp = $(Get-Date -format "yyyyMMdd_HHmm")
    $sourceDir = $tempSvrPath
    $zipfilename = $tempSvrPath + "_" + $timestamp + ".zip"
    ""
    Write-Host ("Compressing IIS logs to location: " + $zipfilename) -ForegroundColor DarkYellow
    
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory( $tempSvrPath, $zipfilename, $compressionLevel, $false )
    Write-Host ("Cleaning up the IIS logs and temp directory at: " + $tempSvrPath) -ForegroundColor DarkYellow
    rmdir $sourcedir -Recurse -Force
}

######################
#Get Destination Path#
######################

Write-Host "Enter a folder path where you want the IIS log files saved"
$outputDir = Read-Host "(For Example: C:\Temp)"

if (test-path -Path $outputDir)
{ Write-Host }

else {
    Write-Host "The path you provided could not be found" -foregroundcolor Yellow
    Write-Host "Path Specified: " $outputDir -ForegroundColor Yellow
    Write-Host
    $outputDir = Read-Host "Enter a folder path where you want the IIS log files saved (For Example: C:\Temp\)"
    $checkPath = test-path $outputDir

    if ($checkPath -ne $true) {
        Write-Host "Path was not found - Exiting Script" -ForegroundColor Yellow
        Return
    }
    else
    { Write-Host "Path is now valid and will continue" }
}

########################################
#Get SharePoint Servers and SP Version##
########################################

$spVersion = (Get-PSSnapin Microsoft.Sharepoint.Powershell).Version.Major

if ((($spVersion -ne 14) -and ($spVersion -ne 15) -and ($spVersion -ne 16))) {
    Write-Host "Supported version of SharePoint not Detected" -ForegroundColor Yellow
    Write-Host "Script is supported for SharePoint 2010, 2013, 2016, 2019" -ForegroundColor Yellow
    Write-Host "Exiting Script" -ForegroundColor Yellow
    Return
}
else {
    ##  get the SPSite and IIS SIte ID ##

    $appCmd = "C:\windows\system32\inetsrv\appcmd.exe"
    $env:Url = $Url
    $site = Get-SPSite $Url
    $aam = Get-SPAlternateURL -WebApplication $site.WebApplication | ? { $_.PublicUrl -eq $Url -or $_.IncomingUrl -eq $Url }
    $iisSiteId = ($site.WebApplication.GetIisSettingsWithFallback($aam.UrlZone)).PreferredInstanceId
    $env:iisSiteId = $iisSiteId
    $iisLogDirectory = & $appCmd --% list site /id:%iisSiteId% /text:logFile.Directory
    $logFileDirectory = ($iisLogDirectory.ToLower()).Replace(":", "$")

    Write-Host (" **We will copy files from each server into a temp directory in the defined Output Folder and then compress those files into a .zip file. This can take several minutes to complete depending on network speed, number of files and size of files.") -ForegroundColor Cyan
    ""
    Write-Host(" **** If the Url you entered is not in the Default zone, and is not backed with an IIS site, like we recommend, then the IIS Logs we collect, may not be from the correct IIS Site.") -ForegroundColor Yellow
    ""
    Write-Host("    The IIS Site Id for $Url is:   $iisSiteId") -ForegroundColor DarkCyan
}

######################################
######################################

if ($Servers -eq $null) {
    $webAppServiceInstances = Get-SPServiceInstance | ? { $_.TypeName -eq "Microsoft SharePoint Foundation Web Application" -and $_.Status -eq "Online" } | select Server
    $Servers = @()
    foreach ($webAppSi in $webAppServiceInstances) {
        $Servers += $webAppSi.Server.Address.ToLower()
    }
    #$Servers
} 
foreach ($server in $Servers) {
    $serverName = $server
    $tempSvrPath = $outputDir + "\" + $servername
    ""
    "Creating a temp directory at: " + $tempSvrPath
    mkdir $tempSvrPath | Out-Null
    grabIISLogs $serverName
}
""
Write-Host ("Finished Copying\Zipping files.. Please upload the zip files located at:  " + $outputDir) -ForegroundColor Green