#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }


$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

try {
    $token = Get-PowerBIAccessToken    
}
catch {
    $pbiAccount = Connect-PowerBIServiceAccount
}

$result = Invoke-PowerBIRestMethod -Url "admin/apps?`$top=1000" -Method Get | ConvertFrom-Json | select -ExpandProperty value

$result | Format-List