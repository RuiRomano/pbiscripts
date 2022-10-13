#Requires -Modules "MSAL.PS"

cls

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$clientId = ""
$tenantId = "common"
$authority = "https://login.microsoftonline.com/$tenantId"
$apiResource = "https://analysis.windows.net/powerbi/api"

$scopes = @("$apiResource/.default")

$app = New-MsalClientApplication -ClientId $clientId -Authority $authority -TenantId $tenantId

$oauthResult = $app | Get-MsalToken -Scopes $scopes 

$accessToken = $oauthResult.AccessToken

$headers = @{
	'Content-Type'= "application/json"
	'Authorization'= "Bearer $accessToken"
	}   

$response = Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/groups" -Headers $headers -Method Get

$response.value