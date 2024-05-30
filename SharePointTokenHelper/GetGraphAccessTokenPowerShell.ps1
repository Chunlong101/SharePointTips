$ClientID_MSG       = "xxx"
$ClientSecret_MSG   = "xxx"
$loginURL_MSG       = "https://login.microsoftonline.com/xxx/oauth2/v2.0/token"
$scope_MSG          = "https://graph.microsoft.com/.default"
$RequestBody_MSG    = @{grant_type="client_credentials";client_id=$ClientID_MSG;client_secret=$ClientSecret_MSG;scope=$scope}
$oauth_MSG          = Invoke-RestMethod -Method Post -Uri $loginURL_MSG -Body $RequestBody_MSG
$oauth_MSG.access_token
