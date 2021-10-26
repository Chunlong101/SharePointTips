This scirpt aims at automatically updating the passwords of a service account used in sharepoint, iis as well as windows services. Pls note, Microsoft doesn't provide production ready scripts, customers need to test/verify/extend this script by themselves. And this script is out of the support scope. 

How to use: Change the passwords in AD Users and Computers, then just run this script on every sharepoint server (one by one serially), it will automatically take care of all steps to reset passwords for sharepoint/iis application pool/windows service. 

Sometimes "Set-SPManagedAccount" and "stsadm.exe –o updatefarmcredentials" may not work properly, below are the manual steps that we'd better take to avoid potential issues (for example, some services like user profile application or search service application are still running with old password then that service account will be blocked by AD due to "login failed attempts", and then all other services runing with that account will be down): 

![image](https://user-images.githubusercontent.com/9314578/138895945-5e6e2d52-7810-43e9-86f8-29ba1e8e5997.png)

This is the article mentioned above: https://social.technet.microsoft.com/wiki/contents/articles/36418.sharepoint-2013-how-to-change-all-service-account-passwords.aspx
