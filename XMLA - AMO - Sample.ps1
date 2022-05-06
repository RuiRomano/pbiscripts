cls

$serverName = "Data Source=powerbi://api.powerbi.com/v1.0/myorg/Contoso"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

if ($PSVersionTable.PSVersion.Major -le 5) {
    $nugetName = "Microsoft.AnalysisServices.retail.amd64"
    $nugetVersion = "19.39.2.2"

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
    $nugetVersion = "4.6.0"

    if (!(Test-Path "$currentPath\Nuget\$nugetName.$nugetVersion" -PathType Container)) {
        Install-Package -Name $nugetName -ProviderName NuGet -Scope CurrentUser -RequiredVersion $nugetVersion -SkipDependencies -Destination "$currentPath\Nuget" -Force
    }

    $dllPath = "$currentPath\Nuget\$nugetName.$nugetVersion\lib\netcoreapp2.1\Microsoft.Identity.Client.dll"

    Add-Type -Path $dllPath

    $nugetName = "Microsoft.AnalysisServices.NetCore.retail.amd64"
    $nugetVersion = "19.39.2.2"

    if (!(Test-Path "$currentPath\Nuget\$nugetName.$nugetVersion" -PathType Container)) {
        Install-Package -Name $nugetName -ProviderName NuGet -Scope CurrentUser -RequiredVersion $nugetVersion -SkipDependencies -Destination "$currentPath\Nuget" -Force
    }

    $dllPath = "$currentPath\Nuget\$nugetName.$nugetVersion\lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.dll"

    Add-Type -Path $dllPath
}

$asModelType = [Microsoft.AnalysisServices.Tabular.Model]

$assembly = $asModelType.Assembly

Write-Host "Assembly version loaded: '$($assembly.FullName)' from '$($assembly.Location)'"

try
{    
    Write-Host "Connecting to Server: '$serverName'"

    $server = New-Object Microsoft.AnalysisServices.Tabular.Server
    
    $server.Connect($serverName)

    Write-Host "Connected"

    $tables = $server.Databases[0].Model.Tables

    foreach($table in $tables)
    {
        Write-Host "$($table.Name)"
    }

}
finally
{
    if($server)
    {
        $server.Dispose()
    }
}
                        


