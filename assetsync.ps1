$start = $(Get-Date)
Write-Output "`nSync started at $start"
<#
FAIR WARNING DON'T USE THIS TILL YOU UNDERSTAND WHAT IT DOES, IT CAN OVERWRITE YOUR CONFIGS!

THIS NEEDS TO RUN FROM YOUR TRMM SERVER OR YOU'LL NEED TO FIGURE OUT EXTERNAL ACCESS TO POSTGRE

MAX ITEMS THIS IS DESIGNED TO HANDLE

7000 Contacts
4000 Managed Workstations and Servers
1000 Companies

This is designed to 

#>
$scsubdomain = '' #Screenconnect subdomain, skip if you don't use sc
$TRMMRootDomain = 'example.com'  # TRMM Root domain
$TRMMPGUser = '**************PGUSER***********' # Preferred create a READONLY Postgre User
$TRMMPGPassword = '********************PGPASSWORD*********************'
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
$i = 1
$requestbody = @{
    Requests = @(
        @{
            SequenceNumber = $i
            Version        = "v2021.1"
            ResourceType   = "Configuration"
            ApiRequest     = @{
                Filters = @{
                    conditions = "type/name = `"Managed Server`" or type/name `"Managed Workstation`""
                }
                Page    = @{         
                    pageSize = 1000
                    page     = 1
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Configuration"
            ApiRequest     = @{
                Filters = @{
                    conditions = "type/name = `"Managed Server`" or type/name `"Managed Workstation`""
                }
                Page    = @{         
                    pageSize = 1000
                    page     = 2
                }
            }
        }@{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Configuration"
            ApiRequest     = @{
                Filters = @{
                    conditions = "type/name = `"Managed Server`" or type/name `"Managed Workstation`""
                }
                Page    = @{         
                    pageSize = 1000
                    page     = 3
                }
            }
        }@{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Configuration"
            ApiRequest     = @{
                Filters = @{
                    conditions = "type/name = `"Managed Server`" or type/name `"Managed Workstation`""
                }
                Page    = @{         
                    pageSize = 1000
                    page     = 4
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Contact"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 1
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Contact"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 2
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Contact"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 3
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Contact"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 4
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Contact"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 5
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Contact"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 6
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Contact"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 7
                }
            }
        }, @{
            SequenceNumber = $($i = $i + 1; $i)
            Version        = "v2021.1"
            ResourceType   = "Company"
            ApiRequest     = @{
                Page = @{         
                    pageSize = 1000
                    page     = 1
                }
            }
        }
    )
}

$bundleresult = (Invoke-RestMethod -uri "$APIurl/system/bundles" -Headers $CWMHeaders -ContentType "application/json" -Method POST -body $($requestbody | ConvertTo-JSON -depth 15)).results
$CWMConfigurations = & {
    $bundleresult[0].entities
    $bundleresult[1].entities
    $bundleresult[2].entities
    $bundleresult[3].entities
}
$CWMContacts = & {
    $bundleresult[4].entities
    $bundleresult[5].entities
    $bundleresult[6].entities
    $bundleresult[7].entities
    $bundleresult[8].entities
    $bundleresult[9].entities
    $bundleresult[10].entities
}
$CWMCompanies = $bundleresult[11].entities
#>

$TRMMDBUrl = "postgresql://$($TRMMPGUser):$($TRMMPGPassword)@localhost:5432/tacticalrmm"

$TRMMAgents = @"
SELECT row_to_json(agents)
FROM (
    SELECT
    	agents_agent.hostname,
		agents_agent.operating_system, 
		agents_agent.agent_id, 
		agents_agent.last_seen, 
		agents_agent.public_ip, 
		agents_agent.total_ram,
		agents_agent.disks,
		agents_agent.logged_in_username,
		agents_agent.last_logged_in_user,
		agents_agent.mesh_node_id,
		agents_agent.modified_time,
		agents_agent.wmi_detail,
		agents_agent.plat,
		clients_site.name as siteName, 
		clients_client.name as clientName,
        (
        	SELECT jsonb_agg(customfield)
        	FROM (
	        	SELECT
		     		agents_agentcustomfield.string_value,
					core_customfield.name
				from agents_agentcustomfield
				inner join core_customfield on agents_agentcustomfield.field_id = core_customfield.id
		        WHERE agents_agent.id = agents_agentcustomfield.agent_id
        	) AS customfield
        ) AS customfields
    FROM agents_agent
	INNER JOIN clients_site ON agents_agent.site_id=clients_site.id
	INNER JOIN clients_client ON clients_site.client_id=clients_client.id
) AS agents;
"@ | psql -t $TRMMDBUrl | ConvertFrom-Json

foreach ($TRMMAgent in $TRMMAgents) {
    $CWMCompany = $CWMCompanies | Where-Object { $_.name -eq $TRMMAgent.clientName }
    if ($CWMCompany) {
        $CWMContact = $false
        if ($TRMMAgent.logged_in_username -ne "None" -and $TRMMAgent.logged_in_username) {
            $username = $TRMMAgent.logged_in_username
        } elseif ($TRMMAgent.last_logged_in_user) {
            $username = $TRMMAgent.last_logged_in_user
        } else {
            $username = $false
            $CWMContact = $false
        }
        if ($username) {
            $CWMContacts | Where-Object { $_.company.id -eq $CWMCompany.id } | ForEach-Object {
                if ($_.lastName -and $_.firstName) {
                    $usernametest = $_.firstName.SubString(0) + $_.lastName
                    if ($username[1] -eq $usernametest) {
                        $CWMContact = $_
                        break
                    }
                    $usernametest = $_.firstName + $_.lastName.SubString(0)
                    if ($username[1] -eq $usernametest) {
                        $CWMContact = $_
                        break
                    }
                }
                foreach ($customfield in $_.customfields) {
                    if ($customfield.value -eq $username[1]) {
                        $CWMContact = $_
                        break
                    }
                }
            }
        }
        $CWMConfiguration = $CWMConfigurations | Where-Object { $_.company.id -eq $CWMCompany.id -and $_.name -eq $TRMMAgent.hostname }          
        if ($CWMConfiguration.count -gt 1) {
            Write-Output "Duplicates found for Asset $($TRMMAgent.clientName) - $($TRMMAgent.hostname) skipping updating asset, check your configs!"
        } elseif ($CWMConfiguration.count -eq 1) {
            [string]$disks = ""
            $TRMMAgent.disks | ForEach-Object {
                $disks = $disks + "$($_.device) - Total: $($_.total) / Used: $($_.used) ($($_.percent)%) - $($_.fstype)`n"
            }
            $assetbody = @{
                #id               = 
                activeFlag       = $true
                billFlag         = $true
                company          = @{
                    id = $CWMCompany.id
                }
                cpuSpeed         = $TRMMAgent.wmi_detail.cpu.name -split "," | Select-Object -First 1
                defaultGateway   = $TRMMAgent.public_ip
                deviceIdentifier = $TRMMAgent.agent_id
                ipAddress        = ($TRMMAgent.wmi_detail.network_config | Where-Object { $_.IPSubnet -and $_.DatabasePath -and $_.Caption -notmatch 'Zero' } | Sort-Object -Property Index).ipAddress | Where-Object { $_ -match '\.' -and $_ -notlike "% .1" } | Select-Object -First 1
                lastLoginName    = $username
                localHardDrives  = $disks
                macAddress       = ($TRMMAgent.wmi_detail.network_config | Where-Object { $_.IPSubnet -and $_.DatabasePath -and $_.Caption -notmatch 'Zero' } | Sort-Object -Property Index).MACAddress | Select-Object -First 1
                managementLink   = "https://rmm.$TRMMRootDomain/agents/$($TRMMAgent.agent_id)"
                #manufacturer    = ""
                modelNumber      = $TRMMAgent.wmi_detail.comp_sys.model
                name             = $TRMMAgent.hostname
                #notes            = ""
                osInfo           = $TRMMAgent.operating_system
                osType           = $TRMMAgent.plat
                ram              = "$($TRMMAgent.total_ram) GB"
                #remoteLink       = "https://mesh.$TRMMRootDomain/?viewmode=10&gotonode=$($TRMMAgent.mesh_node_id)" # Use this one for Mesh
                #remoteLink       = "https://$scsubdomain.screenconnect.com/Host#Access/All%20Machines%1F$($CWMCompany.name)//$(($TRMMAgent.customfields | Where-Object {$_.name -eq 'ScreenConnectGUID'}).string_value)/" # Use this one for ScreenConnect
                showAutomateFlag = $true
                showRemoteFlag   = $true
                #status           = ""
                type             = @{
                    name = $(if ($TRMMAgent.operating_system -match "Server") { "Managed Server" } else { "Managed Workstation" })
                }
            }
            if ($CWMContact) {
                $assetbody.contact = @{ id = $CWMContact.id }
            }
            if (!$CWMConfiguration) {
                $assetbody.site = @{ id = $CWMCompany.site }
                try {
                    Write-Output "Adding Asset $($TRMMAgent.clientName) - $($TRMMAgent.hostname)"
                    Invoke-RestMethod -uri "$APIurl/company/configurations" -Headers $CWMHeaders -ContentType "application/json" -Method POST -body $($assetbody | ConvertTo-JSON -depth 15) | Out-Null
                } catch {
                    Write-Output "Error creating $($TRMMAgent.clientName) - $($TRMMAgent.hostname)"
                }
            } elseif ($CWMConfiguration) {
                $updateItems = New-Object System.Collections.Generic.List[System.Object]
                $assetbody.GetEnumerator() | ForEach-Object {
                    $updateitems.add(@{
                            op    = 'replace'
                            path  = $($_.Key) 
                            value = $($_.Value)
                        })
                } 
            }
            if ($updateItems) {
                Write-Output "Updating $($assetbody.name)"
                try {
                    Invoke-RestMethod -uri "$APIurl/company/configurations/$($CWMConfiguration.id)" -Headers $CWMHeaders -ContentType "application/json" -Method PATCH -body $($updateItems | ConvertTo-JSON -depth 15 -AsArray) | Out-Null
                } catch {
                    Write-Output "Error updating $($TRMMAgent.clientName) - $($TRMMAgent.hostname)"
                    Write-Warning $Error[0]
                    Write-Output $assetbody
                }
            }
        }
    } else {
        Write-Output "No Company found for $($TRMMAgent.hostname) - $($TRMMAgent.agent_id)"
    }
}
$end = $(Get-Date)
[timespan]$elapsed = $end - $start
Write-Output "`nSync ended at $end took $($elapsed.minutes) minutes"
