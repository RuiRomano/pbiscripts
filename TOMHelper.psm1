$script:azureDevOpsLogs = $false

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Write-Host "Loading Module Assemblies"

# Downloading Nugets

if ($PSVersionTable.PSVersion.Major -le 5) {
    $nugetName = "Microsoft.AnalysisServices.retail.amd64"
    $nugetVersion = "19.48.0"

    if (!(Test-Path "$currentPath\Nuget\$nugetName.$nugetVersion" -PathType Container)) {
        Install-Package -Name $nugetName -ProviderName NuGet -Scope CurrentUser -RequiredVersion $nugetVersion -SkipDependencies -Destination "$currentPath\Nuget" -Force
    }

    $dllPath = "$currentPath\Nuget\$nugetName.$nugetVersion\lib\net45\Microsoft.AnalysisServices.Tabular.dll"

    Add-Type -Path $dllPath
}
else
{
    # need to load the Microsoft.Identity.Client, otherwise the Connect fails with 'Connection cannot be made'
    
    $nugetName = "Microsoft.Identity.Client"
    $nugetVersion = "4.43.0"

    if (!(Test-Path "$currentPath\Nuget\$nugetName.$nugetVersion" -PathType Container)) {
        Install-Package -Name $nugetName -ProviderName NuGet -Scope CurrentUser -RequiredVersion $nugetVersion -SkipDependencies -Destination "$currentPath\Nuget" -Force
    }

    $dllPath = "$currentPath\Nuget\$nugetName.$nugetVersion\lib\netcoreapp2.1\Microsoft.Identity.Client.dll"

    Add-Type -Path $dllPath

    $nugetName = "Microsoft.AnalysisServices.NetCore.retail.amd64"
    $nugetVersion = "19.48.0"

    if (!(Test-Path "$currentPath\Nuget\$nugetName.$nugetVersion" -PathType Container)) {
        Install-Package -Name $nugetName -ProviderName NuGet -Scope CurrentUser -RequiredVersion $nugetVersion -SkipDependencies -Destination "$currentPath\Nuget" -Force
    }

    $dllPath = "$currentPath\Nuget\$nugetName.$nugetVersion\lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.dll"

    Add-Type -Path $dllPath
}

$asModelType = [Microsoft.AnalysisServices.Tabular.Model]

$assembly = $asModelType.Assembly

Write-Host "Assembly version loaded: '$($assembly.FullName)' from '$($assembly.Location)'"

Function Set-ModuleConfig
{
    [CmdletBinding()]
    param
    (
        [bool] $azureDevOpsLogs     
	)

    if ($azureDevOpsLogs -ne $script:azureDevOpsLogs)
    {
        Write-Host "Changing 'azureDevOpsLogs' from '$($script:azureDevOpsLogs)' to '$azureDevOpsLogs'"

        $script:azureDevOpsLogs = $azureDevOpsLogs
    }
}

Function Invoke-XMLAScript
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$serverName
        ,
        [Parameter(ParameterSetName = 'script', Mandatory = $true)]
        [string]$xmlaScript   
        ,
        [Parameter(ParameterSetName = 'file', Mandatory = $true)]
        [string]$xmlaScriptFilePath
        ,
        [System.Text.Encoding] $encoding = [System.Text.Encoding]::Default    
        ,
        [string] $username
        ,
        [string] $password
        ,
        [string] $authToken 
	)

    try
    {       
        $server = Connect-ASServer -serverName $serverName -userId $username -password $password -authToken $authToken        
     
        Write-Log "Executing XMLA on on '$serverName'"

        if (![string]::IsNullOrEmpty($xmlaScriptFilePath))
        {
            $xmlaScript = [IO.File]::ReadAllText($xmlaScriptFilePath, $encoding)
        }

        $result = $server.Execute($xmlaScript)

        if ($result.ContainsErrors -eq $true)
        {
            $strErrors = ""

            # Get Messages

            $nl = [System.Environment]::NewLine

            foreach($xr in $result.Messages)
            {
                $strErrors += $xr.Description
                $strErrors += $nl
            }

            throw "Error executing Deploy to Server: $($nl)$($strErrors)"
        }

    }
    finally
    {
        if ($server)
        {
            $server.Dispose()
        }
    }
}

