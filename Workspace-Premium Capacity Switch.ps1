#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

$sourceCapacityId = "BEBF8A28-B230-4187-AD24-92FE2ECEAD53" #rrpbiembedtestgen2
$targetCapacityId = "B841DB73-7A03-4349-BE78-2B81C32EC60F" #Premium Per User

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