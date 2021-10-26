How to use? 

1. Pls feel free to download the files under 15340285. 
2. Pls install PnP PowerShell for SharePoint Online first before running this scripts, https://github.com/SharePoint/PnP-PowerShell/releases/download/3.11.1907.0/SharePointPnPPowerShellOnline.msi
3. Pls make sure "UploadDocuments.ps1" is under the same directory with "Common". 
4. Pls change those variables insdie UploadDocuments.ps1 to meet your environment, you can also use function "UploadFilesDocumentSet" with different parameters to fulfill further requirements. 
5. If you happen to see "0x80131515" error running the scripts, then pls refer to https://stackoverflow.com/questions/34400546/could-not-load-file-or-assembly-operation-is-not-supported-exception-from-hres

What can this scripts do? 

Move all local files (no folders) to corresponding target document set. It also helps provide the logging service so that you can see errors, exceptions and the which files have been uploaded, logs can be found from .\Common\Logging\Logs. 

