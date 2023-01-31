#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }

param (    
    $workspaces = @("401927c5-2c16-4d48-85c9-21f1038c7862"),
    $servicePrincipalId = "",
    $servicePrincipalSecret = "",
    $servicePrincipalTenantId = ""
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

try {
    $token = Get-PowerBIAccessToken    
}
catch {
    if ($servicePrincipalId)
    {
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipalId, ($servicePrincipalSecret | ConvertTo-SecureString -AsPlainText -Force)

        $pbiAccount = Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $servicePrincipalTenantId -Credential $credential
    }
    else {
        $pbiAccount = Connect-PowerBIServiceAccount
    }
}

foreach($workspace in $workspaces)
{
    Write-Host "Calling UserAPIs for workspace: $workspace"

    Write-Host "Workspace"

    Invoke-PowerBIRestMethod -Url "groups?`$filter=contains(id,'$workspace')" -method Get | ConvertFrom-Json | select -ExpandProperty value | Format-List

    Write-Host "Datasets"

    Invoke-PowerBIRestMethod -Url "groups/$workspace/datasets" -method Get | ConvertFrom-Json | select -ExpandProperty value | Format-List 

    Write-Host "Reports"

    Invoke-PowerBIRestMethod -Url "groups/$workspace/reports" -method Get | ConvertFrom-Json | select -ExpandProperty value | Format-List 

    Write-Host "Dashboards"

    Invoke-PowerBIRestMethod -Url "groups/$workspace/dashboards" -method Get | ConvertFrom-Json | select -ExpandProperty value | Format-List 

    Write-Host "Dataflows"

    Invoke-PowerBIRestMethod -Url "groups/$workspace/dataflows" -method Get | ConvertFrom-Json | select -ExpandProperty value | Format-List 
}