Function Invoke-ASTableProcess
{
<#
    .SYNOPSIS
    Issues a Process Command for the specified database/table/partition
    .DESCRIPTION

    .PARAMETER connStr
    Connection String to the tabular database
    .PARAMETER tables
	Collection of tables to add partitions
        Ex: @{
                DatabaseName = "DBName"
                ;
                TableName = "Table"
                ;
                Partitions = @()
            }
    .PARAMETER resetPartitions
    Resets all the partitions for every table specified
    .EXAMPLE
    Invoke-ASTableProcess -tables @(
        @{
            Server = $connStr
            ;
            DatabaseName = $databaseName
            ;
            TableName = "Sales"
            ;
            Partitions = @(($refDate.AddMonths(-2).Month..$refDate.Month) |% { $refDate.Year.ToString() + $_.ToString().PadLeft(2,'0') })
            ;
            Enabled = 1
            ;
            Group = "G2"
        })
#>
    [CmdletBinding()]
    param
    (
         [array]$tables = @(
                @{
                    Server = "<connStr>"
                    ;
                    DatabaseName = "<databaseName>"
                    ;
                    TableName = "<tableName>"
                    ;
                    Partitions = @("ALL")
                    ;
                    Enabled = 1
                    ;
                    Group = "G1"
                }
                )
        ,
        [int] $maxParallelism = 5
        ,
        [string] $executionCode
        ,
        [string] $executionsPath
        ,
        [string] $username
        ,
        [string] $password
	)

    try
    {
        Write-Log "Starting AS Process"

        $executionResult = @()

        if ($executionsPath -and $executionCode)
        {
            New-Item -Path $executionsPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

            $executionFilePath = "$executionsPath\$executionCode.json"

            if (Test-Path $executionFilePath)
            {
                Write-Log "Found active execution '$executionCode'"

                $previousExecutionResult = Get-Content -Path $executionFilePath | ConvertFrom-Json

                $previousExecutionProcessOrders = $previousExecutionResult | Select ProcessGroup,ProcessStatus -ExpandProperty ProcessOrders
            }
            
        }

        # Set default values

        $tables |% {
            if (!$_.RefreshType)
            {
                $_.RefreshType = "full"
            }
        }

        # Group by server & database

        $tables | Group-Object {$_.Server } |% {

            $serverName = $_.Name

            $connStr = $serverName

            $server = Connect-ASServer -serverName  $connStr -userId $username -password $password

            $_.Group | Group-Object { $_.DatabaseName + "|" + $_.Group } | Sort-Object  { $_.Name } |% {

                $databaseName = $_.Name.Split('|')[0]
                $group = $_.Name.Split('|')[1]

                Write-Log "StartTime: $((Get-Date -Format "yyyy-MM-dd HH:mm:ss.ms").Substring(0, 22))"
                Write-Log "Processing database '$databaseName' on group '$group'"

                $startTime = [datetime]::UtcNow

                try
                {
 
                    $processError = $null

                    $database = $server.Databases.GetByName($databaseName)

                    # Iterate the tables

                    $processOrders = $_.Group

                    # Create the process execution to save results

                    $processExecution = @{
                        ProcessGroup = $group
                        ;
                        ProcessOrders = @()
                        ;
                        ProcessStartDate = $startTime.ToString("s")
                    }

                    $executionResult += $processExecution
      
                    $processOrders | Sort-Object  {

                        $processType = $_.RefreshType

                        # Define the order of the process

                        $refreshTypes = @("full", "dataonly", "clearvalues", "automatic", "calculate","defragment")

                        $refreshTypes.IndexOf($processType.ToLower())

                    } |% {

                        $tableName = $_.TableName

                        $processType = $_.RefreshType

                        if ($tableName -eq "ALL" -or !$tableName)
                        {
                            Write-Log "Process '$processType' on database '$databaseName'"

                            $alreadyProcessed = @($previousExecutionProcessOrders |? { ($_.ProcessStatus -in @("Processed") -or !$_.Skipped) -and $_.RefreshType -ne "calculate" -and $_.RefreshType -eq $processType -and $_.Server -eq $serverName -and $_.Database -eq $databaseName -and !$_.Table -and !$_.Partition}).Count -gt 0
                            
                            $processOrder = @{Server = $serverName; Database = $databaseName; RefreshType = $processType}

                            $processExecution.ProcessOrders += $processOrder

                            if (!$alreadyProcessed)
                            {
                                $database.Model.RequestRefresh($processType, $null)
                            }
                            else
                            {
                                $processOrder.Skipped = $true
                                Write-Log "Skipped, already processed in previous execution"
                            }
                        }
                        else
                        {
                            $table = $database.Model.Tables.Find($tableName)

                            if ($table -eq $null)
                            {
                                throw "Cannot find table '$tableName'"
                            }

                            $partitions = $_.Partitions

                            if($partitions -eq $null -or $partitions -contains "ALL")
                            {
                                Write-Log "Process '$processType' on table '$tableName'"

                                $alreadyProcessed = @($previousExecutionProcessOrders |? { ($_.ProcessStatus -in @("Processed") -or !$_.Skipped) -and $_.RefreshType -eq $processType -and $_.Server -eq $serverName -and $_.Database -eq $databaseName -and $_.Table -eq $tableName -and !$_.Partition}).Count -gt 0

                                $processOrder = @{Server = $serverName; Database = $databaseName; Table=$tableName; RefreshType = $processType}
                                $processExecution.ProcessOrders += $processOrder

                                if (!$alreadyProcessed)
                                {
                                    $table.RequestRefresh($processType, $null)
                                }
                                else
                                {
                                    $processOrder.Skipped = $true
                                    Write-Log "Skipped, already processed in previous execution"
                                }
                            }
                            else
                            {
                                $partitionsToProcess = @($table.Partitions |? {

                                    $partitionName = $_.Name

                                    if ($partitions -contains $partitionName)
                                    {
                                        return $true
                                    }

                                    return $false
                                })


                                $partitionsToProcess |% {

                                    $partitionName = $_.Name

                                    Write-Log "Process '$processType' on partition: '$partitionName', table: '$tableName', database: '$databaseName'"

                                    $alreadyProcessed = @($previousExecutionProcessOrders |? { ($_.ProcessStatus -in @("Processed") -or !$_.Skipped) -and $_.RefreshType -eq $processType -and $_.Server -eq $serverName -and $_.Database -eq $databaseName -and $_.Table -eq $tableName -and $_.Partition -eq $partitionName}).Count -gt 0

                                    $processOrder = @{Server = $serverName; Database = $databaseName; Table=$tableName; Partition = $partitionName; RefreshType = $processType}
                                    
                                    $processExecution.ProcessOrders += $processOrder

                                    if (!$alreadyProcessed)
                                    {
                                        $_.RequestRefresh($processType, $null)      
                                    }
                                    else
                                    {
                                        $processOrder.Skipped = $true
                                        Write-Log "Skipped, already processed in previous execution"
                                    }
                                }
                            }

                        }
                    }


                    $groupMaxParallelism = (@($processOrders |? {$_.MaxParallelism} |% { $_.MaxParallelism }) | Measure -Maximum).Maximum

                    if (!$groupMaxParallelism)
                    {
                        $groupMaxParallelism = $maxParallelism
                    }

                    $processExecution.MaxParallelism = $groupMaxParallelism

                    $xmlaResult = Save-ASDatabaseChanges $database -maxParallelism $groupMaxParallelism

                }
                catch
                {
                    $processError = $_.Exception.ToString()

                    Write-Log "Error processing $processError" -Level Error

                    Undo-ASDatabaseChanges $database | Out-Null
                }
                finally
                {
                    $endTime = [datetime]::UtcNow

                    Write-Log "Time Elapsed: $(($endTime-$startTime).TotalSeconds)s; EndTime: $((Get-Date -Format "yyyy-MM-dd HH:mm:ss.ms").Substring(0, 22))" 
                 
                    if ($processError -eq $null)
                    {
                        if ($processExecution.ProcessOrders.Count -eq 0)
                        {
                            $processStatus = "NoProcessOrders"
                        }
                        else
                        {
                            $processStatus = "Processed"
                        }
                    }
                    else {
                        $processStatus = "Error"
                    }

                    $processExecution.ProcessEndDate = $endTime.ToString("s")
                    $processExecution.ProcessDuration = ($endTime - $startTime).TotalSeconds
                    $processExecution.ProcessError = $processError
                    $processExecution.ProcessStatus = $processStatus
                    
                    if ($executionFilePath)
                    {
                        Write-Log "Saving execution"
                        $executionResult | ConvertTo-Json -Depth 5 | Out-File $executionFilePath
                    }

                    Write-Output $processExecution
                }
            }
        }
    }
    finally
    {
        if ($server)
        {
            $server.Dispose()
        }
    }
}

