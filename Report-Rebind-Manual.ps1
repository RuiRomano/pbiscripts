#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(           
    $reports = @(
         # {workspaceId}/{reportId} - get from the URL: https://app.powerbi.com/groups/8d820de8-53a6-4531-885d-20b27c85f413/reports/1c4595e4-b634-4f53-a963-df3a718f36ba            
        "8d820de8-53a6-4531-885d-20b27c85f413/1c4595e4-b634-4f53-a963-df3a718f36ba" # Test 1
        ,
        "8d820de8-53a6-4531-885d-20b27c85f413/daaf220c-3ed2-4cee-9c33-63a925bd15ac" # Test 2
    )
    #, $datasetId = "80ab741f-bcfe-44bb-8dd8-61505af01024" #DataSet B        
    ,$datasetId = "bfe8d5c8-a153-4695-b732-ab7db23580d3" #DataSet A
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
