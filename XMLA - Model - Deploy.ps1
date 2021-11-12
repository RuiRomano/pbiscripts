param (
$serverName = "powerbi://api.powerbi.com/v1.0/myorg/Session%20-%20PBI%20on%20Steroids"
, $databaseName = "WWI - Sales (Partitioned)"
, $bimFilePath = ".\SampleModel.bim"
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

Import-Module "$currentPath\Modules\ASTabularHelper" -Force

Update-ASDatabase -serverName $serverName -databaseName $databaseName -bimFilePath $bimFilePath -deployPartitions:$true -deployRoles:$false -deployConnections:$false
                        


