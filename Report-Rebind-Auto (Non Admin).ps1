#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(        
    # {workspace Id}/{Dataset Id}
    $oldDataSet =  "8d820de8-53a6-4531-885d-20b27c85f413/80ab741f-bcfe-44bb-8dd8-61505af01024" # Dataset B   
    ,
    $newDataSet =  "8d820de8-53a6-4531-885d-20b27c85f413/bfe8d5c8-a153-4695-b732-ab7db23580d3" # DataSet A      
)

cls

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$oldWorkspaceId = (Split-Path $oldDataSet -Parent)
$oldDataSetId = (Split-Path $oldDataSet -Leaf)

$newWorkspaceId = (Split-Path $newDataSet -Parent)
$newDataSetId = (Split-Path $newDataSet -Leaf)

if (!$newWorkspaceId -or !$newDataSetId)
{
    throw "Cannot solve New DataSet Id's"
}

if (!$oldWorkspaceId -or !$oldDataSetId)
{
    throw "Cannot solve Old DataSet Id's"
}

$relatedContentPath = "$currentPath\relatedcontent.json"

if (!(Test-Path $relatedContentPath))
{
    Write-Warning "Execute a DataLineage on the dataset '$oldDataSetId' with a browser network trace and save the request 'datalineage/impactAnalysis/models/*/relatedcontent' to local file '$relatedContentPath'"
    return
}

$relatedContent = Get-Content $relatedContentPath | ConvertFrom-Json

if (!$relatedContent.RelatedReports -or $relatedContent.RelatedReports.Count -eq 0)
{
    Write-Warning "No reports to related to dataset '$oldDataSetId'"
    return
}

Connect-PowerBIServiceAccount

foreach ($report in $relatedContent.RelatedReports)
{
    $reportId = $report.ReportObjectId
    $workspaceId = $report.workspaceObjectId
   
    $bodyStr = @{datasetId = $newDataSetId} | ConvertTo-Json

    # If is a personal workspace, workspaceid must be null on rebind

    if ($report.WorkspaceType -eq 3)
    {
        $workspaceId = $null
    }

    Write-Host "Rebinding report '$workspaceId/$reportId' to new dataset '$newDataSetId'"
    
    if ($workspaceId)
    {
        $apiUrl = "groups/$workspaceId/reports/$reportId/Rebind"       
    }
    else
    {
        $apiUrl = "reports/$reportId/Rebind"       
    }

    Invoke-PowerBIRestMethod -Url $apiUrl -method Post -body $bodyStr -ErrorAction Continue
}

