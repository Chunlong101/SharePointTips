#
# Set the value 4 for Insider, 5 for Production (see an example - [HKLM\SOFTWARE\Policies\Microsoft\OneDrive]"GPOSetUpdateRing"="dword:00000005"), or 0 for Deferred. When you configure this setting to 5 for Production, or 0 for Deferred, the "Get OneDrive Insider preview updates before release", in the sync app, the checkbox does not appear on the Settings > About tab. More details: https://docs.microsoft.com/en-us/onedrive/use-group-policy#set-the-sync-app-update-ring
#
reg add HKLM\SOFTWARE\Policies\Microsoft\OneDrive /v GPOSetUpdateRing /t REG_DWORD /d 00000005