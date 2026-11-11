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

    It 'accepts only known empty child collections' {
        Test-CaseEmpty -Children @() | Should Be $true
        Test-CaseEmpty -Children @([pscustomobject]@{ Id = 1 }) | Should Be $false
        { Test-CaseEmpty -Children $null } | Should Throw 'Child enumeration is unknown'
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
            FailRecycle = $false
            IsAdmin = $true
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
        $item = [pscustomobject]@{ Id = 1; FieldValues = $itemFields }
        $item | Add-Member ScriptMethod Recycle {
            $state.Recycles++
            if ($state.FailRecycle) { throw 'Simulated recycle failure' }
            return [pscustomobject]@{ Value = [guid]'00000000-0000-0000-0000-000000000003' }
        }
        $list = [pscustomobject]@{
            Id = [guid]'00000000-0000-0000-0000-000000000004'
            Title = 'Docs'; BaseType = 1; Hidden = $false
        }
        $list | Add-Member ScriptMethod GetItems {
            param($query)
            $collection = [System.Collections.Generic.List[object]]::new()
            if ($null -ne $query.FolderServerRelativePath) {
                if ($state.FailChildren) { throw 'Simulated child enumeration failure' }
                if (($state.Reads -eq 0 -and $state.NonEmptyAtScan) -or
                    ($state.Reads -gt 0 -and $state.NonEmptyAtDelete)) {
                    $collection.Add([pscustomobject]@{ Id = 2 })
                }
            }
            else {
                $collection.Add($item)
            }
            Add-Member -InputObject $collection -MemberType NoteProperty -Name ListItemCollectionPosition -Value $null
            return ,$collection
        }
        $list | Add-Member ScriptMethod GetItemById {
            param($id)
            $state.Reads++
            if ($state.MetadataChanged) { $item.FieldValues.FileRef = '/sites/test/Docs/Moved' }
            return $item
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
            Should Be 'PreviewEmpty'
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
            Should Be 'SkippedNonEmpty'
    }

    It 'skips folders that gain children after preview' {
        $state.NonEmptyAtDelete = $true
        & $scriptPath @runParameters -Delete
        $state.Recycles | Should Be 0
        (Import-Csv (Join-Path $runParameters.ReportDirectory 'Actions.csv')).Status |
            Should Be 'SkippedNowNonEmpty'
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
}
