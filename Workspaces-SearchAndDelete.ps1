#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

# This script requires you to authenticate with a Power BI Admin account

param(          
    $searchPattern = @("*PBIDevOps*", "Test*", "Team A*")
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

Connect-PowerBIServiceAccount

$workspaces  = Get-PowerBIWorkspace -Scope Organization -All -Filter "tolower(state) eq 'active'"

$filteredWorkspaces = @(
    $workspaces |? { 

        $workspaceName = $_.Name 

        $searchPattern |? { $workspaceName -like $_}

    }
)

if ($filteredWorkspaces.Count -eq 0)
{
    Write-Host "No active workspaces found where Workspace Name like $([string]::join(",", $searchPattern))"
}
else 
{

    Write-Host "Found '$($filteredWorkspaces.Count)' workspaces"
    
    $filteredWorkspaces | Format-Table

    $confirmation = Read-Host "Are you Sure You Want To Proceed (y)"

    if ($confirmation -ieq 'y') {
        
        foreach($workspace in $filteredWorkspaces)
        {
            Write-Host "Deleting Workspace: $($workspace.Name)"

            Invoke-PowerBIRestMethod -Method Delete -Url "groups/$($workspace.id)"
        }
    }
}