Function Get-ASTable
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $serverName
        ,
        [Parameter(Mandatory=$true)]
        [string] $databaseName
        ,
        [string] $tableName
               ,
        [string] $username
        ,
        [string] $password
        ,
        [Switch]$includePartitions
    )

    try {

        $server = Connect-ASServer -serverName $serverName -userId $username -password $password

        $database = $server.Databases.GetByName($databaseName)

        $tables = @()

        if (![string]::IsNullOrEmpty($tableName))
        {
            $table = $database.Model.Tables.Find($tableName)

            if (!$table)
            {
                throw "Cannot find table '$tableName'"
            }

            $tables += $table
        }
        else {
            $tables += $database.Model.Tables
        }

        foreach($table in $tables)
        {
            $outputObj = @{
                Name = $table.Name
            }

            if($includePartitions)
            {
                $outputObj.Partitions = @()

                foreach($partition in $table.Partitions)
                {
                    $outputObjPartition = @{
                        "Name" =  $partition.Name
                        ;
                        "RefreshedTime" = $partition.RefreshedTime
                        ;
                        "State" = $partition.State
                        ;
                        "Type" = $partition.SourceType.ToString()
                    }

                    if ($partition.SourceType -eq [Microsoft.AnalysisServices.Tabular.PartitionSourceType]::Query)
                    {
                        $outputObjPartition.Query = $partition.Source.Query
                    }
                    else
                    {
                        $outputObjPartition.Query = $partition.Source.Expression
                    }

                    $outputObj.Partitions += $outputObjPartition
                } 
            }

            Write-Output $outputObj
        }
    }
    finally {

        if ($database)
        {
            $database.Dispose()
        }

        if ($server)
        {
            $server.Dispose()
        }
    }
}

