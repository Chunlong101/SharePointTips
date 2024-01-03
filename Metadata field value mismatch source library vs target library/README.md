# Metadata field value mismatch issue while uploading files from source library vs target library

Recently, I encountered a somewhat perplexing issue. Its manifestation defies conventional logic, resembling a riddle. However, unlike typical riddles, articulating its enigma is no easy task. Without further ado, let's dive into the repro steps:  

1. We have the source library prepared, including a metadata column labeled "Metadata":

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/ae866e5b-f546-4226-9b41-5999fd21664d)

2. From the source site taxonomy hidden list, we can discern the following associations: Engineering (ID: 1), Executive Management (ID: 2), Operations (ID: 7), as illustrated below. Let's emphasize the ID of the hidden list rather than the ID for the term:

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/b1399a80-adf0-4a93-bc84-701f60a57f1d)

3. Download the document "Engineering.docx" from the source library and inspect its metadata in Word, it should correspond to the category "Engineering":

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/af2112fc-cf26-46a8-a53e-4cb832bfe2c7)

4. Now, let's manually upload those documents to our target library. First, create the target library with the same columns as our source library. Download the files from the source library and upload them to the target library. Within the first few seconds, observe that the metadata values appear as numbers. Please refer to step #2 for an understanding of what these numbers represent:

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/5fd3dafd-6f66-4f45-9f04-85d887f28ef0)

   However, upon refreshing the page, you'll notice that those numbers will transform into incorrect metadata values:

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/6866335e-ddb0-46e3-9383-fb8f2de4ac4f)
   
   This discrepancy arises because in our target taxonomy hidden list, those numbers are mapped to different terms – Executive Management (ID: 1), Engineering (ID: 2), Sales (ID: 7) (please compare with step #2 above):

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/a3c2106d-5d4e-4dae-ab7e-e3b0da9da4a7)
   
   The "ID" column in the above screenshot represents the order/sequence in which those terms appeared in the target site, so the ID is usually different from the source. At this point, attempting to update the metadata value in the browser from the target library is unsuccessful, it remains stuck on "Saving..." indefinitely:  

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/367f8e02-7c89-4d3b-b2fb-525547efd1d8)
   

5. Interestingly, if we now download "Engineering.docx" from the target library, it still reflects the "correct" metadata value (in comparison to the target where it's wrong, but it's accurate comparing to the source, it's still the same vs our step #3 above):  

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/16a17109-27fc-456a-ae74-987c160b88f5)

6. Now, if we upload this document back to the target library to replace the current one, the metadata value will be corrected (I understand this might be confusing):

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/47912a8c-6c90-46ce-8afe-f60005b4a3e3)
   
   Let's set aside step #6 for the moment, assuming we haven't uploaded it back, leaving the metadata value incorrect for the subsequent steps below. 

7. After step #4 or #5, if we use PowerShell to retrieve that file properties of “Engineering.docx” from the target library:

   ```powershell
   $siteUrl = https://xxx.sharepoint.com/sites/xxx
   $listName = "xxx"
   $columnName = "xxx"
   $itemId = xxx
   Connect-PnPOnline -Url $siteUrl -UseWebLogin
   $list = Get-PnPList | ? { $_.Title -eq $listName }
   $item = Get-PnPListItem -List $list -Id $itemId
   $item.FieldValues[$columnName] | fl
   ```

   We will see output like:

   ```powershell
   Label    : Executive Management
   TermGuid : c304f052-7636-4803-81ba-4d338901ba9f
   WssId    : 1
   TypeId   : {19e70ed0-4177-456b-8156-015e4d163ff8}
   ```

   Actually, I also attempted to use Graph API and REST API, and the results align with the above findings. This suggests that through CSOM (PowerShell), Graph API, or REST API, these SharePoint interfaces all retrieve the same metadata value as what we observe in the browser from the target library.

   My REST API:  
   `https://5xxsz0.sharepoint.com/sites/msft/_api/web/getlistbytitle('2311170030000442%20(1)')/getitembyid('xx')`

   My Graph API:  
   `https://graph.microsoft.com/v1.0/sites/339fd26d-a841-4028-bb1c-ef04080e6f38/lists/32a0855c-c784-4c22-8314-225fecd90387/items/xx`

   -----

   Based on my observations so far, we can conclude that the aforementioned behaviors are by design. When manually uploading a file (downloading a copy from the source library and uploading it to the target library), the target library utilizes the WssId from the file. However, this number often has a different mapping in the target taxonomy hidden list, leading to the target library displaying an incorrect metadata value. (In terms of design, I personally believe using TermGuid instead of WssId might be more suitable, but the product group may have other considerations)

   -----

