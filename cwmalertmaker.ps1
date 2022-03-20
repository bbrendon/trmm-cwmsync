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
$TRMMUrl = "rmm.example.com"
$CWMMainLocationName = "My Company"

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
        }, @{
            SequenceNumber = 2
            Version        = "v2021.1"
            ResourceType   = "Configuration"
            ApiRequest     = @{
                Filters = @{
                    conditions = "company/id = $TRMMClientCWMCompID and name = `"$TRMMAgentName`""
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
$CWMConfiguration = $bundleresult[1].entities | Select-Object -Last 1
if ($CWMTicket.status.name -match 'Resolved') {
    Write-Output "Re-opening ticket for recurring alert"
    $body = @(
        @{
            op    = "replace"
            path  = "status"
            value = @{ Name = "New" }
        }
    )
    Invoke-RestMethod -uri "$APIurl/service/tickets/$($CWMTicket.id)" -Headers $CWMHeaders -ContentType "application/json" -Method PATCH -body $(ConvertTo-JSON -depth 15 $body) | Out-Null
}
if ($CWMTicket) {
    Write-Output "Adding new note for ongoing Alert"
    $notebody = @{
        #id                    = ""
        #ticketId              = ""
        text                  = "Alert re-occured at $TRMMAlertTime`nAgent was last seen at $TRMMAgentLastSeen`nhttps://$TRMMUrl/agents/$TRMMAgentID"
        detailDescriptionFlag = $true
        internalAnalysisFlag  = $false
        resolutionFlag        = $false
        #issueFlag             = ""
        #member                = ""
        #contact               = ""
        customerUpdatedFlag   = $true
        processNotifications  = $false
        #internalFlag          = ""
        #externalFlag          = ""
    }
    (Invoke-RestMethod -uri "$APIurl/service/tickets/$($CWMTicket.id)/notes" -Headers $CWMHeaders -ContentType "application/json" -Method POST -body $(ConvertTo-JSON -depth 15 $notebody)) | Out-Null
}
if (!$CWMTicket) {
    Write-Output "Creating new alert in CWM!"
    if ($TRMMAlertSeverity -match 'warning') { 
        $priority = "Priority 3 - Medium" 
    } elseif ($TRMMAlertSeverity -match 'error') { 
        $priority = "Priority 2 - High"
    } if ($TRMMAlertSeverity -match 'info') {
        $priority = "Priority 4 - Low" 
    } else {
        $priority = "SLA Exclusion"
    }
    $ticketbody = @{
        #id                   = ""
        summary              = $summary
        recordType           = "ServiceTicket"
        board                = @{ Name = "Alerts" }
        status               = @{ Name = "New" }
        #workRole             = @{ Name = "Technician" }
        #workType             = @{ Name = "Remote" }
        company              = @{ id = $TRMMClientCWMCompID }
        site                 = @{ id = $CWMConfiguration.site.id }
        #siteName                   = ""
        #addressLine1               = ""
        #addressLine2               = ""
        #city                       = ""
        #stateIdentifier            = ""
        #zip                        = ""
        #country                    = @{}
        contact              = @{ id = $CWMConfiguration.contact.id }
        #contactName                = ""
        #contactPhoneNumber         = ""
        #contactPhoneExtension      = ""
        #contactEmailAddress        = ""
        type                 = @{ Name = "Alert" }
        #subType                    = @{}
        #item                       = @{}
        team                 = @{ Name = "Service Team" }
        owner                = @{ id = $CWMMember.id }
        priority             = @{ Name = $priority }
        serviceLocation      = @{ Name = "Remote" }
        source               = @{ Name = "RMM" }
        #requiredDate               = ""
        #budgetHours                = ""
        #opportunity                = ""
        #agreement            = ""
        #severity                   = ""
        #impact                     = ""
        externalXRef         = "TRMM-Alert"
        #poNumber                   = ""
        #knowledgeBaseCategoryId    = ""
        #knowledgeBaseSubCategoryId = ""
        #allowAllClientsPortalView  = ""
        #customerUpdatedFlag        = ""
        #automaticEmailContactFlag  = ""
        #automaticEmailResourceFlag = ""
        #automaticEmailCcFlag       = ""
        #automaticEmailCc           = ""
        #initialDescription         = ""
        #initialInternalAnalysis    = ""
        #initialResolution          = ""
        #initialDescriptionFrom     = ""
        #contactEmailLookup         = ""
        processNotifications = $false
        #skipCallback               = ""
        #closedDate                 = ""
        #closedBy                   = ""
        #closedFlag                 = ""
        #actualHours                = ""
        #approved                   = ""
        #estimatedExpenseCost       = ""
        #estimatedExpenseRevenue    = ""
        #estimatedProductCost       = ""
        #estimatedProductRevenue    = ""
        #estimatedTimeCost          = ""
        #estimatedTimeRevenue       = ""
        #billingMethod              = ""
        #billingAmount              = ""
        #hourlyRate                 = ""
        #subBillingMethod           = ""
        #subBillingAmount           = ""
        #subDateAccepted            = ""
        #dateResolved         = ""
        #dateResplan          = ""
        #dateResponded        = 
        #resolveMinutes             = ""
        #resPlanMinutes             = ""
        #respondMinutes             = ""
        #isInSla                    = ""
        #knowledgeBaseLinkId        = ""
        #resources                  = ""
        #parentTicketId             = ""
        #hasChildTicket             = ""
        #hasMergedChildTicketFlag   = ""
        #knowledgeBaseLinkType      = ""
        #billTime             = "Billable"
        #billExpenses         = "Billable"
        #billProducts         = "Billable"
        #predecessorType            = ""
        #predecessorId              = ""
        #predecessorClosedFlag      = ""
        #lagDays                    = ""
        #lagNonworkingDaysFlag      = ""
        #estimatedStartDate         = ""
        #duration                   = ""
        location             = @{ Name = $CWMMainLocationName }
        #department                 = @{}
        #mobileGuid                 = ""
        #sla                        = @{}
        #slaStatus                  = ""
        #currency                   = @{}
        #mergedParentTicket         = @{}
        #integratorTags       = ""
        #_info                      = ""
    }
    $CWMTicket = (Invoke-RestMethod -uri "$APIurl/service/tickets" -Headers $CWMHeaders -ContentType "application/json" -Method POST -body $(ConvertTo-JSON -depth 15 $ticketbody))
    Write-Output "Adding note for details."
    $notebody = @{
        #id                    = ""
        #ticketId              = ""
        text                  = "Alert occured at $TRMMAlertTime`nAgent was last seen at $TRMMAgentLastSeen`nhttps://$TRMMUrl/agents/$TRMMAgentID"
        detailDescriptionFlag = $true
        internalAnalysisFlag  = $false
        resolutionFlag        = $false
        #issueFlag             = ""
        #member                = @{ id = $CWMMember.id }
        #contact               = @{ id = $($CWMContact).id }
        customerUpdatedFlag   = $false
        processNotifications  = $false
        #internalFlag          = ""
        #externalFlag          = ""
    }
        (Invoke-RestMethod -uri "$APIurl/service/tickets/$($CWMTicket.id)/notes" -Headers $CWMHeaders -ContentType "application/json" -Method POST -body $(ConvertTo-JSON -depth 15 $notebody)) | Out-Null
    if ($CWMConfiguration) {
        Write-Output "Configuration found attaching to ticket."
        $body = @{
            id = $CWMConfiguration.id
        }
        Invoke-RestMethod -uri "$APIurl/service/tickets/$($CWMTicket.id)/configurations" -Headers $CWMHeaders -ContentType "application/json" -Method POST -body $($body | ConvertTo-JSON -depth 15) | Out-Null
    }
}
