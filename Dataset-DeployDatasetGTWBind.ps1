#Requires -Modules MicrosoftPowerBIMgmt

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$workspaceId = "114ee10f-5e0c-4821-bd5f-058eb8e1f287"
$templateDatasetPath = "$currentPath\SampleFolderGTW.pbix"
$datasetParams = $null
#$datasetParams = @{"Server"=".\sql2019";"Database"="Contoso 1M";"TopN"="100000"}
$numberDatasets = 20
$gatewayName = "PBICATGTW1"
$datasourceName = "temp folder"
$refreshDatasets = $false
$configureDatasets = $true
$scheduleRefreshConfig = @{
    "value" = @{
        "enabled" = "true"
        ;
        "days" = @( "Friday")
        ;
        "times" = @("15:30")
        ;
        "localTimeZoneId" = "UTC"
    }
}

try {
    $token = Get-PowerBIAccessToken    
}
catch {
    Connect-PowerBIServiceAccount
}

$gateways = Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json | Select -ExpandProperty value

$gateway = $gateways |? name -eq $gatewayName

if (!$gateway)
{
    throw "Cannot find gateway '$gatewayName'"
}

$datasources = Invoke-PowerBIRestMethod -url "gateways/$($gateway.id)/datasources" -method Get  | ConvertFrom-Json | Select -ExpandProperty value

$datasource = $datasources |? datasourceName -eq $datasourceName

if (!$datasource)
{
    throw "Cannot find datasource '$datasourceName'"
}

$fileName = [System.IO.Path]::GetFileNameWithoutExtension($templateDatasetPath)

$datasets = Get-PowerBIDataset -WorkspaceId $workspaceId

$deployedDatasetNames = @()

foreach($dsNumber in @(1..$numberDatasets))
{    
    $datasetName = "$fileName - $("{0:000}" -f $dsNumber)"   

    $deployedDatasetNames += $datasetName

    if (@($datasets |? Name -eq $datasetName))
    {
        Write-Host "Dataset '$datasetName' already exists"
    }
    else
    {
        Write-Host "Deploying dataset '$datasetName'"
        $importResult = New-PowerBIReport -Path $templateDatasetPath -WorkspaceId $workspaceId -Name $datasetName -ConflictAction CreateOrOverwrite 
    }

}

# Refresh with new deployed datasets

$datasets = Get-PowerBIDataset -WorkspaceId $workspaceId

$datasets = $datasets |? {
    $deployedDatasetNames -contains $_.name    
}

Write-Host "Processing $($datasets.count) datasets"

if ($configureDatasets)
{
    $scheduleRefreshConfigStr = ConvertTo-Json $scheduleRefreshConfig -Depth 10

    foreach($dataset in $datasets)
    {
        Write-host "Configuring dataset '$($dataset.Name)'"

        if ($datasetParams || $datasetParams.Keys.Count -gt 0)
        {
            Write-Host "Set parameters for dataset"

            $parametersBody = @{updateDetails=@($datasetParams.Keys) |% { 
                    @{
                        "name" = $_
                        ;
                        "newValue" = $datasetParams[$_]
                    }
                }
            }

            $parametersBodyStr = ConvertTo-Json $parametersBody -Depth 10

            Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$($dataset.id)/UpdateParameters" -Body $parametersBodyStr -Method Post | Out-Null
        }

        Write-Host "Bind dataset to Gateway"
        
        $bodyStr = @{gatewayObjectId = $datasource.gatewayId; datasourceObjectIds = @($datasource.id)} | ConvertTo-Json

        Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$($dataset.Id)/Default.BindToGateway" -Method Post -Body $bodyStr | Out-Null

        Write-Host "Schedule refresh config on dataset"

        Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$($dataset.Id)/refreshSchedule" -Method Patch -Body $scheduleRefreshConfigStr | Out-Null    
    }
}

if ($refreshDatasets)
{
    foreach($dataset in $datasets)
    {
        Write-Host "Refresh dataset '$($dataset.Name)'"

        Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$($dataset.Id)/refreshes" -Method Post -Body "" | Out-Null
    }
}