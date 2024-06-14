<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Upload.aspx.cs" Inherits="AppModelv2_WebApp_OpenIDConnect_DotNet.Upload" %>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1">
    <meta name="description" content="Microsoft Graph Api Demo Site">
    <title>Home</title>
    <link rel="stylesheet" href="assets/bootstrap/css/bootstrap.min.css">
    <link rel="stylesheet" href="assets/bootstrap/css/bootstrap-grid.min.css">
    <link rel="stylesheet" href="assets/bootstrap/css/bootstrap-reboot.min.css">
    <link rel="stylesheet" href="assets/parallax/jarallax.css">
    <link rel="stylesheet" href="assets/animatecss/animate.css">
    <link rel="stylesheet" href="assets/dropdown/css/style.css">
    <link rel="stylesheet" href="assets/socicon/css/styles.css">
    <link rel="stylesheet" href="assets/theme/css/style.css">
    <link rel="preload" href="https://fonts.googleapis.com/css?family=Jost:100,200,300,400,500,600,700,800,900,100i,200i,300i,400i,500i,600i,700i,800i,900i&display=swap" as="style" onload="this.onload=null;this.rel='stylesheet'">
    <noscript>
        <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Jost:100,200,300,400,500,600,700,800,900,100i,200i,300i,400i,500i,600i,700i,800i,900i&display=swap">
    </noscript>
    <link rel="preload" as="style" href="assets/mb/css/mbr-additional.css">
    <link rel="stylesheet" href="assets/mb/css/mbr-additional.css" type="text/css">
    <style type="text/css">
        .center-in-center {
            position: fixed;
            top: 50%;
            left: 50%;
            -webkit-transform: translate(-50%, -50%);
            -moz-transform: translate(-50%, -50%);
            -ms-transform: translate(-50%, -50%);
            -o-transform: translate(-50%, -50%);
            transform: translate(-50%, -50%);
        }
    </style>
