#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(           
    $reports = @(
         # {workspaceId}/{reportId} - get from the URL: https://app.powerbi.com/groups/8d820de8-53a6-4531-885d-20b27c85f413/reports/1c4595e4-b634-4f53-a963-df3a718f36ba            
        "632f348f-5828-45b0-8669-2a64d2bf30bc/e5b064b2-116f-4b5a-b48e-b0dbc5b34fe1" # Test 1
        ,
        "632f348f-5828-45b0-8669-2a64d2bf30bc/392e566c-efef-43f7-bf95-c11b169b466d" # Test 2
    )
    , $datasetId = "db12ea48-1bbd-4cb1-90bb-65897897a3a3" #DataSet B        
    #,$datasetId = "663ee438-1470-44a1-bc07-ce7c4b703760" #DataSet A
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
