$vpnName = "MSFTVPN"
$vpn = Get-VpnConnection -Name $vpnName
if ($vpn.ConnectionStatus -eq 'Disconnected') {
    $maxRetries = 5
    $retry = 0
    $retryDelay = 2
    do {
        $retry++
        Write-Host "Connecting to $vpnName, attempt $retry of $maxRetries"
        $result = rasdial $vpnName
        Write-Host $result
        $vpn = Get-VpnConnection -Name $vpnName
        Write-Host "Connection status: $($vpn.connectionstatus)"
        if ($vpn.connectionstatus -ne 'Connected') {
            Write-Host "The connection attempt failed, wait $retryDelay seconds and try again"
            Start-Sleep -Seconds $retryDelay
        }
        else {
            Write-Host "The connection attempt succeeded"
        }
    } while ($retry -lt $maxRetries -and $vpn.connectionstatus -ne 'Connected')
}