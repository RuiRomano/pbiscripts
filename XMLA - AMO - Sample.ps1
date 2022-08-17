cls

$serverName = "Data Source=powerbi://api.powerbi.com/v1.0/myorg/Contoso"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Import-Module "$currentPath\TOMHelper.psm1" -Force

$asModelType = [Microsoft.AnalysisServices.Tabular.Model]

$assembly = $asModelType.Assembly

Write-Host "Assembly version loaded: '$($assembly.FullName)' from '$($assembly.Location)'"

try
{    
    Write-Host "Connecting to Server: '$serverName'"

    $server = New-Object Microsoft.AnalysisServices.Tabular.Server
    
    $server.Connect($serverName)

    Write-Host "Connected"

    $tables = $server.Databases[0].Model.Tables

    foreach($table in $tables)
    {
        Write-Host "$($table.Name)"
    }

}
finally
{
    if($server)
    {
        $server.Dispose()
    }
}
                        


