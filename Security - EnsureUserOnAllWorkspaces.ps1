#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt.Profile"; ModuleVersion="1.2.1026" }
#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt.Workspaces"; ModuleVersion="1.2.1026" }

param(            
    # See more examples here: https://learn.microsoft.com/en-us/rest/api/power-bi/admin/groups-add-user-as-admin
    $identity = "5922c898-2076-4695-a4a3-953e8a62c1a7",        
    $identityType = "App", 
    # $identity = "user@company.com",
    # $identityType = "User", 
    $workspaceRole = "Member",
    $workspaceFilter = @() # @("28544d33-de5f-49cf-8e45-a2a8784fe31f", "d0641e3b-a0c6-404b-a422-afe7be6b2a4f")
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

try
{
    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $stopwatch.Start()

    $currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

    Set-Location $currentPath

    # Get token with admin account

    Connect-PowerBIServiceAccount

    # Get all tenant workspaces    

    $workspaces = Get-PowerBIWorkspace -Scope Organization -All

    Write-Host "Workspaces: $($workspaces.Count)"
     
    # Only look at active workspaces and V2

    $workspaces = @($workspaces |? {$_.type -eq "Workspace" -and $_.state -eq "Active"})

    if ($workspaceFilter -and $workspaceFilter.Count -gt 0)
    {
        $workspaces = @($workspaces |? { $workspaceFilter -contains $_.Id})
    }

    # Filter workspaces where the serviceprincipal is not there

    $workspaces = $workspaces |? {
        
        $members = @($_.users |? { $_.identifier -eq $identity })
       
        if ($members.Count -eq 0)
        {
            $true
        }
        else
        {
            $false
        }
    }    

    Write-Host "Workspaces to set security: $($workspaces.Count)"        

    foreach($workspace in $workspaces)
    {  
        Write-Host "Adding service principal to workspace: $($workspace.name) ($($workspace.id))"

        $body = @{
            "identifier" = $identity
            ;
            "groupUserAccessRight" = $workspaceRole
            ;
            "principalType" = $identityType
        }

        $bodyStr = ($body | ConvertTo-Json)
        
        Invoke-PowerBIRestMethod -method Post -url "admin/groups/$($workspace.id)/users" -body $bodyStr
    }

}
finally
{
    $stopwatch.Stop()

    Write-Host "Ellapsed: $($stopwatch.Elapsed.TotalSeconds)s"
}
