using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Web.UI.WebControls;
using NLog;

namespace AppModelv2_WebApp_OpenIDConnect_DotNet
{
    public partial class Index : System.Web.UI.Page
    {
        private static Logger log = LogManager.GetLogger("Index");

        protected void Page_Load(object sender, EventArgs e)
        {
            // Allow anonymous or not 
            //if (!Request.IsAuthenticated)
            //{
            //    Response.Redirect("~/Home/SignIn");
            //}
            //else
            //{}

            try
            {
                if (!IsPostBack && User.Identity.IsAuthenticated)
                {
                    var claims = ClaimsPrincipal.Current.Identities.First().Claims.ToList();
                    string username = claims?.FirstOrDefault(x => x.Type.Equals("name", StringComparison.OrdinalIgnoreCase))?.Value;
                    SignIn.Text = "Hi " + username;

                    log.Info("Current user is authenticated thru Azure AD OpenId Connect, username : ", username);

                    SignIn.Enabled = false;
                    SignIn.BorderStyle = BorderStyle.None;
                    SignIn.ForeColor = System.Drawing.Color.Black;
                }
            }
            catch (Exception ex)
            {
                log.Fatal("Fatal error occurred pls check the log file for more details : {0}", ex.Message);
                log.Fatal(ex.StackTrace);
                Label1.Text = "Fatal error occurred pls check the log file for more details : " + ex.Message;
            }
        }

        protected void SignIn_Click(object sender, EventArgs e)
        {
            Response.Redirect("~/Home/SignIn");
        }
    }
}