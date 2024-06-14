# ----- 
# 2.1.1 - Download a file using PowerShell with Authorization Code Auth flow
# ----- 

#Define Client Variables Here
#############################
$TenantId="ed3c1c81-f3be-495c-8028-f11b7ad6415a"
$clientId = "87202bda-1a2a-4b6c-917b-df77c98c640d"
$clientSecret = "xxx"
$scope = "https://graph.microsoft.com/.default"
$redirectUri = "https://localhost" #this can be set to any URL
#$resource = "https://graph.microsoft.com"

#UrlEncode variables for special characters
###########################################
Add-Type -AssemblyName System.Web
$clientSecretEncoded = [System.Web.HttpUtility]::UrlEncode($clientSecret)
$redirectUriEncoded =  [System.Web.HttpUtility]::UrlEncode($redirectUri)
$scopeEncoded = [System.Web.HttpUtility]::UrlEncode($scope)

#Obtain Authorization Code
##########################
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=440;Height=640}
$web  = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=420;Height=600;Url=$url}
$url = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize?response_type=code&redirect_uri=$redirectUriEncoded&client_id=$clientId&scope=$scopeEncoded&prompt=admin_consent"
$DocComp  = {
        $Global:uri = $web.Url.AbsoluteUri        
        if ($Global:uri -match "error=[^&]*|code=[^&]*") {$form.Close() }
    }
$web.ScriptErrorsSuppressed = $true
$web.Add_DocumentCompleted($DocComp)
$form.Controls.Add($web)
$form.Add_Shown({$form.Activate()})
$form.ShowDialog() | Out-Null
$queryOutput = [System.Web.HttpUtility]::ParseQueryString($web.Url.Query)
$output = @{}
foreach($key in $queryOutput.Keys){
    $output["$key"] = $queryOutput[$key]
}
$regex = '(?<=code=)(.*)(?=&)'
$authCode  = ($uri | Select-string -pattern $regex).Matches[0].Value

#Get Access Token with obtained Auth Code
#########################################
$body = "grant_type=authorization_code&redirect_uri=$redirectUri&client_id=$clientId&client_secret=$clientSecretEncoded&code=$authCode&resource=$resource"
$authUri = "https://login.microsoftonline.com/common/oauth2/token"
$tokenResponse = Invoke-RestMethod -Uri $authUri -Method Post -Body $body -ErrorAction STOP

#Call Graph API to download a file
#########################################
#$DownloadUri=https://graph.microsoft.com/v1.0/me/drive/root:/ee - Copy.xlsx:/content
$DownloadUri = "https://graph.microsoft.com/v1.0/sites/ec884a3f-7f7e-460a-900b-39c61f8195be/drive/items/01DFEMAO44C7FIP2APCBEZFLF67OL6JAIZ/content"
$destinationFilePath = "C:\Users\menxia\Desktop\Files\Graph Test\Test.pdf"
$header =@{
    'Authorization' = "Bearer $($tokenResponse.access_token)"
}

$results = Invoke-RestMethod -Uri $DownloadUri -Headers $header -Method Get -OutFile $destinationFilePath

# ----- 
# 2.2.1 - Add a new folder with PowerShell in client credential grant flow (with secret)
# ----- 

#Define Client Variables Here
#############################
$TenantId='ed3c1c81-f3be-495c-8028-f11b7ad6415a'
$ClientId='87202bda-1a2a-4b6c-917b-df77c98c640d'
$ClientSecret='xxx'

$Body = @{
    'tenant' = $TenantId
    'client_id' = $ClientId
    'scope' = 'https://graph.microsoft.com/.default'
    'client_secret' = $ClientSecret
    'grant_type' = 'client_credentials'
}

$Params = @{
    'Uri' = https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token   #tenant name is also fine here, like xia053.onmicrosoft.com  
    'Method' = 'Post'
    'Body' = $Body
    'ContentType' = 'application/x-www-form-urlencoded'
}

#Get Access Token
##########################
$AuthResponse = Invoke-RestMethod @Params