Function Add-ASTablePartition
{
    [CmdletBinding()]
    param
    (
        [string] $serverName     
        ,
        [string] $databaseName
        ,
        [string] $bimFilePath
        ,
        [array] $partitions = @(
        @{   
            TableName = "Table"
            ;
            Partitions = @()
        })
        ,
        [switch] $resetPartitions 
        ,
        [switch] $removeDefaultPartition
        ,
        [string] $username
        ,
        [string] $password      
	)

    try
    {

        Write-Log "Starting AS Partition Creation"

        $server = $null

        if ([string]::IsNullOrEmpty($bimFilePath))
        {
            $server = Connect-ASServer -serverName $serverName -userId $username -password $password

            $database = $server.Databases.GetByName($databaseName)
        }
        elseif (![string]::IsNullOrEmpty($bimFilePath))
        {
            $databaseStr = [IO.File]::ReadAllText($bimFilePath)

            $database = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($databaseStr)
        }        
        else
        {
            throw "Must specify -server & -database or -bimFilePath"
        }

        $partitions | Group-Object { $_.TableName } |% {
        
            $tableName = $_.Name
            $tablePartitions = $_.Group

            $table = $database.Model.Tables.Find($tableName)

            if ($table -eq $null)
            {
                throw "Cannot find table '$tableName'"
            }

            if ($resetPartitions)
            {
                $table.Partitions.Clear();
            }

            # If only has the default partition remove it

            if ($removeDefaultPartition -and $table.Partitions.Count -eq 1 -and $table.Partitions[0].Name.StartsWith("$($table.Name)-"))
            {
                $table.Partitions.Clear();
            }

            $tablePartitions |% {

                $part = $_

                $partition = $table.Partitions.Find($part.Name)

                if ($partition -ne $null)
                {
                    Write-Log "Updating Partition '$($part.Name)' on table '$tableName'"
                }
                else
                {
                    Write-Log "Creating Partition '$($part.Name)' on table '$tableName'"

                    $partition = new-object Microsoft.AnalysisServices.Tabular.Partition

                    $partition.Name = $part.Name

                    $table.Partitions.Add($partition)
                }

                if ($part.Type -eq "M")
                {
                    $source = new-object Microsoft.AnalysisServices.Tabular.MPartitionSource

                    $source.Expression = $part.Query
                }
                elseif($part.Type -eq "Legacy")
                {
                    $source = new-object Microsoft.AnalysisServices.Tabular.QueryPartitionSource

                    $dataSource = $database.Model.DataSources.Find($part.DataSourceName)

                    if ($dataSource -eq $null)
                    {
                        throw "Cannot find datasource '$($part.DataSourceName)', legacy partitions must specify a valid datasource name."
                    }

                    $source.DataSource = $dataSource

                    $source.Query = $part.Query
                }
                else {
                    throw "Invalid partition type: '$($part.Type)'"
                }

                $partition.Source = $source

            }            

            if ($server)
            {
                Save-ASDatabaseChanges $database
            }
            else
            {
                $databaseStr = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($database)

                $databaseStr | Out-File $bimFilePath -Force
            }

        }
    }
    finally
    {
        if ($database)
        {
            $database.Dispose()
        }

        if ($server)
        {
            $server.Dispose()
        }        
    }
}

