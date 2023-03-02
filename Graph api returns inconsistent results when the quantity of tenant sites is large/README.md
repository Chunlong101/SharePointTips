## Symptom 
https://graph.microsoft.com/v1.0/sites?search=* returns inconsistent results when the quantity of tenant sites is large
 
## Assessments 
1.	We have 4 fiddler logs in total, everyone of them is just a simple repro of https://graph.microsoft.com/v1.0/sites?search=*, I compared each one of them by following steps below, and confirmed that there is an issue inside that api when the quantity of tenant sites is large. 
2.	Export all sessions in fiddler logs, so that we get all json responses in file like below: 

![image](https://user-images.githubusercontent.com/9314578/174351721-72be1187-873a-439d-b38d-be20b2e61a0e.png)
![image](https://user-images.githubusercontent.com/9314578/174351733-a037f560-b618-43a3-a3d9-63495ed7c4d3.png)
<img alt="image" src="https://user-images.githubusercontent.com/9314578/222315306-e1ee50a6-8e28-4043-90e4-62a6b24fee59.png">

3.	Run powershell script "Calculation.ps1" to generate reports for duplicated sites and unique ones. 
4.	Above script converts all json files into csv, then from there in excel we can easily see the duplicated ones: 

<img alt="image" src="https://user-images.githubusercontent.com/9314578/222315613-2018e5fc-fe8c-415b-9a53-a0d7293c68a4.png">
![image](https://user-images.githubusercontent.com/9314578/174351824-9f9682b8-c3d0-4e8e-bd21-6f70f12797cd.png)

5.	Above script also generates reports like how many duplicated/unique ones there are in each one of fiddler repros, for example below shows https://cloudnativebackup.sharepoint.com/sites/grp_scale_sxDgL_1_36is repeated 8 times (numbers of unique sites are inconsistent as well): 

<img alt="image" src="https://user-images.githubusercontent.com/9314578/222315956-73ae062a-92a6-43ee-b5b9-bc3ae30e53e4.png">

6.	By the way, previously I tried random comparison like below but that conclusion is not accurate, because some duplicated sites are hidden in the same one fiddler session: 

![image](https://user-images.githubusercontent.com/9314578/174351853-84c60b20-af7b-4e81-9824-344f8c997c65.png)
<img alt="image" src="https://user-images.githubusercontent.com/9314578/222316646-8623a183-f0a0-4330-8e0b-fc45221841aa.png">
