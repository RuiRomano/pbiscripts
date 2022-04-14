#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(            
    $gatewayId = "0380ed77-237f-42ec-8f1a-05f2c6cd4a33",
    $server = "sqlserver",
    $database = "database",
    $username = "username",
    $password = "password"      
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

# Install the Power BI package into the current working directory if it's not already installed
if (!(Test-Path "$currentPath\Nuget\Microsoft.PowerBI.Api.3.18.1" -PathType Container)) {
    Install-Package -Name Microsoft.PowerBi.Api -ProviderName NuGet -Scope CurrentUser -RequiredVersion 3.18.1 -SkipDependencies -Destination "$currentPath\Nuget" -Force
}

if ($PSVersionTable.PSVersion.Major -le 5) {
    $pbipath = Resolve-Path "$currentPath\Nuget\Microsoft.PowerBI.Api.3.18.1\lib\net48\Microsoft.PowerBI.Api.dll"
}
else {
    $pbipath = Resolve-Path "$currentPath\Nuget\Microsoft.PowerBI.Api.3.18.1\lib\netstandard2.0\Microsoft.PowerBI.Api.dll"
}

[System.Reflection.Assembly]::LoadFrom($pbipath)

Connect-PowerBIServiceAccount

$gateways = Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json | Select -ExpandProperty value

$gateway = $gateways |? { $_.id -eq $gatewayId }

if (!$gateway)
{
    throw "Cannot find gateway '$gatewayId'"
}
else {

    $gatewayKeyObj = [Microsoft.PowerBI.Api.Models.GatewayPublicKey]::new($gateway.publicKey.exponent, $gateway.publicKey.modulus)
    $basicCreds = [Microsoft.PowerBI.Api.Models.Credentials.BasicCredentials]::new($username, $password)
    $credentialsEncryptor = [Microsoft.PowerBI.Api.Extensions.AsymmetricKeyEncryptor]::new($gatewayKeyObj)
    
    # Construct the CredentialDetails object. The resulting "Credentials" property on this object will have been encrypted appropriately, ready for use in the request payload.
    $credentialDetails = [Microsoft.PowerBI.Api.Models.CredentialDetails]::new(
        $basicCreds, 
        [Microsoft.PowerBI.Api.Models.PrivacyLevel]::Organizational, 
        [Microsoft.PowerBI.Api.Models.EncryptedConnection]::Encrypted, 
        $credentialsEncryptor)

    $updateDatasourceBodyStr = "{
        ""dataSourceType"": ""SQL"",
        ""connectionDetails"": ""{\""server\"":\""$server\"",\""database\"":\""$database\""}"",
        ""datasourceName"": ""$database"",
        ""credentialDetails"": {
            ""credentials"": ""$($credentialDetails.Credentials)"",     
            ""credentialType"": ""Basic"",
            ""encryptedConnection"": ""Encrypted"",
            ""encryptionAlgorithm"": ""RSA-OAEP"",
            ""privacyLevel"": ""Organizational"",
            ""useCallerAADIdentity"": ""False""
            }
      }
      "
    
    Invoke-PowerBIRestMethod -url "gateways/$gatewayId/datasources" -method Post -Body $updateDatasourceBodyStr
    
}
