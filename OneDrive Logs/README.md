# OneDrive Log Collection Guide

## 1. CollectSyncLogs.bat

The file is located in the `%localappdata%\Microsoft\OneDrive\<CurrentInstalledVersion>` directory and is used to collect various logs. After executing the file (opening the `.bat` file), you will see a `.cab` file generated on the user's desktop containing the collected logs.

### Examples of Collected Logs:
- OneDrive sync logs
- Clientpolicy.ini
- Co-auth logs
- Event logs
- Telemetry cache information
- Registry key information
- Currently open tasks
- Various other files

### Usage Steps:
1. Log in as the user experiencing the issue.
2. Use the `CollectSyncLogs.bat` tool from the OneDrive installation folder, which includes additional information related to OneDrive, such as registry keys, installation file information, settings, and Event Viewer logs:
   - **a.** Navigate to `%localappdata%\Microsoft\onedrive\` (or if installed per-machine, navigate to: `C:\Program Files (x86)\Microsoft OneDrive\`).
   - **b.** Open the `19.X` or `20.X` (latest version) folder.
   - **c.** Run `CollectSyncLogs.bat`.
   - **d.** Choose "YES" or "NO" to decide whether to unscramble the logs. For some issues, selecting "NO" is sufficient. If you choose "YES," the logs will include actual file names and paths, which helps investigate file/folder-specific issues.
   - **e.** A `.cab` file similar to `OneDriveLogs_Day_01_01_2020_01_01_01.01.cab` will be generated on the desktop.

---

## 2. Manually Compress User Logs

You can manually compress user logs located in the `%localappdata%\Microsoft\OneDrive\logs` directory.

---

## 3. Mobile Device Logs

### How to Capture Mobile Logs (Shake Logs) - Overview

In some cases, we need more information from the application itself to understand what was happening when the issue occurred. In the SharePoint Online and OneDrive mobile applications, there is a feature called "Shake to Send Feedback." This sends a set of logs, a screenshot of the error, and other details (such as app version and OS version) to an internal team. This information is very useful for troubleshooting mobile device issues.

📒 **Note**: Shake logs cannot be submitted for Government (GCC and GCCH) or Education (EDU) tenants. Logs for these tenants can only be collected manually using the steps below.

### iOS - OneDrive Manual Log Collection
1. Open the OneDrive mobile app.
2. Tap your account icon.
3. Tap "Help & Feedback."
4. Tap "Tell Us About Something You Like."
5. Tap "Cancel."
6. Immediately tap "Help & Feedback" again.
7. New menu options will appear. Tap "Share Logs."
8. Choose a location to save the log files.

### iOS - OneDrive Shake to Send Feedback
1. Open the OneDrive mobile app.
2. Reproduce the issue.
3. Physically shake the device twice with a brief pause in between to trigger the "Shake to Send Feedback" dialog.
4. Tap "Send."
5. Tap "Report a Problem."
   - If this option does not appear, wait 20-30 seconds or sign in to the app with a personal account (Microsoft Account) and try again.
6. Enter a description and tap "Send."

### Android - OneDrive Shake to Send Feedback
1. Open the OneDrive mobile app.
2. Reproduce the issue.
3. Physically shake the device twice with a brief pause in between to trigger the "Shake to Send Feedback" dialog.
4. Tap "Send."
5. Tap "Report a Problem."
   - If this option does not appear, wait 20-30 seconds or sign in to the app with a personal account (Microsoft Account) and try again.
6. Check the box "Include Logs."
7. Enter a description and tap "Send."

---
---
---

# OneDrive 日志收集指南

## 1. CollectSyncLogs.bat

该文件位于 `%localappdata%\Microsoft\OneDrive\<CurrentInstalledVersion>` 目录下，用于收集各种日志，执行该文件（打开 `.bat` 文件）后，您会在用户的桌面上看到一个生成的 `.cab` 文件，其中包含收集的日志。

### 收集的日志示例：
- OneDrive 同步日志
- Clientpolicy.ini
- 协同认证日志
- 事件日志
- 遥测缓存信息
- 注册表键信息
- 当前打开的任务
- 其他各种文件

### 使用步骤：
1. 以遇到问题的用户身份登录。
2. 从 OneDrive 安装文件夹中使用 `CollectSyncLogs.bat` 工具，该工具包含与 OneDrive 相关的其他信息，如注册表键、安装文件信息、设置和事件查看器日志：
   - **a.** 导航到 `%localappdata%\Microsoft\onedrive\`（如果按机器安装，则导航到：`C:\Program Files (x86)\Microsoft OneDrive\`）。
   - **b.** 打开 `19.X` 或 `20.X`（最新版本）文件夹。
   - **c.** 运行 `CollectSyncLogs.bat`。
   - **d.** 选择“YES”或“NO”以决定是否解密日志。对于某些问题，选择“NO”即可。如果选择“YES”，日志将包含实际文件名和路径，这有助于调查文件/文件夹特定问题。
   - **e.** 桌面上会生成一个类似 `OneDriveLogs_Day_01_01_2020_01_01_01.01.cab` 的 `.cab` 文件。

---

## 2. 手动压缩用户日志

您可以手动压缩位于 `%localappdata%\Microsoft\OneDrive\logs` 目录下的用户日志。

---

## 3. 移动设备日志

### 如何捕获移动日志（摇一摇日志） - 概述

在某些情况下，我们需要从应用程序本身获取更多信息，以了解问题发生时的具体情况。在 SharePoint Online 和 OneDrive 移动应用程序中，有一个名为“摇一摇发送反馈”的功能。这将向内部团队发送一组日志、错误发生时的截图以及其他详细信息（如应用程序版本和操作系统版本）。这些信息在排查移动设备问题时非常有用。

📒 **注意**：政府（GCC 和 GCCH）或教育（EDU）租户无法提交摇一摇日志。这些租户的日志只能通过以下步骤手动收集。

### iOS - OneDrive 手动日志收集
1. 打开 OneDrive 移动应用。
2. 点击您的账户图标。
3. 点击“帮助与反馈”。
4. 点击“告诉我们您喜欢的内容”。
5. 点击“取消”。
6. 立即再次点击“帮助与反馈”。
7. 新菜单选项会出现，点击“分享日志”。
8. 选择保存日志文件的位置。

### iOS - OneDrive 摇一摇发送反馈
1. 打开 OneDrive 移动应用。
2. 重现问题。
3. 物理摇动设备两次，中间稍作停顿，以触发“摇一摇发送反馈”对话框。
4. 点击“发送”。
5. 点击“报告问题”。
   - 如果此选项未出现，请等待 20-30 秒，或使用个人账户（Microsoft 账户）登录应用后重试。
6. 输入描述并点击“发送”。

### Android - OneDrive 摇一摇发送反馈
1. 打开 OneDrive 移动应用。
2. 重现问题。
3. 物理摇动设备两次，中间稍作停顿，以触发“摇一摇发送反馈”对话框。
4. 点击“发送”。
5. 点击“报告问题”。
   - 如果此选项未出现，请等待 20-30 秒，或使用个人账户（Microsoft 账户）登录应用后重试。
6. 勾选“包含日志”。
7. 输入描述并点击“发送”。