#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" } -Assembly System.IO.Compression

<# 
WARNING - This script will change the internal files of your PBIX files. A backup will be made but its not supported by Microsoft. 
#>

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$reportsPath = "C:\Users\ruiromano\OneDrive - Microsoft\Work\202110\MMeyersSamples\Reports\Sales*"
$datasetId = "80cc1541-7ba7-4a52-b7f2-496f58389975"
$workingDir = "$currentPath\_temp\fixconnections"
$backupdir = "$currentPath\_temp\fixconnections\bkup"
$sharedDatasetsPath = "$currentPath\shareddatasets.json"

if (!(Test-Path $sharedDatasetsPath))
{
    Write-Warning "Cannot find shareddatasets file '$sharedDatasetsPath'. Login to app.powerbi.com and execute a networktrace and save the 'sharedatasets' request to file: '$sharedDatasetsPath'."
    return
}

# Ensure folders exists
@($workingDir, $backupDir) |% { New-Item -ItemType Directory -Path $_ -Force -ErrorAction SilentlyContinue | Out-Null }

$reports = Get-ChildItem -File -Path "$reportsPath" -Include "*.pbix" -Recurse -ErrorAction SilentlyContinue

if ($reports.Count -eq 0)
{
    Write-Host "No reports on path '$reportsPath'"
    return
}

# Connect to PBI

Connect-PowerBIServiceAccount

$sharedDataSetsStr = Get-Content $sharedDatasetsPath
#ConverFrom-Json doesnt like properties with same name
$sharedDataSetsStr = $sharedDataSetsStr.Replace("nextRefreshTime","nextRefreshTime_").Replace("lastRefreshTime","lastRefreshTime_")
$sharedDataSets = $sharedDataSetsStr | ConvertFrom-Json

$reports |% {

    $pbixFile = $_

    Write-Host "Fixing connection of report: '$($pbixFile.Name)'"

    $filePath = $pbixFile.FullName

    $fileName = [System.IO.Path]::GetFileName($pbixFile.FullName)

    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

    Write-Host "Finding dataset model id of dataset '$dataSetId'"

    # Find model for the dataset

    $model = $sharedDataSets |? { $_.model.dbName -eq $dataSetId }

    if (!$model)    
    {
        Write-Host "Cannot find a Power BI model for dataset '$dataSetId'"
    }
    else
    {
        $modelId = $model.modelId

        Write-Host "Found Power BI model '$modelId' for '$dataSetId'"

        Write-Host "Backup '$fileName' into '$backupDir'"

        Copy-Item -Path $filePath -Destination  "$backupDir\$fileNameWithoutExt.$(Get-Date -Format "yyyyMMddHHmmss").pbix" -Force

        $zipFile = "$workingDir\$fileName.zip"

        $zipFolder = "$workingDir\$fileNameWithoutExt"

        Write-Host "Unziping '$fileName' into $zipFolder"

        Copy-Item -Path $filePath -Destination $zipFile -Force
    
        Expand-Archive -Path $zipFile -DestinationPath $zipFolder -Force | Out-Null

        $connectionsJson = Get-Content "$zipFolder\Connections"  | ConvertFrom-Json

        $connection = $connectionsJson.Connections[0]

        $remoteArtifactId = $null

        if($connectionsJson.RemoteArtifacts -and $connectionsJson.RemoteArtifacts.Count -ne 0)
        {
            $remoteArtifactId = $connectionsJson.RemoteArtifacts[0].DatasetId             
        }

        if ($connection.PbiModelDatabaseName -eq $dataSetId -and $remoteArtifactId -eq $dataSetId)
        {
            Write-Warning "PBIX '$fileName' already connects to dataset '$dataSetId' skipping the rebind"
            return
        }
    
        $connection.PbiServiceModelId = $modelId
        $connection.ConnectionString = $connection.ConnectionString.Replace($connection.PbiModelDatabaseName, $dataSetId)
        $connection.PbiModelDatabaseName = $dataSetId

        if ($remoteArtifactId)
        {
            $connectionsJson.RemoteArtifacts[0].DatasetId = $dataSetId
        }        

        $connectionsJson | ConvertTo-Json -Compress | Out-File "$zipFolder\Connections" -Encoding ASCII 

        # Update the connections on zip file

        Write-Host "Updating connections file on zip file"

        Compress-Archive -Path "$zipFolder\Connections" -CompressionLevel Optimal -DestinationPath $zipFile -Update

        # Remove SecurityBindings

        Write-Host "Removing SecurityBindings"

        try{
            $stream = new-object IO.FileStream($zipfile, [IO.FileMode]::Open)
            $zipArchive = new-object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Update)
            $securityBindingsFile = $zipArchive.Entries |? Name -eq "SecurityBindings" | Select -First 1
        
            if ($securityBindingsFile)
            {
                $securityBindingsFile.Delete()
            }
            else
            {
                Write-Host "Cannot find SecurityBindings on zip"
            }
        
        }
        finally{
            if ($zipArchive) { $zipArchive.Dispose() }
            if ($stream) { $stream.Dispose() } 
        }

        Write-Host "Overwriting original pbix"

        Copy-Item -Path $zipfile -Destination $filePath -Force

    }
}

