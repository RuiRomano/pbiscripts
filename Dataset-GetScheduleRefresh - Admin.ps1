#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Connect-PowerBIServiceAccount

$result = Invoke-PowerBIRestMethod -url "admin/capacities/refreshables" -method Get | ConvertFrom-Json | select -ExpandProperty value

$result | Format-Table