#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$datasetId = "0ed822d8-46c5-4132-8dfc-0b813e126e06"

$outputPath = "$currentPath\output"

$date = [datetime]"2016-01-22"

$query = "EVALUATE
	
	VAR p_currentDate = dt""$($date.ToString("yyyy-MM-dd"))""
	
	return 
		FILTER(
			SUMMARIZECOLUMNS(
			'Employee'[Employee]			
			, TREATAS({p_currentDate}, 'Calendar'[Date])
			, ""Sales Amount"", [Sales Amount]
			, ""Sales Qty"", [Sales Qty]
			, ""Sales Profit"", [Sales Profit]
			, ""Sales Amount vs LY"", [% Sales Amount vs ly]
			)
		, [Sales Amount vs LY] < 0)"


Connect-PowerBIServiceAccount

$body = @{
    "queries" = @(
        @{               
            "query" = $query

            ;
            "includeNulls" = $false
        }
    )
}

$bodyStr = $body | ConvertTo-Json

$result = Invoke-PowerBIRestMethod -url "datasets/$datasetId/executeQueries" -body $bodyStr -method Post | ConvertFrom-Json

$result.results[0].tables[0].rows | Format-Table

New-Item -ItemType Directory -Path $outputPath -ErrorAction SilentlyContinue | Out-Null

$result.results[0].tables[0].rows | ConvertTo-Csv -NoTypeInformation | Out-File ("$outputPath\{0:yyyyMMdd}_DAXQuery.csv" -f [datetime]::UtcNow)
