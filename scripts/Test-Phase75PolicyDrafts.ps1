[CmdletBinding()]
param([switch]$CheckOfficialActions)

$ErrorActionPreference = 'Stop'
$phase75PolicyDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'iam'
$phase75References = @{}
if ($CheckOfficialActions) {
    foreach ($phase75Service in @('ec2', 'logs', 'network-firewall', 'kms', 's3', 'iam', 'sts')) {
        $phase75References[$phase75Service] = Invoke-RestMethod "https://servicereference.us-east-1.amazonaws.com/v1/$phase75Service/$phase75Service.json"
    }
}

# Synthetic substitutions test rendered lengths without exposing account or resource IDs.
$phase75Account = '1' * 12
$phase75Substitutions = @{
    '<ACCOUNT_ID>' = $phase75Account
    '<VPC_ID>' = 'vpc-' + ('a' * 17)
    '<AMI_ID>' = 'ami-' + ('b' * 17)
    '<EBS_KEY_ARN>' = "arn:aws:kms:ap-northeast-1:${phase75Account}:key/" + ('c' * 36)
    '<STATE_BUCKET_ARN>' = 'arn:aws:s3:::' + ('d' * 63)
}
$phase75Policies = @{}
$phase75Results = foreach ($phase75File in Get-ChildItem -LiteralPath $phase75PolicyDirectory -Filter 'phase75*.json.example') {
    $phase75Text = Get-Content -LiteralPath $phase75File.FullName -Raw
    foreach ($phase75Entry in $phase75Substitutions.GetEnumerator()) {
        $phase75Text = $phase75Text.Replace($phase75Entry.Key, $phase75Entry.Value)
    }
    if ($phase75Text -match '<[A-Z_]+>') { throw "Unresolved placeholder in $($phase75File.Name)" }
    $phase75Policy = $phase75Text | ConvertFrom-Json
    if ($phase75Policy.Version -ne '2012-10-17' -or !$phase75Policy.Statement) {
        throw "Invalid policy structure: $($phase75File.Name)"
    }
    $phase75Compact = $phase75Policy | ConvertTo-Json -Depth 50 -Compress
    if ($phase75Compact.Length -gt 6144) { throw "Managed policy size exceeded: $($phase75File.Name)" }
    foreach ($phase75Statement in $phase75Policy.Statement) {
        if ($phase75Statement.Effect -notin @('Allow', 'Deny') -or !$phase75Statement.Action -or (!$phase75Statement.Resource -and !$phase75Statement.Principal)) {
            throw "Incomplete statement: $($phase75File.Name)"
        }
        if ($CheckOfficialActions) {
            foreach ($phase75Action in @($phase75Statement.Action)) {
                $phase75Parts = $phase75Action.Split(':', 2)
                if ($phase75Parts[1] -notmatch '[*?]' -and $phase75Parts[1] -notin $phase75References[$phase75Parts[0]].Actions.Name) {
                    throw "Unknown official action: $phase75Action"
                }
            }
        }
    }
    $phase75Policies[$phase75File.Name] = $phase75Policy
    [pscustomobject]@{ File = $phase75File.Name; SyntheticRenderedCharacters = $phase75Compact.Length; Result = 'PASS' }
}

$phase75Boundary = $phase75Policies['phase75-lab-boundary.json.example']
$phase75BoundaryAllows = @($phase75Boundary.Statement | Where-Object Effect -eq 'Allow' | ForEach-Object { $_.Action })
foreach ($phase75Name in $phase75Policies.Keys | Where-Object { $_ -like '*permissions.fragment*' }) {
    foreach ($phase75Statement in $phase75Policies[$phase75Name].Statement) {
        foreach ($phase75Action in @($phase75Statement.Action)) {
            if ($phase75Action -notin $phase75BoundaryAllows) { throw "Action missing from Boundary: $phase75Action" }
        }
    }
}
$phase75Results
Write-Output 'PASS: JSON, conservative rendered sizes, and Boundary action coverage.'
Write-Output 'This is not IAM simulation: resource/condition compatibility, AWS validation, and API tests remain required.'
