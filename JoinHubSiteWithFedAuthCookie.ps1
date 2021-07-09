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

#region ClaimsAuth C# code 

$claimsAuthDef = @'
using System;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace ClaimsAuth
{
    public class ClaimsCookie
    {
        public static string GetAuthCookie(Uri targetUri)
        {
            using (ClaimsWebAuth webAuth = new ClaimsWebAuth(targetUri))
            {
                return webAuth.GetAuthCookie();
            }
        }
    }

    public class ClaimsWebAuth : IDisposable
    {
        private WebBrowser webBrowser;
        private Form loginForm;
        private string authCookie;

        public const int DefaultWidth = 925;
        public const int DefaultHeight = 625;

        public Uri TargetUri { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }

        public Uri BaseUri { get; private set; }
        public Uri LoginUri { get; private set; }
        public Uri ReturnUri { get; private set; }

        public ClaimsWebAuth(Uri targetUri)
        {
            this.TargetUri = targetUri;
            this.Width = DefaultWidth;
            this.Height = DefaultHeight;
        }

        public bool Initialize()
        {
            if (this.TargetUri == null)
            {
                return false;
            }

            Uri loginUri, returnUri;
            InitializeAuthUris(this.TargetUri, out loginUri, out returnUri);
            if (loginUri == null || returnUri == null)
            {
                return false;
            }

            this.LoginUri = loginUri;
            this.ReturnUri = returnUri;
            this.BaseUri = new Uri(this.LoginUri, "/");

            return true;
        }

        public string GetAuthCookie()
        {
            if (!this.Initialize())
            {
                return null;
            }

            this.webBrowser = new WebBrowser();
            this.webBrowser.Dock = DockStyle.Fill;
            this.webBrowser.ScriptErrorsSuppressed = true;
            this.webBrowser.Navigated += new WebBrowserNavigatedEventHandler(ClaimsWebBrowser_Navigated);
            this.webBrowser.Navigate(this.LoginUri);

            this.loginForm = new Form();
            this.loginForm.Width = this.Width;
            this.loginForm.Height = this.Height;
            this.loginForm.Text = this.TargetUri.ToString();
            this.loginForm.Controls.Add(this.webBrowser);

            Application.Run(this.loginForm);

            return this.authCookie;
        }

        private void ClaimsWebBrowser_Navigated(object sender, WebBrowserNavigatedEventArgs e)
        {
            if (e.Url == this.ReturnUri)
            {
                string cookie = Win32Utils.GetCookie(this.BaseUri.ToString());
                if (!String.IsNullOrEmpty(cookie))
                {
                    this.authCookie = ExtractAuthCookie(this.BaseUri, cookie);
                    this.loginForm.Close();
                }
            }
        }

        public void Dispose()
        {
            if (this.webBrowser != null)
            {
                ((IDisposable)this.webBrowser).Dispose();
            }
            if (this.loginForm != null)
            {
                ((IDisposable)this.loginForm).Dispose();
            }

            this.webBrowser = null;
            this.loginForm = null;
        }

        public static void InitializeAuthUris(Uri targetUri, out Uri loginUri, out Uri returnUri)
        {
            loginUri = returnUri = null;

            if (targetUri == null)
            {
                return;
            }

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(targetUri);
            request.Method = "OPTIONS";

            WebResponse response = null;
            try
            {
                response = request.GetResponse();
                ExtractAuthUris(response, out loginUri, out returnUri);
            }
            catch (WebException webEx)
            {
                ExtractAuthUris(webEx.Response, out loginUri, out returnUri);
            }
            finally
            {
                if (response != null)
                {
                    response.Close();
                }
            }
        }

        public static void ExtractAuthUris(WebResponse response, out Uri loginUri, out Uri returnUri)
        {
            loginUri = returnUri = null;

            if (response != null)
            {
                string loginUrl = response.Headers["X-Forms_Based_Auth_Required"];
                string returnUrl = response.Headers["X-Forms_Based_Auth_Return_Url"];

                if (!String.IsNullOrEmpty(loginUrl))
                {
                    loginUri = new Uri(loginUrl);
                }

                if (!String.IsNullOrEmpty(returnUrl))
                {
                    returnUri = new Uri(returnUrl);
                }
            }
        }

        public static string ExtractAuthCookie(Uri baseUri, string cookieHeader)
        {
            CookieCollection cookies;

            if (baseUri == null || String.IsNullOrEmpty(cookieHeader))
            {
                return null;
            }

            CookieContainer cc = new CookieContainer();
            cc.SetCookies(baseUri, cookieHeader.Replace("; ", ",").Replace(";", ","));
            cookies = cc.GetCookies(baseUri);

            if (cookies["FedAuth"] != null && cookies["rtFa"] != null)
            {
                return String.Join("; ", cookies["FedAuth"], cookies["rtFa"]);
            }

            return null;
        }
    }

    public static class Win32Utils
    {
        [DllImport("Kernel32.dll")]
        public static extern uint GetLastError();

        private const uint INTERNET_COOKIE_HTTPONLY = 0x00002000;

        [DllImport("wininet.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool InternetGetCookieEx(
            string url,
            string cookieName,
            StringBuilder cookieData,
            ref uint size,
            uint flags,
            IntPtr pReserved);

        public static string GetCookie(string url)
        {
            uint size = 2048;
            StringBuilder sb = new StringBuilder((int)size);

            if (!InternetGetCookieEx(url, null, sb, ref size, INTERNET_COOKIE_HTTPONLY, IntPtr.Zero))
            {
                if (size == 0)
                {
                    return null;
                }

                sb = new StringBuilder((int)size);
                if (!InternetGetCookieEx(url, null, sb, ref size, INTERNET_COOKIE_HTTPONLY, IntPtr.Zero))
                {
                    return null;
                }
            }

            return sb.ToString();
        }
    }
}
'@

Add-Type -TypeDefinition $claimsAuthDef -ReferencedAssemblies "System.Windows.Forms.dll" -IgnoreWarnings

function Get-AuthCookie
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Url
    )

    return [ClaimsAuth.ClaimsCookie]::GetAuthCookie($Url)
}

#endregion ClaimsAuth C# code

$WebUrl = "https://a830edad9050849jpmwss1eur.sharepoint.com/sites/Chunlong"
$SiteId = "70d1fbae-ba31-4ba9-bd04-4391c26990df"

$Cookie = Get-AuthCookie -Url $WebUrl
JoinHubSite -WebUrl $WebUrl -Cookie $Cookie -SiteId $SiteId