#requires -Version 7.4.6
# Run with Pester 3 or 4: Invoke-Pester -Script .\tests\RemoveUnwantedContent.Tests.ps1

$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'RemoveUnwantedContent.ps1'
. $scriptPath

Describe 'RemoveUnwantedContent offline helpers' {
    BeforeEach {
        $fields = @{
            FSObjType = 1
            Author = [pscustomobject]@{ LookupId = 7; LookupValue = 'Test User' }
            Created = ([datetimeoffset]'2026-10-02T12:00:00Z').UtcDateTime
            Modified = ([datetimeoffset]'2023-10-16T12:00:00Z').UtcDateTime
            UniqueId = [guid]'00000000-0000-0000-0000-000000000001'
            FileRef = '/sites/test/Docs/Empty'
        }
        $criteria = @{
            AuthorId = 7
            CreatedStartUtc = ([datetimeoffset]'2026-10-02T00:00:00Z').UtcDateTime
            CreatedEndUtc = ([datetimeoffset]'2026-10-03T00:00:00Z').UtcDateTime
            ModifiedStartUtc = ([datetimeoffset]'2023-10-16T00:00:00Z').UtcDateTime
            ModifiedEndUtc = ([datetimeoffset]'2023-10-17T00:00:00Z').UtcDateTime
        }
    }

    It 'parses without errors' {
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$parseErrors)
        $parseErrors.Count | Should Be 0
    }

    It 'interprets unspecified CSOM dates as UTC' {
        $value = [datetime]::SpecifyKind([datetime]'2026-10-02T12:00:00', 'Unspecified')
        $utc = ConvertTo-CaseUtc $value
        $utc.Kind | Should Be ([DateTimeKind]::Utc)
        $utc.Ticks | Should Be $value.Ticks
    }

    It 'converts local dates and preserves UTC dates' {
        $local = [datetime]::SpecifyKind([datetime]'2026-10-02T12:00:00', 'Local')
        (ConvertTo-CaseUtc $local).Ticks | Should Be $local.ToUniversalTime().Ticks
        (ConvertTo-CaseUtc $fields.Created).Ticks | Should Be $fields.Created.Ticks
    }

    It 'matches folders by author and both dates' {
        Test-CaseFolderMatch $fields $criteria | Should Be $true
        $fields.FSObjType = 0
        Test-CaseFolderMatch $fields $criteria | Should Be $false
        $fields.FSObjType = 1
        $fields.Author.LookupId = 8
        Test-CaseFolderMatch $fields $criteria | Should Be $false
    }

    It 'rejects missing and null filter fields' {
        foreach ($name in 'FSObjType', 'Author', 'Created', 'Modified') {
            $copy = $fields.Clone()
            $copy.Remove($name)
            Test-CaseFolderMatch $copy $criteria | Should Be $false
            $copy[$name] = $null
            Test-CaseFolderMatch $copy $criteria | Should Be $false
        }
    }

    It 'uses inclusive starts and exclusive ends for both days' {
        foreach ($name in 'Created', 'Modified') {
            $copy = $fields.Clone()
            $copy[$name] = $criteria["${name}StartUtc"]
            Test-CaseFolderMatch $copy $criteria | Should Be $true
            $copy[$name] = $criteria["${name}StartUtc"].AddTicks(-1)
            Test-CaseFolderMatch $copy $criteria | Should Be $false
            $copy[$name] = $criteria["${name}EndUtc"].AddTicks(-1)
            Test-CaseFolderMatch $copy $criteria | Should Be $true
            $copy[$name] = $criteria["${name}EndUtc"]
            Test-CaseFolderMatch $copy $criteria | Should Be $false
        }
    }

    It 'detects every snapshot field changing, including path case' {
        $snapshot = New-CaseSnapshot $fields
        Test-CaseSnapshot $fields $snapshot | Should Be $true
        $changes = @{
            UniqueId = [guid]::NewGuid()
            FileRef = '/sites/test/Docs/EMPTY'
            Author = [pscustomobject]@{ LookupId = 8 }
            Created = $fields.Created.AddSeconds(1)
            Modified = $fields.Modified.AddSeconds(1)
        }
        foreach ($name in $changes.Keys) {
            $copy = $fields.Clone()
            $copy[$name] = $changes[$name]
            Test-CaseSnapshot $copy $snapshot | Should Be $false
        }
    }

    It 'accepts empty collections and collections containing only folders' {
        Test-CaseFileFreeItems -Items @() | Should Be $true
        $folder = [pscustomobject]@{ FieldValues = @{ FSObjType = 1 } }
        Test-CaseFileFreeItems -Items @($folder, $folder) | Should Be $true
    }

    It 'rejects any file in a descendant page' {
        $folder = [pscustomobject]@{ FieldValues = @{ FSObjType = 1 } }
        $file = [pscustomobject]@{ FieldValues = @{ FSObjType = 0 } }
        Test-CaseFileFreeItems -Items @($folder, $file) | Should Be $false
    }

    It 'refuses unknown descendant enumeration or item types' {
        { Test-CaseFileFreeItems -Items $null } | Should Throw 'Descendant enumeration is unknown'
        foreach ($values in @(@{}, @{ FSObjType = $null }, @{ FSObjType = 2 })) {
            $unknown = [pscustomobject]@{ FieldValues = $values }
            { Test-CaseFileFreeItems -Items @($unknown) } | Should Throw 'Unknown descendant item type'
        }
    }

    It 'computes UTC day boundaries without a SharePoint connection' {
        $bounds = Get-CaseDateBoundaries -CreatedDay '2026-10-02' -ModifiedDay '2023-10-16' `
            -OverrideTimeZoneId UTC
        $bounds.CreatedStartUtc | Should Be $criteria.CreatedStartUtc
        $bounds.CreatedEndUtc | Should Be $criteria.CreatedEndUtc
        $bounds.ModifiedStartUtc | Should Be $criteria.ModifiedStartUtc
        $bounds.ModifiedEndUtc | Should Be $criteria.ModifiedEndUtc
        $bounds.TimeZone | Should Be 'UTC'
    }

    It 'rejects invalid timezone overrides' {
        { Get-CaseDateBoundaries -CreatedDay '2026-10-02' -ModifiedDay '2023-10-16' `
            -OverrideTimeZoneId 'Not/A/Timezone' } | Should Throw 'Not/A/Timezone'
    }

    It 'writes CSV under WhatIf and escapes formula prefixes' {
        $path = Join-Path $TestDrive 'report.csv'
        $WhatIfPreference = $true
        foreach ($value in @('=1+1', '+1', '-1', '@name', "`tvalue", "`rvalue", "`nvalue", 'ordinary')) {
            Write-CaseCsvRow -Row ([pscustomobject]@{ Name = $value; Count = 2 }) -Path $path
        }
        $rows = @(Import-Csv -LiteralPath $path)
        $rows.Count | Should Be 8
        foreach ($row in $rows[0..6]) {
            $row.Name.StartsWith("'") | Should Be $true
            $row.Count | Should Be '2'
        }
        $rows[7].Name | Should Be 'ordinary'
    }
}

