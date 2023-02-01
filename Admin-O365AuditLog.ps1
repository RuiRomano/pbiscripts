#Requires -Modules ExchangeOnlineManagement 

param (    
    $numberDays = 1,
    $outputPath = ".\output\o365Audit"
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

# Ensure its enabled: https://learn.microsoft.com/en-us/microsoft-365/compliance/audit-log-enable-disable?view=o365-worldwide
# Get-AdminAuditLogConfig | FL UnifiedAuditLogIngestionEnabled

Connect-ExchangeOnline

# Now you can query for Power BI activity. In this example, the results are limited to 

$pivotDate = [datetime]::UtcNow.Date.AddDays(-1*$numberDays)

while ($pivotDate -le [datetime]::UtcNow) {   
    
    Write-Host "Getting audit data for: '$($pivotDate.ToString("yyyyMMdd"))'" 

    $results = Search-UnifiedAuditLog -StartDate $pivotDate -EndDate $pivotDate.AddHours(24).AddSeconds(-1) -RecordType PowerBIAudit -ResultSize 5000

    $outputFilePath = "$outputPath\auditLogsO365\{0:yyyyMMdd}.json" -f $pivotDate

    New-Item -Path (Split-Path $outputFilePath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    ConvertTo-Json @($results) -Compress -Depth 10 | Out-File $outputFilePath -force

    $pivotDate = $pivotDate.AddDays(1)
}