#Call Graph API to add a new folder 
####################################
$FolderName ='New Folder Name'
$SiteId = 'ec884a3f-7f7e-460a-900b-39c61f8195be'
$Uri=https://graph.microsoft.com/v1.0/sites/$SiteId/drive/root/children
$post = @"
{
        "name":  "$FolderName",
        "folder":  { }
}
"@

$header =@{
    'Authorization' = "Bearer $($AuthResponse.access_token)"
    'Content-Type' = 'application/json'
}

$results = Invoke-WebRequest -Uri $Uri -Headers $header -Method Post -Body $post

# ----- 
# 2.2.2 - Get an item with MSAL in client credential grant flow (with secret)
# ----- 

#	Install MSAL.PS module: https://github.com/AzureAD/MSAL.PS 
 
#	Run command below to get an item by calling Graph API:
$s=Get-MsalToken -ClientId '87202bda-1a2a-4b6c-917b-df77c98c640d' -ClientSecret (ConvertTo-SecureString 'xxx' -AsPlainText -Force)  -TenantId 'ed3c1c81-f3be-495c-8028-f11b7ad6415a' -Scopes 'https://graph.microsoft.com/.default' -Authority https://login.microsoftonline.com/ed3c1c81-f3be-495c-8028-f11b7ad6415a 

$requestUri = https://graph.microsoft.com/v1.0/sites/ec884a3f-7f7e-460a-900b-39c61f8195be/drive/items/01DFEMAO44C7FIP2APCBEZFLF67OL6JAIZ
$header =@{
     'Authorization' = "Bearer $($s.AccessToken)"
}
$results = Invoke-RestMethod -Uri $requestUri -Headers $header -Method Get 
$results 

# ----- 
# 2.2.3 - Get an item with PowerShell in client credential grant flow (with certificate)
# ----- 

#Define Client Variables Here
#############################
$ClientID = "87202bda-1a2a-4b6c-917b-df77c98c640d" # Application/Client id used for the cert name 
$TenantID = "ed3c1c81-f3be-495c-8028-f11b7ad6415a" # tenant id is used for the cert name 
$CertPassWord = "Access1" # Password used for creating the certificate
$aud = https://login.microsoftonline.com/$TenantID/v2.0/
$CertificatePath_Pfx = "C:\Users\menxia\Desktop\VicCert.pfx" # Path where the certificate is saved
$scope = https://graph.microsoft.com/.default

#Install and load DLLs
#############################
Function JsonWeb-Libraries{

    if ( ! (Get-ChildItem $HOME/IdentityModel/lib/Microsoft.IdentityModel.Logging.* -erroraction ignore) ) {
        install-package -Source nuget.org -ProviderName nuget -SkipDependencies Microsoft.IdentityModel.Logging -Destination $HOME/IdentityModel/lib -force -forcebootstrap | out-null
    }
    [System.Reflection.Assembly]::LoadFrom((Get-ChildItem $HOME/IdentityModel/lib/Microsoft.IdentityModel.Logging.*/lib/net45/Microsoft.IdentityModel.Logging.dll).fullname) | out-null
    if ( ! (Get-ChildItem $HOME/IdentityModel/lib/Microsoft.IdentityModel.Tokens.* -erroraction ignore) ) {
        install-package -Source nuget.org -ProviderName nuget -SkipDependencies Microsoft.IdentityModel.Tokens -Destination $HOME/IdentityModel/lib -force -forcebootstrap | out-null
    }
    [System.Reflection.Assembly]::LoadFrom((Get-ChildItem $HOME/IdentityModel/lib/Microsoft.IdentityModel.Tokens.*/lib/net45/Microsoft.IdentityModel.Tokens.dll).fullname) | out-null

    if ( ! (Get-ChildItem $HOME/IdentityModel/lib/Microsoft.IdentityModel.JsonWebTokens.* -erroraction ignore) ) {
        install-package -Source nuget.org -ProviderName nuget -SkipDependencies Microsoft.IdentityModel.JsonWebTokens -Destination $HOME/IdentityModel/lib -force -forcebootstrap | out-null
    }
    [System.Reflection.Assembly]::LoadFrom((Get-ChildItem $HOME/IdentityModel/lib/Microsoft.IdentityModel.JsonWebTokens.*/lib/net45/Microsoft.IdentityModel.JsonWebTokens.dll).fullname) | out-null
}

