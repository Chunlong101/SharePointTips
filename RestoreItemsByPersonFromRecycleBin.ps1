# Connect to SPO via PnP

Connect-PnPOnline -Url <SiteURL>

# If the connect command succeeded, Get-PnPList should print a list of lists.

Get-PnPList

# The following function filters Recycle Bin items by Deleted By and Deleted Date, prints item info, and restores the item.

Function RestoreItems {

    param($deletedByName, $deletedOnOrAfterDate)

    foreach ($i in Get-PnPRecycleBinItem) {

        if ($i.DeletedByName -eq $deletedByName -and $i.DeletedDate -ge (Get-Date($deletedOnOrAfterDate))) {

            Write-Host "Restoring: $($i.Id),$($i.DeletedByName),$($i.DirName),$($i.LeafName)"

            Restore-PnPRecycleBinItem -Identity $i -Force

        }

    }

}

# Run the function to restore the items.The time system "MM/DD/YY" is based on the system time format of your computer, change it if you are "DD/MM/YY".

RestoreItems -deletedByName 'Firstname Lastname' -deletedOnOrAfterDate '01-13-2020'