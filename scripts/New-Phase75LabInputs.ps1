[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d{12}$')][string]$AccountId,
    [Parameter(Mandatory = $true)][ValidatePattern('^vpc-([0-9a-f]{8}|[0-9a-f]{17})$')][string]$VpcId,
    [Parameter(Mandatory = $true)][ValidatePattern('^ami-([0-9a-f]{8}|[0-9a-f]{17})$')][string]$AmiId,
    [Parameter(Mandatory = $true)][ValidatePattern('^ap-northeast-1[a-z]$')][string]$AvailabilityZone,
    [Parameter(Mandatory = $true)][string]$EbsKeyArn,
    [Parameter(Mandatory = $true)][string]$StateBucketArn
)

$ErrorActionPreference = 'Stop'
if ($EbsKeyArn -notmatch ('^arn:aws:kms:ap-northeast-1:' + $AccountId + ':key/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')) {
    throw 'Supply one EBS key in the expected account and Tokyo.'
}
if ($StateBucketArn -notmatch '^arn:aws:s3:::(?<bucket>[a-z0-9][a-z0-9.-]{1,61}[a-z0-9])$' -or
    $Matches.bucket -match '\.\.|^\d+\.\d+\.\d+\.\d+$') {
    throw 'Supply one exact S3 bucket ARN without an object key or wildcard.'
}
$phase75BucketName = $Matches.bucket
$phase75Repository = Split-Path $PSScriptRoot -Parent
$phase75InputDirectory = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) ('phase75-lab-inputs-' + [guid]::NewGuid())))
$phase75RepositoryPrefix = [System.IO.Path]::GetFullPath($phase75Repository).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($phase75InputDirectory.StartsWith($phase75RepositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Private inputs must stay outside the repository.'
}
if (Test-Path -LiteralPath $phase75InputDirectory) { throw 'Destination already exists.' }
$phase75Substitutions = @{
    '<ACCOUNT_ID>' = $AccountId
    '<VPC_ID>' = $VpcId
    '<AMI_ID>' = $AmiId
    '<EBS_KEY_ARN>' = $EbsKeyArn
    'ap-northeast-1a' = $AvailabilityZone
}
$phase75VarsText = Get-Content -LiteralPath (Join-Path $phase75Repository 'envs/phase75/terraform.tfvars.example') -Raw
foreach ($phase75Entry in $phase75Substitutions.GetEnumerator()) {
    $phase75VarsText = $phase75VarsText.Replace($phase75Entry.Key, $phase75Entry.Value)
}
if ($phase75VarsText -match '<[A-Z_]+>') { throw 'Unresolved input placeholder.' }
$phase75BackendText = 'bucket = "' + $phase75BucketName + '"' + [Environment]::NewLine
[void](New-Item -ItemType Directory -Path $phase75InputDirectory)
$phase75VarsPath = Join-Path $phase75InputDirectory 'terraform.tfvars'
$phase75BackendPath = Join-Path $phase75InputDirectory 'backend.hcl'
[System.IO.File]::WriteAllText($phase75VarsPath, $phase75VarsText, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($phase75BackendPath, $phase75BackendText, [System.Text.UTF8Encoding]::new($false))
[pscustomobject]@{
    Directory = $phase75InputDirectory
    BackendConfigPath = $phase75BackendPath
    TfvarsPath = $phase75VarsPath
    State = 'Private input files only; no AWS calls, backend initialization, or apply performed'
}
