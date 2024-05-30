using Microsoft.SharePoint.Client;
using NLog;
using OfficeDevPnP.Core;
using System;
using System.Diagnostics;
using System.Windows.Forms;

namespace TokenHelper
{
    public partial class TokenHelper : MetroFramework.Forms.MetroForm
    {
        Logger log = LogManager.GetLogger(typeof(Program).FullName);

        public TokenHelper()
        {
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            log.Info("Hello world, the form has been loaded");

            HideAdfsParameterControls();
            checkHighTrust.Checked = true;

            LoadSettings();
        }

        private void TokenHelper_FormClosing(object sender, System.Windows.Forms.FormClosingEventArgs e)
        {
            log.Info("Bye world, the form is closing");
            SaveSettings();
        }

        private void ShowAdfsParameterControls()
        {
            lbSpDomain.Show();
            txtSpDomain.Show();
            lbSpSts.Show();
            txtSpSts.Show();
            lbSpIdp.Show();
            txtSpIdp.Show();
            lbSpTokenExpirationWindow.Show();
            txtSpTokenExpirationWindow.Show();
        }

        private void HideAdfsParameterControls()
        {
            lbSpDomain.Hide();
            txtSpDomain.Hide();
            lbSpSts.Hide();
            txtSpSts.Hide();
            lbSpIdp.Hide();
            txtSpIdp.Hide();
            lbSpTokenExpirationWindow.Hide();
            txtSpTokenExpirationWindow.Hide();
        }

        private void ShowHighTrustParameterControls()
        {
            lbSpCertificateIssuerId.Show();
            txtSpCertificateIssuerId.Show();
            lbSpCertificatePath.Show();
            txtSpCertificatePath.Show();
            lbSpCertificatePasswords.Show();
            txtSpCertificatePasswords.Show();
            btnSpCertificatePath.Show();
            lbSpAppSecret.Hide();
            txtSpAppSecret.Hide();
        }

        private void HideHighTrustParameterControls()
        {
            lbSpCertificateIssuerId.Hide();
            txtSpCertificateIssuerId.Hide();
            lbSpCertificatePath.Hide();
            txtSpCertificatePath.Hide();
            lbSpCertificatePasswords.Hide();
            txtSpCertificatePasswords.Hide();
            btnSpCertificatePath.Hide();
            lbSpAppSecret.Show();
            txtSpAppSecret.Show();
        }

        private void LoadSettings()
        {
            txtSpoSiteUrlCredentials.Text = Properties.Settings.Default.SiteUrlSpoCred;
            txtSpoUsername.Text = Properties.Settings.Default.UsernameSpo;
            txtSpoPasswords.Text = Properties.Settings.Default.PasswordsSpo;

            txtSpoSiteUrlAppOnly.Text = Properties.Settings.Default.SiteUrlSpoApp;
            txtSpoAppId.Text = Properties.Settings.Default.AppIdSpo;
            txtSpoAppSecret.Text = Properties.Settings.Default.AppSecretSpo;

            txtSpoSiteUrlInteractive.Text = Properties.Settings.Default.SiteUrlSpoInteractive;

            txtSpSiteUrlCredentials.Text = Properties.Settings.Default.SiteUrlSpCred;
            txtSpUsername.Text = Properties.Settings.Default.UsernameSp;
            txtSpPasswords.Text = Properties.Settings.Default.PasswordsSp;

            txtSpDomain.Text = Properties.Settings.Default.DomainAdfs;
            txtSpSts.Text = Properties.Settings.Default.StsAdfs;
            txtSpIdp.Text = Properties.Settings.Default.IdpAdfs;
            txtSpTokenExpirationWindow.Text = Properties.Settings.Default.TokenExpAdfs;

            txtSpSiteUrlAppOnly.Text = Properties.Settings.Default.SiteUrlSpoApp;
            txtSpAppId.Text = Properties.Settings.Default.AppIdSp;

            txtSpCertificateIssuerId.Text = Properties.Settings.Default.CertificateIssuerIdSp;
            txtSpCertificatePath.Text = Properties.Settings.Default.CertificatePathSp;
            txtSpCertificatePasswords.Text = Properties.Settings.Default.CertificatePasswordsSp;

            txtAzureSiteUrl.Text = Properties.Settings.Default.SiteUrlAzureAdCred;
            txtAzureClientId.Text = Properties.Settings.Default.ClientIdAzureAd;
            txtAzureRedirectUrl.Text = Properties.Settings.Default.RedirectUrlAzureAdCred;

            txtAzureSiteUrlAppOnly.Text = Properties.Settings.Default.SiteUrlAzureAdApp;
            txtAzureAdTenant.Text = Properties.Settings.Default.TenatAzureAd;
            txtAzureAppIdAppOnly.Text = Properties.Settings.Default.AppIdAzureAd;
            txtAzureCertificatePath.Text = Properties.Settings.Default.CertificatePathAzureAd;
            txtAzureCertificatePasswords.Text = Properties.Settings.Default.CertificatePasswordsAzureAd;
        }

