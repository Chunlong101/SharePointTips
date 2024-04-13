# ----- 
# Step 1: Create a self-signed certificate, you can skip this step if you already have a one
# ----- 

$CERT_NAME = "MyCert99"
$CERT_PATH = "C:\Temp"
$CERT_Store = "Cert:\CurrentUser\My" # MMC >> Add/Remove Snap-ins >> Certificates >> Current User >> Personal >> MyCert99
$CERT_Subject = "CN=$($CERT_NAME)"

# Create a self-signed certificate that expires in 99 years
$cert = New-SelfSignedCertificate -Subject $CERT_Subject -CertStoreLocation $CERT_Store -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter (Get-Date).AddYears(99)

# Export the certificate to a .cer file. If encountering errors due to policy restrictions then use "Set-ExecutionPolicy RemoteSigned #Unrestricted" or manually export the certificate instead
Export-Certificate -Cert $cert -FilePath "$CERT_PATH\$($CERT_NAME).cer" -Force

<#
Then go to MMC >> Add/Remove Snap-ins >> Certificates >> Current User >> Personal >> MyCert99 >> Export the certificate to a .pfx file with private key, then you should have two files: MyCert99.cer and MyCert99.pfx
#>

# Private key to Base64, not used for current scenario
$privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$privateKeyBytes = $privateKey.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
$privateKeyBase64 = [System.Convert]::ToBase64String($privateKeyBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
$privateKeyString = @"
-----BEGIN PRIVATE KEY-----
$privateKeyBase64
-----END PRIVATE KEY-----
"@
 
# Print private key to output
Write-Host $privateKeyString

# ----- 
# Step 2: Configure your app in azure app registrations
# ----- 

<# Open Azure Portal >> App registrations >> Your app >> Configure your app with proper SharePoint/Graph permissions, upload the certifcate to Azure App #>

# ----- 
# Step 3: Get the access token with the certificate to call SharePoint REST API and Graph API
# ----- 

# Define the Azure AD tenant ID and app client ID
$tenantId = "311ca363-cc76-4086-93a7-94f6b8f4ae2a"
$clientId = "efec52de-b554-40e0-8596-27a895cb4589"
<# 
Use the certificate thumbprint to get the certificate:
$thumbprint = "9c3c823815c56832457ed15b90d0b03261f822e3" # Thumbprint for MyCert99
$cert = Get-Item Cert:\CurrentUser\My\$Thumbprint
#>
$cert = Get-ChildItem -Path $CERT_Store | Where-Object { $_.Subject -Match $CERT_Subject } # | Select-Object FriendlyName, Thumbprint, Subject, NotBefore, NotAfter
$scope = "https://5xxsz0.sharepoint.com"
<# 
For Graph api call:
$scope="https://graph.microsoft.com"
#>

# Function to generate a JWT token (client_assertion)
function GenerateJWT ($cert, $clientId, $tenantId, $scope) {
    $hash = $cert.GetCertHash()
    $hashValue = [System.Convert]::ToBase64String($hash) -replace '\+', '-' -replace '/', '_' -replace '='

    $exp = ([DateTimeOffset](Get-Date).AddHours(1).ToUniversalTime()).ToUnixTimeSeconds()
    $nbf = ([DateTimeOffset](Get-Date).ToUniversalTime()).ToUnixTimeSeconds()

    $jti = New-Guid
    [hashtable]$header = @{alg = "RS256"; typ = "JWT"; x5t = $hashValue }
    [hashtable]$payload = @{aud = "https://login.microsoftonline.com/$tenantId/oauth2/token"; iss = "$clientId"; sub = "$clientId"; jti = "$jti"; exp = $Exp; Nbf = $Nbf }

    $headerjson = $header | ConvertTo-Json -Compress
    $payloadjson = $payload | ConvertTo-Json -Compress

    $headerjsonbase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($headerjson)).Split('=')[0].Replace('+', '-').Replace('/', '_')
    $payloadjsonbase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadjson)).Split('=')[0].Replace('+', '-').Replace('/', '_')

    $toSign = [System.Text.Encoding]::UTF8.GetBytes($headerjsonbase64 + "." + $payloadjsonbase64)

    $rsa = $cert.PrivateKey # -as [System.Security.Cryptography.RSACryptoServiceProvider]

    $signature = [Convert]::ToBase64String($rsa.SignData($toSign, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) -replace '\+', '-' -replace '/', '_' -replace '='

    $token = "$headerjsonbase64.$payloadjsonbase64.$signature"

    return $token # client_assertion
}

# Get the client_assertion
$RequestToken = GenerateJWT -cert $cert -clientId $clientId -tenantId $tenantId -scope $scope

$AccessTokenResponse = Invoke-WebRequest `
    -Method POST `
    -ContentType "application/x-www-form-urlencoded" `
    -Headers @{"accept" = "application/json" } `
    -Body "scope=$($scope)/.default&client_id=$($clientId)&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=$RequestToken&grant_type=client_credentials" `
    -Verbose `
    "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" 

$AccessTokenJsonResponse = ConvertFrom-Json $AccessTokenResponse.Content
$AccessToken = $AccessTokenJsonResponse.access_token

# Output the access token
Write-Output "Access Token: $AccessToken"

<# 
Alternatively, you can also go to MMC >> Add/Remove Snap-ins >> Certificates >> Current User >> Personal >> MyCert99 >> Export the certificate to a .pfx file with private key, then use the following code to get access token(s)
$password = (ConvertTo-SecureString -AsPlainText 'Your Private Key (generated while exporting .pfx)' -Force)
Connect-PnPOnline -Url "https://5xxsz0.sharepoint.com/sites/test" -ClientId $clientId -CertificatePath "$CERT_PATH\\$CERT_NAME.pfx" -CertificatePassword $password  -Tenant '5xxsz0.onmicrosoft.com'
Get-PnPAccessToken -ResourceTypeName SharePoint # Access Token For SharePoint REST API
Get-PnPAccessToken -ResourceTypeName Graph # Access Token For Microsoft Graph API 
#>
