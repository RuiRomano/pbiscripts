#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt"; ModuleVersion="1.2.1026" }

cls

# Get the authentication token using ADAL library (OAuth)

Connect-PowerBIServiceAccount

# Artifacts

$result = Invoke-PowerBIRestMethod -method Get -url "admin/widelySharedArtifacts/linksSharedToWholeOrganization" | ConvertFrom-Json

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