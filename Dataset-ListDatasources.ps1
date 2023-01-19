#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(            
    $workspaceId = "cdee92d2-3ff9-43e2-9f71-0916e888ad27",
    $datasetId = "33fc0a15-4be2-4f02-85fd-a3f2e9fdec8c"
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

try { Get-PowerBIAccessToken | out-null } catch {  Connect-PowerBIServiceAccount }

Write-Host "Getting Gateways"

$gateways = Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json | Select -ExpandProperty value

$datasources = @(Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/datasources" -method Get | ConvertFrom-Json | Select -ExpandProperty value)

$datasources | Format-List

$gatewayId = $datasources | select -First 1 -ExpandProperty gatewayId

$gwDatasources = Invoke-PowerBIRestMethod -url "gateways/$gatewayId/datasources" -method Get | ConvertFrom-Json | Select -ExpandProperty value

$gwDatasources | Format-List
