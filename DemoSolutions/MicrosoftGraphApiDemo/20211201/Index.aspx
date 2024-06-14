<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Index.aspx.cs" Inherits="AppModelv2_WebApp_OpenIDConnect_DotNet.Index" %>

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
    <form runat="server">
        <%--Menu Bar--%>
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
        <%--Purpose--%>
        <section data-bs-version="5.1" class="header18 cid-sPBCvSTRPx mbr-fullscreen" id="header18-a">
            <div class="align-center container">
                <div class="row justify-content-center">
                    <div class="col-12 col-lg-10">
                        <h1 class="mbr-section-title mbr-fonts-style mbr-white mb-3 display-1"><strong>Microsoft Graph Api OAuth Flow</strong></h1>
                        <p class="mbr-text mbr-fonts-style mbr-white display-7">
                            This demo site aims at demonstrating how graph api works with different access token
                        </p>
                        <div class="mbr-section-btn mt-3"><a class="btn btn-primary display-4" href="Upload.aspx">Get Started!</a></div>
                        <asp:Label ID="Label1" runat="server" class="mbr-text mbr-fonts-style display-7 text-danger"></asp:Label>
                    </div>
                </div>
            </div>
        </section>
    </form>
    <a href="https://mobirise.site/w" style="display: none"></a>
    <script src="assets/bootstrap/js/bootstrap.bundle.min.js"></script>
    <script src="assets/parallax/jarallax.js"></script>
    <script src="assets/smoothscroll/smooth-scroll.js"></script>
    <script src="assets/ytplayer/index.js"></script>
    <script src="assets/dropdown/js/navbar-dropdown.js"></script>
    <script src="assets/theme/js/script.js"></script>
    <div id="scrollToTop" class="scrollToTop mbr-arrow-up"><a style="text-align: center;"><i class="mbr-arrow-up-icon mbr-arrow-up-icon-cm cm-icon cm-icon-smallarrow-up"></i></a></div>
    <input name="animation" type="hidden">
</body>
</html>
