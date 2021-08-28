#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Get the current folder of the running script

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

$workspaceId = "833acf64-db3c-48bf-818e-6f5f998e4734"
$datasetOperatorsName = "StreamingDataset - Calls - Operators"
$datasetTotalsName = "StreamingDataset - Calls - Totals"

# README - If the dataset is recreated these endpoints must be obtained from the stream dataset settings
$datasetOperatorsEndpoint = "https://api.powerbi.com/beta/3a364c67-349a-484d-8dcb-873c88970c00/datasets/2d5649fb-d841-4b2b-b7fd-d39e3998e76a/rows?key=RR3MP307efubWI9DiC%2FUjoXspeMjda%2B9p%2BWB8EM755tuPl7h2ZgEnx4CWsszxubozDdALTZSAGzjkd7MQZzcgQ%3D%3D"
$datasetTotalsEndpoint = "https://api.powerbi.com/beta/3a364c67-349a-484d-8dcb-873c88970c00/datasets/56a56cfa-3210-4289-824c-a1728d16fb2f/rows?key=M8uWKTpjmPFN4UicLhdKWsl3jKjRFfhNcVwr%2BZnNqIBBhx7PUQEKGoDolYuxVAE5Eip4UpdFM0RpBRhjaA6LkQ%3D%3D"

Connect-PowerBIServiceAccount

$streamingDatasets = @(
        @{
			name = $datasetOperatorsName
            ; defaultMode = "Streaming"
		    ; tables = @(
				@{ 	name = $datasetOperatorsName
					; columns = @( 
						@{ name = "Timestamp"; dataType = "DateTime"  }
						, @{ name = "Operator"; dataType = "String"  }
						, @{ name = "WaitingTime"; dataType = "Int64"  }						
						) 
				}            
			)                        	
		}
        ,@{
			name = $datasetTotalsName
            ; defaultMode = "Streaming"	
		    ; tables = @(
				@{ 	name = $datasetTotalsName
					; columns = @( 
						@{ name = "Timestamp"; dataType = "DateTime"  }
						, @{ name = "WaitingCalls"; dataType = "Int64"  }
						, @{ name = "AnsweringCalls"; dataType = "Int64"  }						
                        , @{ name = "TotalAnsweringCalls"; dataType = "Int64"  }
                        , @{ name = "TotalAnsweringCallsTarget"; dataType = "Int64"  }
						) 
				}            
			)            
		}	
)

foreach($streamingDataset in $streamingDatasets)
{
    $dataset = Get-PowerBIDataset -WorkspaceId $workspaceId |? Name -eq $streamingDataset.name

    if (!$dataSet)
    {
        $bodyStr = $streamingDataset | ConvertTo-Json -Depth 5

	    $result = Invoke-PowerBIRestMethod -method Post -url "groups/$workspaceId/datasets" -body $bodyStr
    }
    else
    {
        Write-Host "Dataset '$($dataset.name)' already created"
    }
}

Write-Host "Pushing Data"

$totalCalls = 0

while($true)
{
    
    Write-Host "Pushing to 'CallCenter.Calls.Totals'"

    $totalCalls += (Get-Random -Minimum 1 -Maximum 10)

    $payload = @{
        Timestamp = get-date -Format "u"
        WaitingCalls = (Get-Random -Minimum 0 -Maximum 10)
        AnsweringCalls =(Get-Random -Minimum 0 -Maximum 50)
        TotalAnsweringCalls = $totalCalls
        TotalAnsweringCallsTarget = 400
    }

    Invoke-RestMethod -Method Post -Uri $datasetTotalsEndpoint -Body (ConvertTo-Json @($payload))

    Write-Output "Pushing to 'CallCenter.Calls'"

    $operators = @("Rui Romano", "Rui Quintino", "Bruno Ferreira", "Joana Barbosa", "Jose Barbosa", "Ricardo Santos", "Rui Barbosa", "Ricardo Calejo")

    $timestamp = get-date -Format "u"
       
    $payload = $operators | get-random -Count (Get-Random -Minimum 1 -Maximum 3) |%{

        $waitOperator = $_
         
        @{
            Timestamp = $timestamp
            Operator = $waitOperator
            WaitingTime = (Get-Random -Minimum 60 -Maximum 360)           
        }       
    }   

    Invoke-RestMethod -Method Post -Uri $datasetOperatorsEndpoint -Body (ConvertTo-Json @($payload))

    Write-Output "Sleeping..."

    Start-Sleep -Seconds 1
}

