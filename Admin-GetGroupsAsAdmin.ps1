#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }

param (    
    $workspaces = @("cdee92d2-3ff9-43e2-9f71-0916e888ad27"),
    $expand="users,reports,dashboards,datasets,dataflows,workbooks",
    $outputPath = ".\output\getgroupsadmin"
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

New-Item -ItemType Directory -Path $outputPath  -ErrorAction SilentlyContinue | Out-Null

try {
    $token = Get-PowerBIAccessToken    
}
catch {
    $pbiAccount = Connect-PowerBIServiceAccount
}
    
foreach ($workspace in $workspaces)
{
    $apiUrl = "admin/groups/$workspace"

    if ($expand)
    {
        $apiUrl = $apiUrl + "?`$expand=$expand"
    }

    $workspacesScanRequests = Invoke-PowerBIRestMethod -Url $apiUrl -method Get | ConvertFrom-Json

    $outputFilePath = "$outputPath\$workspace.json"

    New-Item -Path (Split-Path $outputFilePath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    ConvertTo-Json $workspacesScanRequests -Depth 10 -Compress | Out-File $outputFilePath -force

}