#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(            
    $oldDataSetId = "db12ea48-1bbd-4cb1-90bb-65897897a3a3" # Dataset B  
    ,
    $newDataSetId =  "663ee438-1470-44a1-bc07-ce7c4b703760" # DataSet A        
)

cls

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

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

