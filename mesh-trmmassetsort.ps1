#TRMM Token and Auth
$TRMMToken = ''
$MeshUser = ""
$MeshPassword = ''
$TRMMAPIUrl = "https://api.domain.com"


$TRMMHeaders = @{
    'X-API-Key' = $TRMMToken
}
$TRMMAgents = Invoke-RestMethod -uri "$TRMMAPIUrl/agents" -Headers $TRMMHeaders -Method GET
$MeshGroups = (node /meshcentral/node_modules/meshcentral/meshctrl.js ListDeviceGroups --url wss://mesh.cn-s.org:443 --loginuser $MeshUser --loginpass $MeshPassword --json) | ConvertFrom-Json
$MeshDevices = (node /meshcentral/node_modules/meshcentral/meshctrl.js ListDevices --url wss://mesh.cn-s.org:443 --loginuser $MeshUser --loginpass $MeshPassword --json --group TacticalRMM) | ConvertFrom-JSON
foreach ($MeshDevice in $MeshDevices) {
    $TRMMAgent = $TRMMAgents | Where-Object { $_.hostname -eq $MeshDevice.name } #| Where-Object { $_.properties.configuration.primary_ip -eq $MeshDevice.ip } #-or $_.properties.'ScreenConnect GUID' -eq $TRMMAgent.custom_fields.value 
    if ($TRMMAgent.count -gt 1) {
        $TRMMAgentDupes = @()
        foreach ($TRMMAgentDup in $TRMMAgent) {
            $TRMMAgentDupes += (Invoke-RestMethod -uri "$TRMMAPIUrl/agents/$($TRMMAgentDup.agent_id)" -Headers $TRMMHeaders -Method GET)
        }
        $TRMMAgent = $TRMMAgentDupes | Where-Object { $_.public_ip -eq $MeshDevice.ip -or $_.local_ips -match $MeshDevice.ip }
    }
    if ($TRMMAgent.count -eq 1) {
        $MeshGroup = $MeshGroups | Where-Object { $_.name -eq $TRMMAgent.client_name -or $_.name -eq $TRMMAgent.client }
        if ($MeshGroup) {
            Write-output "Moving $($MeshDevice.name) to $($MeshGroup.name)"
            node /meshcentral/node_modules/meshcentral/meshctrl.js MoveToDeviceGroup --url wss://mesh.cn-s.org:443 --loginuser $MeshUser --loginpass $MeshPassword --json --group "$($MeshGroup.name)" --devid $($Meshdevice._id) | Out-Null
        } else {
            Write-Output "No matching groups for $($MeshDevice.name) with $($TRMMAgent.client_name)"
            #$TRMMAgent
        }
    } else {
        Write-Output "Found $($TRMMAgent.count) matches for $($MeshDevice.name)"
    }
}
