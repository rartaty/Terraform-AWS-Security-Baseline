[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d{12}$')][string]$AccountId,
    [Parameter(Mandatory = $true)][ValidatePattern('^vpc-([0-9a-f]{8}|[0-9a-f]{17})$')][string]$VpcId,
    [Parameter(Mandatory = $true)][ValidatePattern('^ami-([0-9a-f]{8}|[0-9a-f]{17})$')][string]$AmiId,
    [Parameter(Mandatory = $true)][string]$EbsKeyArn,
    [Parameter(Mandatory = $true)][string]$StateBucketArn
)

$ErrorActionPreference = 'Stop'
if ($EbsKeyArn -notmatch ('^arn:aws:kms:ap-northeast-1:' + $AccountId + ':key/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')) {
    throw 'EBS key ARN must identify one key in this account and Tokyo.'
}
if ($StateBucketArn -notmatch '^arn:aws:s3:::(?<bucket>[a-z0-9][a-z0-9.-]{1,61}[a-z0-9])$' -or
    $Matches.bucket -match '\.\.|^\d+\.\d+\.\d+\.\d+$') {
    throw 'Expected one exact S3 state bucket ARN, without an object key or wildcard.'
}
$phase75Repository = Split-Path $PSScriptRoot -Parent
$phase75Templates = Join-Path $phase75Repository 'iam'
$phase75Substitutions = @{
    '<ACCOUNT_ID>' = $AccountId
    '<VPC_ID>' = $VpcId
    '<AMI_ID>' = $AmiId
    '<EBS_KEY_ARN>' = $EbsKeyArn
    '<STATE_BUCKET_ARN>' = $StateBucketArn
}
$phase75Mapping = [ordered]@{
    'phase75-firewall-permissions.fragment' = 'Phase75LabFirewallPermissions'
    'phase75-network-permissions.fragment' = 'Phase75LabNetworkPermissions'
    'phase75-compute-permissions.fragment' = 'Phase75LabComputePermissions'
    'phase75-logs-state-permissions.fragment' = 'Phase75LabLogsStatePermissions'
    'phase75-lab-boundary' = 'Phase75LabExecutionBoundary'
    'phase75-lab-trust' = 'Phase75LabTrust'
    'phase75-budget-deny' = 'DenyPhase75ProvisioningAtBudgetLimit'
    'phase75-budget-attachment' = 'Phase75BudgetAttachmentAddition'
}

# No AWS operations. Validate every policy before creating private output files.
$phase75Rendered = foreach ($phase75Entry in $phase75Mapping.GetEnumerator()) {
    $phase75Text = Get-Content -LiteralPath (Join-Path $phase75Templates "$($phase75Entry.Key).json.example") -Raw
    foreach ($phase75Replacement in $phase75Substitutions.GetEnumerator()) {
        $phase75Text = $phase75Text.Replace($phase75Replacement.Key, $phase75Replacement.Value)
    }
    if ($phase75Text -match '<[A-Z_]+>') { throw "Unresolved placeholder: $($phase75Entry.Key)" }
    $phase75Policy = $phase75Text | ConvertFrom-Json
    if ($phase75Policy.Version -ne '2012-10-17' -or !$phase75Policy.Statement) {
        throw "Invalid policy structure: $($phase75Entry.Key)"
    }
    $phase75Length = ($phase75Policy | ConvertTo-Json -Depth 50 -Compress).Length
    if ($phase75Length -gt 6144) { throw "Policy size exceeded: $($phase75Entry.Value) ($phase75Length). No files written." }
    [pscustomobject]@{ Name = $phase75Entry.Value; Json = $phase75Text; Characters = $phase75Length }
}
$phase75Destination = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) ('phase75-lab-policies-' + [guid]::NewGuid())))
$phase75RepositoryPrefix = [System.IO.Path]::GetFullPath($phase75Repository).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($phase75Destination.StartsWith($phase75RepositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Private output must not be inside the repository.'
}
if (Test-Path -LiteralPath $phase75Destination) { throw 'Output directory already exists.' }
[void](New-Item -ItemType Directory -Path $phase75Destination)
foreach ($phase75Item in $phase75Rendered) {
    [System.IO.File]::WriteAllText((Join-Path $phase75Destination "$($phase75Item.Name).json"), $phase75Item.Json, [System.Text.UTF8Encoding]::new($false))
}
$phase75Manifest = [ordered]@{
    GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
    State = 'Private drafts only; AWS policy validation, IAM setup, Budget Action and paid-resource approval pending'
    Policies = @($phase75Rendered | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Characters = $_.Characters
            Sha256 = (Get-FileHash -LiteralPath (Join-Path $phase75Destination "$($_.Name).json") -Algorithm SHA256).Hash
        }
    })
}
[System.IO.File]::WriteAllText((Join-Path $phase75Destination 'manifest.json'), ($phase75Manifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
[pscustomobject]@{
    Directory = $phase75Destination
    RoleName = 'Phase75LabExecutionRole'
    BoundaryName = 'Phase75LabExecutionBoundary'
    BoundaryCharacters = ($phase75Rendered | Where-Object Name -eq 'Phase75LabExecutionBoundary').Characters
    State = $phase75Manifest.State
}
