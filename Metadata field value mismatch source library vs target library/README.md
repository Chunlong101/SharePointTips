1. **We have the source library ready with a metadata column named “Metadata”:**
   
2. **From the source site taxonomy hidden list, we can identify the mapping of categories - Engineering: 1; Executive Management: 2; Operations: 7, focusing on the ID of the hidden list (not the term ID):**

3. **Download “Engineering.docx” from the source library and check its metadata in Word; it's “Engineering,” as expected:**

4. **Now, manually upload these documents to our target library (create a target library with the same columns as our source library, download files from the source, and upload them to the target library). Within the first few seconds, we will observe that metadata values appear as numbers (refer to step #2 for understanding the mapping):**

   But upon refreshing the page, those numbers become incorrect metadata values:

   This discrepancy occurs because, in our target taxonomy hidden list, these numbers map to different terms - Executive Management: 1; Engineering: 2; Sales: 7 (compare with step #2):

   The “ID” column in the above screenshot represents the order/sequence in which those terms appeared in the target site, making the target different from the source. If we try to update metadata values in the browser from the target library, it won't allow it and will remain stuck at "Saving…"

5. **If we download “Engineering.docx” from the target library, interestingly, it still shows the “correct” metadata value (wrong in target but correct in source):**

6. **Now, if we upload this document back to the target library to replace the current one, the metadata value will be corrected (ignoring this step for now):**

   Let's assume we didn't upload it back, so the metadata value remains incorrect for the following steps.

7. **After step #4 or #5, if we use PowerShell to get the file property for “Engineering.docx” from the target library:**

   ```powershell
   $siteUrl = "https://xxx.sharepoint.com/sites/xxx"
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

   This behavior is consistent across CSOM (PowerShell), Graph API, and REST API, indicating that SharePoint interfaces retrieve the same metadata value as seen in the browser from the target library.

   My REST API:
   ```powershell
   https://5xxsz0.sharepoint.com/sites/msft/_api/web/getlistbytitle('2311170030000442%20(1)')/getitembyid('xx')
   ```

   My Graph API:
   ```powershell
   https://graph.microsoft.com/v1.0/sites/339fd26d-a841-4028-bb1c-ef04080e6f38/lists/32a0855c-c784-4c22-8314-225fecd90387/items/xx
   ```

   -----

   **My observations so far:**
   
   The mentioned behaviors are by design. When we manually upload a file (download a copy from the source library and upload it to the target library), the target library will use WssId from the file. However, that number usually has a different mapping in the target taxonomy hidden list, leading to incorrect metadata values. For this design, using TermGuid instead of WssId might be preferable, but the product group may have other considerations.

   -----

8. **Now, I will demonstrate some more interesting or inconsistent behaviors. I attempted to create a flow like below, similar to step #7, fetching metadata value for “Engineering.docx” from the target library:**

   As seen, the result differs from step #7. This is somewhat convoluted and confusing. Originally, I expected this action in Power Automate to use the SharePoint connector in the same way as either Graph API or REST API in step #7. However, the SharePoint connector seems to be a distinct entity, behaving differently from other SharePoint interfaces.

9. **Now, let’s create another flow to copy “Engineering.docx” from the source to target. As you can see below, it's working perfectly, and the metadata value is automatically set correctly (move file action also works). This is different from our step #4 above:**

   I've noticed that every time this flow runs, it increments the ID of the target file in the target library by 2 units. For instance, if the current maximum ID in the target library is 100, manually uploading a document should give it an ID of 101. However, using Flow to Copy or Move the document instead of uploading it manually makes the document's ID become 102. I suspect that Flow might be performing the upload action twice, explaining why the above Flow works well with that metadata value.

10. **If I download the file from the source library and then use the following PowerShell to upload it to the target library:**

    ```powershell
    Add-PnPFile -Path "C:\Users\chunlonl\Downloads\Engineering.docx" -Folder "2311170030000442%201"
    ```

    It gives the wrong value, similar to the behavior in step #4 above:

    But if I add one more parameter in that PowerShell:

    ```powershell
    $columnName = "Metadata"
    $termId = "e4a448b8-33af-4254-b53c-de7616afd080" 
    Add-PnPFile -Path "C:\Users\chunlonl\Downloads\Engineering.docx" -Folder "2311170030000442%201" -Values @{ $columnName = $termId }
    ```

    Then it works correctly:

    Additionally, we can leverage the following PowerShell command without the need for file downloads. This command facilitates a direct copy from the source to the target, ensuring seamless transfer of both content and metadata values:

    ```powershell
    $sourceSiteUrl = "https://5xxsz0.sharepoint.com/sites/Test"
    Connect-PnPOnline -Url $sourceSiteUrl -Interactive
    Copy-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
    # Move-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
    ```

   In summary, our requirement is to

 move/copy a file from the source library to the target library with correct/consistent metadata value. Currently, we have four options:

   - Download the file from the source library, upload it to the target library, download it from the target library, and upload it back to the target library.
   - Use PowerShell:

     ```powershell
     $sourceSiteUrl = "https://5xxsz0.sharepoint.com/sites/Test"
     Connect-PnPOnline -Url $sourceSiteUrl -Interactive
     Copy-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
     # Move-PnPFile -SourceUrl "2311170030000442/Engineering.docx" -TargetUrl "/sites/MSFT/2311170030000442%201" -Overwrite -Force
     # Add-PnPFile -Path "C:\Users\chunlonl\Downloads\Engineering.docx" -Folder "2311170030000442%201" -Values @{ $columnName = $termId }
     ```
   - Use Power Automate (refer to step #9 above).
   - Use “Move to” or “Copy to” in UX.
