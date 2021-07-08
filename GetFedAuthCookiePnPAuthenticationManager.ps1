拿FedAuth Cookie需要借助浏览器(IE): 

https://github.com/pnp/PnP-Sites-Core/blob/deba8844ac45fa3e481ab11c66dfa4cd85489b4d/Core/OfficeDevPnP.Core/AuthenticationManager.cs#L407

https://docs.microsoft.com/en-us/dotnet/api/officedevpnp.core.authenticationmanager?view=sharepoint-pnpcoreol-3.2.1810

Connect-PnPOnline -UseWebLogin

///<summary>
///Returns a SharePoint on-premises / SharePoint Online ClientContext object. Requires claims based authentication with FedAuth cookie.
///</summary>
///<paramname="siteUrl">Site for which the ClientContext object will be instantiated</param>
///<paramname="icon">Optional icon to use for the popup form</param>
///<paramname="scriptErrorsSuppressed">Optional parameter to set WebBrowser.ScriptErrorsSuppressed value in the popup form</param>
///<paramname="loginRequestUri">Optional URL to use to log the user in to a specific page. If not provided, the <paramrefname="siteUrl"/> will be used.</param>
///<returns>ClientContext to be used by CSOM code</returns>
publicClientContextGetWebLoginClientContext(stringsiteUrl, System.Drawing.Iconicon= null, boolscriptErrorsSuppressed= true, UriloginRequestUri= null)
{
    varauthCookiesContainer = newCookieContainer();
    varsiteUri = newUri(siteUrl);

    varthread = newThread(() =>
    {
        varform = newSystem.Windows.Forms.Form();
        if (icon != null)
        {
            form.Icon = icon;
        }
        varbrowser = newSystem.Windows.Forms.WebBrowser
            {
            ScriptErrorsSuppressed = scriptErrorsSuppressed,
            Dock = DockStyle.Fill
        };

        form.SuspendLayout();
        form.Width = 900;
        form.Height = 500;
        form.Text = $"Log in to {siteUrl}";
        form.Controls.Add(browser);
        form.ResumeLayout(false);

        browser.Navigate(loginRequestUri ?? siteUri);

        browser.Navigated += (sender, args) =>
        {
            if ((loginRequestUri ?? siteUri).Host.Equals(args.Url.Host))
            {
                varcookieString = CookieReader.GetCookie(siteUrl).Replace("; ", ",").Replace(";", ",");

                //Get FedAuth and rtFa cookies issued by ADFS when accessing claims aware applications.
                //- or get the EdgeAccessCookie issued by the Web Application Proxy (WAP) when accessing non-claims aware applications (Kerberos).
                IEnumerable<string> authCookies = null;
                if (Regex.IsMatch(cookieString, "FedAuth", RegexOptions.IgnoreCase))
                {
                    authCookies = cookieString.Split(',').Where(c => c.StartsWith("FedAuth", StringComparison.InvariantCultureIgnoreCase) || c.StartsWith("rtFa", StringComparison.InvariantCultureIgnoreCase));
                }
                elseif(Regex.IsMatch(cookieString, "EdgeAccessCookie", RegexOptions.IgnoreCase))
                {
                    authCookies = cookieString.Split(',').Where(c => c.StartsWith("EdgeAccessCookie", StringComparison.InvariantCultureIgnoreCase));
                }
                if (authCookies != null)
                {
                    //Set the authentication cookies both on the SharePoint Online Admin as well as on the SharePoint Online domains to allow for APIs on both domains to be used
                    varauthCookiesString = string.Join(",", authCookies);
                    authCookiesContainer.SetCookies(siteUri, authCookiesString);
                    authCookiesContainer.SetCookies(newUri(siteUri.Scheme + "://" + siteUri.Authority.Replace(".sharepoint.com", "-admin.sharepoint.com")), authCookiesString);
                    form.Close();
                }
            }
        };

        form.Focus();
        form.ShowDialog();
        browser.Dispose();
    });

    thread.SetApartmentState(ApartmentState.STA);
    thread.Start();
    thread.Join();

    if (authCookiesContainer.Count > 0)
    {
        varctx = newClientContext(siteUrl);
#if!SP2013
        ctx.DisableReturnValueCache = true;
#endif
        ctx.ExecutingWebRequest += (sender, e) => e.WebRequestExecutor.WebRequest.CookieContainer = authCookiesContainer;

        ClientContextSettingsclientContextSettings = newClientContextSettings()
        {
            Type = ClientContextType.Cookie,
            SiteUrl = siteUrl,
            AuthenticationManager = this
        };

        ctx.AddContextSettings(clientContextSettings);

        returnctx;
    }

    returnnull;
}