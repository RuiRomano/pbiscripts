#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(           
    $reports = @(
         # {workspaceId}/{reportId} - get from the URL: https://app.powerbi.com/groups/8d820de8-53a6-4531-885d-20b27c85f413/reports/1c4595e4-b634-4f53-a963-df3a718f36ba            
        "aafc842b-f6d8-4006-bbdc-0eb2130b3fa6/f04b284a-fad2-4c53-8a8e-a19bae93f929" 
        ,
        "aafc842b-f6d8-4006-bbdc-0eb2130b3fa6/1333a143-37b9-40df-a798-a26e77619c03" 
    )
    , $datasetId = "e0f9d017-7e56-45ec-b39c-d09352a64828" 
)


$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Connect-PowerBIServiceAccount

$reports |% {

    $report = $_

    $workspaceId = Split-Path $_ -Parent
    $reportId = Split-Path $_ -Leaf

    Write-Host "Rebinding report '$workspaceId/$reportId' to dataset '$datasetId'"

    $bodyStr = @{datasetId = $datasetId} | ConvertTo-Json

    Invoke-PowerBIRestMethod -url "groups/$workspaceId/reports/$reportId/Rebind" -method Post -body $bodyStr -ErrorAction Continue

}