        private void SaveSettings()
        {
            Properties.Settings.Default.SiteUrlSpoCred = txtSpoSiteUrlCredentials.Text;
            Properties.Settings.Default.UsernameSpo = txtSpoUsername.Text;
            Properties.Settings.Default.PasswordsSpo = txtSpoPasswords.Text;

            Properties.Settings.Default.SiteUrlSpoApp = txtSpoSiteUrlAppOnly.Text;
            Properties.Settings.Default.AppIdSpo = txtSpoAppId.Text;
            Properties.Settings.Default.AppSecretSpo = txtSpoAppSecret.Text;

            Properties.Settings.Default.SiteUrlSpoInteractive = txtSpoSiteUrlInteractive.Text;

            Properties.Settings.Default.SiteUrlSpCred = txtSpSiteUrlCredentials.Text;
            Properties.Settings.Default.UsernameSp = txtSpUsername.Text;
            Properties.Settings.Default.PasswordsSp = txtSpPasswords.Text;

            Properties.Settings.Default.DomainAdfs = txtSpDomain.Text;
            Properties.Settings.Default.StsAdfs = txtSpSts.Text;
            Properties.Settings.Default.IdpAdfs = txtSpIdp.Text;
            Properties.Settings.Default.TokenExpAdfs = txtSpTokenExpirationWindow.Text;

            Properties.Settings.Default.SiteUrlSpoApp = txtSpSiteUrlAppOnly.Text;
            Properties.Settings.Default.AppIdSp = txtSpAppId.Text;

            Properties.Settings.Default.CertificateIssuerIdSp = txtSpCertificateIssuerId.Text;
            Properties.Settings.Default.CertificatePathSp = txtSpCertificatePath.Text;
            Properties.Settings.Default.CertificatePasswordsSp = txtSpCertificatePasswords.Text;

            Properties.Settings.Default.SiteUrlAzureAdCred = txtAzureSiteUrl.Text;
            Properties.Settings.Default.ClientIdAzureAd = txtAzureClientId.Text;
            Properties.Settings.Default.RedirectUrlAzureAdCred = txtAzureRedirectUrl.Text;

            Properties.Settings.Default.SiteUrlAzureAdApp = txtAzureSiteUrlAppOnly.Text;
            Properties.Settings.Default.TenatAzureAd = txtAzureAdTenant.Text;
            Properties.Settings.Default.AppIdAzureAd = txtAzureAppIdAppOnly.Text;
            Properties.Settings.Default.CertificatePathAzureAd = txtAzureCertificatePath.Text;
            Properties.Settings.Default.CertificatePasswordsAzureAd = txtAzureCertificatePasswords.Text;

            Properties.Settings.Default.Save();
        }