#Get token with certificate
#############################    
JsonWeb-Libraries
$x509cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath_Pfx, $CertPassWord)
$claims = new-object 'System.Collections.Generic.Dictionary[String, Object]'
$claims['aud'] = $aud
$claims['iss' ] = $ClientID
$claims['sub'] = $ClientID
$claims['jti'] = [GUID]::NewGuid().ToString('D')
                    
$signingCredentials = [Microsoft.IdentityModel.Tokens.X509SigningCredentials]::new($x509cert)
$securityTokenDescriptor = [Microsoft.IdentityModel.Tokens.SecurityTokenDescriptor]::new()
$securityTokenDescriptor.Claims = $claims
$securityTokenDescriptor.SigningCredentials = $signingCredentials

$tokenHandler = [Microsoft.IdentityModel.JsonWebTokens.JsonWebTokenHandler]::new()
$clientAssertion = $tokenHandler.createToken($securityTokenDescriptor)

#Get access token using certificate
###########################################
$Body = @{
    'client_id' = $ClientId
    'scope' = 'https://graph.microsoft.com/.default'
    'client_assertion_type' = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    'client_assertion' = $clientAssertion
    'grant_type' = 'client_credentials'
}

$Params = @{
    'Uri' = https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token   #tenant name is also fine here, like xia053.onmicrosoft.com
    'Method' = 'Post'
    'Body' = $Body
    'ContentType' = 'application/x-www-form-urlencoded'
}

$AuthResponse = Invoke-RestMethod @Params

#Call Graph API to get an item
##################################
$requestUri = https://graph.microsoft.com/v1.0/sites/ec884a3f-7f7e-460a-900b-39c61f8195be/drive/items/01DFEMAO44C7FIP2APCBEZFLF67OL6JAIZ
$header =@{
    'Authorization' = "Bearer $($AuthResponse.access_token)"
}

$results = Invoke-RestMethod -Uri $requestUri -Headers $header -Method Get 
$results 

# ----- 
# 2.2.4 - Download a file using Graph PowerShell SDK (with certificate)
# ----- 

•	Note: we do not support client secret due to security reason: https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/686
 
•	Create a self-signed certfiicate for test: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-self-signed-certificate
$cert = New-SelfSignedCertificate -Subject "CN=VicCert" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256   
 
•	Export-Certificate -Cert $cert -FilePath "C:\Users\menxia\Desktop\VicCert.cer"  
 
•	$mypwd = ConvertTo-SecureString -String "Access1" -Force -AsPlainText  
Export-PfxCertificate -Cert $cert -FilePath "C:\Users\menxia\Desktop\VicCert.pfx" -Password $mypwd 
 
•	Register an application in Azure AD and upload the certificate (.cer) into the registered app. 
 
•	Authenticate to Graph in PowerShell:
Connect-MgGraph -ClientID 87202bda-1a2a-4b6c-917b-df77c98c640d -TenantId ed3c1c81-f3be-495c-8028-f11b7ad6415a -CertificateName "CN=VicCert"
 
•	Connect-MgGraph -ClientID 87202bda-1a2a-4b6c-917b-df77c98c640d -TenantId ed3c1c81-f3be-495c-8028-f11b7ad6415a -CertificateThumbprint 8F1973A927B0DCFA4E4A71B251A3B3CE98C48CEB
 
•	Call Graph API to download a file:
 
•	References: https://docs.microsoft.com/en-us/graph/powershell/navigating

# ----- 
# 2.1.2 - Download a file using Graph PowerShell SDK with Authorization Code Auth flow 
# ----- 

•	Run command to connect Microsoft Graph in PowerShell (auth code flow)
 
•	Or you can run command below to connect Microsoft Graph in PowerShell (using device code flow): https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-device-code         

•	Verify the context for auth code flow:
 
•	Verify the context for device code flow:
 
•	Actually it is using this auto-registered app called Microsoft Graph PowerShell for doing the authentication:
 
•	Call graph API to download a file: 
 
•	Reference: Microsoft.Graph.Files Module | Microsoft Docs