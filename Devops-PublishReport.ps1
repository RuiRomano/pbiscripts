#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(           
    [string]$path = ".\SampleReport - Live.pbix",
    [string]$workspaceId = "00fad993-e80b-45b1-9376-0a1e637cafa9",
    [string]$datasetId,
    [bool]$handleReportDuplication = $true
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

Connect-PowerBIServiceAccount

$reports = Get-ChildItem -File -Path $path -ErrorAction SilentlyContinue

foreach($pbixFile in $reports)
{
    Write-Host "Deploying report: '$($pbixFile.Name)'"

    $filePath = $pbixFile.FullName

    $reportName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)    

    $targetReport = @(Get-PowerBIReport -WorkspaceId $workspaceId -Name $reportName)

    if ($targetReport.Count -eq 0 -or !$handleReportDuplication)
    {
        Write-Host "Uploading new report to workspace '$workspaceId'"
        
        $importResult = New-PowerBIReport -Path $filePath -WorkspaceId $workspaceId -Name $reportName -ConflictAction CreateOrOverwrite 
        
        $targetReportId = $importResult.Id
    }
    elseif ($handleReportDuplication)
    {    
        if ($targetReport.Count -gt 1)
        {
            throw "More than one report with name '$reportName', please remove and keep only one"
        }

        Write-Host "Report already exists on workspace '$workspaceId', uploading to temp report & updatereportcontent"

        $targetReport = $targetReport[0]

        $targetReportId = $targetReport.id

        # Upload a temp report and update the report content of the target report

        # README - This is required because of a limitation of Import API that always duplicate the report if the dataset is different (may be solved in the future)

        $tempReportName = "Temp_$([System.Guid]::NewGuid().ToString("N"))"

        Write-Host "Uploadind as a temp report '$tempReportName'"
    
        $importResult = New-PowerBIReport -Path $filePath -WorkspaceId $workspaceId -Name $tempReportName -ConflictAction Abort
    
        $tempReportId = $importResult.Id

        Write-Host "Updating report content"
    
        $updateContentResult = Invoke-PowerBIRestMethod -method Post -Url "groups/$workspaceId/reports/$targetReportId/UpdateReportContent" -Body (@{
            sourceType = "ExistingReport"
            sourceReport = @{
            sourceReportId = $tempReportId
            sourceWorkspaceId = $workspaceId
            }
        } | ConvertTo-Json)

        # Delete the temp report

        Write-Host "Deleting temp report '$tempReportId'"
            
        Invoke-PowerBIRestMethod -Method Delete -Url "groups/$workspaceId/reports/$tempReportId"
    }
    
    if ($targetReportId -and $dataSetId)
    {
        Write-Host "Rebinding to dataset '$dataSetId'"
        
        Invoke-PowerBIRestMethod -Method Post -Url "groups/$workspaceId/reports/$targetReportId/Rebind" -Body "{datasetId: '$dataSetId'}" | Out-Null
    }   
    
}