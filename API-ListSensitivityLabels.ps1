#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }

param (    
    $graphUrl = "https://graph.microsoft.com/beta",
    $apiResource = "https://graph.microsoft.com",
    $servicePrincipalId = "",
    $servicePrincipalSecret = "",
    $servicePrincipalTenantId = ""
    
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

function Get-AuthToken {
    [cmdletbinding()]
    param
    (
        [string]
        $authority = "https://login.microsoftonline.com",
        [string]
        $tenantid,
        [string]
        $appid,
        [string]
        $appsecret ,
        [string]
        $resource         
    )

    write-verbose "getting authentication token"
    
    $granttype = "client_credentials"    

    $tokenuri = "$authority/$tenantid/oauth2/token?api-version=1.0"

    $appsecret = [System.Web.HttpUtility]::urlencode($appsecret)

    $body = "grant_type=$granttype&client_id=$appid&resource=$resource&client_secret=$appsecret"    

    $token = invoke-restmethod -method post -uri $tokenuri -body $body

    $accesstoken = $token.access_token    

    write-output $accesstoken

}

function Read-FromGraphAPI {
    [CmdletBinding()]
    param
    (
        [string]
        $url,
        [string]
        $accessToken,
        [string]
        $format = "JSON"     
    )

    #https://blogs.msdn.microsoft.com/exchangedev/2017/04/07/throttling-coming-to-outlook-api-and-microsoft-graph/

    try {
        $headers = @{
            'Content-Type'  = "application/json"
            'Authorization' = "Bearer $accessToken"
        }    

        $result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers

        if ($format -eq "CSV") {
            ConvertFrom-CSV -InputObject $result | Write-Output
        }
        else {
            Write-Output $result.value            

            while ($result.'@odata.nextLink') {            
                $result = Invoke-RestMethod -Method Get -Uri $result.'@odata.nextLink' -Headers $headers

                Write-Output $result.value
            }
        }

    }
    catch [System.Net.WebException] {
        $ex = $_.Exception

        try {                
            $statusCode = $ex.Response.StatusCode

            if ($statusCode -eq 429) {              
                $message = "429 Throthling Error - Sleeping..."

                Write-Host $message

                Start-Sleep -Seconds 1000
            }              
            else {
                if ($ex.Response -ne $null) {
                    $statusCode = $ex.Response.StatusCode

                    $stream = $ex.Response.GetResponseStream()

                    $reader = New-Object System.IO.StreamReader($stream)

                    $reader.BaseStream.Position = 0

                    $reader.DiscardBufferedData()

                    $errorContent = $reader.ReadToEnd()
                
                    $message = "$($ex.Message) - '$errorContent'"
                      				
                }
                else {
                    $message = "$($ex.Message) - 'Empty'"
                }               
            }    

            Write-Error -Exception $ex -Message $message        
        }
        finally {
            if ($reader) { $reader.Dispose() }
            
            if ($stream) { $stream.Dispose() }
        }       		
    }
}

$authToken = Get-AuthToken -resource $apiResource -appid $servicePrincipalId -appsecret $servicePrincipalSecret -tenantid $servicePrincipalTenantId

$data = Read-FromGraphAPI -accessToken $authToken -url "$graphUrl/security/informationProtection/sensitivityLabels" | select * -ExcludeProperty "@odata.id"

$data | Format-Table