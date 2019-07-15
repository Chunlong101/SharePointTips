Add-PSSnapin microsoft.sharepoint.powershell -ErrorAction SilentlyContinue
 
$WebUrl = "http://localhost" 
$ListName = "Test" 
$FileUpload = "C:\DocumentsReports.csv" 
 
$ErrorActionPreference = "Stop"
 
$Web = Get-SPWeb $WebUrl
 
try
{
 
    $List = $Web.GetFolder($ListName)
 
    $Files = $List.Files
 
    $File = Get-ChildItem $FileUpload
 
    $Files.Add($File.Name, $File.OpenRead(), $true) 
}
catch 
{
    $_
}
finally
{
    $Web.Dispose()
} 
