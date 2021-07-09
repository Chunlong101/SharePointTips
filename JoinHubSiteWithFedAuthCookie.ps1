Function Invoke-RestSPO() {
    Param(
        [Parameter(Mandatory = $True)]
        [String]$Url,
        [Parameter(Mandatory = $False)]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,
        [Parameter(Mandatory = $False)]
        [String]$Metadata,
        [Parameter(Mandatory = $False)]
        [System.Byte[]]$Body,
        [Parameter(Mandatory = $False)]
        [String]$RequestDigest,
        [Parameter(Mandatory = $False)]
        [String]$ETag,
        [Parameter(Mandatory = $False)]
        [String]$XHTTPMethod,
        [Parameter(Mandatory = $False)]
        [System.String]$Accept = "application/json;odata=verbose",
        [Parameter(Mandatory = $False)]
        [String]$ContentType = "application/json;odata=verbose",
        [Parameter(Mandatory = $False)]
        [Boolean]$BinaryStringResponseBody = $False,
        [Parameter(Mandatory = $False)]
        $Credentials,
        [Parameter(Mandatory = $False)]
        [String]$Origin,
        [Parameter(Mandatory = $False)]
        $Cookie
    )

    $request = [System.Net.WebRequest]::Create($Url)

    #   Set this for debugging
    $request.Timeout = 100000 * 10000

    if ($Credentials) {
        Write-Host "Using credentials" -ForegroundColor DarkGray
        $request.Credentials = $credentials
    }
    else { 
        if ($Cookie) {
            Write-Host (Get-Date) " Using provided cookie" -ForegroundColor DarkGray
            $request.Headers.Add("Cookie", $Cookie)
        } 
        else {
            Write-Host "Working on devbox" -ForegroundColor DarkGray
            $request.UseDefaultCredentials = $true
        }
    }

    $request.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
    $request.ContentType = $ContentType
    $request.Accept = $Accept
    $request.Method = $Method

    #    if ($Cookie) {
    #         $request.Headers.Add("Cookie", $Cookie)
    #    }

    if ($Origin) {
        $request.Headers.Add("Origin", $Origin)
    }

    if ($RequestDigest) { 
        $request.Headers.Add("X-RequestDigest", $RequestDigest)
    }

    if ($ETag) {
        $request.Headers.Add("If-Match", $ETag)
    }

    if ($XHTTPMethod) {
        $request.Headers.Add("X-HTTP-Method", $XHTTPMethod)
    }

    if ($Metadata -or $Body) {
        if ($Metadata) {
            $Body = [byte[]][char[]]$Metadata
        }

        $request.ContentLength = $Body.Length
        $stream = $request.GetRequestStream()
        $stream.Write($Body, 0, $Body.Length)
    }
    else {
        $request.ContentLength = 0
    }


    $response = $request.GetResponse()
    try {
        if ($BinaryStringResponseBody -eq $False) {
            $streamReader = New-Object System.IO.StreamReader $response.GetResponseStream()
            try {
                $data = $streamReader.ReadToEnd()

                $results = $data | ConvertFrom-Json
                $results.d 
            }
            finally {
                $streamReader.Dispose()
            }
        }
        else {
            $dataStream = New-Object System.IO.MemoryStream
            try {
                Stream-CopyTo -Source $response.GetResponseStream() -Destination $dataStream
                $dataStream.ToArray()
            }
            finally {
                $dataStream.Dispose()
            }
        }
    }
    finally {
        $response.Dispose()
    }
}

Function Get-SPOContextInfo() {
    Param(
        [Parameter(Mandatory = $True)]
        [String]$WebUrl,
        [Parameter(Mandatory = $False)]
        $Credentials,
        [Parameter(Mandatory = $False)]
        [String]$Cookie
    )  
    $Url = $WebUrl + "/_api/contextinfo"
    Invoke-RestSPO -Url $Url -Method "Post" -Credentials $Credentials -Cookie $Cookie
}

Function JoinHubSite() {
    Param(
        [Parameter(Mandatory = $True)]
        [String]$WebUrl,
        [Parameter(Mandatory = $True)]
        [String]$SiteId,
        [Parameter(Mandatory = $False)]
        $Credentials,
        [Parameter(Mandatory = $False)]
        [String]$Cookie
    )  
    $Url = $WebUrl + "/_api/site/JoinHubSite(@v1)?@v1='$SiteId'"
    $ContectInfo = Get-SPOContextInfo -WebUrl $WebUrl -Cookie $Cookie
    $Digest = $ContectInfo.GetContextWebInformation.FormDigestValue
    Invoke-RestSPO -Url $Url -Method "Post" -Cookie $Cookie -RequestDigest $Digest
}

$WebUrl = "https://a830edad9050849jpmwss1eur.sharepoint.com/sites/Chunlong"
$SiteId = "70d1fbae-ba31-4ba9-bd04-4391c26990df"

Import-Module .\HttpRequest.psm1
$Cookie = Get-AuthCookie -Url $WebUrl
JoinHubSite -WebUrl $WebUrl -Cookie $Cookie -SiteId $SiteId