        private void BtnGo_Click(object sender, EventArgs e)
        {
            try
            {
                Cursor.Current = Cursors.WaitCursor;
                lbHint.Text = "Trying...";

                #region SharePoint Online 

                if (toggleSpoCredentials.Checked)
                {
                    // SharePoint Online Credentials 
                    log.Info("Getting the client context now using GetSharePointOnlineAuthenticatedContextTenant sharepoint online credentials, delegated");
                    using (ClientContext cc = new AuthenticationManager().GetSharePointOnlineAuthenticatedContextTenant(txtSpoSiteUrlCredentials.Text, txtSpoUsername.Text, txtSpoPasswords.Text))
                    {
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetSharePointOnlineAuthenticatedContextTenant");
                    }
                }

                if (toggleSpoAppOnly.Checked)
                {
                    // SharePoint Online App Only 
                    log.Info("Getting the client context now using GetAppOnlyAuthenticatedContext sharepoint online app only, low trust");
                    using (ClientContext cc = new AuthenticationManager().GetAppOnlyAuthenticatedContext(txtSpoSiteUrlAppOnly.Text, txtSpoAppId.Text, txtSpoAppSecret.Text))
                    {
                        log.Debug(string.Format("Getting the access token: {0}", cc.GetAccessToken()));
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetAppOnlyAuthenticatedContext");
                    }
                }

                if (toggleSpoInteractive.Checked)
                {
                    // SharePoint Online Interactive 
                    log.Info("Getting the client context now using GetWebLoginClientContext sharepoint online interactive, delegated");
                    using (ClientContext cc = new AuthenticationManager().GetWebLoginClientContext(txtSpoSiteUrlInteractive.Text))
                    {
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetWebLoginClientContext");
                    }
                }

                #endregion SharePoint Online 

                #region SharePoint On Prem 

                if (toggleSpCredentials.Checked && !checkADFS.Checked)
                {
                    // SharePoint On Prem Credentials, without ADFS 
                    log.Info("Getting the client context now using GetNetworkCredentialAuthenticatedContext sharepoint on prem credentials, delegated no ADFS");
                    using (ClientContext cc = new AuthenticationManager().GetNetworkCredentialAuthenticatedContext(txtSpSiteUrlCredentials.Text, txtSpUsername.Text, txtSpPasswords.Text, txtSpDomain.Text))
                    {
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetNetworkCredentialAuthenticatedContext");
                    }
                }

                if (toggleSpCredentials.Checked && checkADFS.Checked)
                {
                    // SharePoint On Prem Credentials, with ADFS 
                    log.Info("Getting the client context now using GetADFSUserNameMixedAuthenticatedContext sharepoint on prem credentials, delegated with ADFS");
                    using (ClientContext cc = new AuthenticationManager().GetADFSUserNameMixedAuthenticatedContext(txtSpSiteUrlCredentials.Text, txtSpUsername.Text, txtSpPasswords.Text, txtSpDomain.Text, txtSpSts.Text, lbSpIdp.Text, lbSpTokenExpirationWindow.Text.ToInt32()))
                    {
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetADFSUserNameMixedAuthenticatedContext");
                    }
                }

                if (toggleSpAppOnly.Checked && checkHighTrust.Checked)
                {
                    // SharePoint On Prem App Only, High Trust 
                    log.Info("Getting the client context now using GetHighTrustCertificateAppOnlyAuthenticatedContext sharepoint on prem, app only high trust");
                    using (ClientContext cc = new AuthenticationManager().GetHighTrustCertificateAppOnlyAuthenticatedContext(txtSpSiteUrlAppOnly.Text, txtSpAppId.Text, txtSpCertificatePath.Text, txtSpCertificatePasswords.Text, txtSpCertificateIssuerId.Text))
                    {
                        log.Debug(string.Format("Getting the access token: {0}", cc.GetAccessToken()));
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetHighTrustCertificateAppOnlyAuthenticatedContext");
                    }
                }

                if (toggleSpAppOnly.Checked && !checkHighTrust.Checked)
                {
                    // SharePoint On Prem App Only, Low Trust 
                    log.Info("Getting the client context now using GetAppOnlyAuthenticatedContext sharepoint on prem, app only low trust");
                    using (ClientContext cc = new AuthenticationManager().GetAppOnlyAuthenticatedContext(txtSpSiteUrlAppOnly.Text, txtSpAppId.Text, txtSpAppSecret.Text))
                    {
                        log.Debug(string.Format("Getting the access token: {0}", cc.GetAccessToken()));
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetAppOnlyAuthenticatedContext");
                    }
                }

                #endregion SharePoint On Prem 

                #region Azure Ad 

                if (toggleAzureNativeApp.Checked)
                {
                    // Azure native app 
                    log.Info("Getting the client context now using GetAzureADNativeApplicationAuthenticatedContext sharepoint on prem credentials, delegated interactive");
                    using (ClientContext cc = new AuthenticationManager().GetAzureADNativeApplicationAuthenticatedContext(txtAzureSiteUrl.Text, txtAzureClientId.Text, txtAzureRedirectUrl.Text))
                    {
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetAzureADNativeApplicationAuthenticatedContext");
                    }
                }

                if (toggleAzureAppOnly.Checked)
                {
                    // Azure app only 
                    log.Info("Getting the client context now using GetAzureADAppOnlyAuthenticatedContext sharepoint on prem, app only high trust");
                    using (ClientContext cc = new AuthenticationManager().GetAzureADAppOnlyAuthenticatedContext(txtAzureSiteUrlAppOnly.Text, txtAzureAppIdAppOnly.Text, txtAzureAdTenant.Text, txtAzureCertificatePath.Text, txtAzureCertificatePasswords.Text))
                    {
                        log.Debug(string.Format("Getting the access token: {0}", cc.GetAccessToken()));
                        Web web = cc.Web;
                        cc.Load(web, w => w.Title);
                        cc.ExecuteQueryRetry();

                        lbHint.Text = System.String.Format("You've just got the token, the site title is {0}", web.Title);
                        log.Info("You've got the token via GetAzureADAppOnlyAuthenticatedContext");
                    }
                }

                #endregion Azure Ad 
            }
            catch (Exception ex)
            {
                lbHint.Text = "Something went wrong, pls check the log file for more details";
                log.Error(ex, "Getting errors while BtnGo_Click");
            }
            finally
            {
                Cursor.Current = Cursors.Default;
            }
        }

