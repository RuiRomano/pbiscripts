#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param (
    $sourceCapacityName = "rrpbiembedded"
    ,
    $targetCapacityName = "rrmsft_P1"
)

$ErrorActionPreference = "Stop"

Connect-PowerBIServiceAccount

Write-Host "Getting existent capacities"

$capacities = Get-PowerBICapacity

$capacities | Format-Table

$sourceCapacity = ($capacities |? DisplayName -eq $sourceCapacityName | select -First 1)

if (!$sourceCapacity)
{
    throw "Cannot find capacity with name '$sourceCapacityName'"
}

$targetCapacity = ($capacities |? DisplayName -eq $targetCapacityName | select -First 1)

if (!$targetCapacity)
{
    throw "Cannot find capacity with name '$targetCapacityName'"
}

Write-Host "Getting workspaces"

$premiumWorkspaces  = Get-PowerBIWorkspace -Scope Organization -All -Filter "isOnDedicatedCapacity eq true and tolower(state) eq 'active'"

$sourcePremiumWorkspaces = @($premiumWorkspaces |? {$_.capacityId -eq $sourceCapacity.Id}) | sort-object -Property Id -Unique

if ($sourcePremiumWorkspaces.Count -gt 0)
{
    Write-Host "Assigning $($sourcePremiumWorkspaces.Count) workspaces to new capacity '$($targetCapacity.DisplayName)' / '$($targetCapacity.Id)'"

    $sourcePremiumWorkspaces | Format-Table

    $confirmation = Read-Host "Are you Sure You Want To Proceed (y)"

    if ($confirmation -ieq 'y') {

        $workspaceIds = @($sourcePremiumWorkspaces.id)

        # Unassign workspaces

        $body = @{
            capacityMigrationAssignments=  @(@{
                targetCapacityObjectId = $targetCapacity.Id;
                workspacesToAssign = $workspaceIds
            })
        }

        $bodyStr = ConvertTo-Json $body -Depth 3
    
        Invoke-PowerBIRestMethod -url "admin/capacities/AssignWorkspaces" -method Post -body $bodyStr
    }
}
else
{
    Write-Host "No workspaces on source capacity: '$($sourceCapacity.DisplayName)' / '$($sourceCapacity.Id)'"
}