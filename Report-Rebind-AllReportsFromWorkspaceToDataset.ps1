#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(     
    $workspaces = @(      
        # Demo Pipelines - Sales Reports
        @{
            workspaceId = 'aafc842b-f6d8-4006-bbdc-0eb2130b3fa6'
            ; datasetId = 'e0f9d017-7e56-45ec-b39c-d09352a64828'
        }
        ,
        @{
            workspaceId = 'e1a86102-084c-4cb3-b4d8-addf75d38e6c'
            ; datasetId = 'efd01a85-b741-4205-b0d3-afe8beea9ce8'
        }
        ,
        @{
            workspaceId = '35314361-6641-4c5b-a6e6-91bb10c60ed0'
            ; datasetId = 'a94e51e4-e49a-4878-b223-ae3d8bd4b205'
        }
        ,
        # Demo Pipelines - Marketing Reports
        @{
            workspaceId = '54dd21eb-a543-461b-b947-03ff40db93fd'
            ; datasetId = 'e0f9d017-7e56-45ec-b39c-d09352a64828'
        }
        ,
        @{
            workspaceId = 'da58456c-45c7-418a-8e89-bbbb3c1618ac'
            ; datasetId = 'efd01a85-b741-4205-b0d3-afe8beea9ce8'
        }
        ,
        @{
            workspaceId = 'e6386d06-8368-49da-a796-e47fb8b23fd4'
            ; datasetId = 'a94e51e4-e49a-4878-b223-ae3d8bd4b205'
        }
    )
)


$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Connect-PowerBIServiceAccount

foreach($workspace in $workspaces)
{
    $workspaceId = $workspace.workspaceId
    $datasetId = $workspace.datasetId

    $reports = Get-PowerBIReport -WorkspaceId $workspaceId

    foreach ($report in $reports)
    {
    
        $reportId = $report.Id

        Write-Host "Rebinding report '$workspaceId/$reportId' to dataset '$datasetId'"

        $bodyStr = @{datasetId = $datasetId} | ConvertTo-Json

        Invoke-PowerBIRestMethod -url "groups/$workspaceId/reports/$reportId/Rebind" -method Post -body $bodyStr -ErrorAction Continue

    }
}
