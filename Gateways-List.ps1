#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Connect-PowerBIServiceAccount

$result = Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json

$result.value | Out-String
