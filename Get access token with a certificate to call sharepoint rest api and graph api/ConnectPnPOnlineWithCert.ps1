$password = (ConvertTo-SecureString -AsPlainText 'xxx' -Force)
Connect-PnPOnline -Url "https://5xxsz0.sharepoint.com/sites/test" -ClientId c4941f75-cc4f-4f84-b254-093937eb4b26 -CertificatePath 'C:\Users\chunlonl\Desktop\Tools\Cert\pnp.pfx' -CertificatePassword $password  -Tenant '5xxsz0.onmicrosoft.com'
Get-PnPAccessToken -ResourceTypeName SharePoint # Use this token returned to call sharepoint rest api
Get-PnPAccessToken -ResourceTypeName Graph # Use this token returned to call microsoft graph api