8. What I am about to show you now is more interesting, I'll demonstrate some additional variations and inconsistent behaviors: I created a flow like below, very simple, just like step #7 above, retrieving that metadata value against “Engineering.docx” from the target library:

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/153af067-e487-4d3c-b23e-a797e5cff5c3)
   
   As you can see, the result is different vs step #7. To be honest, this is quite convoluted, making me feel confused. From my original perspective, this action in Power Automate uses SharePoint connector that should go with the same way as either Graph API or REST API in step #7, but apparently, that SharePoint connector is a special entity, distinct from other SharePoint interfaces.

9. Now let’s create another flow to copy “Engineering.docx” from the source to the target. As you can see below, it’s working perfectly, the metadata value is automatically set correctly (I tried move file action as well, it’s also working). This is different from our step #4 above:

   ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/e7868159-10c8-4e39-b7d2-e6314b44f09a)
   
   I've noticed that every time this flow runs, it increments the ID of the target file in the target library by 2 units. What I mean is, let's say the current maximum ID in the target library is 100. If I manually upload a document, its ID should be 101. However, if I use Flow to Copy or Move the document instead of uploading it manually, the document's ID becomes 102. I suspect that Flow might be performing the upload action twice, and that could be the reason why the above Flow is working well with that metadata value.

10. If I download the file from the source library, then use below PowerShell to upload it to the target library:

    ```powershell
    Add-PnPFile -Path "C:\Users\chunlonl\Downloads\Engineering.docx" -Folder "2311170030000442%201"
    ```

    Then it gives the wrong value. This is the same behavior as step #4 above:
    ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/4b88d1c8-868b-4c0a-91f4-02d4235cd254)

    But if I add one more parameter in that PowerShell:

    ```powershell
    $columnName = "Metadata"
    $termId = "e4a448b8-33af-4254-b53c-de7616afd080" 
    Add-PnPFile -Path "C:\Users\chunlonl\Downloads\Engineering.docx" -Folder "2311170030000442%201" -Values @{ $columnName = $termId }
    ```

    Then it works correctly:
    ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/ba87993b-aa4a-4c93-aa98-32287723b858)

    Additionally, we can leverage the following PowerShell command without the need for file downloads. This command facilitates a direct copy from the source to the target, ensuring seamless transfer of both content and metadata values:

    ```powershell
    $sourceSiteUrl = https://5xxsz0.sharepoint.com/sites/Test
    Connect-PnPOnline -Url $sourceSiteUrl -Interactive
    Copy-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
    # Move-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
    ```

    Long in short, our requirement is to move/copy a file from the source library to the target library with correct/consistent metadata value. At this moment, we have 4 options/workarounds below:

    - Download the file from the source library >> upload it to the target library >> download the file from the target library >> upload it back to the target library again. Or manually download the affected document from source, remove the metadata from the advanced properties in word, and re-place the document in the target SharePoint library. 
    - Use PowerShell:

      ```powershell
      $sourceSiteUrl = https://5xxsz0.sharepoint.com/sites/Test
      Connect-PnPOnline -Url $sourceSiteUrl -Interactive
      Copy-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
      # Move-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
      # Add-PnPFile -Path "C:\Users\chunlonl\Downloads\Engineering.docx" -Folder "2311170030000442%201" -Values @{ $columnName = $termId }
      ```

    - Use Power Automate, refer to step #9 above.
    - Use “Move to” or “Copy to” in UX below:
      ![image](https://github.com/Chunlong101/SharePointScripts/assets/9314578/242dcacd-18f1-4463-a97a-5888a9852c38)

Taxonomy values are not supposed to be retained while moving docs across libraries and sites, currently this scenario is not supported, IcM 449897994. 