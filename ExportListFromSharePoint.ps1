Add-PSSnapin microsoft.sharepoint.powershell -ErrorAction SilentlyContinue
 
$WebUrl = "http://apps/cases/LGH/LGH-2014-00081/" 
$ListName = "Vilkår"  
$ReportLocation = "export.csv" 

#
# This indicates which column(s) you would like to pull out from sharepoint list. Following commands can help return all columns of target list: $Web = Get-SPWeb $WebUrl; $List = $Web.Lists[$ListName]; $List.Fields.InternalName
#
$ColumnsSharePoint = @("LH_ConditionNumber", "Title", "LH_EndedDate", "LH_InitialActivitiesCompleted", "LH_ReviewResponsible", "LH_ActivitiesMet", "LH_Responsible", "LH_Approver", "LH_ConditionDate", "LH_CategoryID", "LH_ReviewDate", "LH_WorkflowActivated", "LH_Permit", "_ModerationStatus", "SendDela", "TermDesc")

#
# This indicates what column names you would like to display in csv reprot. The number of coulumns below has to be the same as "ColumnsToBeDisplayed". 
#
$ColumnsCsv = @("Vilkårsnummer", "Titel", "Udgået den", "Gennemført", "Review ansvarlig", "Aktiviteter Opfyldt", "Ansvarlig", "Godkender", "Gyldighedsdato", "Kategori", "Næste review", "Review-workflow aktiveret", "Miljøgodkendelse", "Approval Status", "Send Delayed Review Reminder", "Vilkårs tekst")

$ErrorActionPreference = "Stop"

$Web = Get-SPWeb $WebUrl

$Result = New-Object System.Data.Datatable

try
{
    $List = $Web.Lists[$ListName]
 
    $query=New-Object Microsoft.SharePoint.SPQuery
    $query.Query = $list.DefaultView.Query
    $Items = $List.GetItems($query)
 
    ForEach ($field in $ColumnsSharePoint)
    {
        if (!$Result.Columns.Contains($field)) 
        {
            [void]$Result.Columns.Add($field)
        }
    }
 
    foreach ($item in $Items)
    {
        $row = $Result.NewRow()    

        for ($i = 0; $i -lt $Result.Columns.Count; $i++) 
        {
            $cellValue = $item[$Result.Columns[$i].ColumnName]
            $cellType = $item.Fields.GetFieldByInternalName($Result.Columns[$i].ColumnName).Type
            $currentCell = $item.Fields.GetFieldByInternalName($Result.Columns[$i].ColumnName)
            
            if ([System.String]::IsNullOrEmpty($cellValue)) 
            {
                $row[$Result.Columns[$i].ColumnName] = $cellValue
                continue
            }
            
            if ($cellType -eq "User") # People picker column
            {
                $cellValue = $cellValue.Split("#")[-1]
                $row[$Result.Columns[$i].ColumnName] = $cellValue
                continue
            }

            if ($cellType -eq "Invalid") # Metadata column
            {
                $cellValue = $cellValue.Label
                $row[$Result.Columns[$i].ColumnName] = $cellValue
                continue
            }

            if ($cellType -eq "WorkflowStatus") # Workflow column
            {
                switch ($cellValue)
                {
                    '0' {$cellValue = "Not Started"}
                    '1' {$cellValue = "Failed On Start"}
                    '2' {$cellValue = "In Progress"}
                    '3' {$cellValue = "Error Occurred"}
                    '4' {$cellValue = "Stopped By User"}
                    '5' {$cellValue = "Completed"}
                    '6' {$cellValue = "Failed On Start Retrying"}
                    '7' {$cellValue = "Error Occurred Retrying"}
                    '15' {$cellValue = "Canceled"}
                    '16' {$cellValue = "Approved"}
                    '17' {$cellValue = "Rejected"}
                    Default {}
                }
                $row[$Result.Columns[$i].ColumnName] = $cellValue
                continue
            }

            if ($currentCell.InternalName -eq "_ModerationStatus") # Approval status column
            {
                $cellValue = $currentCell.GetFieldValueAsText($item["_ModerationStatus"])
                $row[$Result.Columns[$i].ColumnName] = $cellValue
                continue
            }
            
            $row[$Result.Columns[$i].ColumnName] = $cellValue           
        }

        $Result.Rows.Add($row)
    }
}
catch
{
    $_
}
finally
{
    $Web.Dispose()
}

function ChangeColumnsDisplayName ([System.Data.Datatable] $Result, $ColumnsCsv) 
{
    for ($i = 0; $i -lt $Result.Columns.Count; $i++)
    { 
        $Result.Columns[$i].ColumnName = $ColumnsCsv[$i]
    }
}

ChangeColumnsDisplayName $Result $ColumnsCsv

$Result | Export-Csv $ReportLocation -NoTypeInformation -Encoding UTF8
