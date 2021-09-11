param (
$serverName = "powerbi://api.powerbi.com/v1.0/myorg/Session%20-%20PBI%20Dev%20on%20Steroids"
, $databaseName = "WWI - Sales (Partitioned)"
, $tables = @('Orders','Calendar')
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Add-Type -Path "$currentPath\Modules\ASTabularHelper\Microsoft.AnalysisServices.Tabular.dll"

try
{    
    Write-Host "Connecting to Server: '$serverName'"

    $server = New-Object Microsoft.AnalysisServices.Tabular.Server
    
    $server.Connect($serverName)

    Write-Host "Connected"

    foreach($table in $tables)
    {
        $refreshCommand = @{
            "refresh" = @{
                "type" = "full"
                ;
                "objects"= @(
                    @{
                        "database" = $databaseName
                        ;
                        "table" = $table
                    }
                )
            }
        }

        Write-Host "Refreshing table: '$table'"

        $script = $refreshCommand | ConvertTo-Json -Depth 5

        $sw = [system.diagnostics.stopwatch]::StartNew()

        $result = $server.Execute($script)        
        
        $sw.Stop()

        Write-Host "Time: $($sw.Elapsed.TotalSeconds)s"

    }

}
finally
{
    if($server)
    {
        $server.Dispose()
    }
}
                        


