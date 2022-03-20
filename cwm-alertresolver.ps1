param (
    [string] $TRMMAgentName,
    [string] $TRMMClientCWMCompID,
    [string] $TRMMAlertMessage,
    [string] $TRMMAlertSeverity,
    [string] $TRMMAlertTime,
    [string] $TRMMAgentLastSeen,
    [string] $TRMMAgentID
)

Write-Output "Creating Alert in CWM for Tactical RMM for $TRMMAgentName"
#Setup CWM Connection
$Server = 'na.myconnectwise.net'
$Company = '***********COMPANYID***********'
$pubKey = '***********PUBKEY********'
$privateKey = '***********PRIVKEY***********'
$clientId = '***********CLIENTID*************'
$CWMHeaders = @{
    ClientID        = $ClientID
    'Cache-Control' = 'no-cache'
}
try { $CompanyInfo = Invoke-RestMethod "https://$($Server)/login/companyinfo/$($Company)" -ErrorAction Stop }
catch { Write-Error $_ -ErrorAction Stop }

$APIurl = "https://$($CompanyInfo.SiteUrl)/$($CompanyInfo.Codebase)apis/3.0"

$AuthString = "$($Company)+$($PubKey):$($PrivateKey)"
$EncodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($AuthString))
$CWMHeaders.add('Authorization', "Basic $EncodedAuth")
$CWMHeaders.Accept = "application/vnd.connectwise.com+json"
$summary = $(if ($TRMMAlertMessage) { "$TRMMAlertMessage ($TRMMAlertSeverity)" } else { "$TRMMAgentName Offline! ($TRMMAlertSeverity)" })
$requestbody = @{
    Requests = @(
        @{
            SequenceNumber = 1
            Version        = "v2021.1"
            ResourceType   = "Ticket"
            ApiRequest     = @{
                Filters = @{
                    conditions = "externalXRef = `"TRMM-Alert`" and status/name != `">Closed`" and company/id = $TRMMClientCWMCompID and summary = `"$summary`""
                }
                Page    = @{         
                    pageSize = 1000
                    page     = 1
                }
            }
        }
    )
}

$bundleresult = (Invoke-RestMethod -uri "$APIurl/system/bundles" -Headers $CWMHeaders -ContentType "application/json" -Method POST -body $($requestbody | ConvertTo-JSON -depth 15)).results
$CWMTicket = $bundleresult[0].entities | Select-Object -Last 1
if ($CWMTicket) {
    Write-Output "Found existing ticket #$($CWMTicket.id)"
}
if ($CWMTicket) {
    Write-Output "Resolving Ticket for Alert"
    $body = @(
        @{
            op    = "replace"
            path  = "status"
            value = @{ Name = "Resolved" }
        }
    )
    Invoke-RestMethod -uri "$APIurl/service/tickets/$($CWMTicket.id)" -Headers $CWMHeaders -ContentType "application/json" -Method PATCH -body $(ConvertTo-JSON -depth 15 $body) | Out-Null
}
