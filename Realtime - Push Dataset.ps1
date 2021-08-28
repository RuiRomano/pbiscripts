#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

# parameters

# https://app.powerbi.com/groups/8e953ff5-38fa-4b9e-9e63-1b897f2f005b/dashboards/172c4f21-b41a-42eb-8356-e616bec80fcd?ctid=3a364c67-349a-484d-8dcb-873c88970c00

$workspaceId = "833acf64-db3c-48bf-818e-6f5f998e4734"
$datasetName = "PushDataSet - Server Counters"
$reset = $true
$computers = @($env:COMPUTERNAME)

# Get the authentication token using ADAL library (OAuth)

Connect-PowerBIServiceAccount

# Dataset Schema

$dataSetSchema = @{name = $datasetName
    ; defaultMode = "Push"
    ; tables = @(
        @{name = "Counters"
	    ; columns = @( 
		        @{ name = "ComputerName"; dataType = "String"; isHidden = "true"  }
		        , @{ name = "TimeStamp"; dataType = "DateTime"  }	
				, @{ name = "CounterSet"; dataType = "String"  }
		        , @{ name = "CounterName"; dataType = "String"  }
		        , @{ name = "CounterValue"; dataType = "Double"  }
		        )        
        }
		, 
		@{name = "Computers"
	    ; columns = @( 
		        @{ name = "ComputerName"; dataType = "String"  }
		        , @{ name = "Domain"; dataType = "string"  }	
				, @{ name = "Manufacturer"; dataType = "string"  }		        		        			
		        )
        ;measures = @(
            @{name="Average CPU"; expression="CALCULATE(AVERAGE('Counters'[CounterValue]) / 100, FILTER('Counters', 'Counters'[CounterSet] = ""Processor(_Total)"" && 'Counters'[CounterName] = ""% Processor Time""))"; formatString="0.00%"}
           )
        }
        )
    ; relationships = @(
        @{
            name = [guid]::NewGuid().ToString()
          ; fromTable = "Computers"
          ; fromColumn = "ComputerName"
          ; toTable = "Counters"
          ; toColumn = "ComputerName"
          ; crossFilteringBehavior = "oneDirection"      

        })
    }


$dataset = Get-PowerBIDataset -WorkspaceId $workspaceId |? Name -eq $datasetName

if (!$dataset)
{
    Write-Host "Creating dataset"

    $bodyStr = $dataSetSchema | ConvertTo-Json -Depth 5

	$result = Invoke-PowerBIRestMethod -method Post -url "groups/$workspaceId/datasets?defaultRetentionPolicy=basicFIFO" -body $bodyStr

    $dataset = $result | ConvertFrom-Json
		
	Write-Verbose "DataSet created with id: '$($result.id)"
}
else
{    Write-Host "Dataset already created"}

$datasetId = $dataset.Id

if ($reset)
{
    Write-Host "Clearing table rows"

    @("Counters","Computers") |% {
        $tableName = $_
        Invoke-PowerBIRestMethod -method Delete -url "groups/$workspaceId/datasets/$datasetId/tables/$tableName/rows"    
    }
}

# Push Data

# Get Computer Info

Write-Host "Writing Computers data"

$computersInfo = $computers |% {
    
    $computerInfo = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $_

    Write-Output @{
        ComputerName = $_
        ; Domain = $computerInfo.Domain
        ; Manufacturer = $computerInfo.Manufacturer
    }       
}

$bodyStr = @{rows = @($computersInfo)} | ConvertTo-Json

Invoke-PowerBIRestMethod -method Post -url "groups/$workspaceId/datasets/$datasetId/tables/Computers/rows" -body $bodyStr | Out-Null

# Collect data from continuosly in intervals of 5 seconds

Write-Host "Writing Counter Data"

$counters = Get-Counter -ComputerName $computers -ListSet @("processor", "memory", "physicaldisk")

$counters | Get-Counter -Continuous -SampleInterval 5 |%{		
	
	# Parse the Counters into the schema of the PowerBI dataset
	
	$pbiData = $_.CounterSamples | Select  @{Name = "ComputerName"; Expression = {$_.Path.Split('\')[2]}} `
			, @{Name="TimeStamp"; Expression = {$_.TimeStamp.ToString("yyyy-MM-dd HH:mm:ss")}} `
			, @{Name="CounterSet"; Expression = {$_.Path.Split('\')[3]}} `
			, @{Name="CounterName"; Expression = {$_.Path.Split('\')[4]}} `
			, @{Name="CounterValue"; Expression = {$_.CookedValue}}
			
    
    $bodyStr = @{rows = @($pbiData)} | ConvertTo-Json

    Invoke-PowerBIRestMethod -method Post -url "groups/$workspaceId/datasets/$datasetId/tables/Counters/rows" -body $bodyStr | Out-Null	      
	
	Write-Output "Sleeping..."
}


