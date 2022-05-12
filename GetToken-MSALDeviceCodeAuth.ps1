#Requires -Modules "MSAL.PS"

cls

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$clientId = ""
$authority = "https://login.microsoftonline.com/common"
$apiResource = "https://analysis.windows.net/powerbi/api"

$scopes = @("$apiResource/.default")

$app = New-MsalClientApplication -ClientId $clientId -Authority $authority

# Warning - Dont work with PowerShell 7, must use powershell5

Enable-MsalTokenCacheOnDisk $app

Write-Host "Cache file: $([TokenCacheHelper]::CacheFilePath)"

try {
	$token = $app | Get-MsalToken -Scopes $scopes -Silent	
}
catch {
	Write-Host "Getting token"

    $token = $app | Get-MsalToken -Scopes $scopes -DeviceCode -Silent
}

$headers = @{
	'Content-Type'= "application/json"
	'Authorization'= "Bearer $($token.AccessToken)"
	}   

$response = Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/admin/apps?`$top=100" -Headers $headers -Method Get -ContentType $contentType

$response.value