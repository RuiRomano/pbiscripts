cls

Install-Module MicrosoftPowerBIMgmt

# Authentication Prompt
Connect-PowerBIServiceAccount

#region Service Principal
$appId = ""
$tenantId = ""
$appSecret = ""
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appId, ($appSecret | ConvertTo-SecureString -AsPlainText -Force)
#Disconnect-PowerBIServiceAccount
Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $tenantId -Credential $credential
#endregion

# Call the API using the PowerBIRestMethod
$result = Invoke-PowerBIRestMethod -Url "groups" -Method Get | ConvertFrom-Json | select -ExpandProperty value
$result | Format-Table
$result.Count

# RAW API Call - https://docs.microsoft.com/en-us/powershell/module/microsoftpowerbimgmt.profile/invoke-powerbirestmethod?view=powerbi-ps
# https://app.powerbi.com/groups/1eb4ce83-58cb-4360-8ac5-b7930e81360a/list
$result = Invoke-PowerBIRestMethod -Url "groups/da09fedd-9cb2-460a-986f-9624a1662168/datasets" -Method Get | ConvertFrom-Json | select -ExpandProperty value
$result | Format-Table
$result.Count

# https://docs.microsoft.com/en-us/rest/api/power-bi/admin/apps-get-apps-as-admin
$result = Invoke-PowerBIRestMethod -Url "admin/apps?`$top=2000" -Method Get | ConvertFrom-Json | select -ExpandProperty value
$result | Format-Table
$result.Count

# https://docs.microsoft.com/en-us/powershell/module/microsoftpowerbimgmt.workspaces/get-powerbiworkspace?view=powerbi-ps
$result = Get-PowerBIWorkspace -All
$result | Format-Table
$result.Count

# Call API as Admin

$result = Get-PowerBIWorkspace -Scope Organization -All
$result | Format-Table
$result.Count

# https://docs.microsoft.com/en-us/powershell/module/microsoftpowerbimgmt.data/get-powerbidataset?view=powerbi-ps
$result = Get-PowerBIDataset -WorkspaceId "1eb4ce83-58cb-4360-8ac5-b7930e81360a"
$result
$result.Count

$result = Get-PowerBIDataset -WorkspaceId "8d820de8-53a6-4531-885d-20b27c85f413"
$result
$result.Count


