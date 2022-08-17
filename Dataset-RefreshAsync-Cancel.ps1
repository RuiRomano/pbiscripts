#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $workspaceId = "cdee92d2-3ff9-43e2-9f71-0916e888ad27"
    ,
    $datasetId = "ff63139f-eea9-4296-a5e4-3f56c0005701" 
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Connect-PowerBIServiceAccount

# Get running refreshes, only 1 operation is allowed "Only one refresh operation at a time is accepted for a dataset. If there's a current running refresh operation and another is submitted"

Write-Host "Get Runnning Refreshes"

$refreshes = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=5" -method Get | ConvertFrom-Json | select -ExpandProperty value

$refreshes = @($refreshes |? { $_.extendedStatus -in @("Unknown", "inProgress", "notStarted") })

Write-Host "Canceling '$($refreshes.Count)' refreshes"

foreach($refresh in $refreshes)
{
    $refreshId = $refresh.requestId

    do
    {
        Write-Host "Cancelling..."

        Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes/$refreshId" -method Delete | ConvertFrom-Json

        $refreshDetails = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes/$refreshId" -method Get | ConvertFrom-Json

        Write-Host "Status: $($refreshDetails.status)"

        Write-Host "sleeping..."

        Start-Sleep -Seconds 2

    }
    while($refreshDetails.extendedStatus -iin @("notStarted", "Unknown", "inProgress"))

}