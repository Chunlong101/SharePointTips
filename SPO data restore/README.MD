# File and Data Recovery Guide

This document offers various methods and steps for recovering files and data that have been lost in the cloud or locally.

## Cloud Data Recovery

1. **Confirm Last Visibility Time of File in Cloud**: Confirm when the file/folder was last visible in the cloud. For individually deleted items, check the relevant SharePoint site's recycle bin regardless of whether more than 14 days have passed. If the file is not in the recycle bin, it might indicate that the file was never in the cloud or has been permanently deleted. Self-service restore is available for both OneDrive and SharePoint document libraries:
   - **OneDrive**: End-users can try [Restore your OneDrive](https://support.microsoft.com/en-us/office/restore-your-onedrive-fa231298-759d-41cf-bcd0-25ac53eb8a15).
   - **SharePoint document libraries**: For widespread deletion, overwriting, corruption, or malware infection, a site admin can open the affected library in the modern experience and select **Settings > Restore this library** to undo file and folder activities within the last **30 days**. This option is not limited to losses within 14 days. See [Restore a shared library](https://support.microsoft.com/en-us/sharepoint/documents-and-library/restore-a-shared-library).
   - **Scope and limitations of library restore**: Review the activity list and coordinate with library users before proceeding, because restoring undoes all activities after the selected restore point, not just changes to the missing file. Library restore relies on version history and the recycle bin; previous versions cannot be restored if version history was disabled, and files permanently removed from the site collection recycle bin cannot be recovered this way. An entirely deleted library must be recovered from the recycle bin instead.

2. **Data Recovery within 14 Days**: If the file was lost less than 14 days ago, Microsoft backend services can also help recover data from this period. For instance, the entire site can be restored to the state it was in on a specific previous date. Note that this will result in the loss of new data added after that date.

3. **Recycle Bin File Retention Period**: The recycle bin can save deleted files for up to 93 days, after which they are automatically permanently deleted.

4. **Document Library File Activity**: Refer to this documentation (https://support.microsoft.com/en-us/office/file-activity-in-a-document-library-6105ecda-1dd0-4f6f-9542-102bf5c0ffe0) for records of file activity in the document library for the past 60 days.

5. **Search Audit Logs**: Audit logs can help confirm what activities occurred with the target file over the past year, such as who uploaded or deleted it.

6. **Retention Policies**: If your organization has set retention policies, try looking in “Site contents >> Preservation Hold Library” for the target file. If this library is not present, it indicates no retention policy is set, and setting one up can protect important data from being deleted.

7. **Global Search**: If you remember the file name, try a global search in the SharePoint site’s search box to see if the file has been mistakenly moved to another path.

8. **Check OneDrive Synchronization**: Ask if anyone has synchronized (or been shared with) the target file with OneDrive and check their device for an offline backup.

## Local Data Recovery (For Windows 11)

1. **Check the Recycle Bin**: Accidentally deleted files might be in the local recycle bin.

2. **Use File History**: If this feature was previously enabled, recover files via “Settings” -> “Update & Security” -> “Backup”, and select “Restore files with File History”.

3. **Search for Files**: Use Windows search functionality to try finding the file by name or type.

4. **Check if Files Were Moved or Renamed**.

5. **Use 3rd party Data Recovery Software**: Such as Recuva and EaseUS Data Recovery Wizard.

6. **Check System Restore Points**: If you have set system restore points, try restoring to a point before the problematic file was created.

7. **3rd party Professional Help**: If the file is very important and other methods are ineffective, consider seeking professional data recovery services.

Please note, the success rate of file recovery depends on several factors, such as how the file was used and the length of time since it was lost. Before using data recovery software or services, ensure they are from a trusted source to avoid further data loss or privacy breaches.

# 文件和数据恢复指南

本文档提供了关于如何恢复在云端或本地丢失的文件和数据的不同方法和步骤。

## 云端数据恢复

1. **确认文件在云端的最后可见时间**：确认文件/文件夹在云端最后一次可见的时间。对于单个被删除的项目，无论是否已超过14天，都可以先在相关SharePoint站点的回收站中查找并恢复。如果回收站中找不到，可能意味着文件未曾出现在云端，或者被永久删除。OneDrive和SharePoint文档库均提供自助还原功能：
   - **OneDrive**：终端用户可以自行尝试[还原OneDrive（Restore your OneDrive）](https://support.microsoft.com/en-us/office/restore-your-onedrive-fa231298-759d-41cf-bcd0-25ac53eb8a15)。
   - **SharePoint文档库**：如果大量文件被删除、覆盖、损坏或受到恶意软件感染，站点管理员可以在现代体验中打开受影响的文档库，选择 **设置 > 还原此库（Settings > Restore this library）**，撤销过去 **30天** 内的文件和文件夹操作。此功能不限于14天内的数据丢失场景，具体步骤参见[还原共享库（Restore a shared library）](https://support.microsoft.com/en-us/sharepoint/documents-and-library/restore-a-shared-library)。
   - **文档库还原的影响与限制**：执行前应检查活动列表并与文档库用户确认，因为还原会撤销所选还原时间点之后的所有操作，而不只是丢失文件的变更。文档库还原依赖版本历史记录和回收站；如果之前未开启版本历史记录，则无法还原到先前版本；已从网站集回收站永久删除的文件也无法通过此功能恢复。如果整个文档库已被删除，应改从回收站恢复。

2. **14天内数据恢复**：如果文件丢失时间小于14天，还可以通过微软后台恢复这段时间内的数据。例如，可以将整个站点恢复到之前某个特定日期的状态。注意，这样做会导致该日期之后的新数据丢失。

3. **回收站文件保存期限**：回收站可以保存被删除文件最长93天，之后文件将被自动永久删除。

4. **文档库文件活动**：可以参考这篇文档（https://support.microsoft.com/zh-cn/office/%E6%96%87%E6%A1%A3%E5%BA%93%E4%B8%AD%E7%9A%84%E6%96%87%E4%BB%B6%E6%B4%BB%E5%8A%A8-6105ecda-1dd0-4f6f-9542-102bf5c0ffe0）来查看文档库中过去60天的文件活动记录。

5. **搜索审核日志**：通过搜索审核日志，可以确认目标文件在过去一年内的活动记录，例如文件的上传或删除情况。

6. **保留策略**：如果组织配置了保留策略，可以在“Site contents >> Preservation Hold Library”中查找目标文件。如果没有配置保留策略，可以建议配置新的保留策略以保护重要数据。

7. **全局搜索**：如果记得文件名，可以在SharePoint站点的搜索框进行全局搜索，检查文件是否被误操作移动到其他路径。

8. **OneDrive同步检查**：询问是否有人使用OneDrive同步过目标文件，并在其设备上查找线下备份。

## 本地数据恢复（以Windows 11为例）

1. **检查回收站**：不小心删除的文件可能在本地回收站中。

2. **使用文件历史记录**：如果之前开启了此功能，可以通过“设置” -> “更新与安全” -> “备份”，使用“文件历史记录”恢复文件。

3. **搜索文件**：使用Windows搜索功能，尝试按文件名或类型进行搜索。

4. **检查文件是否被移动或重命名**。

5. **使用第三方数据恢复软件**：如Recuva和EaseUS Data Recovery Wizard。

6. **检查系统还原点**：如果设置了系统还原点，尝试还原到创建问题文件之前的时间点。

7. **专业帮助**：如文件非常重要且其他方法无效，可寻求专业第三方数据恢复服务。

请注意，文件恢复的成功率取决于多种因素，例如文件丢失后的使用情况和时间长度。在使用数据恢复软件或服务前，请确保来源可信，以避免进一步数据损失或隐私泄露。