Function Remove-ASTablePartition
{
    [CmdletBinding()]
    param
    (
        [string]$serverName
        ,
        [string]$databaseName
        ,
        [string]$tableName
        ,
        [array]$partitions = @()
        ,
        [string] $username
        ,
        [string] $password
	)

    try
    {
        $server = Connect-ASServer -serverName $serverName -userId $username -password $password

        $database = $server.Databases.GetByName($databaseName)

        $table = $database.Model.Tables.Find($tableName)

        if ($table -eq $null)
        {
            throw "Cannot find table '$tableName'"
        }

        $partitions |% {

            $partitionName = $_

            $partition = $table.Partitions.Find($partitionName)

            if ($partition -eq $null)
            {
                Write-Log "Cannot find Partition '$partitionName'"
            }

            Write-Log "Removing partition '$partitionName'"

            $table.Partitions.Remove($partitionName)
        }

        Save-ASDatabaseChanges $database

    }
    finally
    {
        if ($server)
        {
            $server.Dispose()
        }
    }
}

Function Get-ASDatabase
{
    [CmdletBinding()]
    param
    (
        [string] $serverName
        ,
        [string] $databaseName
        ,
        [string] $username
        ,
        [string] $password
        ,
        [string] $bimFilePath
	)

    try
    {

        $server = Connect-ASServer -serverName $serverName -userId $username -password $password

        $database = $server.Databases.GetByName($databaseName)

        $databaseStr = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($database)

        $databaseStr | Out-File $bimFilePath -Force
    }
    finally
    {
        if ($server)
        {
            $server.Dispose()
        }
    }
}

Function Get-ASTablePartition
{
    [CmdletBinding()]
    param
    (
        [string] $serverName
        ,
        [string] $databaseName
        ,
        [string] $tableName
        ,
        [string] $username
        ,
        [string] $password
	)

    try
    {

        $server = Connect-ASServer -serverName $serverName -userId $username -password $password

        $database = $server.Databases.GetByName($databaseName)

        $table = $database.Model.Tables.Find($tableName)

        if ($table -eq $null)
        {
            throw "Cannot find table '$tableName'"
        }

        Write-Log "Getting partitions for table '$tableName'"

        $table.Partitions |% {

            $partition = $_

            $outputObj = @{
                "Name" =  $partition.Name
                ;
                "RefreshedTime" = $partition.RefreshedTime
                ;
                "State" = $partition.State
                ;
                "Type" = $partition.SourceType.ToString()
            }

            if ($partition.SourceType -eq [Microsoft.AnalysisServices.Tabular.PartitionSourceType]::Query)
            {
                $outputObj.Query = $partition.Source.Query
            }
            else
            {
                $outputObj.Query = $partition.Source.Expression
            }

            Write-Output $outputObj
        }

    }
    finally
    {
        if ($server)
        {
            $server.Dispose()
        }
    }
}

