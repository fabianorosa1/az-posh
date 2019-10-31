
<#PSScriptInfo

.VERSION 1.1

.GUID 4a8b763f-0f38-4b46-9e35-71d58f24d7d8

.AUTHOR vmehmeri

.TAGS PSEdition_Desktop, PSEdition_Core, Windows, Linux, MacOS

.PROJECTURI https://github.com/vmehmeri/az-posh

#>

<#

.DESCRIPTION
 Fetches a job stream from Azure Automation account, ignoring verbose log lines about importing or exporting cmdlets, 
 and outputs it on the screen and also write it to an output file.

#>
param(
    [Parameter(Mandatory = $true)]
    [string]
    $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]
    $AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [string]
    $RunbookNameStartsWith,

    [Parameter(Mandatory = $false)]
    [int32]
    $SkipJobs = 0

)


function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'

    if(-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."
    }

    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant " + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}

$header = @{
    Authorization = ('Bearer {0}' -f (Get-AzCachedAccessToken))
}

$JobURI = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName/jobs/" +"?api-version=2017-05-15-preview"

Write-Debug "Invoking GET $JobURI"
$response = Invoke-RestMethod -Uri $JobURI -Method GET -Headers $header

$jobId = ''

$count = 0
foreach ($result in $response.value) {
    $runbookName = $result.properties.runbook.name

    if ($runbookName -like ($RunbookNameStartsWith + "*")) {
        if($count -lt $SkipJobs) {
            $count += 1
            continue
        }
        $jobId = $result.properties.jobId
        break
    }
}

if (-not $jobId) {
    $next = $Response.nextLink
    Write-Information "Checking older jobs..."
    while($next) {
        $response = Invoke-RestMethod -Uri $next -Method GET -Headers $header
        $count = 0
        foreach ($result in $response.value) {
            $runbookName = $result.properties.runbook.name

            if ($runbookName -like ($RunbookNameStartsWith + "*")) {
                if($count -lt $SkipJobs) {
                    $count += 1
                    continue
                }
                $jobId = $result.properties.jobId
                break
            }
        }

        if ($jobId) {
            break
        }

        $next = $Response.nextLink
    }
}

if (-not  $jobId) {
    write-error "Could not find any job for runbook starting with $RunbookNameStartsWith"
    exit 1
}


$URI  = "https://management.azure.com/subscriptions/$SubscriptionId/"`
      +"resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/"`
      +"automationAccounts/$AutomationAccountName/jobs/$jobId/"`
      +"streams?$filter=properties/streamType%20eq%20'Verbose'&api-version=2015-10-31"

$response = Invoke-RestMethod -Uri $URI -Method GET -Headers $header

$TempOutputFile = New-TemporaryFile

$logLines = ($Response.value).properties.summary
foreach ($line in $logLines) {
    if (($line -notmatch "Importing") -and ($line -notmatch "Exporting") -and ($line -notmatch "Loading")) {
        $line
        $line >> $TempOutputFile
    }
}

$next = $Response.nextLink
while($next) {
    $response = Invoke-RestMethod -Uri $next -Method GET -Headers $header
    $nextLogLines = ($Response.value).properties.summary
    foreach ($line in $nextLogLines) {
        if (($line -notmatch "Importing") -and ($line -notmatch "Exporting") -and ($line -notmatch "Loading")) {
            $line
            $line >> $TempOutputFile
        }
    }
    $next = $Response.nextLink
 }

 write-output "Output written to $TempOutputFile"

