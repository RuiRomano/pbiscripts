#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

# Object Id from Azure AD
$workspaceId = "f5e73633-29c1-432f-ad5f-3ef5863dcaec"

#https://docs.microsoft.com/en-us/rest/api/power-bi/groups/update-group-user#groupuseraccessright
$principalObj = @{

    identifier = "2eab306a-bbd8-4f14-8793-eea2d1589585";
    groupUserAccessRight = "Member";    
    principalType = "Group"
}

# Get the authentication token using ADAL library (OAuth)

Connect-PowerBIServiceAccount

$body = $principalObj | ConvertTo-Json

Invoke-PowerBIRestMethod -Url "groups/$workspaceId/users" -Method Post -Body $body