        private void BtnLogs_Click(object sender, EventArgs e)
        {
            try
            {
                Process.Start(@".\Logs");
                lbHint.Text = "";
            }
            catch (Exception ex)
            {
                lbHint.Text = "Something went wrong, pls check the config file";
                log.Error(ex, "Getting errors while BtnLogs_Click");
            }
        }

        private void CheckADFS_CheckedChanged(object sender, EventArgs e)
        {
            try
            {
                if (!checkADFS.Checked)
                {
                    HideAdfsParameterControls();
                }
                else
                {
                    ShowAdfsParameterControls();
                }
            }
            catch (Exception ex)
            {
                lbHint.Text = "Something went wrong, pls check the config file";
                log.Error(ex, "Getting errors while CheckADFS_CheckedChanged");
            }
        }

        private void CheckHighTrust_CheckedChanged(object sender, EventArgs e)
        {
            try
            {
                if (checkHighTrust.Checked)
                {
                    ShowHighTrustParameterControls();
                }
                else
                {
                    HideHighTrustParameterControls();
                }
            }
            catch (Exception ex)
            {
                lbHint.Text = "Something went wrong, pls check the config file";
                log.Error(ex, "Getting errors while CheckHighTrust_CheckedChanged");
            }
        }

        private void BtnSpCertificatePath_Click(object sender, EventArgs e)
        {
            try
            {
                openFileDialog1.ShowDialog();
                txtSpCertificatePath.Text = openFileDialog1.FileName;

            }
            catch (Exception ex)
            {
                lbHint.Text = "Something went wrong, pls check the config file";
                log.Error(ex, "Getting errors while CheckHighTrust_CheckedChanged");
            }
        }

        private void BtnAzureAdCertificatePath_Click(object sender, EventArgs e)
        {
            try
            {
                openFileDialog1.ShowDialog();
                txtAzureCertificatePath.Text = openFileDialog1.FileName;
            }
            catch (Exception ex)
            {
                lbHint.Text = "Something went wrong, pls check the config file";
                log.Error(ex, "Getting errors while CheckHighTrust_CheckedChanged");
            }
        }
    }
}
