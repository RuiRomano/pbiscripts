#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(          
    $workspaceId = "cdee92d2-3ff9-43e2-9f71-0916e888ad27"    
    ,
    $reportId = "d471e78e-2251-4085-9a60-678c0d4b5dfa"
    ,
    $format = "PDF"
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
    Write-Host "Export Successfull"
    
    $result = Invoke-PowerBIRestMethod -url "groups/$workspaceId/reports/$reportId/exports/$($status.id)/file" -method Get -OutFile "$currentPath\output\export_$($status.id).$format"
}