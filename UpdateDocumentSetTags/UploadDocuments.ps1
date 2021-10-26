#
# Current goal: Move all local files (no folders) to corresponding target document set 
#

#
# Variables that need to be changed to meet your environment
#
$workSpace = "C:\Users\chunlonl\VsCode\Repo\Test\15340285" # Where this scripts is stored
$localSubSiteFolderPath = "C:\Users\chunlonl\VsCode\Repo\Test\15340285\Canberra Region Presbytery"
$subSiteUrl = "https://xia053.sharepoint.com/sites/Chunlong/SubSite1"
$managedMetadataColumn = "ManagedMetadata"
$managedMetadataDocumentLibraryLevel = "15340285|Office|T1|Canberra|027050"

#
# Get a logger, the log file will be stored at .\Common\Logging\, pls see more details from https://github.com/Chunlong101/Logger
#
cd $workSpace
Import-Module $workSpace\Common\Logging\NLog.dll
[NLog.LogManager]::LoadConfiguration("$workSpace\Common\Logging\NLog.config")
$log = [NLog.LogManager]::GetCurrentClassLogger()
$ErrorActionPreference = "Stop"

#
# Example: UploadFilesDocumentSet -localFolderLocation "C:\Users\chunlonl\source\repos\Test\15340285\Canberra Region Presbytery\Aimee Louise Kent - 027050\Agreements" -siteUrl "https://xia053.sharepoint.com/sites/chunlong/subsite" -documentSetRelativePath "15340285/Agreements" -managedMetadataColumnName "ManagedMetadata" -managedMetadataDocumentSetLevel "Group|TermSet|Level1|Level2"
# localFolderLocation should be at document set level
# siteUrl should be at sub site level
# documentSetRelativePath should be like LibraryName\DocumentSetName, at document set level, the same as localFolderLocation
# managedMetadataDocumentSetLevel should be mapped with document set level 
#
function UploadFilesDocumentSet() {
    Param(
        [ValidateScript( { If (Test-Path $_) { $true } else { $log.Error("Invalid path given: {0}", $_); return } })] 
        $localFolderLocation,
        [String] 
        $subSiteUrl,
        [String]
        $documentSetRelativePath,
        [String]
        $managedMetadataColumnName,
        [String]
        $managedMetadataDocumentSetLevel
    )
    
    $path = $localFolderLocation.TrimEnd('\')
    $subSiteUrl = $subSiteUrl.TrimEnd('/')
    $documentSetRelativePath = $documentSetRelativePath.TrimEnd('/').TrimStart('/')

    $files = dir $path -Recurse -File

    $log.Info("{0} files + folders now are ready, only files will be uploaded, folders will not, local path: {1}, site url: {2}, document set path: {3}, metadata column: {4}, metadata: {5}", $files.Count, $path, $subSiteUrl, $documentSetRelativePath, $managedMetadataColumnName, $managedMetadataDocumentSetLevel)
        
    foreach ($f in $files) {
        try {
            $log.Trace("No pre-check to see if the resource file exists or not from the target resource, so if you have multiple files with the same file name then only one of them will be uploaded, overwritten actually")
                
            $metadataValue = $managedMetadataDocumentSetLevel + "|" + $f.PSParentPath.Split('\')[-1]
            
            $documentSetRelativePath = $documentSetRelativePath.Replace("- ", "")

            $t = Add-PnPFile -Path $f.FullName -Folder $documentSetRelativePath -Values @{$managedMetadataColumnName = $metadataValue }

            $log.Info("A file has been successfully uploaded, local path: {0}, site url: {1}, document set path: {2}, metadata column: {3}, metadata: {4}", $f.FullName, $subSiteUrl, $documentSetRelativePath, $managedMetadataColumnName, $metadataValue)
        }
        catch {
            $log.Error($_, "Failed uploading, pls check the log file")
            $log.Error($_.ScriptStackTrace)
            $log.Error("Failed to upload, local path: {0}, site url: {1}, document set path: {2}, metadata column: {3}, metadata: {4}", $f.FullName, $subSiteUrl, $documentSetRelativePath, $managedMetadataColumnName, $metadataValue)
        }
    }
}

try {
    $credentials = Get-Credential
    Connect-PnPOnline -Url $subSiteUrl -Credentials $credentials

    # Get all libraries (local folders) under a sub site 
    $localDocumentLibraryFolders = dir $localSubSiteFolderPath -Directory

    foreach ($localDocumentLibrary in $localDocumentLibraryFolders) {
        $spoDocumentLibraryPath = $localDocumentLibrary.FullName.Split('\')[-1]
        # Get all document sets (local folders) under a library 
        $localDocumentSetFolders = dir $localDocumentLibrary.FullName -Directory
        foreach ($localDocumentSet in $localDocumentSetFolders) {
            $localDocumentSetPath = $localDocumentSet.FullName
            $spoDocumentSetName = $localDocumentSetPath.Split('\')[-1]
            $spoDocumentSetPath = $spoDocumentLibraryPath + "/" + $spoDocumentSetName
            $managedMetadataDocumentSetLevel = $managedMetadataDocumentLibraryLevel + "|" + $spoDocumentSetName
            UploadFilesDocumentSet -localFolderLocation $localDocumentSetPath -siteUrl $subSiteUrl -documentSetRelativePath $spoDocumentSetPath -managedMetadataColumnName $managedMetadataColumn -managedMetadataDocumentSetLevel $managedMetadataDocumentSetLevel
        }
    }
}
catch {
    $log.Fatal($_, "Something went wrong, pls check the log file")
    $log.Error($_.ScriptStackTrace)
}