Function Update-ASDatabase
{
    param
    (
        [string]$serverName
        ,
        [string]$databaseName
        ,
        [string]$bimFilePath
        ,
        [string]$outputFile
        ,
        [switch]$deployToServer = $true
        ,
        [switch]$deployRoles = $false
        ,
        [switch]$deployConnections = $false
        ,
        [switch]$deployPartitions = $false
        ,
        [switch]$deployPartitionsWithRefreshPolicy = $false
        ,
        [hashtable]$dataSourceSettings
        ,
        [hashtable]$parameters
        ,
        [string] $username
        ,
        [string] $password
        ,
        [string] $authToken
        ,
        [System.Text.Encoding] $encoding = [System.Text.Encoding]::Default
	)

    try
    {
        
        Write-Log "Starting AS Deploy of '$databaseName' on '$serverName' from bimfile: '$bimFilePath'"

        $model = [IO.File]::ReadAllText($bimFilePath, $encoding)

        $database = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($model)

        $database.ID = $databaseName
        $database.Name = $databaseName

        if ($parameters)
        {
            $parameters.GetEnumerator() |? {

                $parameterName = $_.Name
                $parameterValue = $_.Value

                $bimParameters = @($database.model.Expressions |? { $_.Name -eq $parameterName })

                if ($bimParameters.Count -gt 1)
                {
                    throw "Found more that one parameter with name '$parameterName'"
                }

                if ($bimParameters.Count -eq 1)
                {
                    Write-Log "Updating parameter '$parameterName' with value '$parameterValue'"

                    $bimParameters[0].Expression = $bimParameters[0].Expression -replace """?(.*)""? meta","""$parameterValue"" meta"
                }
                else
                {
                    Write-Log "Cannot find parameter '$parameterName' in bimfile"
                }
            }   

            # TODO - Check Schema after change
        }

        $tmslScript = [Microsoft.AnalysisServices.Tabular.JsonScripter]::ScriptCreateOrReplace($database, $true)

        $tmslObj = [Newtonsoft.Json.Linq.JObject]::Parse($tmslScript)

        $tmslModel = $tmslObj["createOrReplace"]["database"]["model"]

        $server = Connect-ASServer -serverName $serverName -userId $username -password $password -authToken $authToken

        $currentDatabase = $server.Databases.FindByName($databaseName)

        if ($currentDatabase -ne $null)
        {
            $tmslObj["createOrReplace"]["object"]["database"].Value = $currentDatabase.Name

            $tmslObj["createOrReplace"]["database"].Add("id", [Newtonsoft.Json.Linq.JValue]::CreateString($currentDatabase.ID))

            $tmslObj["createOrReplace"]["database"]["name"].Value = $currentDatabase.Name

            # if !deployRoles then remove the ones on bim and add the existing ones

            if (!$deployRoles)
            {
                Write-Log "Keeping roles in the current DB"

                $rolesArray = [Newtonsoft.Json.Linq.JArray]::new()

                foreach($role in $currentDatabase.Model.Roles)
                {
                    $json = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeObject($role)

                    $rolesArray.Add([Newtonsoft.Json.Linq.JObject]::Parse($json))
                }

                if (!$tmslModel["roles"])
                { 
                    $tmslModel.Add("roles", $rolesArray)
                }
                else
                {
                    $tmslModel["roles"] = $rolesArray
                }
            
            }

            if (!$deployConnections)
            {
                Write-Log "Keeping the current connections"

                if ($currentDatabase.Model.DataSources -and $currentDatabase.Model.DataSources.Count -ne 0)
                {
                    $dataSourcesArray = [Newtonsoft.Json.Linq.JArray]::new()

                    foreach($dataSource in $currentDatabase.Model.DataSources)
                    {
                        $json = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeObject($dataSource)

                        $dataSourcesArray.Add([Newtonsoft.Json.Linq.JObject]::Parse($json))
                    }

                    if (!$tmslModel["dataSources"])
                    { 
                        $tmslModel.Add("dataSources", $dataSourcesArray)
                    }
                    else
                    {
                        $tmslModel["dataSources"] = $dataSourcesArray
                    }
                }
            }


            # Partitions

            foreach($table in $tmslModel["tables"])
            {
                $tableName = $table["name"].Value

                if ($currentDatabase.Model.Tables.Contains($tableName))
                {
                    $currentTable = $currentDatabase.Model.Tables[$tableName]

                    # Keeps database partitions only if is asked to or the table as a refresh policy (incremental refresh)

                    if (!$deployPartitions -or ($currentTable.RefreshPolicy -and !$deployPartitionsWithRefreshPolicy))
                    {
                        if ($currentTable.RefreshPolicy)
                        {
                            Write-Log "Keeping the existent partitions on table '$tableName' because it has a refreshpolicy"
                        }
                        else
                        {
                            Write-Log "Keeping the existent partitions on table '$tableName'"
                        }
                        
                        $partitionsArray = [Newtonsoft.Json.Linq.JArray]::new()

                        foreach($partition in $currentTable.Partitions)
                        {
                            $json = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeObject($partition)

                            $partitionsArray.Add([Newtonsoft.Json.Linq.JObject]::Parse($json))
                        }
 
                        $table["partitions"] = $partitionsArray

                    }
                    else
                    {
                        Write-Log "Overriding partitions on table '$tableName'"
                    }

                }
            }
       
        }

        if ($dataSourceSettings)
        {
            Write-Log "Overriding DataSource settings"

            foreach($jsonObj in $tmslModel["dataSources"])
            {
                $dataSourceSettings.Keys |% {

                    $dsName = $_

                    # If the DataSource name matches apply the configuration

                    if ($jsonObj["name"].Value -eq $dsName)
                    {
                        $dsObj = $dataSourceSettings[$dsName]

                        if ($dsObj.ContainsKey("CredentialPassword"))
                        {
                            Write-Log "Setting CredentialPassword for datasource '$dsName'"
                            
                            $jsonObj["credential"].Add("Password", [Newtonsoft.Json.Linq.JValue]::CreateString($dsObj["CredentialPassword"])) 
                        }

                        if ($dsObj.ContainsKey("CredentialUsername"))
                        {
                            Write-Log "Setting CredentialUsername for datasource '$dsName'"
                        
                            $jsonObj["credential"]["Username"] = [Newtonsoft.Json.Linq.JValue]::CreateString($dsObj["CredentialUsername"])
                        }

                        if ($dsObj.ContainsKey("ConnectionString"))
                        {
                            Write-Log "Setting ConnectionString for datasource '$dsName'"

                            $jsonObj["connectionString"] = [Newtonsoft.Json.Linq.JValue]::CreateString($dsObj["ConnectionString"])
                        }

                        if ($dsObj.ContainsKey("Server"))
                        {
                            Write-Log "Setting server for datasource '$dsName'"

                            $jsonObj["connectionDetails"]["address"]["server"] = [Newtonsoft.Json.Linq.JValue]::CreateString($dsObj["Server"])
                        }

                        if ($dsObj.ContainsKey("Database"))
                        {
                            Write-Log "Setting Database for datasource '$dsName'"

                            $jsonObj["connectionDetails"]["address"]["database"] = [Newtonsoft.Json.Linq.JValue]::CreateString($dsObj["Database"])
                        }
                    }

                }
            }
        }

        $deployTmslScript = $tmslObj.ToString()
    
        # Write XMLA to disk

        if (![string]::IsNullOrEmpty($outputFile))
        {
            # ensure directory exists 

            New-Item -Path $outputFile -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null

            Write-Log "Writing output file: '$outputFile'"

            $deployTmslScript | Out-File $outputFile -Force

        }

        if ($deployToServer)
        {
            Write-Log "Deploying '$databaseName' on '$server'"

            $result = $server.Execute($deployTmslScript)

            if ($result.ContainsErrors -eq $true)
            {
                $strErrors = ""

                # Get Messages

                $nl = [System.Environment]::NewLine

                foreach($xr in $result.Messages)
                {
                    $strErrors += $xr.Description
                    $strErrors += $nl
                }

                throw "Error executing Deploy to Server: $($nl)$($strErrors)"
            }
        }
        else
        {
            Write-Log "Skipping deploy to '$databaseName' on '$server'"
        }

    }
    finally
    {
        if ($currentDatabase)
        {
            $currentDatabase.Dispose()
        }

        if ($server)
        {
            $server.Dispose()
        }
    }
}

