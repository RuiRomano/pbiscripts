#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1077" }

param (    
    $numberDays = 2,
    $outputPath = ".\output\activity",
    $filter = "",
    $outputBatchCount = 5000,
    $servicePrincipalId = "",
    $servicePrincipalSecret = "",
    $servicePrincipalTenantId = ""
)

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

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

Write-Host "Login with: $($pbiAccount.UserName)"

$maxHistoryDate = [datetime]::UtcNow.Date.AddDays(-30)

$pivotDate = [datetime]::UtcNow.Date.AddDays(-1*$numberDays)

Write-Host "Since: $($pivotDate.ToString("s"))"

while ($pivotDate -le [datetime]::UtcNow) {   

    Write-Host "Getting audit data for: '$($pivotDate.ToString("yyyyMMdd"))'"        
        
    $activityAPIUrl = "admin/activityevents?startDateTime='$($pivotDate.ToString("s"))'&endDateTime='$($pivotDate.AddHours(24).AddSeconds(-1).ToString("s"))'"

    if ($filter)
    {
        $activityAPIUrl += "&`$filter=$filter"
    }

    $audits = @()                  
    $pageIndex = 1
    $flagNoActivity = $true

    do
    {          
        if (!$result.continuationUri)
        {
            $result = Invoke-PowerBIRestMethod -Url $activityAPIUrl -method Get | ConvertFrom-Json
        }
        else {
            $result = Invoke-PowerBIRestMethod -Url $result.continuationUri -method Get | ConvertFrom-Json
        }            
                            
        if ($result.activityEventEntities)
        {
            $audits += @($result.activityEventEntities)               
        }

        if ($audits.Count -ne 0 -and ($audits.Count -ge $outputBatchCount -or $result.continuationToken -eq $null))
        {
            # To avoid duplicate data on existing files, first dont append pageindex to overwrite existing full file

            if ($pageIndex -eq 1)
            {
                $outputFilePath = ("$outputPath\{0:yyyyMMdd}.json" -f $pivotDate)                        
            }
            else {
                $outputFilePath = ("$outputPath\{0:yyyyMMdd}_$pageIndex.json" -f $pivotDate)
            }                    

            Write-Host "Writing '$($audits.Count)' audits"

            New-Item -Path (Split-Path $outputFilePath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

            ConvertTo-Json @($audits) -Compress -Depth 10 | Out-File $outputFilePath -force
            
            $flagNoActivity = $false

            $pageIndex++

            $audits = @()
        }
    }
    while($result.continuationToken -ne $null)

    if ($flagNoActivity)
    {
        Write-Warning "No audit logs for date: '$($pivotDate.ToString("yyyyMMdd"))'"
    }    

    $pivotDate = $pivotDate.AddDays(1)
}

