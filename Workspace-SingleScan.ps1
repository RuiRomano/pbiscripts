#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }

param (    
    $workspaces = @("401927c5-2c16-4d48-85c9-21f1038c7862"),
    $getInfoDetails = "getArtifactUsers=true&lineage=true&datasourceDetails=true&datasetSchema=true&datasetExpressions=true",
    $outputPath = ".\output\workspacesinglescan"
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

$scansOutputPath = $outputPath 

New-Item -ItemType Directory -Path $scansOutputPath -ErrorAction SilentlyContinue | Out-Null

Connect-PowerBIServiceAccount
    
$bodyStr = @{"workspaces" = @($workspaces) } | ConvertTo-Json
    
# $script: scope to reference the outerscope variable

$workspacesScanRequests = @(Invoke-PowerBIRestMethod -Url "admin/workspaces/getInfo?$getInfoDetails" -Body $bodyStr -method Post | ConvertFrom-Json)

while(@($workspacesScanRequests |? status -in @("Running", "NotStarted")))
{
    Write-Host "Waiting for scan results, sleeping..."

    Start-Sleep -Seconds 5

    foreach ($workspaceScanRequest in $workspacesScanRequests)
    {            
        $scanStatus = Invoke-PowerBIRestMethod -Url "admin/workspaces/scanStatus/$($workspaceScanRequest.id)" -method Get | ConvertFrom-Json

        Write-Host "Scan '$($scanStatus.id)' : '$($scanStatus.status)'"

        $workspaceScanRequest.status = $scanStatus.status
    }
}

foreach ($workspaceScanRequest in $workspacesScanRequests)
{   
    $scanResult = Invoke-PowerBIRestMethod -Url "admin/workspaces/scanResult/$($workspaceScanRequest.id)" -method Get | ConvertFrom-Json

    Write-Host "Scan Result'$($scanStatus.id)' : '$($scanResult.workspaces.Count)'"
    
    $outputFilePath = ("$scansOutputPath\{0:yyyy}{0:MM}{0:dd}_$($workspaceScanRequest.id).json" -f [datetime]::Today)

    $scanResult | Add-Member –MemberType NoteProperty –Name "scanCreatedDateTime"  –Value $workspaceScanRequest.createdDateTime -Force

    ConvertTo-Json $scanResult -Depth 10 -Compress | Out-File $outputFilePath -force
}
