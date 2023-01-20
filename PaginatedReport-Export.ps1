#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(          
    $workspaceId = "cdee92d2-3ff9-43e2-9f71-0916e888ad27"    
    ,
    $reportId = "041eca9c-f5ad-465f-8153-dc257d56c485"
    ,
    $format = "XLSX"
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)


Connect-PowerBIServiceAccount

$bodyStr = @{format=$format} | ConvertTo-Json

$result = Invoke-PowerBIRestMethod -url "groups/$workspaceId/reports/$reportId/ExportTo" -body $bodyStr -method Post

$status = $result | ConvertFrom-Json

while($status.status -in @("NotStarted", "Running"))
{   
    Write-Host "Sleeping..."

    Start-Sleep -Seconds 5    
    
    $result = Invoke-PowerBIRestMethod -url "groups/$workspaceId/reports/$reportId/exports/$($status.id)" -method Get
    
    $status = $result | ConvertFrom-Json

}

if ($status.status -eq "Succeeded")
{
    $result = Invoke-PowerBIRestMethod -url "groups/$workspaceId/reports/$reportId/exports/$($status.id)/file" -method Get -OutFile "$currentPath\output\export.$format"
}