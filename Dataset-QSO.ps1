#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

param(
    $workspaceId = "70f9aed2-7b42-45dd-a1fe-94c6e9cc89c1"
    ,
    $datasetId = "99b285a0-086e-47b7-8af6-7938b698e37a"
)

try { Get-PowerBIAccessToken | out-null } catch {  Connect-PowerBIServiceAccount }

Write-Host "Checking sync status"

$syncStatus = Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$datasetId/syncStatus" -Method Get | ConvertFrom-Json 

if ($syncStatus.commitVersion -ne $syncStatus.minActiveReadVersion)
{
    Write-Warning "Dataset is out of sync, reason: $($syncStatus.triggerReason)"

    $syncStatus | Format-List 

    Write-Host "Syncing"

    $syncStatus = Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$datasetId/sync" -Method Post | ConvertFrom-Json 

    while ($syncStatus.commitVersion -ne $syncStatus.minActiveReadVersion)
    {
        $syncStatus = Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$datasetId/syncStatus" -Method Get | ConvertFrom-Json 

        if ($syncStatus.commitVersion -eq $syncStatus.minActiveReadVersion)
        {
            Write-Host "Dataset in Sync"
            Write-Host "Sync duration: $(($syncStatus.syncEndTime - $syncStatus.syncStartTime).TotalSeconds)"
            Write-Host "minActiveReadTimestamp: $($syncStatus.minActiveReadTimestamp)"

        }
        else {
            Write-Warning "Dataset not in sync, sleeping..."
            Start-Sleep -Seconds 5
        }    
    }

}
else {
    Write-Host "Dataset is in sync"
}

