#
# This script is to export all SharePoint App Principals that registered with ACS (aka azure access control service, low-trust provider-hosted add-ins, which https://accounts.accesscontrol.windows.net will be deprecated by end of 2023)
#

Import-Module Microsoft.Graph

Connect-MgGraph -Scopes "Application.Read.All"

$legacyServicePrincipals = Get-MgServicePrincipal -Filter { ServicePrincipalType eq 'Legacy' }

# remove any principals that don't have KeyCredentials (Workflow, Napa, etc.)
$legacyServicePrincipals = $legacyServicePrincipals | Where-Object -Property KeyCredentials

$results = @()

foreach( $legacyServicePrincipal in $legacyServicePrincipals )
{
    $results += [PSCustomObject] @{
                    ServicePrincipalId    = $legacyServicePrincipal.Id
                    ClientId              = $legacyServicePrincipal.AppId
                    DisplayName           = $legacyServicePrincipal.DisplayName
                    CreatedDate           = $legacyServicePrincipal.AdditionalProperties["createdDateTime"]
                    RedirectURL           = $legacyServicePrincipal.ReplyUrls -join ','
                    AppDomain             = $legacyServicePrincipal.ServicePrincipalNames[-1] -replace "$($legacyServicePrincipal.AppId)/", ""
                    StartDateTime         = $legacyServicePrincipal.KeyCredentials | SELECT -First 1 -ExpandProperty StartDateTime
                    EndDateTime           = $legacyServicePrincipal.KeyCredentials | SELECT -First 1 -ExpandProperty EndDateTime
                }
}

$results | Export-Csv -Path "SharePointAppPrincipals.csv" -NoTypeInformation