#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $sourceWorkspaceId = "e2472ddb-f24f-4b25-ab4b-04537746819c"
    ,
    $targetWorkspaceName = "Test - Clone Workspace (Clone) 2"
    ,
    $reset = $false
)

$ErrorActionPreference = "Stop"

try { Get-PowerBIAccessToken | out-null } catch {  Connect-PowerBIServiceAccount }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$outputPath = "$currentPath\Output\WorkspaceClone"

if ($reset)
{
    Get-ChildItem -Path $outputPath -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse 
}

New-Item -ItemType Directory -Path $outputPath -Force -ErrorAction SilentlyContinue | Out-Null

$sourceWorkspace = Get-PowerBIWorkspace -Id $sourceWorkspaceId
$targetWorkspace = Get-PowerBIWorkspace -Name $targetWorkspaceName

if (!$targetWorkspace)
{
    Write-Host "Creating workspace '$targetWorkspaceName'"
    $targetWorkspace = New-PowerBIWorkspace -Name $targetWorkspaceName
}

#Export Reports

$sourceReports = Get-PowerBIReport -WorkspaceId $sourceWorkspaceId
$targetReports = Get-PowerBIReport -WorkspaceId $targetWorkspace.Id

$exportedDatasetIds = @{}
$exportedReportIds = @{}

foreach ($report in $sourceReports)
{
    Write-Host "Processing report '$($report.Name)'"

    $outputFilePath = "$outputPath\$($report.Name).pbix"

    if ($exportedDatasetIds[$report.DatasetId]) {
        Write-Host "Dataset $($report.DatasetId) already downloaded"
        continue
    }

    if (Test-Path $outputFilePath)
    {
        Write-Host "PBIX was already downloaded."
    }
    else {
        Invoke-PowerBIRestMethod -url "groups/$sourceWorkspaceId/reports/$($report.id)/export" -method Get -OutFile $outputFilePath   
    }          

    if (($targetReports |? { $_.name -eq $report.Name }))
    {
        Write-Host "PBIX was already imported to target workspace"
    }
    else
    {
        Write-Host "Importing PBIX to target workspace"
        $importResult = New-PowerBIReport -Path $outputFilePath -WorkspaceId $targetWorkspace.Id -Name $report.Name -ConflictAction CreateOrOverwrite         
    }

    $targetDataset = Get-PowerBIDataset -WorkspaceId $targetWorkspace.Id |? { $_.name -eq $report.Name } | Select -First 1
    $targetReport = Get-PowerBIReport -WorkspaceId $targetWorkspace.Id |? { $_.name -eq $report.Name } | Select -First 1

    $exportedDatasetIds[[string]$report.DatasetId] = [string]$targetDataset.Id
    $exportedReportIds[[string]$report.id] = [string]$targetReport.Id
}

# Cloning reports and rebing to existing dataset

$otherSourceReports = $sourceReports |? {!($exportedReportIds.Keys -contains $_.id)}

foreach($report in $otherSourceReports)
{
    Write-Host "Cloning report '$($report.Name)'"

    $targetReport = $targetReports |? { $_.name -eq $report.Name }

    if ($targetReport)
    {
        Write-Host "Report was already cloned"

        $exportedReportIds[[string]$report.id] = [string]$targetReport.Id
    }
    else {
        $body = @{name = $report.Name; targetWorkspaceId = $targetWorkspace.id; targetModelId = $exportedDatasetIds[$report.DatasetId]} | ConvertTo-Json

        $targetReport = Invoke-PowerBIRestMethod -Method Post -Url "groups/$sourceWorkspaceId/reports/$($report.id)/Clone" -Body $body | ConvertFrom-Json

        $exportedReportIds[[string]$report.id] = [string]$targetReport.Id
    }
}

#Cloning dashboards

$sourceDashboards = Get-PowerBIDashboard -WorkspaceId $sourceWorkspaceId
$targetDashhboards = Get-PowerBIDashboard -WorkspaceId $targetWorkspace.Id

foreach($dashboard in $sourceDashboards)
{    
    $targetDashboard = $targetDashhboards |? Name -eq $dashboard.Name

    if (!$targetDashboard)
    {
        Write-Host "Cloning dashboard '$($dashboard.Name)'"

        $targetDashboard = New-PowerBIDashboard -WorkspaceId $targetWorkspace.Id -Name $dashboard.Name
    }
    else {
        Write-Host "Dashboard already exists"
    }

    $dashboardTiles = Get-PowerBIDashboardTile -WorkspaceId $sourceWorkspaceId -DashboardId $dashboard.Id
    $targetDashboardTiles = Get-PowerBIDashboardTile -WorkspaceId $targetWorkspace.Id -DashboardId $targetDashboard.Id

    foreach($dashboardTile in $dashboardTiles)
    {
        if (($targetDashboardTiles |? { $_.Title -eq $dashboardTile.Title }))
        {
            Write-Host "Tile '$($dashboardTile.Title)' was already cloned"
        }
        else {
            Write-Host "Cloning tile '$($dashboardTile.Title)'"

            $body = @{targetDashboardId = $targetDashboard.Id; targetWorkspaceId = $targetWorkspace.id}

            if ($dashboardTile.ReportId){
                $body["TargetReportId"] = $exportedReportIds[$dashboardTile.ReportId]
            }

            if ($dashboardTile.DatasetId)
            {
                $body["TargetModelId"] = $exportedDatasetIds[$dashboardTile.DatasetId]
            }

            $bodyStr = $body | ConvertTo-Json 
    
            $dashboardTileClone = Invoke-PowerBIRestMethod -Method Post -Url "groups/$sourceWorkspaceId/dashboards/$($dashboard.id)/tiles/$($dashboardTile.Id)/Clone" -Body $bodyStr
        }
    }
}