#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt.Profile"; ModuleVersion="1.2.1026" }
#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt.Workspaces"; ModuleVersion="1.2.1026" }

param(            
    # See more examples here: https://learn.microsoft.com/en-us/rest/api/power-bi/admin/groups-add-user-as-admin    
    $identity = "FreeUser@rrmsft.onmicrosoft.com",
    $identityType = "User", 
    $workspaceRole = "Member",
    $workspaces = @("664e5e57-47a2-4cbc-9539-99da11abf341"),
    $servicePrincipalId = "",
    $servicePrincipalSecret = "",
    $servicePrincipalTenantId = ""
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

# Get token with admin account

if ($servicePrincipalId)
{
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipalId, ($servicePrincipalSecret | ConvertTo-SecureString -AsPlainText -Force)

    $pbiAccount = Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $servicePrincipalTenantId -Credential $credential
}
else {
    $pbiAccount = Connect-PowerBIServiceAccount
}

Write-Host "Login with: $($pbiAccount.UserName)"

Write-Host "Workspaces to set security: $($workspaces.Count)"        

foreach($workspace in $workspaces)
{  
    Write-Host "Adding identity to workspace: $workspace)"

    $body = @{
        "identifier" = $identity
        ;
        "groupUserAccessRight" = $workspaceRole
        ;
        "principalType" = $identityType
    }

    $bodyStr = ($body | ConvertTo-Json)
    
    Invoke-PowerBIRestMethod -method Post -url "admin/groups/$workspace/users" -body $bodyStr
}


