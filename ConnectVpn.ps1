$vpnName = "MSFTVPN"
$vpn = Get-VpnConnection -Name $vpnName
if ($vpn.ConnectionStatus -eq 'Disconnected') {
    $maxRetries = 5
    $retry = 0
    $retryDelay = 2
    do {
        $retry++
        $result = rasdial $vpnName
        $vpn = Get-VpnConnection -Name $vpnName
        if ($result -match 'The connection attempt failed because the remote computer did not respond') {
            Write-Host "The connection attempt failed because the remote computer did not respond, wait $retryDelay seconds and try again"
            Start-Sleep -Seconds $retryDelay
        }
    } while ($retry -lt $maxRetries -and $vpn.connectionstatus -ne 'Connected')
}