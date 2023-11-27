.\Ctsinfo.ps1 https://xxx.sharepoint.com/sites/xxx

Prod-SSL (xxx) PS C:\Users\chunlonl\VsCode\Repo\Test> Request-FarmSPSearchCommand -Farm $cio.farmid -GetCrawlInfo -DisplayUrl https://xxx.sharepoint.com/sites/xxx
Checking result for job [Id=54355213]...
 
Invoking command ShouldExecute on xxx [07/15/2019 20:12:54]
True
 
Complete invoking ShouldExecute. ElapsedTime: [00:00:18.2499996]
 
Invoking command Execute on xxx [07/15/2019 20:13:13]
Calling get crawl docs from url. IsLike on? False
Checking the NoCrawl Status. To skip this step use -SkipIsNoCrawlEnabled
 
Complete invoking Execute. ElapsedTime: [00:00:21.7812388]
 
Invoking command IsComplete on xxx [07/15/2019 20:13:36]
IsComplete
True
 
Complete invoking IsComplete. ElapsedTime: [00:00:08.6874893]
 
Executing Request-FarmSPSearchCommand completed at [07/15/2019 20:13:47] (Total Execution time: 00:02:31.6713076)
 
DocId                     : 7928
DatabaseName              : xxx
SiteId                    : xxx
Protocol                  :
DisplayUrl                : https://xxx.sharepoint.com/sites/<PII:H1(YXKcAT13d2EI3IcZECB0Gy7UWC2liGOZlVGjaB6nWfs=)>
ParentDocID               : 1
ObjectId                  : {xxx}_{xxx}
AccessData                : Site
NoIndex                   : True
DocumentFlags             :
DeletePending             : 0
IsDeleted                 : False
DeleteReason              : 0
CPSTimeStamp              : 4/12/2019 9:38:39 AM
CPSTimeStamp_SecurityOnly :
SPItemModifiedTime        :
ErrorCode                 : 0
ErrorDescription          :
ErrorCount                : 0
ErrorCodeSecurityOnly     : 0
ErrorCountSecurityOnly    : 0
CorrelationID             :
BSN                       :
ScsDocIndexType           : sp-site
ScsDocIndexName           : xxx
ScsClientId               : 3bfb2eca5d726e0826e7ae5652b5bf2d822d10eb9f26d725c6e514843d329dab

DocId                     : 21546
DatabaseName              : xxx
SiteId                    : xxx
Protocol                  :
DisplayUrl                : https://xxx.sharepoint.com/sites/<PII:H1(YXKcAT13d2EI3IcZECB0Gy7UWC2liGOZlVGjaB6nWfs=)>
ParentDocID               : 7928
ObjectId                  : {xxx}_{fbb000d2-532f-4a52-bee7-ec9df24c5de2}
AccessData                : Web
NoIndex                   : False
DocumentFlags             :
DeletePending             : 0
IsDeleted                 : False
DeleteReason              : 0
CPSTimeStamp              : 7/15/2019 7:18:44 PM
CPSTimeStamp_SecurityOnly :
SPItemModifiedTime        :
ErrorCode                 : 0
ErrorDescription          :
ErrorCount                : 0
ErrorCodeSecurityOnly     : 0
ErrorCountSecurityOnly    : 0
CorrelationID             :
BSN                       :
ScsDocIndexType           : sp-site
ScsDocIndexName           : xxx
ScsClientId               : eb615c2f396c818714d03bbd299fad3c1aebcbec7bc744ac1021a9a47295f768

Prod-SSL (xxx) PS C:\Users\chunlonl\VsCode\Repo\Test> Request-FarmSPSearchCommand -Farm $cio.farmid -MarkDocumentForRecrawl –docid 7928 -DBName xxx
Checking result for job [Id=54363276]...
 
 
Invoking command ShouldExecute on BOT20019-675 [07/15/2019 20:24:32]
True
 
Complete invoking ShouldExecute. ElapsedTime: [00:00:45.8907466]
 
Invoking command Execute on BOT20019-675 [07/15/2019 20:25:20]
Document is successfully added to the queue with priority 3
 
Complete invoking Execute. ElapsedTime: [00:00:38.0000163]
 
Invoking command IsComplete on BOT20019-675 [07/15/2019 20:25:59]
IsComplete
True
 
Complete invoking IsComplete. ElapsedTime: [00:00:20.4220048]
 
Executing Request-FarmSPSearchCommand completed at [07/15/2019 20:26:24] (Total Execution time: 00:04:51.2808469)
 
True
