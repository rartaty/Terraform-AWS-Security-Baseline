[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$AuditFile,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$audit = Get-Content -LiteralPath $AuditFile -Raw | ConvertFrom-Json
if ($audit.AccountId -notmatch '^\d{12}$') { throw 'Invalid audit account ID.' }
$execution = @($audit.Roles | Where-Object { $_.Role.RoleName -eq 'TerraformExecutionRole' })
if ($execution.Count -ne 1) { throw 'Expected exactly one TerraformExecutionRole.' }
$execution = $execution[0]
$operatorPrincipal = 'arn:aws:iam::' + $audit.AccountId + ':user/terraform-operator'
if ($audit.CallerArn -ne $operatorPrincipal) { throw 'Unexpected audit caller.' }

function Get-ExactBucketArn {
    param([string]$PolicyName, [string]$StatementSid, [bool]$Managed)
    if ($Managed) {
        $policy = @($audit.ManagedPolicies | Where-Object { $_.Policy.PolicyName -eq $PolicyName })
        if ($policy.Count -ne 1) { throw "Missing managed policy: $PolicyName" }
        $document = $policy[0].DefaultVersion.Document
    } else {
        $policy = @($execution.InlinePolicies | Where-Object { $_.PolicyName -eq $PolicyName })
        if ($policy.Count -ne 1) { throw "Missing inline policy: $PolicyName" }
        $document = $policy[0].PolicyDocument
    }
    $statement = @($document.Statement | Where-Object { $_.Sid -eq $StatementSid })
    if ($statement.Count -ne 1) { throw "Missing bucket statement: $StatementSid" }
    $resource = @($statement[0].Resource)
    if ($resource.Count -ne 1 -or $resource[0] -notmatch '^arn:aws:s3:::[a-z0-9.-]+$') {
        throw "Expected one exact bucket ARN in $StatementSid"
    }
    return [string]$resource[0]
}

$config = @($audit.Roles | Where-Object { $_.Role.RoleName -eq 'ConfigEvidenceReadRole' })
if ($config.Count -ne 1) { throw 'Missing ConfigEvidenceReadRole.' }
$keyStatement = @($config[0].InlinePolicies.PolicyDocument.Statement | Where-Object { $_.Sid -eq 'DenyKMSOperations' })
if ($keyStatement.Count -ne 1) { throw 'Missing security log key reference.' }
$keyArn = [string]$keyStatement[0].Resource
if ($keyArn -notmatch ('^arn:aws:kms:ap-northeast-1:' + $audit.AccountId + ':key/[0-9a-f-]+$')) {
    throw 'Unexpected security log key ARN.'
}
$replacements = @{
    '<ACCOUNT_ID>' = [string]$audit.AccountId
    '<STATE_BUCKET_ARN>' = Get-ExactBucketArn 'BootstrapS3StateBucket' 'ManageOnlyTerraformStateBucket' $false
    '<CLOUDTRAIL_BUCKET_ARN>' = Get-ExactBucketArn 'ManageCloudTrailAuditLogging' 'ManageCloudTrailLogBucket' $false
    '<CONFIG_BUCKET_ARN>' = Get-ExactBucketArn 'ManagePhase6ConfigStorage' 'ManageConfigHistoryBucket' $true
    '<FLOW_LOGS_BUCKET_ARN>' = Get-ExactBucketArn 'ManagePhase7FlowLogsStorage' 'ManagePhase7FlowLogsBucket' $true
    '<SECURITY_LOGS_KEY_ARN>' = $keyArn
}

$templateNames = @(
    'terraform-execution-boundary', 'cloudtrail-reader-boundary', 'config-reader-boundary',
    'policy-editor-permissions', 'policy-editor-trust'
)
$rendered = @()
$templateDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'iam'
foreach ($name in $templateNames) {
    $text = Get-Content -LiteralPath (Join-Path $templateDirectory ($name + '.json.example')) -Raw
    foreach ($placeholder in $replacements.Keys) { $text = $text.Replace($placeholder, $replacements[$placeholder]) }
    if ($text -match '<[A-Z_]+>') { throw "Unresolved placeholder in $name" }
    $document = $text | ConvertFrom-Json
    $compact = $document | ConvertTo-Json -Depth 100 -Compress
    if ($compact.Length -gt 6144) { throw "Managed policy size limit exceeded in $name ($($compact.Length)). No policy files written." }
    $rendered += [pscustomobject]@{ Name = $name; Json = $compact; Length = $compact.Length }
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('baseline-boundary-policies-' + [guid]::NewGuid().ToString())
}
$destination = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $destination) { throw 'Output directory already exists.' }
[void](New-Item -ItemType Directory -Path $destination)
foreach ($item in $rendered) {
    [System.IO.File]::WriteAllText((Join-Path $destination ($item.Name + '.json')), $item.Json, [System.Text.UTF8Encoding]::new($false))
}
$sourceHash = Get-FileHash -LiteralPath $AuditFile -Algorithm SHA256
[pscustomobject]@{
    GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
    SourceAuditSha256 = $sourceHash.Hash
    State = 'Draft; AWS validation and application pending'
    PolicySizes = @($rendered | Select-Object Name, Length)
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $destination 'manifest.json') -Encoding utf8
Write-Output "Draft policy files saved privately: $destination"
$rendered | Select-Object Name, Length | Format-Table -AutoSize
