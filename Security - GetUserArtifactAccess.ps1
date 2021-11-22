#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

# Object Id from Azure AD
$userGraphId = "1e399999-ee51-4ebb-9c84-7adb562d1074"

# Get the authentication token using ADAL library (OAuth)

Connect-PowerBIServiceAccount

# Artifacts

$result = Invoke-PowerBIRestMethod -method Get -url "admin/users/$userGraphId/artifactAccess" | ConvertFrom-Json

$artifactAccessEntities = @()

$artifactAccessEntities += @($result.ArtifactAccessEntities)

while($result.continuationToken -ne $null)
{          
    $result = Invoke-PowerBIRestMethod -Url $result.continuationUri -method Get | ConvertFrom-Json
                                
    if ($result.ArtifactAccessEntities)
    {
        $artifactAccessEntities += @($result.ArtifactAccessEntities)
    }
}

$artifactAccessEntities | Format-Table