#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$datasetId = "33fc0a15-4be2-4f02-85fd-a3f2e9fdec8c"

Connect-PowerBIServiceAccount

$result = Invoke-PowerBIRestMethod -url "admin/datasets/$datasetId/users" -method Get | ConvertFrom-Json | Select -ExpandProperty value

$result