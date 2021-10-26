$Cred = Get-Credential

#
# Enable site policy feature
#
function EnableSitePolicyFeature ($SiteUrl, $Cred) {
    Connect-PnPOnline -Url $SiteUrl -Credentials $Cred

    $sitePolicyFeature = Get-PnPFeature -Scope Site -Identity "2fcd5f8a-26b7-4a6a-9755-918566dba90a"

    if (!$sitePolicyFeature.Current) {
        Enable-PnPFeature "2fcd5f8a-26b7-4a6a-9755-918566dba90a" -Scope Site -Force
    }

    Disconnect-PnPOnline
}

EnableSitePolicyFeature https://xxx.sharepoint.com/sites/xxx

#
# Create a list from stp tempalte
#
function CreateListFromStpTemplate ($SiteUrl, $ListTemplateName, $NewListName, $Cred) {
    Connect-PnPOnline -Url $SiteUrl -Credentials $Cred

    $Context = Get-PnPContext
    $Web = $Context.Site.RootWeb
    $ListTemplates = $Context.Site.GetCustomListTemplates($Web)
    $Context.Load($Web)
    $Context.Load($ListTemplates)
    Invoke-PnPQuery

    $ListTemplate = $ListTemplates | ? { $_.InternalName -eq $ListTemplateName }

    if ($ListTemplate -eq $null) {
        Throw [System.Exception] "Template not found"
    }

    $ListCreation = New-Object Microsoft.SharePoint.Client.ListCreationInformation
    $ListCreation.Title = $NewListName
    $ListCreation.ListTemplate = $ListTemplate

    $Web.Lists.Add($ListCreation)
    Invoke-PnPQuery

    Disconnect-PnPOnline
}

CreateListFromStpTemplate -SiteUrl "https://xxx.sharepoint.com/sites/xxx" -ListTemplateName "ProjectPolicyItemList.stp" -NewListName "ProjectPolicyItemList" -Cred $Cred
