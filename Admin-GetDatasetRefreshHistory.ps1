#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }

param (    
    $outputPath = ".\output\refreshhistory",
    $servicePrincipalId = "",
    $servicePrincipalSecret = "",
    $servicePrincipalTenantId = ""
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

try {
    $token = Get-PowerBIAccessToken    
}
catch {
    if ($servicePrincipalId)
    {
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipalId, ($servicePrincipalSecret | ConvertTo-SecureString -AsPlainText -Force)

        $pbiAccount = Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $servicePrincipalTenantId -Credential $credential
    }
    else {
        $pbiAccount = Connect-PowerBIServiceAccount
    }
}

New-Item -ItemType Directory -Path $outputPath -ErrorAction SilentlyContinue | Out-Null
    
# Find Token Object Id, by decoding OAUTH TOken - https://blog.kloud.com.au/2019/07/31/jwtdetails-powershell-module-for-decoding-jwt-access-tokens-with-readable-token-expiry-time/
$token = (Get-PowerBIAccessToken -AsString).Split(" ")[1]
$tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
while ($tokenPayload.Length % 4) { $tokenPayload += "=" }
$tokenPayload = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($tokenPayload)) | ConvertFrom-Json
# Service Principal
#$pbiUserIdentifier = $tokenPayload.oid
# PBI Account
$pbiUserIdentifier = $tokenPayload.upn

# Using the Admin API to get all workspaces with workspaces

$workspaces = Get-PowerBIWorkspace -Scope Organization -All -Include Datasets

Write-Host "Workspaces: $($workspaces.Count)"

$workspaces = $workspaces |? { $_.users |? { $_.identifier -ieq $pbiUserIdentifier } }

Write-Host "Workspaces where user is a member: $($workspaces.Count)"

# Only look at Active, V2 Workspaces and with Datasets

$workspaces = @($workspaces |? {$_.type -eq "Workspace" -and $_.state -eq "Active" -and $_.datasets.Count -gt 0})

if ($workspaceFilter -and $workspaceFilter.Count -gt 0)
{
    $workspaces = @($workspaces |? { $workspaceFilter -contains $_.Id})
}

Write-Host "Workspaces to get refresh history: $($workspaces.Count)"

$total = $Workspaces.Count
$item = 0

foreach($workspace in $Workspaces)
{          
    $item++
               
    Write-Host "Processing workspace: '$($workspace.Name)' $item/$total" 

    Write-Host "Datasets: $(@($workspace.datasets).Count)"

    $refreshableDatasets = @($workspace.datasets |? { $_.isRefreshable -eq $true -and $_.addRowsAPIEnabled -eq $false})

    Write-Host "Refreshable Datasets: $($refreshableDatasets.Count)"

    foreach($dataset in $refreshableDatasets)
    {
        try
        {
            Write-Host "Processing dataset: '$($dataset.name)'" 

            Write-Host "Getting refresh history"

            $dsRefreshHistory = Invoke-PowerBIRestMethod -Url "groups/$($workspace.id)/datasets/$($dataset.id)/refreshes" -Method Get | ConvertFrom-Json

            $dsRefreshHistory = $dsRefreshHistory.value               

            if ($dsRefreshHistory)
            {              
                $dsRefreshHistory = @($dsRefreshHistory | Select *, @{Name="dataSetId"; Expression={ $dataset.id.ToString() }}, @{Name="dataSet"; Expression={ $dataset.name }}`
                    ,@{Name="workspaceId"; Expression={ $workspace.id.ToString() }}, @{Name="workspace"; Expression={ $workspace.name }}, @{Name="configuredBy"; Expression={ $dataset.configuredBy }})

                $dsRefreshHistoryGlobal += $dsRefreshHistory
            }
        }
        catch
        {
            $ex = $_.Exception

            Write-Error -message "Error processing dataset: '$($ex.Message)'" -ErrorAction Continue

            # If its unauthorized no need to advance to other datasets in this workspace

            if ($ex.Message.Contains("Unauthorized") -or $ex.Message.Contains("(404) Not Found"))
            {
                Write-Host "Got unauthorized/notfound, skipping workspace"
            
                break
            
            }
        }
    }
}

if ($dsRefreshHistoryGlobal.Count -gt 0)
{        
    $outputFilePath = "$outputPath\$(("{0:yyyy}{0:MM}{0:dd}" -f [datetime]::Today)).json"

    ConvertTo-Json @($dsRefreshHistoryGlobal) -Compress -Depth 5 | Out-File $outputFilePath -force
}