param (
    $serverName = "powerbi://api.powerbi.com/v1.0/myorg/WWI"
    , $datasetName = "WWI - Sales"
    , $username = "app:<Service Principal Id>@<Azure AD TenantId>"
    , $password = "<Secret>"
    , $query = "EVALUATE Customer"
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Add-Type -Path "$currentPath\lib\Microsoft.AnalysisServices.AdomdClient.dll"

$asModelType = [Microsoft.AnalysisServices.AdomdClient.AdomdConnection]

$assembly = $asModelType.Assembly

Write-Host "Assembly version loaded: '$($assembly.FullName)' from '$($assembly.Location)'"

try
{

    $conn = new-object Microsoft.AnalysisServices.AdomdClient.AdomdConnection

    $conn.ConnectionString = "Data Source=$serverName;User Id=$username;Password=$password"

    $conn.Open()   

    $conn.ChangeDatabase($datasetName)

    $cmd = $conn.CreateCommand()
	
    $cmd.CommandText = $query	                
	          
    $cmd.CommandTimeout = 30

    $reader = $cmd.ExecuteReader()

    $i = 0

    Write-Host "Reading..."

    while($reader.Read())
    {
        if ($i % 50 -eq 0)
        {
            Write-Host "Reading... ($i)"
        }

        $i++
    }   
    
    $reader.Dispose()           

}
finally
{
    if ($conn)
    {
        Write-Host "Closing connection"

        $conn.Dispose()
    }
}


