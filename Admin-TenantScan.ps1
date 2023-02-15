#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }

param (    
    $modifiedSince = $null, #[datetime]::UtcNow.Date.AddDays(-10),
    $getInfoDetails = "getArtifactUsers=true&lineage=true&datasourceDetails=true&datasetSchema=true&datasetExpressions=true",
    $excludePersonalWorkspaces = $false,
    $excludeInActiveWorkspaces = $true,
    $outputPath = ".\output\tenantscan",
    $servicePrincipalId = "",
    $servicePrincipalSecret = "",
    $servicePrincipalTenantId = ""
)

#region Functions

function Get-ArrayInBatches
{
    [cmdletbinding()]
    param
    (        
        [array]$array
        ,
        [int]$batchCount
        ,
        [ScriptBlock]$script
        ,
        [string]$label = "Get-ArrayInBatches"
    )

    $skip = 0

    do
    {   
        $batchItems = @($array | Select -First $batchCount -Skip $skip)

        if ($batchItems)
        {
            Write-Host "[$label] Batch: $($skip + $batchCount) / $($array.Count)"
            
            Invoke-Command -ScriptBlock $script -ArgumentList @(,$batchItems)

            $skip += $batchCount
        }       
        
    }
    while($batchItems.Count -ne 0 -and $batchItems.Count -ge $batchCount)   
}

function Wait-On429Error
{
    [cmdletbinding()]
    param
    (        
        [ScriptBlock]$script
        ,
        [int]$sleepSeconds = 3601
        ,
        [int]$tentatives = 1
    )
 
    try {
        
        Invoke-Command -ScriptBlock $script

    }
    catch {

        $ex = $_.Exception

        if ($ex.ToString().Contains("429 (Too Many Requests)")) {
            Write-Host "'429 (Too Many Requests)' Error - Sleeping for $sleepSeconds seconds before trying again" -ForegroundColor Yellow

            $tentatives = $tentatives - 1

            if ($tentatives -lt 0)
            {            
               throw "[Wait-On429Error] Max Tentatives reached!"    
            }
            else
            {
                Start-Sleep -Seconds $sleepSeconds
                
                Wait-On429Error -script $script -sleepSeconds $sleepSeconds -tentatives $tentatives            
            }
        }
        else {
            throw  
        }         
    }
}

#endregion

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

$scansOutputPath = Join-Path $outputPath ("{0:yyyy}\{0:MM}\{0:dd}" -f [datetime]::Today)

New-Item -ItemType Directory -Path $scansOutputPath -ErrorAction SilentlyContinue | Out-Null

try {
    $token = Get-PowerBIAccessToken    
}
catch {
    if ($servicePrincipalId)
    {
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipalId, ($servicePrincipalSecret | ConvertTo-SecureString -AsPlainText -Force)

        $pbiAccount = Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $servicePrincipalTenantId -Credential $credential
    }
    else {
        $pbiAccount = Connect-PowerBIServiceAccount
    }
}
    
$modifiedRequestUrl = "admin/workspaces/modified?excludePersonalWorkspaces=$excludePersonalWorkspaces&excludeInActiveWorkspaces=$excludeInActiveWorkspaces"

if ($modifiedSince)
{
    $modifiedRequestUrl = $modifiedRequestUrl + "&modifiedSince=$($modifiedSince.ToString("o"))"
    $fullScan = $false
}
else
{
    $fullScan = $true
}

Write-Host "WorkspacesModified: $modifiedRequestUrl"

# Delete existent fullscans

if ($fullScan)
{
    Write-Host "Removing full scans"
    Get-ChildItem -Path "$scansOutputPath\*fullscan*" | Remove-Item -Force
}

$workspacesModified = Invoke-PowerBIRestMethod -Url $modifiedRequestUrl  -Method Get | ConvertFrom-Json

if (!$workspacesModified -or $workspacesModified.Count -eq 0)
{
    Write-Host "No workspaces modified"
}
else {
    Write-Host "Modified workspaces: $($workspacesModified.Count)"    

    $throttleErrorSleepSeconds = 3700
    $scanStatusSleepSeconds = 5
    $getInfoOuterBatchCount = 1500
    $getInfoInnerBatchCount = 100  

    Write-Host "Throttle Handling Variables: getInfoOuterBatchCount: $getInfoOuterBatchCount;  getInfoInnerBatchCount: $getInfoInnerBatchCount; throttleErrorSleepSeconds: $throttleErrorSleepSeconds"

    Get-ArrayInBatches -array $workspacesModified -label "GetInfo Global Batch" -batchCount $getInfoOuterBatchCount -script {
        param($workspacesModifiedOuterBatch)
                                        
        $script:workspacesScanRequests = @()

        # Call GetInfo in batches of 100 (MAX 500 requests per hour)

        Get-ArrayInBatches -array $workspacesModifiedOuterBatch -label "GetInfo Local Batch" -batchCount $getInfoInnerBatchCount -script {
            param($workspacesBatch)
            
            Wait-On429Error -tentatives 1 -sleepSeconds $throttleErrorSleepSeconds -script {
                
                $bodyStr = @{"workspaces" = @($workspacesBatch.Id) } | ConvertTo-Json
    
                # $script: scope to reference the outerscope variable

                $getInfoResult = @(Invoke-PowerBIRestMethod -Url "admin/workspaces/getInfo?$getInfoDetails" -Body $bodyStr -method Post | ConvertFrom-Json)

                $script:workspacesScanRequests += $getInfoResult

            }
        }                

        # Wait for Scan to execute - https://docs.microsoft.com/en-us/rest/api/power-bi/admin/workspaceinfo_getscanstatus (10,000 requests per hour)
    
        while(@($workspacesScanRequests |? status -in @("Running", "NotStarted")))
        {
            Write-Host "Waiting for scan results, sleeping for $scanStatusSleepSeconds seconds..."
    
            Start-Sleep -Seconds $scanStatusSleepSeconds
    
            foreach ($workspaceScanRequest in $workspacesScanRequests)
            {            
                $scanStatus = Invoke-PowerBIRestMethod -Url "admin/workspaces/scanStatus/$($workspaceScanRequest.id)" -method Get | ConvertFrom-Json
    
                Write-Host "Scan '$($scanStatus.id)' : '$($scanStatus.status)'"
    
                $workspaceScanRequest.status = $scanStatus.status
            }
        }
    
        # Get Scan results (500 requests per hour) - https://docs.microsoft.com/en-us/rest/api/power-bi/admin/workspaceinfo_getscanresult    
    
        foreach ($workspaceScanRequest in $workspacesScanRequests)
        {   
            Wait-On429Error -tentatives 1 -sleepSeconds $throttleErrorSleepSeconds -script {

                $scanResult = Invoke-PowerBIRestMethod -Url "admin/workspaces/scanResult/$($workspaceScanRequest.id)" -method Get | ConvertFrom-Json
        
                Write-Host "Scan Result'$($scanStatus.id)' : '$($scanResult.workspaces.Count)'"
        
                $fullScanSuffix = ".scan"

                if ($fullScan)
                {              
                    $fullScanSuffix = ".fullscan"      
                }              
                
                $outputFilePath = "$scansOutputPath\$($workspaceScanRequest.id)$fullScanSuffix.json"
        
                $scanResult | Add-Member –MemberType NoteProperty –Name "scanCreatedDateTime"  –Value $workspaceScanRequest.createdDateTime -Force
        
                ConvertTo-Json $scanResult -Depth 10 -Compress | Out-File $outputFilePath -force
            }
    
        }
    }                        
    
}