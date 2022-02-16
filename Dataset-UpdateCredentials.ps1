#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$workspaceId = "9f19cb45-1182-4656-82b0-e7a049985835"
$datasetId = "d688fbb7-01ba-4a8c-a9b6-5d1e262bb347"
$username = "sqluser"
$password = "sqluserpwd"

Connect-PowerBIServiceAccount

$datasources = @(Invoke-PowerBIRestMethod -url "groups/$workspaceId/datasets/$datasetId/datasources" -method Get | ConvertFrom-Json | Select -ExpandProperty value)

$datasource = $datasources[0]

$updateDatasourceBodyStr = "{
  ""credentialDetails"": {
    ""credentials"": ""{\""credentialData\"":[{\""name\"":\""username\"",\""value\"":\""$username\""},{\""name\"":\""password\"",\""value\"":\""$password\""}]}"",
    ""credentialType"": ""Basic"",
    ""encryptedConnection"": ""NotEncrypted"",
    ""encryptionAlgorithm"": ""None"",
    ""privacyLevel"": ""None"",
    ""useCallerAADIdentity"": false
  }
}
"

Invoke-PowerBIRestMethod -url "gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" -method Patch -Body $updateDatasourceBodyStr
