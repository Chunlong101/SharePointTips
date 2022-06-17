## Symptom 
https://graph.microsoft.com/v1.0/sites?search=* returns inconsistent results
 
## Assessments 
1.	We have 4 fiddler logs in total, everyone of them is just a simple repro of https://graph.microsoft.com/v1.0/sites?search=*, I compared each one of them by following steps below, and confirmed that there is an issue inside that api when the quantity of tenant sites is large. 
2.	Export all sessions in fiddler logs, so that we get all json responses in file like below: 

![image](https://user-images.githubusercontent.com/9314578/174351721-72be1187-873a-439d-b38d-be20b2e61a0e.png)
![image](https://user-images.githubusercontent.com/9314578/174351733-a037f560-b618-43a3-a3d9-63495ed7c4d3.png)
![image](https://user-images.githubusercontent.com/9314578/174351768-f00bc5b7-69ee-46d5-9ab4-91f3d1e3bcc0.png)

3.	Run powershell script "Calculation.ps1" to generate reports for duplicated sites and unique ones. 
4.	Above script converts all json files into csv, then from there in excel we can easily see the duplicated ones: 

![image](https://user-images.githubusercontent.com/9314578/174351666-a6fff385-2d9f-4d43-9f40-55bde6ee7120.png)
![image](https://user-images.githubusercontent.com/9314578/174351824-9f9682b8-c3d0-4e8e-bd21-6f70f12797cd.png)

5.	Above script also generates reports like how many duplicated/unique ones there are in each one of fiddler repros, for example below shows https://cloudnativebackup.sharepoint.com/sites/grp_scale_sxDgL_1_36is repeated 8 times (numbers of unique sites are inconsistent as well): 

![image](https://user-images.githubusercontent.com/9314578/174351842-f7b7696b-0c35-4bca-b532-416828f7e7dd.png)

6.	By the way, previously I tried random comparison like below but that conclusion is not accurate, because some duplicated sites are hidden in the same one fiddler session: 

![image](https://user-images.githubusercontent.com/9314578/174351853-84c60b20-af7b-4e81-9824-344f8c997c65.png)
![image](https://user-images.githubusercontent.com/9314578/174351870-32dab59c-6ba6-40da-8752-e5d535139926.png)
