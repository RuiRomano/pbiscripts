#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $workspaceId = "7331d174-e08f-4802-acba-898b8cecbc75"
    ,
    $datasetId = "ae14bdd8-d5da-4908-a566-917db2c275e9"
    ,
    $type = "full"
    ,
    $maxParallelism = 3
    ,
    $commitMode = "transactional"    
    #$commitMode = "partialBatch"
    ,
    $retryCount = 5
    ,
    $objects = @(
       
    )
    
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$executeJsonObj = @{
    "type" = $type
    ;
    "commitMode" = $commitMode
    ;
    "maxParallelism" = $maxParallelism
    ;
    "retryCount" = $retryCount
    ;
    "objects" = $objects
}

$executeJsonBody = $executeJsonObj | ConvertTo-Json -Depth 5

Connect-PowerBIServiceAccount

# Get running refreshes, only 1 operation is allowed "Only one refresh operation at a time is accepted for a dataset. If there's a current running refresh operation and another is submitted"

$refreshes = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=10" -method Get | ConvertFrom-Json | select -ExpandProperty value

if (!($refreshes |? { $_.refreshType -eq "ViaEnhancedApi" -and $_.status -iin @("Unknown", "inProgress", "notStarted") }))
{
    Write-Host "Posting a new Refresh Command"

    Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes" -method Post -Body $executeJsonBody
}

Write-Host "Waiting for refresh to end"

$refreshes = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=10" -method Get | ConvertFrom-Json | select -ExpandProperty value

$refreshId = $refreshes[0].requestId

do
{
    $refreshDetails = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes/$refreshId" -method Get | ConvertFrom-Json

    Write-Host "Status: $($refreshDetails.status)"
    Write-Host ($refreshDetails.objects | format-table | out-string)
    Write-Host "sleeping..."

    Start-Sleep -Seconds 2

}
while($refreshDetails.status -iin @("Unknown", "inProgress", "notStarted"))

Write-Host "Refresh complete: $((([datetime]$refreshDetails.endTime) - ([datetime]$refreshDetails.startTime)).TotalSeconds)s"

$refreshDetails | Format-Table

$refreshDetails.objects | Format-Table