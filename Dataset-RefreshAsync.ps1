#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $workspaceId = "cdee92d2-3ff9-43e2-9f71-0916e888ad27"
    ,
    $datasetId = "ff63139f-eea9-4296-a5e4-3f56c0005701"
    ,
    $type = "full"
    ,
    $maxParallelism = 6
    ,
    $commitMode = "transactional"
    ,
    $retryCount = 0
    ,
    $objects = @(
        @{
            "table" = "Product"           
        }    
        ,
        @{
            "table" = "Sales"
            ;
            "partition" = "Sales_2018"
        }
        ,
        @{
            "table" = "Sales"
            ;
            "partition" = "Sales_2019"
        } 
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

# Get running refreshes, only 1 operation is allowed

$refreshes = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=10" -method Get | ConvertFrom-Json | select -ExpandProperty value

if (!($refreshes |? { $_.refreshType -eq "ReliableProcessing" -and $_.status -iin @("Unknown", "inProgress", "notStarted") }))
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
    Write-Host "sleeping..."

    Start-Sleep -Seconds 2

}
while($refreshDetails.status -iin @("Unknown", "inProgress", "notStarted"))

Write-Host "Refresh complete: $((([datetime]$refreshDetails.endTime) - ([datetime]$refreshDetails.startTime)).TotalSeconds)s"