Describe 'RemoveUnwantedContent offline execution guards' {
    # Untyped test adapters let Pester 3 mock CSOM objects without a live connection.
    function Get-PnPProperty {
        param($ClientObject, $Property, $Connection)
        throw 'Unmocked Get-PnPProperty call'
    }
    function Get-PnPUser {
        param($Identity, $Connection)
        throw 'Unmocked Get-PnPUser call'
    }
    function Get-PnPSubWeb {
        param([switch]$Recurse, [switch]$IncludeRootWeb, $Connection)
        throw 'Unmocked Get-PnPSubWeb call'
    }
    function Invoke-PnPQuery {
        param($Connection)
        throw 'Unmocked Invoke-PnPQuery call'
    }

    function New-TestTreeItem {
        param([int]$Id, [string]$Path, [int]$Type = 1, [int]$AuthorId = 7)
        $values = $itemFields.Clone()
        $values.ID = $Id
        $values.FileRef = $Path
        $values.UniqueId = [guid]::NewGuid()
        $values.FSObjType = $Type
        $values.Author = [pscustomobject]@{ LookupId = $AuthorId; LookupValue = 'Test User' }
        $testItem = [pscustomobject]@{ Id = $Id; FieldValues = $values }
        $testItem | Add-Member ScriptMethod Recycle {
            $state.Recycles++
            $state.RecycledIds.Add($this.Id)
            if ($state.FailRecycle) { throw 'Simulated recycle failure' }
            return [pscustomobject]@{ Value = [guid]'00000000-0000-0000-0000-000000000003' }
        }
        return $testItem
    }

    BeforeEach {
        $runParameters = @{
            SarahLogin = 'test@example.com'
            ClientId = [guid]'00000000-0000-0000-0000-000000000002'
            SiteUrl = 'https://example.sharepoint.com/sites/test'
            TimeZoneId = 'UTC'
            ReportDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            Confirm = $false
        }
        $state = @{
            Recycles = 0
            Reads = 0
            NonEmptyAtScan = $false
            NonEmptyAtDelete = $false
            MetadataChanged = $false
            FailChildren = $false
            FailChildrenAtDelete = $false
            FailSecondPage = $false
            FailRecycle = $false
            IsAdmin = $true
            Items = [System.Collections.Generic.List[object]]::new()
            RecycledIds = [System.Collections.Generic.List[int]]::new()
            TreeQueries = [System.Collections.Generic.List[object]]::new()
        }
        $itemFields = @{
            ID = 1; FSObjType = 1; FileLeafRef = 'Empty'
            FileRef = '/sites/test/Docs/Empty'
            UniqueId = [guid]'00000000-0000-0000-0000-000000000001'
            Author = [pscustomobject]@{ LookupId = 7; LookupValue = 'Test User' }
            Editor = $null
            Created = ([datetimeoffset]'2026-10-02T12:00:00Z').UtcDateTime
            Modified = ([datetimeoffset]'2023-10-16T12:00:00Z').UtcDateTime
            ItemChildCount = 0; FolderChildCount = 0
        }
        $item = New-TestTreeItem -Id 1 -Path $itemFields.FileRef
        $state.Items.Add($item)
        $list = [pscustomobject]@{
            Id = [guid]'00000000-0000-0000-0000-000000000004'
            Title = 'Docs'; BaseType = 1; Hidden = $false
        }
        $list | Add-Member ScriptMethod GetItems {
            param($query)
            $collection = [System.Collections.Generic.List[object]]::new()
            $position = $null
            if ($null -ne $query.FolderServerRelativePath) {
                if ($state.FailChildren -or ($state.Reads -gt 0 -and $state.FailChildrenAtDelete)) {
                    throw 'Simulated child enumeration failure'
                }
                $view = [xml]$query.ViewXml
                $recursive = $view.DocumentElement.GetAttribute('Scope') -eq 'RecursiveAll'
                $prefix = $query.FolderServerRelativePath.DecodedUrl.TrimEnd('/') + '/'
                $descendants = @($state.Items | Where-Object {
                    $path = $_.FieldValues.FileRef
                    $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
                        ($recursive -or -not $path.Substring($prefix.Length).Contains('/'))
                })
                if (($state.Reads -eq 0 -and $state.NonEmptyAtScan) -or
                    ($state.Reads -gt 0 -and $state.NonEmptyAtDelete)) {
                    $descendants += [pscustomobject]@{
                        Id = 9999; FieldValues = @{ FSObjType = 0; FileRef = $prefix + 'new.txt' }
                    }
                }
                $start = 0
                if ($null -ne $query.ListItemCollectionPosition) {
                    if ($state.FailSecondPage) { throw 'Simulated next-page failure' }
                    $start = [int]([regex]::Match($query.ListItemCollectionPosition.PagingInfo, 'p_ID=(\d+)').Groups[1].Value)
                }
                $limit = [int]$view.SelectSingleNode('/View/RowLimit').InnerText
                $state.TreeQueries.Add([pscustomobject]@{ Scope = $view.DocumentElement.GetAttribute('Scope'); Start = $start })
                $end = [Math]::Min($start + $limit, $descendants.Count)
                for ($index = $start; $index -lt $end; $index++) {
                    $collection.Add($descendants[$index])
                }
                if ($end -lt $descendants.Count) {
                    $position = [Microsoft.SharePoint.Client.ListItemCollectionPosition]::new()
                    $position.PagingInfo = "Paged=TRUE&p_ID=$end"
                }
            }
            else {
                foreach ($entry in $state.Items) { $collection.Add($entry) }
            }
            Add-Member -InputObject $collection -MemberType NoteProperty -Name ListItemCollectionPosition -Value $position
            return ,$collection
        }
        $list | Add-Member ScriptMethod GetItemById {
            param($id)
            $state.Reads++
            $freshItem = $state.Items | Where-Object Id -eq $id
            if ($state.MetadataChanged) { $freshItem.FieldValues.FileRef = '/sites/test/Docs/Moved' }
            return $freshItem
        }
        $context = [pscustomobject]@{
            Web = [pscustomobject]@{ CurrentUser = [pscustomobject]@{ IsSiteAdmin = $true } }
        }
        $context | Add-Member ScriptMethod Load { param($value) }
        $mockConnection = [pscustomobject]@{ Context = $context }
        $web = [pscustomobject]@{
            Url = 'https://example.sharepoint.com/sites/test'
            Lists = @($list)
        }

        # Replace all network entry points; use the installed CSOM query type only.
        Import-Module PnP.PowerShell -MinimumVersion 3.0.0
        Mock Connect-PnPOnline { return $mockConnection }
        Mock Get-PnPProperty {
            if ($Property -eq 'IsSiteAdmin') { return $state.IsAdmin }
            return $ClientObject.$Property
        }
        Mock Get-PnPUser {
            return [pscustomobject]@{
                Id = 7; Title = 'Test User'
                LoginName = 'i:0#.f|membership|test@example.com'; Email = 'test@example.com'
            }
        }
        Mock Get-PnPSubWeb { return $web }
        Mock Invoke-PnPQuery {}
    }

    It 'never recycles in the default Preview mode' {
        & $scriptPath @runParameters
        $state.Recycles | Should Be 0
        $state.Reads | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Candidates.csv')).Status |
            Should Be 'PreviewFileFreeTree'
        Test-Path (Join-Path $runParameters.ReportDirectory 'Actions.csv') | Should Be $false
    }

    It 'never recycles with Delete and WhatIf' {
        & $scriptPath @runParameters -Delete -WhatIf
        $state.Recycles | Should Be 0
        $state.Reads | Should Be 0
        $actions = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv'))
        $actions[0].Status | Should Be 'NotExecuted'
    }

    It 'never recycles in RunMode WhatIf' {
        & $scriptPath @runParameters -RunMode WhatIf
        $state.Recycles | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv')).Status |
            Should Be 'NotExecuted'
    }

    It 'supports the F5 RunMode Delete setting' {
        & $scriptPath @runParameters -RunMode Delete
        $state.Reads | Should Be 1
        $state.Recycles | Should Be 1
    }

    It 'honors explicitly disabling Delete even in RunMode Delete' {
        & $scriptPath @runParameters -RunMode Delete -Delete:$false
        $state.Recycles | Should Be 0
    }

    It 'rechecks and recycles an unchanged empty candidate with audit rows' {
        & $scriptPath @runParameters -Delete
        $state.Reads | Should Be 1
        $state.Recycles | Should Be 1
        $actions = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv'))
        $actions.Count | Should Be 2
        $actions[0].Status | Should Be 'AttemptingRecycle'
        $actions[1].Status | Should Be 'Recycled'
        $actions[1].RecycleBinId | Should Be '00000000-0000-0000-0000-000000000003'
    }

    It 'never selects nonempty folders for deletion' {
        $state.NonEmptyAtScan = $true
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 0
        $state.Reads | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Candidates.csv')).Status |
            Should Be 'SkippedContainsFiles'
    }

    It 'skips trees that gain files after preview' {
        $state.NonEmptyAtDelete = $true
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv')).Status |
            Should Be 'SkippedNowContainsFiles'
    }

    It 'skips folders whose metadata changes after preview' {
        $state.MetadataChanged = $true
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv')).Status |
            Should Be 'SkippedMetadataChanged'
    }

    It 'stops if child enumeration fails instead of assuming emptiness' {
        $state.FailChildren = $true
        { & $scriptPath @runParameters -Delete } | Should Throw 'Simulated child enumeration failure'
        $state.Recycles | Should Be 0
    }

    It 'records an unknown outcome and stops after a recycle failure' {
        $state.FailRecycle = $true
        { & $scriptPath @runParameters -Delete } | Should Throw 'Simulated recycle failure'
        $actions = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv'))
        $actions[0].Status | Should Be 'AttemptingRecycle'
        $actions[1].Status | Should Be 'FailedOrOutcomeUnknown'
        $actions[1].Error | Should Match 'Simulated recycle failure'
    }

    It 'rejects non-administrators before scanning' {
        $state.IsAdmin = $false
        { & $scriptPath @runParameters -Delete } | Should Throw 'Sign in as a site collection administrator'
        Assert-MockCalled Get-PnPSubWeb -Times 0 -Exactly -Scope It
        $state.Recycles | Should Be 0
    }

    It 'recycles a matching root together with nested nonmatching empty folders' {
        $state.Items.Add((New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty/B' -AuthorId 8))
        $state.Items.Add((New-TestTreeItem -Id 3 -Path '/sites/test/Docs/Empty/B/C' -AuthorId 9))
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 1
        $state.RecycledIds[0] | Should Be 1
        $rows = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Candidates.csv'))
        $rows.Count | Should Be 1
        $rows[0].FileFreeTreeAtScan | Should Be 'True'
        $rows[0].RecycleScope | Should Be 'FolderAndAllDescendants'
        $state.TreeQueries.Count | Should Be 2
        foreach ($query in $state.TreeQueries) { $query.Scope | Should Be 'RecursiveAll' }
    }

    It 'never recycles a tree containing a file at any depth' {
        $state.Items.Add((New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty/B' -AuthorId 8))
        $state.Items.Add((New-TestTreeItem -Id 3 -Path '/sites/test/Docs/Empty/B/C' -AuthorId 8))
        $state.Items.Add((New-TestTreeItem -Id 4 -Path '/sites/test/Docs/Empty/B/C/file.txt' -Type 0))
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Candidates.csv')).Status |
            Should Be 'SkippedContainsFiles'
    }

    It 'rechecks deep descendants for new files after confirmation' {
        $state.Items.Add((New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty/B' -AuthorId 8))
        $state.Items.Add((New-TestTreeItem -Id 3 -Path '/sites/test/Docs/Empty/B/C' -AuthorId 8))
        $list | Add-Member ScriptMethod GetItemById {
            param($id)
            $state.Reads++
            $state.Items.Add((New-TestTreeItem -Id 4 -Path '/sites/test/Docs/Empty/B/C/new.txt' -Type 0))
            return $state.Items | Where-Object Id -eq $id
        } -Force
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv')).Status |
            Should Be 'SkippedNowContainsFiles'
    }

    It 'selects only the outermost matching root regardless of scan order' {
        $child = New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty/B'
        $state.Items.Insert(0, $child)
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 1
        $state.RecycledIds[0] | Should Be 1
        $rows = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Candidates.csv'))
        $childRow = $rows | Where-Object ItemId -eq 2
        $childRow.Status | Should Be 'SkippedCoveredByAncestor'
        $childRow.CoveredByAncestor | Should Be '/sites/test/Docs/Empty'
        $actions = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv'))
        $actions.Count | Should Be 2
    }

    It 'keeps path-prefix siblings as separate roots' {
        $state.Items.Add((New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty2'))
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 2
    }

    It 'previews tree scope and ancestor coverage without recycling' {
        $state.Items.Add((New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty/B'))
        & $scriptPath @runParameters
        $state.Recycles | Should Be 0
        $rows = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Candidates.csv'))
        ($rows | Where-Object ItemId -eq 1).Status | Should Be 'PreviewFileFreeTree'
        ($rows | Where-Object ItemId -eq 2).Status | Should Be 'SkippedCoveredByAncestor'
    }

    It 'simulates only the outer root when an entire empty tree is selected' {
        $state.Items.Add((New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty/B'))
        & $scriptPath @runParameters -Delete -WhatIf
        $state.Recycles | Should Be 0
        $state.Reads | Should Be 0
        $actions = @(Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv'))
        $actions.Count | Should Be 1
        $actions[0].ItemId | Should Be '1'
        $actions[0].Status | Should Be 'NotExecuted'
        $actions[0].RecycleScope | Should Be 'FolderAndAllDescendants'
    }

    It 'does not include a nonmatching ancestor when its matching child is selected' {
        $item.FieldValues.Author.LookupId = 8
        $state.Items.Add((New-TestTreeItem -Id 2 -Path '/sites/test/Docs/Empty/B'))
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 1
        $state.RecycledIds[0] | Should Be 2
    }

    It 'finds a file beyond the first descendant page' {
        for ($id = 2; $id -le 2001; $id++) {
            $state.Items.Add((New-TestTreeItem -Id $id -Path "/sites/test/Docs/Empty/B$id" -AuthorId 8))
        }
        $state.Items.Add((New-TestTreeItem -Id 2002 -Path '/sites/test/Docs/Empty/last.txt' -Type 0))
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 0
        $state.TreeQueries.Count | Should Be 2
        $state.TreeQueries[1].Start | Should Be 2000
    }

    It 'accepts a file-free tree spanning multiple descendant pages' {
        for ($id = 2; $id -le 2002; $id++) {
            $state.Items.Add((New-TestTreeItem -Id $id -Path "/sites/test/Docs/Empty/B$id" -AuthorId 8))
        }
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 1
        $state.TreeQueries.Count | Should Be 4
    }

    It 'stops if any descendant page cannot be read' {
        for ($id = 2; $id -le 2002; $id++) {
            $state.Items.Add((New-TestTreeItem -Id $id -Path "/sites/test/Docs/Empty/B$id" -AuthorId 8))
        }
        $state.FailSecondPage = $true
        { & $scriptPath @runParameters -Delete } | Should Throw 'Simulated next-page failure'
        $state.Recycles | Should Be 0
    }

    It 'records an error and does not recycle if the final tree check fails' {
        $state.FailChildrenAtDelete = $true
        { & $scriptPath @runParameters -Delete } | Should Throw 'Simulated child enumeration failure'
        $state.Recycles | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv')).Status |
            Should Be 'FailedOrOutcomeUnknown'
    }
}
