$Cred = Get-Credential
$SiteURL = "https://xia053.sharepoint.com/sites/Chunlong"
Connect-PnPOnline -Url $SiteURL -Credentials $Cred

# Just created a site column "16096925" (Single line of text) then get its "SchemaXml" property using PnP 
$siteColumn = Get-PnPField | ? {$_.Title -eq "16096925"} 
[string]$schemaXml = $siteColumn.SchemaXml

# Original schema xml 
$schemaXml
<Field Type="Text" DisplayName="16096925" Required="FALSE" EnforceUniqueValues="FALSE" Indexed="FALSE" MaxLength="255" Group="Custom Columns" ID="{53089c27-0a60-479b-8b12-46cb2e5b9419}" SourceID="{3b34f8a3-9980-46ac-9d95-30e49d090d51}" StaticName="_x0031_6096925" Name="_x0031_6096925" Version="1"></Field>

# Change the original schema xml from "Text" to "Date" 
$newSchemaXml = '<Field Type="Date" DisplayName="16096925" Required="FALSE" EnforceUniqueValues="FALSE" Indexed="FALSE" MaxLength="255" Group="Custom Columns" ID="{53089c27-0a60-479b-8b12-46cb2e5b9419}" SourceID="{3b34f8a3-9980-46ac-9d95-30e49d090d51}" StaticName="_x0031_6096925" Name="_x0031_6096925" Version="1"></Field>'
Set-PnPField -Identity "16096925" -Values @{SchemaXml=$newSchemaXml}

# Here comes the error and it's also not able to be deleted from web UI as well 
PS C:\Users\chunlonl\VsCode\Repo\Test> Get-PnPField 16096925
Get-PnPField : Field type Date is not installed properly. Go to the list settings page to delete this field. 
At line:1 char:1
+ Get-PnPField 16096925
+ ~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : WriteError: (:) [Get-PnPField], ServerException
    + FullyQualifiedErrorId : EXCEPTION,SharePointPnP.PowerShell.Commands.Fields.GetField
