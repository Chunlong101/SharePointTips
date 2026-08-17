[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$targets = Get-ChildItem $scriptRoot -Filter "*.ps1" | Where-Object Name -ne "Test-ScriptSafety.ps1"
$errors = [System.Collections.Generic.List[string]]::new()
foreach ($target in $targets) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $target.FullName,
        [ref]$tokens,
        [ref]$parseErrors) | Out-Null
    foreach ($parseError in $parseErrors) {
        $errors.Add("$($target.Name): parser error: $($parseError.Message)")
    }

    $content = Get-Content $target.FullName -Raw
    if ($target.Name -eq "Prepare-SpeTestIdentities.ps1" -and $content -notmatch '\[switch\]\$Apply') {
        $errors.Add("Prepare script must expose an explicit -Apply switch.")
    }
    if ($content -match 'Write-(Host|Output|Information).*\$(plainPassword|securePassword|ClientSecret|accessToken)') {
        $errors.Add("$($target.Name): potentially writes a secret variable.")
    }
}
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "PowerShell safety checks passed for $($targets.Count) scripts."
