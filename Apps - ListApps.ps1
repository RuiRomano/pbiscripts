#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

# Get the authentication token using ADAL library (OAuth)

Connect-PowerBIServiceAccount

# Artifacts

$result = Invoke-PowerBIRestMethod -method Get -url "admin/apps?`$top=1000" | ConvertFrom-Json | Select -ExpandProperty value

$result | Format-Table

Write-Host "App Users"

foreach ($app in $result)
{
    Write-Host "App '$($app.id)' users:"

    $users = Invoke-PowerBIRestMethod -method Get -url "admin/apps/$($app.id)/users" | ConvertFrom-Json | Select -ExpandProperty value

    $users | Format-Table
}