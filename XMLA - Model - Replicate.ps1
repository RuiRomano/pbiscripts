param (
$sourceWorkspace = "powerbi://api.powerbi.com/v1.0/myorg/Demo%20-%20XMLA%20Replicate%20Dataset"
,
$targetWorkspaces = @(
    "powerbi://api.powerbi.com/v1.0/myorg/Demo%20-%20XMLA%20Replicate%20Dataset%201"
    ,
    "powerbi://api.powerbi.com/v1.0/myorg/Demo%20-%20XMLA%20Replicate%20Dataset%202"
    ,
    "powerbi://api.powerbi.com/v1.0/myorg/Demo%20-%20XMLA%20Replicate%20Dataset%203"
)
, 
$databaseName = "WWI-Model"
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

Import-Module "$currentPath\TOMHelper.psm1" -Force

$bimFilePath = "$currentPath\output\$databaseName.bim" 

New-Item -ItemType Directory -Path (Split-Path $bimFilePath -Parent) -ErrorAction SilentlyContinue | Out-Null

# Get the bim file from the workspace

Get-ASDatabase -serverName $sourceWorkspace -databaseName $databaseName -bimFilePath $bimFilePath

foreach ($targetWorkspace in $targetWorkspaces)
{
    Write-Host "Deploying to workspace '$targetWorkspace'"

    $bimJson = Get-Content $bimFilePath | ConvertFrom-Json
    
    # For simplicity, this should be a configuration

    if ($targetWorkspace.EndsWith("1"))
    {
        $states = @("Texas", "Pennsylvania")
    }
    elseif($targetWorkspace.EndsWith("2"))
    {
        $states = @("Florida", "New York")
    }
    else
    {
        $states = @("California", "Colorado")
    }
   
    $statesFilterStr = ($states |% {"'$_'"}) -join ","

    $partitions = @(    
        @{
            TableName = "Sales"
            ;
            Partitions = @(
                    @{
                    Name = "Sales"
                    ;
                    Type = "M"
                    ;
                    Query = "let
                        Source = Sql.Database(Server, Database, [Query=""
                        SELECT
		                        [Sale Key]
		                        , s.[City Key]
		                        ,[Customer Key]
		                        ,[Bill To Customer Key]
		                        ,[Stock Item Key]
		                        ,[Invoice Date Key]
		                        , case when (ABS(CAST(CAST(NEWID() AS VARBINARY) AS INT)) % 10) > 5 then 
			                        DATEADD(DAY, ABS(CAST(CAST(NEWID() AS VARBINARY) AS INT)) % 300, [Invoice Date Key]) else 
			                        null end 
			                        [Invoice Paid Date Key]
		                        ,[Delivery Date Key]
		                        , s.[Salesperson Key] [Employee Key]       
		                        ,[Quantity]      
		                        ,[Unit Price]
		                        ,[Total Excluding Tax] [Total Amount]
		                        ,[Tax Amount] 	  
		                        ,[Profit]	  	        	 
	                        FROM [Fact].[Sale] s
	                        left join [Dimension].[City] c on c.[City Key] = s.[City Key]
	                        where c.[State Province] in  ($statesFilterStr)""])
                    in
                        Source"
                    }
            )        
        } 
    )

    # Change the partition in the local BIM file

    Add-ASTablePartition -bimFilePath $bimFilePath -partitions $partitions -removeDefaultPartition -Verbose

    # Deploy/Update the database in the target workspace

    Update-ASDatabase -serverName $targetWorkspace -databaseName $databaseName -bimFilePath $bimFilePath -deployPartitions:$true -deployRoles:$false -deployConnections:$false

    # Process/Refresh the dataset

    Invoke-ASTableProcess -tables @(@{Server = $targetWorkspace; DatabaseName = $databaseName}) -maxParallelism 6
}

