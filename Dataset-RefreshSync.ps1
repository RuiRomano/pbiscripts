#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $workspaceId = "279de5c8-f502-43e7-8b65-5e9ebd6f9434"
    ,
    $datasetId = "faf7eff7-413e-49e1-ba98-b1daa03a52d9"
)

$executeJsonObj = @{
    "notifyOption" = "MailOnCompletion"    
}

$executeJsonBody = $executeJsonObj | ConvertTo-Json -Depth 5

Connect-PowerBIServiceAccount

Write-Host "Posting a new Refresh Command"

Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes" -method Post -Body $executeJsonBody

Write-Host "Waiting for refresh to end"

do
{
    $refreshes = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=1" -method Get | ConvertFrom-Json | select -ExpandProperty value

    Write-Host "sleeping..."

    Start-Sleep -Seconds 2

}

while($refreshes.status -iin @("Unknown", "inProgress", "notStarted"))

Write-Host "Refresh complete: $((([datetime]$refreshes.endTime) - ([datetime]$refreshes.startTime)).TotalSeconds)s"