param (
$serverName = "powerbi://api.powerbi.com/v1.0/myorg/Session%20-%20PBI%20on%20Steroids"
, $databaseName = "WWI - Sales (Partitioned)"
, $years = (2013..2016)
)

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Import-Module "$currentPath\Modules\ASTabularHelper" -Force

$partitions = @(    
    @{
        TableName = "Sales"
        ;
        Partitions = @($years |% {
                $year = $_

                foreach($month in (1..12))
                {                   
                    $partitionName = "Sales_$($year)_$($month.ToString().PadLeft(2,"0"))"

                    @{
                    Name = $partitionName
                    ;
                    Type = "M"
                    ;
                    Query = "let
                        Source = Sql.Database(Server, Database, [Query=""
                        SELECT
                            [Sale Key]
                            ,[City Key]
                            ,[Customer Key]
                            ,[Bill To Customer Key]
                            ,[Stock Item Key]
                            ,[Invoice Date Key]
                            , case when (ABS(CAST(CAST(NEWID() AS VARBINARY) AS INT)) % 10) > 5 then 
                                  DATEADD(DAY, ABS(CAST(CAST(NEWID() AS VARBINARY) AS INT)) % 300, [Invoice Date Key]) else 
                                  null end 
                                  [Invoice Paid Date Key]
                            ,[Delivery Date Key]
                            , e.[WWI Employee ID] [Employee Key]       
                            ,[Quantity]      
	                        ,[Unit Price]
	                        ,[Total Excluding Tax] [Total Amount]
                            ,[Tax Amount] 	  
                            ,[Profit]	  	        	 
                            FROM [Fact].[Sale] s
                                left join [Dimension].[Employee] e on e.[Employee Key] = s.[Salesperson Key]                            
                            WHERE year([Invoice Date Key]) = $year and month([Invoice Date Key]) = $month""])
                    in
                        Source"
                    }
                }

            })        
    } 
    ,
    @{
        TableName = "Orders"
        ;
        Partitions = @($years |% {
                $year = $_

                $partitionName = "Orders_$($year)"

                @{
                Name = $partitionName
                ;
                Type = "M"
                ;
                Query = "let
                    Source = Sql.Database (Server, Database),
                    Table = Source{[Schema=""Fact"",Item=""Order""]}[Data],
                    #""Filtered Rows"" = Table.SelectRows(Table, each Date.Year([Order Date Key]) = $year),
                    KeepColumns = Table.SelectColumns(#""Filtered Rows"",{""Order Date Key"", ""City Key"", ""Customer Key"", ""Stock Item Key"", ""Salesperson Key"", ""Quantity"", ""Unit Price"", ""Tax Rate"", ""Total Excluding Tax"", ""Tax Amount"", ""Total Including Tax""})
                in
                    KeepColumns"
                }

            })        
    }          
    ,
    @{
        TableName = "Transactions"
        ;
        Partitions = @($years |% {
                $year = $_   

                $partitionName = "Transactions_$($year)"

                @{
                Name = $partitionName
                ;
                Type = "M"
                ;
                Query = "let
                    Source = Sql.Database(Server, Database),
                    Table = Source{[Schema=""Fact"",Item=""Transaction""]}[Data],
                    #""Expanded Dimension.Payment Method"" = Table.ExpandRecordColumn(Table, ""Dimension.Payment Method"", {""Payment Method""}, {""Dimension.Payment Method.Payment Method""}),
                    #""Filtered Rows"" = Table.SelectRows(#""Expanded Dimension.Payment Method"", each Date.Year([Date Key]) = $year),
                    KeepColumns = Table.SelectColumns(#""Filtered Rows"",{""Date Key"", ""Dimension.Payment Method.Payment Method"", ""Customer Key"", ""Bill To Customer Key"", ""Supplier Key"", ""Transaction Type Key"", ""Payment Method Key"", ""Total Excluding Tax"", ""Total Including Tax"", ""Is Finalized""}),
                    #""Changed Type"" = Table.TransformColumnTypes(KeepColumns,{{""Total Including Tax"", Currency.Type}, {""Total Excluding Tax"", Currency.Type}}),
                    #""Renamed Columns"" = Table.RenameColumns(#""Changed Type"",{{""Dimension.Payment Method.Payment Method"", ""Payment Method""}})
                in
                    #""Renamed Columns"""
                }

            })        
    } 
    ,
    @{
        TableName = "Purchases"
        ;
        Partitions = @($years |% {
                
                $year = $_
 
                $partitionName = "Purchases_$($year)"

                @{
                Name = $partitionName
                ;
                Type = "M"
                ;
                Query = "let  
                        Source = Sql.Database(Server, Database),
                        Fact_Purchase = Source{[Schema=""Fact"",Item=""Purchase""]}[Data],
                        #""Filtered Rows"" = Table.SelectRows(Fact_Purchase, each Date.Year([Date Key]) = $year),
                        #""Removed Other Columns"" = Table.SelectColumns(#""Filtered Rows"",{""Purchase Key"", ""Date Key"", ""Supplier Key"", ""Stock Item Key"", ""Ordered Quantity"", ""Is Order Finalized""}),
                        #""Renamed Columns"" = Table.RenameColumns(#""Removed Other Columns"",{{""Date Key"", ""Purchase Date Key""}})
                    in
                        #""Renamed Columns"""
                }

            })        
    } 
      
)

$results = Add-ASTablePartition -serverName $serverName -databaseName $databaseName -partitions $partitions -removeDefaultPartition -Verbose

$results