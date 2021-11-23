#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$workspaceId = "e25577b9-1f8e-4bb3-8fa7-73c35e067a06"
$datasetId = "5833cb8c-458a-4876-b1b0-ef3fe4c11e4e"

Connect-PowerBIServiceAccount

$result = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshes" -method Get | ConvertFrom-Json

Write-Host "Latest Refresh"

$result.value | Format-Table

$result = Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/refreshSchedule" -method Get | ConvertFrom-Json

Write-Host "Refresh Schedule"

$result | Out-String
