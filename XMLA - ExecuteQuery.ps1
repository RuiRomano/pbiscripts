param(
    $connStr = "Provider=MSOLAP;Integrated Security=SSPI;Persist Security Info=False;Data Source=localhost\sql2019; Initial Catalog = AdventureWorks;SubQueries=2;"
    ,
    $query = "
    SELECT NON EMPTY CrossJoin(Hierarchize(CrossJoin({[Geography].[Country Region Name].[Country Region Name].AllMembers}, {([Customer].[Education].[Education].AllMembers)})), {[Measures].[Internet Total Sales],[Measures].[Internet Total Units],[Measures].[Internet Total Tax Amt],[Measures].[Internet Total Product Cost],[Measures].[Internet Total Margin],[Measures].[Internet Total Freight],[Measures].[Internet Distinct Count Sales Order],[Measures].[Internet Total Discount Amount]}) DIMENSION PROPERTIES MEMBER_CAPTION ON COLUMNS , NON EMPTY Hierarchize(CrossJoin({[Customer].[Customer Id].[Customer Id].AllMembers}, {([Date].[Date].[Date].AllMembers,[Geography].[Postal Code].[Postal Code].AllMembers,[Internet Sales].[Due Date].[Due Date].AllMembers,[Product].[Product Id].[Product Id].AllMembers)})) DIMENSION PROPERTIES MEMBER_CAPTION ON ROWS  FROM [Adventure Works Internet Sales Model]
    "
    ,
    $logRowCount = 10000
    ,
    $executionTimes = 2
    ,
    $executionSleep = 5
    ,
    $reuseConnection = $true
    ,
    $assemblyPath = $null
    #$assemblyPath = "C:\Program Files\Microsoft Power BI Desktop\bin\Microsoft.PowerBI.AdomdClient.dll"
    #$assemblyPath = "C:\Program Files\On-premises data gateway\Microsoft.AnalysisServices.AdomdClient.dll"
    #$assemblyPath = "C:\Program Files\On-premises data gateway\m\Microsoft.PowerBI.AdomdClient.dll"
)

cls

$ErrorActionPreference = "Stop"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

if (!$assemblyPath)
{
    $nugetName = "Microsoft.AnalysisServices.AdomdClient.retail.amd64"
    $nugetVersion = "19.54.1"

    if (!(Test-Path "$currentPath\Nuget\$nugetName.$nugetVersion" -PathType Container)) {
        Install-Package -Name $nugetName -ProviderName NuGet -Scope CurrentUser -RequiredVersion $nugetVersion -SkipDependencies -Destination "$currentPath\Nuget" -Force
    }

    $assemblyPath = Resolve-Path "$currentPath\Nuget\$nugetName.$nugetVersion\lib\net45\Microsoft.AnalysisServices.AdomdClient.dll"
}

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

            $sw2 = $null

            $sw = New-Object System.Diagnostics.Stopwatch

            $sw.Start()

            $cmd = $conn.CreateCommand()

            $cmd.CommandText = $query	                

            $reader = $cmd.ExecuteReader()

            $rowCount = 0        
            
            while($reader.Read())
            {               
                if (!$sw2)
                {
                    $sw2 = New-Object System.Diagnostics.Stopwatch
                }
                 
                if ($rowCount % $logRowCount -eq 0)
                {
                    Write-Host "Reading... [$rowCount] - [$([datetime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss"))] - $([Math]::Round($sw2.Elapsed.TotalMilliseconds,0))ms"

                    $sw2.Restart()
                }

                $rowCount++
            }          
        
        }
        finally
        {        
            $sw.Stop()

            Write-Host "Query Execution: $($sw.Elapsed.TotalSeconds.ToString("N3"))s"

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