Function Connect-ASServer
{
    [CmdletBinding()]
    param
    (
        [string]$serverName,
        [string]$userId,
        [string]$password,
        [string]$authToken
	)

    Write-Log "Connecting to server '$serverName'"

    $server = New-Object Microsoft.AnalysisServices.Tabular.Server

    $connStr = "DataSource=$serverName"

    if (![string]::IsNullOrEmpty($authToken))
    {
        $connStr += ";User ID=;Password=$authToken"
    }
    elseif (![string]::IsNullOrEmpty($userId) -and ![string]::IsNullOrEmpty($password))
    {
        $connStr += ";User ID=$userId;Password=$password"
    }

    $server.Connect($connStr)

    $server

}


Function Save-ASDatabaseChanges
{
    [CmdletBinding()]
    param
    (
        [Microsoft.AnalysisServices.Tabular.Database]$database
        , [int] $maxParallelism = 5
        , [Microsoft.AnalysisServices.Tabular.SaveFlags] $flags = [Microsoft.AnalysisServices.Tabular.SaveFlags]::Default
	)

    if ($database.Model.HasLocalChanges)
    {
        Write-Log "Saving Changes with MaxParallelism of '$maxParallelism'"

        $saveOptions = New-Object "Microsoft.AnalysisServices.Tabular.SaveOptions"
        $saveOptions.MaxParallelism = $maxParallelism
        $saveOptions.SaveFlags = $flags

        $database.Model.SaveChanges($saveOptions)

        # Using Reflection because of the error 'invalid type for a default value': https://social.technet.microsoft.com/Forums/azure/en-US/607674fa-9f67-4750-8584-5c396d58460d/trying-process-tabular-1400-amo-powershell?forum=sqlanalysisservices

        #$method = $asModelType.GetMethod("SaveChanges", ([Reflection.BindingFlags] "Public,Instance"), $null, [Reflection.CallingConventions]::Any, @([Microsoft.AnalysisServices.Tabular.SaveOptions]), $null)

        #$method.Invoke($database.Model, $saveOptions)
    }
    else
    {
         Write-Log "No changes on database $($database.Name)"
    }
}


