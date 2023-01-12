#Requires -Modules MicrosoftPowerBIMgmt

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$workspaceId = "9758f2b2-de31-433a-8ebd-197e4b754ed3"
$templateDatasetPath = "$currentPath\SampleSQLReport.pbix"
$datasetParams = @{"Server"=".\sql2019";"Database"="Contoso 1M";"TopN"="100000"}
$numberDatasets = 100
$gatewayName = "RRMSFT-GW"
$datasourceName = "localhost_sql20192"
$refreshDatasets = $false
$configureDatasets = $true
$scheduleRefreshConfig = @{
    "value" = @{
        "enabled" = "false"
        # ;
        # "days" = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
        # ;
        # "times" = @("17:30")
        # ;
        # "localTimeZoneId" = "UTC"
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

foreach($dsNumber in @(1..$numberDatasets))
{    
    $datasetName = "$fileName - $dsNumber"   

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

if ($configureDatasets)
{
    $scheduleRefreshConfigStr = ConvertTo-Json $scheduleRefreshConfig -Depth 10

    foreach($dataset in $datasets)
    {
        Write-Host "Set parameters for dataset '$($dataset.Id)'"

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

        Write-Host "Bind dataset '$($dataset.Id)' to Gateway"
        
        $bodyStr = @{gatewayObjectId = $datasource.gatewayId; datasourceObjectIds = @($datasource.id)} | ConvertTo-Json

        Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$($dataset.Id)/Default.BindToGateway" -Method Post -Body $bodyStr | Out-Null

        Write-Host "Schedule refresh config on dataset '$($dataset.Id)'"

        Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$($dataset.Id)/refreshSchedule" -Method Patch -Body $scheduleRefreshConfigStr | Out-Null    
    }
}

if ($refreshDatasets)
{
    foreach($dataset in $datasets)
    {
        Write-Host "Refresh dataset '$($dataset.Id)'"

        Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$($dataset.Id)/refreshes" -Method Post -Body $bodyStr | Out-Null
    }
}