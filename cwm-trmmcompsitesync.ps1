
#TRMM Token and Auth
Write-Output "Syncing CWM to TRMM Companies and Sites"
$TRMMToken = '***********************' # TRMM API Token
$TRMMHeaders = @{
    'X-API-Key' = $TRMMToken
}
$TRMMAPIUrl = "https://api.example.com"
##CWM Auth and Tokens
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

#WORK!

$CWMCompanies = (Invoke-RestMethod -uri "$APIurl/company/companies?pagesize=1000" -Headers $CWMHeaders -ContentType "application/json") | Where-Object { $_.types.name -eq 'Client' -and !$_.deletedflag }

$TRMMClients = Invoke-RestMethod -uri "$TRMMAPIUrl/clients" -Headers $TRMMHeaders -Method GET
#$TRMMAgents = Invoke-RestMethod -uri "$TRMMAPIUrl/agents" -Headers $TRMMHeaders -Method GET
$CustomFields = Invoke-RestMethod -uri "$TRMMAPIUrl/core/customfields/" -Headers $TRMMHeaders -Method GET
Write-Output "Looping Companies"
foreach ($CWMCompany in $CWMCompanies) {
    $TRMMClient = $TRMMClients | Where-Object { $_.name -eq $CWMCompany.name }
    $TRMMSites = $TRMMClient.sites
    if (!$TRMMClient) {
        $body = [ordered]@{
            client        = @{
                name               = $CWMCompany.name
                server_policy      = 2
                workstation_policy = 4
            }
            site          = @{
                name = $CWMCompany.site.name
            }
            custom_fields = @(
                [ordered]@{
                    field        = ($CustomFields | Where-Object { $_.name -eq 'CW Manage Client ID' }).id
                    string_value = $($CWMCompany.id)
                }
            )
        }
        Invoke-RestMethod -uri "$TRMMAPIUrl/clients/" -Headers $TRMMHeaders -ContentType 'application/json' -Method POST -Body $($body | ConvertTo-JSON -depth 10) | Out-Null
    } else {
        $body = [ordered]@{
            client        = @{}
            custom_fields = @(
                [ordered]@{
                    field        = ($CustomFields | Where-Object { $_.name -eq 'CW Manage Client ID' }).id
                    string_value = $($CWMCompany.id)
                }
            )
        }
        Invoke-RestMethod -uri "$TRMMAPIUrl/clients/$($TRMMClient.id)/" -Headers $TRMMHeaders -ContentType 'application/json' -Method PUT -Body $($body | ConvertTo-JSON -depth 10) | Out-Null
    }

    $CWMSites = (Invoke-RestMethod -uri "$APIurl/company/companies/$($CWMCompany.id)/sites?pagesize=1000" -Headers $CWMHeaders -ContentType "application/json")
    if ($CWMSites.count -gt 1) {
        foreach ($CWMSite in $CWMSites) {
            $TRMMSite = $TRMMSites | Where-Object { $_.Name -match $CWMSite.name }
            if (!$TRMMSite) {
                $body = @{
                    site          = @{
                        client = $TRMMClient.id
                        name   = $CWMSite.name
                    }
                    custom_fields = @(
                        [ordered]@{
                            field        = ($CustomFields | Where-Object { $_.name -eq 'CW Manage Site ID' }).id
                            string_value = $($CWMSite.id)
                        }
                    )
                }
                Invoke-RestMethod -uri "$TRMMAPIUrl/clients/sites/" -Headers $TRMMHeaders -ContentType 'application/json' -Method POST -Body $($body | ConvertTo-JSON -depth 10) | Out-Null
            } else {
                $body = [ordered]@{
                    site          = @{}
                    custom_fields = @(
                        [ordered]@{
                            field        = ($CustomFields | Where-Object { $_.name -eq 'CW Manage Site ID' }).id
                            string_value = $($CWMSite.id)
                        }
                    )
                }
                Invoke-RestMethod -uri "$TRMMAPIUrl/clients/sites/$($TRMMSite.id)/" -Headers $TRMMHeaders -ContentType 'application/json' -Method PUT -Body $($body | ConvertTo-JSON -depth 10) | Out-Null
            }
        }
    } else {
        $body = [ordered]@{
            site          = @{}
            custom_fields = @(
                [ordered]@{
                    field        = ($CustomFields | Where-Object { $_.name -eq 'CW Manage Site ID' }).id
                    string_value = $($CWMSites.id)
                }
            )
        }
        Invoke-RestMethod -uri "$TRMMAPIUrl/clients/sites/$($TRMMClient.sites.id)/" -Headers $TRMMHeaders -ContentType 'application/json' -Method PUT -Body $($body | ConvertTo-JSON -depth 10) | Out-Null
    }
}
Write-Output "All Done."
