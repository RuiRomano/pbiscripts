#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(            
    $gatewayId = "0380ed77-237f-42ec-8f1a-05f2c6cd4a33",   
    $datasourceName = "Contoso X5",
    $datasourceType = "SQL",
    $server = "<server connection>",
    $database = "<databasename>",
    $username = "<username>",
    $password = "<password>",
    # Ensure the Service Principal is added as a Gateway Admin and is allowed to call Power BI Apis
    $servicePrincipalId = "",
    $servicePrincipalSecret = "",
    $servicePrincipalTenantId = "",
    # Optional, it will bind this new datasource to existent datasets
    $datasetsToBind = @(@{workspaceId="6119d5fa-7cba-4560-b244-37f81946de6b"; datasetId="b41e055d-06fb-4c3d-b775-17b3ff1a4d00"})
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

# Install the Power BI package into the current working directory if it's not already installed
if (!(Test-Path "$currentPath\Nuget\Microsoft.PowerBI.Api.3.18.1" -PathType Container)) {
    Install-Package -Name "Microsoft.PowerBI.Api" -ProviderName NuGet -Scope CurrentUser -RequiredVersion 3.18.1 -SkipDependencies -Destination "$currentPath\Nuget" -Force
}

if ($PSVersionTable.PSVersion.Major -le 5) {
    $pbipath = Resolve-Path "$currentPath\Nuget\Microsoft.PowerBI.Api.3.18.1\lib\net48\Microsoft.PowerBI.Api.dll"
}
else {
    $pbipath = Resolve-Path "$currentPath\Nuget\Microsoft.PowerBI.Api.3.18.1\lib\netstandard2.0\Microsoft.PowerBI.Api.dll"
}

[System.Reflection.Assembly]::LoadFrom($pbipath)

if ($servicePrincipalId)
{
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipalId, ($servicePrincipalSecret | ConvertTo-SecureString -AsPlainText -Force)

    $pbiAccount = Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $servicePrincipalTenantId -Credential $credential
}
else {
    $pbiAccount = Connect-PowerBIServiceAccount
}

Write-Host "Login with: $($pbiAccount.UserName)"

Write-Host "Getting Gateways"

$gateways = Invoke-PowerBIRestMethod -url "gateways" -method Get | ConvertFrom-Json | Select -ExpandProperty value

$gateway = $gateways |? { $_.id -eq $gatewayId }

if (!$gateway)
{
    throw "Cannot find gateway '$gatewayId'"
}
else {

    $datasources = Invoke-PowerBIRestMethod -url "gateways/$gatewayId/datasources" -method Get | ConvertFrom-Json | Select -ExpandProperty value

    $datasource = $datasources |? datasourceName -eq $datasourceName | select -First 1

    if ($datasource)
    {
        Write-Host "Datasource '$datasourceName' already exists"
    }
    else
    {
        Write-Host "Creating Datasource '$datasourceName'"

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
            ""dataSourceType"": ""$datasourceType"",
            ""connectionDetails"": ""{\""server\"":\""$server\"",\""database\"":\""$database\""}"",
            ""datasourceName"": ""$datasourceName"",
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
        
        $datasource = Invoke-PowerBIRestMethod -url "gateways/$gatewayId/datasources" -method Post -Body $updateDatasourceBodyStr 

        $datasource = $datasource | ConvertFrom-Json
    }    
}

if ($datasetsToBind)
{
    foreach($dataset in $datasetsToBind)
    {
        Write-Host "Taking ownership of dataset '$($dataset.datasetId)'"

        Invoke-PowerBIRestMethod -Url "groups/$($dataset.workspaceId)/datasets/$($dataset.datasetId)/Default.TakeOver" -Method Post | Out-Null

        Write-Host "Set dataset '$($dataset.datasetId)' Parameters"

        $bodyStr = @{updateDetails = @(@{name = "Server"; newValue = $server}, @{name = "Database"; newValue = $database})} | ConvertTo-Json

        Invoke-PowerBIRestMethod -Url "groups/$($dataset.workspaceId)/datasets/$($dataset.datasetId)/UpdateParameters" -Body $bodyStr -Method Post | Out-Null

        Write-Host "Bind dataset '$($dataset.datasetId)' to Gateway"
    
        $bodyStr = @{gatewayObjectId = $datasource.gatewayId; datasourceObjectIds = @($datasource.id)} | ConvertTo-Json

        Invoke-PowerBIRestMethod -Url "groups/$($dataset.workspaceId)/datasets/$($dataset.datasetId)/Default.BindToGateway" -Method Post -Body $bodyStr | Out-Null
    }
}