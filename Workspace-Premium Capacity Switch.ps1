#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

$sourceCapacityId = "45fa0865-b985-4eaf-886a-144cd56561e7" #Premium Per User
$targetCapacityId = "7de26338-a4b5-445d-a455-058b336117a3" #rrpbiembedtestgen2

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition –Parent)

Connect-PowerBIServiceAccount

Write-Host "Capacities"

$capacities = Invoke-PowerBIRestMethod -url "capacities" -method Get | ConvertFrom-Json | Select -ExpandProperty value

$capacities | Format-Table

Write-Host "Getting workspaces"

$premiumWorkspaces  = Get-PowerBIWorkspace -Scope Organization -All -Filter "isOnDedicatedCapacity eq true"

$sourcePremiumWorkspaces = @($premiumWorkspaces |? {$_.capacityId -eq $sourceCapacityId})

if ($sourcePremiumWorkspaces.Count -gt 0)
{
    Write-Host "Assigning $($sourcePremiumWorkspaces.Count) workspaces to new capacity '$targetCapacityId'"

    $workspaceIds = @($sourcePremiumWorkspaces.id)

    # Unassign workspaces

    $body = @{
        capacityMigrationAssignments=  @(@{
            targetCapacityObjectId = $targetCapacityId;
            workspacesToAssign = $workspaceIds
        })
    }

    $bodyStr = ConvertTo-Json $body -Depth 3
 
    Invoke-PowerBIRestMethod -url "admin/capacities/AssignWorkspaces" -method Post -body $bodyStr
}
else
{
    Write-Host "No workspaces on source capacity: '$sourceCapacityId'"
}