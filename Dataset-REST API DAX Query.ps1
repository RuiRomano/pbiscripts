#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$datasetId = "4425e7b6-fa28-48d9-8cdd-a5bfd62c93ab"
$query = "EVALUATE
	
	VAR p_currentDate = dt""2016-01-22""
	
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
