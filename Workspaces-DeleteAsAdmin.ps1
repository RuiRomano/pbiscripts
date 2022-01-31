#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

# This script requires you to authenticate with a Power BI Admin account

param(          
    $searchPattern = "*PBIDevOps*"    
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

Connect-PowerBIServiceAccount

$workspaces  = Get-PowerBIWorkspace -Scope Organization -All

$filteredWorkspaces = @($workspaces |? { $_.Name -like $searchPattern})

if ($filteredWorkspaces.Count -eq 0)
{
    Write-Host "No workspace found where name = '$searchPattern'"
}
else {
    # TODO
}