</head>
<body>
    <form runat="server" id="form">
        <asp:ScriptManager ID="ScriptManager1" runat="server"></asp:ScriptManager>
        <asp:UpdatePanel ID="UpdatePanel1" runat="server">
            <Triggers>
                <asp:PostBackTrigger ControlID="Upload1" />
            </Triggers>
            <Triggers>
                <asp:PostBackTrigger ControlID="Upload2" />
            </Triggers>
            <ContentTemplate>
                <%--Mene Bar--%>
                <section data-bs-version="5.1" class="menu menu2 cid-sOVTQ46G4z" once="menu" id="menu2-0">
                    <nav class="navbar navbar-dropdown navbar-fixed-top navbar-expand-lg">
                        <div class="container">
                            <div class="navbar-brand">
                                <span class="navbar-logo">
                                    <img src="assets/images/mbr-196x196.png" style="height: 3rem;">
                                </span>
                                <span class="navbar-caption-wrap"><a class="navbar-caption text-black display-7">Microsoft Graph Api Demo Site</a></span>
                            </div>
                            <button class="navbar-toggler" type="button" data-toggle="collapse" data-bs-toggle="collapse" data-target="#navbarSupportedContent" data-bs-target="#navbarSupportedContent" aria-controls="navbarNavAltMarkup" aria-expanded="false" aria-label="Toggle navigation">
                                <div class="hamburger">
                                    <span></span>
                                    <span></span>
                                    <span></span>
                                    <span></span>
                                </div>
                            </button>
                            <div class="collapse navbar-collapse" id="navbarSupportedContent">
                                <ul class="navbar-nav nav-dropdown nav-right" data-app-modern-menu="true">
                                    <li class="nav-item">
                                        <asp:Button ID="SignIn" runat="server" Text="Sign In" class="nav-link link text-black display-4" OnClick="SignIn_Click" />
                                    </li>
                                </ul>
                            </div>
                        </div>
                    </nav>
                </section>
                <%--Buttons--%>
                <section data-bs-version="5.1" class="header2 cid-sPBGRU4P18 mbr-fullscreen mbr-parallax-background" id="header2-f">
                    <div class="mbr-overlay" style="opacity: 0.8; background-color: rgb(255, 255, 255);"></div>
                    <div class="container">
                        <div class="row">
                            <div class="col-12 col-lg-7">
                                <h1 class="mbr-section-title mbr-fonts-style mb-3 display-1"><strong>Upload a file</strong></h1>
                                <p class="mbr-text mbr-fonts-style display-7">There're two buttons below using <a href="https://docs.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0&tabs=http#http-request-to-upload-a-new-file" class="text-primary">the same graph api</a>&nbsp;to upload a file (under 4MB), pls try and see the difference.&nbsp;</p>
                                <div class="mbr-section-btn mt-3">
                                    <asp:Button ID="Upload1" runat="server" Text="Button 1" OnClick="Upload1_Click" class="btn btn-success display-4" />
                                    <span></span>
                                    <asp:Button ID="Upload2" runat="server" Text="Button 2" OnClick="Upload2_Click" class="btn btn-secondary display-4" />
                                    <p></p>
                                    <asp:Label ID="Label1" runat="server" class="mbr-text mbr-fonts-style display-7 text-danger"></asp:Label>
                                    <p></p>
                                    <asp:FileUpload ID="FileUpload1" runat="server" class="btn" Style="padding-left: 0px;" />
                                </div>
                            </div>
                        </div>
                    </div>
                </section>
                <%--What's the difference--%>
                <section data-bs-version="5.1" class="content6 cid-sPBq3Ewd0Y" id="content6-7">
                    <div class="container">
                        <div class="row justify-content-center">
                            <div class="col-md-12 col-lg-10">
                                <hr class="line">
                                <p class="mbr-text align-center mbr-fonts-style my-4 display-5">
                                    What's the difference?
                                </p>
                                <hr class="line">
                            </div>
                        </div>
                    </div>
                </section>
                <section data-bs-version="5.1" class="image1 cid-sPBqdKpPjl" id="image1-8">
                    <div class="container">
                        <div class="row align-items-center">
                            <div class="col-12 col-lg-6">
                                <div class="image-wrapper">
                                    <img src="assets/images/authorization-code-flow.svg">
                                    <p class="mbr-description mbr-fonts-style pt-2 align-center display-4">Authorization Code Flow</p>
                                </div>
                            </div>
                            <div class="col-12 col-lg">
                                <div class="text-wrapper">
                                    <h3 class="mbr-section-title mbr-fonts-style mb-3 display-5"><strong>Authorization Code Flow</strong></h3>
                                    <p class="mbr-text mbr-fonts-style display-7">
                                        Authorization code flow provides permissions for your application to manipulate documents and other resources on behalf of a user and make requests for all API resources. Access tokens while having a limited lifetime, can be renewed with a refresh token. A refresh token is valid indefinitely and provides ability for your application to schedule tasks on behalf of a user without their interaction.<br>
                                        <br>
                                        <a href="https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow" class="text-primary">https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow</a><br>
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>
                <section data-bs-version="5.1" class="image2 cid-sPBqeo7RBv" id="image2-9">
                    <div class="container">
                        <div class="row align-items-center">
                            <div class="col-12 col-lg-6">
                                <div class="image-wrapper">
                                    <img src="assets/images/client-credentials-flow.svg">
                                    <p class="mbr-description mbr-fonts-style mt-2 align-center display-4">
                                        Client Credentials Flow&nbsp;<br>
                                    </p>
                                </div>
                            </div>
                            <div class="col-12 col-lg">
                                <div class="text-wrapper">
                                    <h3 class="mbr-section-title mbr-fonts-style mb-3 display-5"><strong>Client Credentials Flow</strong></h3>
                                    <p class="mbr-text mbr-fonts-style display-7">
                                        The OAuth 2.0 client credentials grant flow permits a web service (confidential client) to use its own credentials, instead of impersonating a user, to authenticate when calling another web service. For a higher level of assurance, the Microsoft identity platform also allows the calling service to authenticate using a certificate or federated credential instead of a shared secret. Because the applications own credentials are being used, these credentials must be kept safe - never publish that credential in your source code, embed it in web pages, or use it in a widely distributed native application.
                            <br>
                                        <br>
                                        In the client credentials flow, permissions are granted directly to the application itself by an administrator. When the app presents a token to a resource, the resource enforces that the app itself has authorization to perform an action since there is no user involved in the authentication.&nbsp;<br>
                                        <br>
                                        <a href="https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-client-creds-grant-flow" class="text-primary">https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-client-creds-grant-flow</a><br>
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>
                <a href="https://mobirise.site/w" style="display: none"></a>
                <script src="assets/bootstrap/js/bootstrap.bundle.min.js"></script>
                <script src="assets/parallax/jarallax.js"></script>
                <script src="assets/smoothscroll/smooth-scroll.js"></script>
                <script src="assets/ytplayer/index.js"></script>
                <script src="assets/dropdown/js/navbar-dropdown.js"></script>
                <script src="assets/theme/js/script.js"></script>
                <div id="scrollToTop" class="scrollToTop mbr-arrow-up"><a style="text-align: center;"><i class="mbr-arrow-up-icon mbr-arrow-up-icon-cm cm-icon cm-icon-smallarrow-up"></i></a></div>
                <input name="animation" type="hidden">
            </ContentTemplate>
        </asp:UpdatePanel>
        <asp:UpdateProgress ID="UpdateProgress1" runat="server" AssociatedUpdatePanelID="UpdatePanel1" class="center-in-center container">
            <ProgressTemplate>
                <div class="container-fluid text-center mbr-text mbr-fonts-style display-7 text-danger">Loading...</div>
            </ProgressTemplate>
        </asp:UpdateProgress>
    </form>
</body>
</html>
