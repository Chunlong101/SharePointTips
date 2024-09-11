# SPCacheCleaner

This script helps to clear the SharePoint Timer cache files, which can resolve various issues within a SharePoint farm.

## How to Use (Option 1 - Run the script)

1. **Download** the `SPCacheCleaner.zip` file.
2. **Unzip** it to one of your SharePoint servers.
3. **Run** the `SPCacheCleaner.cmd` script.

## How to Use (Option 2 - Manual Cache Clearing Steps)

You can manually clear the SharePoint configuration cache by following the steps below.

### Why Clear the SharePoint Configuration Cache?

Clearing the cache is often the first step in troubleshooting SharePoint issues. Some common problems that can be resolved by clearing the cache include:

- Deployment errors such as "Error occurred in deployment step 'Add Solution'."
- General SharePoint performance issues.
- Stuck or failing timer jobs.

### Step-by-Step Guide to Clear the SharePoint Configuration Cache

#### 1. Stop the SharePoint Timer Service

On each server in your SharePoint farm, follow these steps:

- Open **Services**, locate "SharePoint Timer Service," right-click, and select **Stop**.
  
  ![Stop Timer Service](https://github.com/user-attachments/assets/fe421d10-40ac-4490-9278-c1c53310f6c1)

- Alternatively, you can stop the service via PowerShell:

    ```powershell
    net stop SPTimerV4
    ```

#### 2. Navigate to the SharePoint Config Folder

- Navigate to the following folder:
  
  ```
  %SystemDrive%\ProgramData\Microsoft\SharePoint\Config
  ```

- Locate the folder with a GUID name, such as `61450a31-c061-4303-a51a-52fc9ac7ba5d`.

  ![Config Folder](https://github.com/user-attachments/assets/dbc8341c-373c-483f-84fe-e5f0affec26f)

#### 3. Delete Temporary Files

- Open the GUID folder and **delete all files except `Cache.ini`** (DO NOT delete `Cache.ini`).
  
  ![Cache.ini](https://github.com/user-attachments/assets/7139556d-56a0-4a2c-98ba-ab36adf64a03)

#### 4. Modify the Cache.ini File

- Open the `Cache.ini` file in Notepad.
- Delete the contents of the file (e.g., `23139`).
- Replace the contents with the number `1`:

  ![Modify Cache.ini](https://github.com/user-attachments/assets/8fe46bad-9407-46b7-9463-5fc307269ef7)

- Save and close the file.

#### 5. Start the SharePoint Timer Service

- Once you've completed the steps on each server in the farm, restart the SharePoint Timer Service.
  
  - Open **Services**, locate "SharePoint Timer Service," right-click, and select **Start**.
  
  - Alternatively, you can start the service via PowerShell:

    ```powershell
    net start SPTimerV4
    ```

The SharePoint Timer Service will repopulate the configuration folder and update the `Cache.ini` file automatically.

By following these steps, you can successfully clear the SharePoint configuration cache and resolve potential issues.
