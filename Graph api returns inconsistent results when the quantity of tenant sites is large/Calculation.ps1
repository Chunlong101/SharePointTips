$jsonFilesPath = ".\31054921\FiddlerDump1\graph.microsoft.com\v1.0"
$hash1 = @{ } # Key: WebRul, Value: Count
$dir = dir $jsonFilesPath
foreach ($d in $dir) {
    $json = Get-Content -Force $d.FullName | Out-String | ConvertFrom-Json
    foreach ($v in $json.value) {
        $v | Export-Csv -Force -Append .\31054921\FiddlerDumpAllSites1.csv
        if ($hash1.ContainsKey($v.webUrl)) {
            $hash1[$v.webUrl]++;
        }
        else {
            $hash1.Add($v.webUrl, 1)
        }
    }
}
$hash1.GetEnumerator() | foreach {
    $_ | Export-Csv -Append .\31054921\Unique1.csv
    if ($_.Value -gt 1) {
        $_ | Export-Csv -Append .\31054921\Duplicated1.csv
    }
}

$jsonFilesPath = ".\31054921\FiddlerDump2\graph.microsoft.com\v1.0"
$hash2 = @{ } 
$dir = dir $jsonFilesPath
foreach ($d in $dir) {
    $json = Get-Content -Force $d.FullName | Out-String | ConvertFrom-Json
    foreach ($v in $json.value) {
        $v | Export-Csv -Force -Append .\31054921\FiddlerDumpAllSites2.csv
        if ($hash2.ContainsKey($v.webUrl)) {
            $hash2[$v.webUrl]++;
        }
        else {
            $hash2.Add($v.webUrl, 1)
        }
    }
}
$hash2.GetEnumerator() | foreach {
    $_ | Export-Csv -Append .\31054921\Unique2.csv
    if ($_.Value -gt 1) {
        $_ | Export-Csv -Append .\31054921\Duplicated2.csv
    }
}

$jsonFilesPath = ".\31054921\FiddlerDump3\graph.microsoft.com\v1.0"
$hash3 = @{ } # Key: WebRul, Value: Count
$dir = dir $jsonFilesPath
foreach ($d in $dir) {
    $json = Get-Content -Force $d.FullName | Out-String | ConvertFrom-Json
    foreach ($v in $json.value) {
        $v | Export-Csv -Force -Append .\31054921\FiddlerDumpAllSites3.csv
        if ($hash3.ContainsKey($v.webUrl)) {
            $hash3[$v.webUrl]++;
        }
        else {
            $hash3.Add($v.webUrl, 1)
        }
    }
}
$hash3.GetEnumerator() | foreach {
    $_ | Export-Csv -Append .\31054921\Unique3.csv
    if ($_.Value -gt 1) {
        $_ | Export-Csv -Append .\31054921\Duplicated3.csv
    }
}

$jsonFilesPath = ".\31054921\FiddlerDump4\graph.microsoft.com\v1.0"
$hash4 = @{ } # Key: WebRul, Value: Count
$dir = dir $jsonFilesPath
foreach ($d in $dir) {
    $json = Get-Content -Force $d.FullName | Out-String | ConvertFrom-Json
    foreach ($v in $json.value) {
        $v | Export-Csv -Force -Append .\31054921\FiddlerDumpAllSites4.csv
        if ($hash4.ContainsKey($v.webUrl)) {
            $hash4[$v.webUrl]++;
        }
        else {
            $hash4.Add($v.webUrl, 1)
        }
    }
}
$hash4.GetEnumerator() | foreach {
    $_ | Export-Csv -Append .\31054921\Unique4.csv
    if ($_.Value -gt 1) {
        $_ | Export-Csv -Append .\31054921\Duplicated4.csv
    }
}
