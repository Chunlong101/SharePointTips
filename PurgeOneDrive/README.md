# What is this script? 

This script is intended to delete all files/folders in a user's onedrive. 

# How to use? 

1. Pls install "PnP PowerShell" first before running this script: https://pnp.github.io/powershell/articles/installation.html

2. Copy that script to your powershell console and run (make sure $onedriveUrl is your own onedrive). 

# Pls note 

Microsoft doesn't provide production ready scripts, customers need to test/verify/develop this script by themselves, this script is actually out of the support scope. 

# In case you see below msg while login 

If you're seeing some kind of msg like "PnP Management Shell This app requires your admin's approval" (admin consent) then pls follow that guidance (user inputs justification >> global admin receives an email then follow the instruction in that email) or your global admin can run this command "Register-PnPManagementShellAccess" before you run this script. 
