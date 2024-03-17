# Azure DevOps Organization URL
$organizationUrl = "https://dev.azure.com/raivivek1989"

# Personal Access Token (PAT) with appropriate permissions
$pat = "thztn6n2o75s2mndsxlqh5o63kgs2ujbkqafp2jpe26pndyw5fla"

# Base64 encode the PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)"))

function Get-Identities {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        $url = "https://vssps.dev.azure.com/raivivek1989/_apis/identities?api-version=7.2-preview.1"
    }
    
    process {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ContentType "application/json"
    }
    
    end {
        return $response
    }
}
# Function to make REST API request
function Invoke-AzDevOpsRestApi {
    param (
        [string]$uri,
        [string]$method = "GET",
        [string]$body = $null
    )

    $headers = @{
        Authorization = "Basic $base64AuthInfo"
    }

    $url = "$organizationUrl/_apis/$uri?api-version=6.0-preview.3"

    if ($method -eq "GET") {
        $response = Invoke-RestMethod -Uri $url -Method $method -Headers $headers -ContentType "application/json"
    } elseif ($method -eq "POST") {
        $response = Invoke-RestMethod -Uri $url -Method $method -Headers $headers -ContentType "application/json" -Body $body
    }

    return $response
}

# Get all users in the organization
$users = Get-Identities

# Display user details
foreach ($user in $users.value) {
    Write-Host "User: $($user.displayName), Email: $($user.mail)"
}

# Get all teams in the organization
$teams = Invoke-AzDevOpsRestApi "teams?api-version=6.0"

# Display team details
foreach ($team in $teams.value) {
    Write-Host "Team: $($team.name), Description: $($team.description)"
}