Function Undo-ASDatabaseChanges
{
    [CmdletBinding()]
    param
    (
        [Microsoft.AnalysisServices.Tabular.Database]$database
	)

    try
    {
        if ($database.Model.HasLocalChanges)
        {
            Write-Log "Undo Changes"

            $database.Model.UndoLocalChanges()

            #$method = $asModelType.GetMethod("UndoLocalChanges", ([Reflection.BindingFlags] "Public,Instance"), $null, [Reflection.CallingConventions]::Any, @(), $null)

            #$method.Invoke($database.Model)
        }
        else
        {
             Write-Log "No changes on database $($database.Name)"
        }
    }
    catch
    {
        Write-Log "Error on UndoLocalChanges(): $($_.Exception.Message)" -Level Error
    }


}

function Write-Log
{
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)][string]$Message
		, [Parameter(Mandatory=$false)][ValidateSet("Log", "Warning", "Error", "Debug")] [string]$Level = "Debug"
	)

	try
	{
		# Format the message	
	
		$now = [datetime]::UtcNow

		$formattedMessage = "$($now.ToString(""yyyy-MM-dd HH:mm:ss"")) | $Message"
		 
        if($script:AzureDevOpsLogs)
        {
            $devopsLog = "debug"

            if ($Level -in @("Error"))
            {
                $devopsLog = "error"
            }
            elseif($Level -in @("Warning"))
            {
                $devopsLog = "Warning"
            }

            $formattedMessage = "##[$devopsLog] $formattedMessage"
        }
        else
        {
            $formattedMessage = "$Level | $formattedMessage"
        }

        if ($Level -eq "Error")
        {
            Write-Host $formattedMessage -ForegroundColor Red
        }
        elseif($Level -eq "Warning")
        {
            Write-Host $formattedMessage -ForegroundColor Yellow
        }
        else
        {
            Write-Host $formattedMessage 
        }              
	}
	catch
	{
		Write-Host ("Error Writing to Log: '{0}'" -f $_.ToString())
	}	
}