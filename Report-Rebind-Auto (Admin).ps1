#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

# This script requires you to authenticate with a Power BI Admin account

param(          
    $oldDataSetId = "663ee438-1470-44a1-bc07-ce7c4b703760" # DataSet A   
    ,
    $newDataSetId =  "db12ea48-1bbd-4cb1-90bb-65897897a3a3" # Dataset B
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Connect-PowerBIServiceAccount

$workspaces  = Get-PowerBIWorkspace -Scope Organization -All -Include @("reports", "datasets")

$reportDataSetRelationship = $workspaces |%{
    $workspace = $_
    
    $workspace.reports |% {
        
        $report = $_

        Write-Output @{
            workspaceId = $workspace.id
            ;
            workspaceType = $workspace.type
            ;
            reportId = $report.id
            ;
            datasetId = $report.datasetId
        }   
    }    
} 

$oldDataSetRelatedReports = $reportDataSetRelationship |? datasetId -eq $oldDataSetId

if ($oldDataSetRelatedReports.Count -eq 0)
{
    Write-Warning "No reports connected to dataset '$oldDataSetId'"
}

foreach ($report in $oldDataSetRelatedReports)
{
    $reportId = $report.ReportId
    $workspaceId = $report.WorkspaceId
   
    $bodyStr = @{datasetId = $newDataSetId} | ConvertTo-Json

    # If is a personal workspace, workspaceid must be null on rebind

    if ($report.WorkspaceType -eq "PersonalGroup")
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

