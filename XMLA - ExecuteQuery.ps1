param(
    $connStr = "Provider=MSOLAP;Integrated Security=SSPI;Persist Security Info=False;Data Source=localhost\sql2019; Initial Catalog = AdventureWorks;SubQueries=2;"
    ,
    #$query = "SELECT {[Measures].[Internet Total Sales]}  ON 0,    [Date].[Calendar Year].[Calendar Year].MEMBERS  ON 1  FROM  [Adventure Works Internet Sales Model]"
    $query = "EVALUATE 'Internet Sales'"
    ,
    $logRowCount = 10000
    ,
    $executionTimes = 3
    ,
    $executionSleep = 5
    ,
    $reuseConnection = $true
)

cls

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$nugetName = "Microsoft.AnalysisServices.AdomdClient.retail.amd64"
$nugetVersion = "19.54.1"

if (!(Test-Path "$currentPath\Nuget\$nugetName.$nugetVersion" -PathType Container)) {
    Install-Package -Name $nugetName -ProviderName NuGet -Scope CurrentUser -RequiredVersion $nugetVersion -SkipDependencies -Destination "$currentPath\Nuget" -Force
}

$assemblyPath = Resolve-Path "$currentPath\Nuget\$nugetName.$nugetVersion\lib\net45\Microsoft.AnalysisServices.AdomdClient.dll"

Add-Type -Path $assemblyPath

$assembly = [Microsoft.AnalysisServices.AdomdClient.AdomdConnection].Assembly

Write-Host "Assembly version loaded: '$($assembly.FullName)' from '$($assembly.Location)'"

$report = @()

$conn = $null

for ($i = 1; $i -le $executionTimes; $i++)
{    
    Write-Host "Execution $i / $executionTimes"

    try
    {
        if (!$reuseConnection -or !$conn)
        {
            Write-Host "Opening connection"

            $conn = new-object Microsoft.AnalysisServices.AdomdClient.AdomdConnection

            $conn.ConnectionString = $connStr

            $conn.Open()
        }

        try 
        {
            
            Write-Host "Executing Query"

            $sw = New-Object System.Diagnostics.Stopwatch

            $sw.Start()

            $cmd = $conn.CreateCommand()

            $cmd.CommandText = $query	                

            $reader = $cmd.ExecuteReader()

            $rowCount = 0        
            
            while($reader.Read())
            {                
                if ($rowCount % $logRowCount -eq 0)
                {
                    Write-Host "Reading... [$rowCount] - [$([datetime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss"))]"
                }

                $rowCount++
            }          
        
        }
        finally
        {        
            $sw.Stop()

            Write-Host "Query Execution Seconds: $($sw.Elapsed.TotalSeconds.ToString("N3"))"

            $report += @{ExecutionId = $i; Duration = [Math]::Round($sw.Elapsed.TotalSeconds,3)}

            if ($reader)
            {
                $reader.Dispose()
            }

            if ($cmd)
            {
                $cmd.Dispose()
            }            
        }
    }
    finally
    {
        if (!$reuseConnection -and $conn -ne $null)
        {        
            Write-Host "Disposing Connection"

            $conn.Dispose()

            $conn = $null
        }
    }

    Write-Host "Sleeping..."

    Start-Sleep -Seconds $executionSleep
}

 if ($conn -ne $null)
{        
    Write-Host "Disposing Connection"

    $conn.Dispose()

    $conn = $null
}

$report |% { [PSCustomObject]$_ } | format-table -AutoSize