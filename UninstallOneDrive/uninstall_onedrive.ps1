Set-Variable -Name "Location_PerMachine" -Value "C:\Program Files\Microsoft OneDrive\"
Set-Variable -Name "Location_PerMachinex86" -Value "C:\Program Files (x86)\Microsoft OneDrive\"
Set-Variable -Name "Location_PerUser" -Value "$env:LOCALAPPDATA\Microsoft\OneDrive\"
Set-Variable -Name "SetupFile" -Value "OneDriveSetup.exe"

function testLocation($loc) {
              Write-Host "Checking for $SetupFile under path $loc" -ForegroundColor DarkGray
    $check = Get-ChildItem -Path $loc -Recurse $SetupFile -ErrorAction SilentlyContinue | Select-Object -Property FullName -First 1
    if(-not $check){
        $result = $false
    } else {
        $result = $check.Fullname
    }
              
              if($result){
                           Write-Host "Found: $result" -ForegroundColor Green
              }
              else{
                           Write-Host "Not Found" -ForegroundColor Red
              }
    return $result
}
function uninstallOneDrive($path, $type) {
    Write-Host "--- --- --- --- ---" -ForegroundColor DarkGray
    Write-Host "Starting $type uninstall"; 
    $uninstall = "/uninstall"
    if ($type -eq "PerMachine") {
        $uninstall = "/allusers /uninstall"
    }
    Write-Host $path $uninstall -ForegroundColor Yellow
    Start-Process -FilePath $path -ArgumentList $uninstall
    Write-Host "--- --- --- --- ---" -ForegroundColor DarkGray
}

Write-Host "--- --- --- --- ---" -ForegroundColor DarkGray
Write-Host "Checking for $SetupFile locations ... "
$path_PerMachine = testLocation $Location_PerMachine
$path_PerMachinex86 = testLocation $Location_PerMachinex86
$path_PerUser = testLocation $Location_PerUser

if($path_PerMachine) {
    # Write-Host "Found 64-bit per-machine installer" -ForegroundColor Green
    uninstallOneDrive $path_PerMachine "PerMachine"
    Start-Sleep -s 5
} 
if($path_PerMachinex86) {
    # Write-Host "Found 32-bit per-machine installer" -ForegroundColor Green
    uninstallOneDrive $path_PerMachinex86 "PerMachine"
    Start-Sleep -s 5
} 
if($path_PerUser) {
    # Write-Host "Found per-user installer" -ForegroundColor Green
              uninstallOneDrive $path_PerUser "PerUser"
    Start-Sleep -s 5
} 

Write-Host All done! -ForegroundColor Green
Read-Host -Prompt "Press Enter to exit"
