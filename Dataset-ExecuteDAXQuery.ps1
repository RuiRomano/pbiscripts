#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$outputPath = "$currentPath\output"

$relativeDate = [datetime]"2016-01-22"

$queries = @(
	@{
		DatasetId = "0ed822d8-46c5-4132-8dfc-0b813e126e06"
		;
		QueryName = "EmployeesWithLessSales"
		;
		Query = "EVALUATE
	
		VAR p_currentDate = dt""$($relativeDate.ToString("yyyy-MM-dd"))""
		
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
	}
	,
	@{
		DatasetId = "0ed822d8-46c5-4132-8dfc-0b813e126e06"
		;
		QueryName = "Employees"
		;
		Query = "EVALUATE 'Employee'"
	}
)

Connect-PowerBIServiceAccount

foreach ($query in $queries)
{
	Write-Host "Executing query: $($query.QueryName)"

	$body = @{
		"queries" = @(
			@{               
				"query" = $query.Query

				;
				"includeNulls" = $false
			}
		)
	}

	$bodyStr = $body | ConvertTo-Json

	$result = Invoke-PowerBIRestMethod -url "datasets/$($query.DatasetId)/executeQueries" -body $bodyStr -method Post | ConvertFrom-Json

	$result.results[0].tables[0].rows | Format-Table

	$outputFile = ("$outputPath\{0:yyyyMMdd}\$($query.QueryName).csv" -f [datetime]::UtcNow)

	New-Item -ItemType Directory -Path (Split-Path $outputFile -Parent) -ErrorAction SilentlyContinue | Out-Null
	
	$result.results[0].tables[0].rows | ConvertTo-Csv -NoTypeInformation | Out-File $outputFile

}


