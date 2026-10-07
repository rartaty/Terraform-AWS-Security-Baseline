[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^i-[0-9a-f]{17}$')][string]$ClientInstanceId,
    [Parameter(Mandatory = $true)][ValidatePattern('^i-[0-9a-f]{17}$')][string]$ServerInstanceId,
    [Parameter(Mandatory = $true)][DateTimeOffset]$StartedAt,
    [string]$Profile = 'phase75-lab'
)

$ErrorActionPreference = 'Stop'
$phase75Region = 'ap-northeast-1'
$phase75Name = 'terraform-aws-security-baseline-dev-phase75-firewall'
if ($ClientInstanceId -eq $ServerInstanceId) { throw 'Supply two distinct Lab instances.' }
if ($StartedAt -gt [DateTimeOffset]::UtcNow) { throw 'Start time must not be in the future.' }

function Invoke-Phase75EvidenceRead {
    param([string[]]$Arguments)
    $response = & aws @Arguments --profile $Profile --region $phase75Region --output json --no-cli-pager
    if ($LASTEXITCODE -ne 0) { throw "Evidence read failed: $($Arguments[0]) $($Arguments[1]). Do not extend the cleanup deadline." }
    return (($response -join "`n") | ConvertFrom-Json)
}

$phase75Caller = Invoke-Phase75EvidenceRead @('sts', 'get-caller-identity')
if ($phase75Caller.Arn -notmatch ':assumed-role/Phase75LabExecutionRole/') {
    throw 'Use the dedicated Lab execution Role.'
}
$phase75Instances = Invoke-Phase75EvidenceRead @('ec2', 'describe-instances', '--instance-ids', $ClientInstanceId, $ServerInstanceId)
$phase75InstanceList = @($phase75Instances.Reservations | ForEach-Object { $_.Instances })
if ($phase75InstanceList.Count -ne 2) { throw 'Expected two Lab instances.' }
foreach ($phase75Instance in $phase75InstanceList) {
    $phase75Purpose = @($phase75Instance.Tags | Where-Object { $_.Key -eq 'Purpose' -and $_.Value -eq 'phase75-firewall-test' })
    $phase75ExpectedIp = if ($phase75Instance.InstanceId -eq $ClientInstanceId) { '10.70.20.10' } else { '10.70.22.10' }
    if ($phase75Purpose.Count -ne 1 -or $phase75Instance.PrivateIpAddress -ne $phase75ExpectedIp) {
        throw 'Instance identity, Lab tag or expected private IP does not match.'
    }
}

# A unique private directory preserves existing evidence and never writes inside Git.
$phase75Destination = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('phase75-evidence-' + [guid]::NewGuid())))
$phase75RepositoryPrefix = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ($phase75Destination.StartsWith($phase75RepositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Evidence must remain outside the repository.'
}
[void](New-Item -ItemType Directory -Path $phase75Destination)
function Save-Phase75EvidenceJson {
    param([string]$Name, $Document)
    [IO.File]::WriteAllText((Join-Path $phase75Destination $Name), ($Document | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
}
Save-Phase75EvidenceJson 'caller.json' $phase75Caller
Save-Phase75EvidenceJson 'instances.json' $phase75Instances
$phase75Collected = [ordered]@{}
$phase75CollectionError = $null
try {
    $phase75Collected['firewall.json'] = Invoke-Phase75EvidenceRead @('network-firewall', 'describe-firewall', '--firewall-name', $phase75Name)
    $phase75Collected['logging-configuration.json'] = Invoke-Phase75EvidenceRead @('network-firewall', 'describe-logging-configuration', '--firewall-name', $phase75Name)
    $phase75Collected['rule-group.json'] = Invoke-Phase75EvidenceRead @('network-firewall', 'describe-rule-group', '--rule-group-name', 'terraform-aws-security-baseline-dev-phase75-http-rule', '--type', 'STATEFUL')
    $phase75Collected['client-console.json'] = Invoke-Phase75EvidenceRead @('ec2', 'get-console-output', '--instance-id', $ClientInstanceId, '--latest')
    $phase75Collected['server-console.json'] = Invoke-Phase75EvidenceRead @('ec2', 'get-console-output', '--instance-id', $ServerInstanceId, '--latest')
    foreach ($phase75LogType in @('alert', 'flow')) {
        # AWS CLI automatic pagination stays enabled; save events, not only the last page.
        $phase75Collected["$phase75LogType-events.json"] = Invoke-Phase75EvidenceRead @(
            'logs', 'filter-log-events', '--log-group-name', "/aws/vendedlogs/network-firewall/phase75-$phase75LogType",
            '--start-time', $StartedAt.ToUnixTimeMilliseconds().ToString()
        )
    }
} catch {
    $phase75CollectionError = $_.Exception.Message
} finally {
    foreach ($phase75Entry in $phase75Collected.GetEnumerator()) { Save-Phase75EvidenceJson $phase75Entry.Key $phase75Entry.Value }
    $phase75Hashes = @(Get-ChildItem -LiteralPath $phase75Destination -File | ForEach-Object {
        [pscustomobject]@{ File = $_.Name; Bytes = $_.Length; Sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    Save-Phase75EvidenceJson 'manifest.json' ([ordered]@{
        RecordedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
        StartedAtUtc = $StartedAt.ToUniversalTime().ToString('o')
        Complete = ($null -eq $phase75CollectionError)
        Files = $phase75Hashes
        Limitations = @(
            'Sequential CLI reads are not an atomic snapshot; log delivery may still be pending.',
            'Console output may omit earlier cycles; collection does not prove the HTTP test passed.',
            'SHA-256 detects changes after collection; it does not establish AWS authenticity.',
            'Raw evidence contains private identifiers. Never commit or upload these files.',
            'No write AWS API, Terraform apply or resource deletion is performed.'
        )
    })
}
if ($phase75CollectionError) { throw "Partial evidence retained in $phase75Destination. $phase75CollectionError" }
[pscustomobject]@{
    Directory = $phase75Destination
    Complete = $true
    HashedFiles = $phase75Hashes.Count
    AlertEvents = @($phase75Collected['alert-events.json'].events).Count
    FlowEvents = @($phase75Collected['flow-events.json'].events).Count
    State = 'Private evidence saved; cleanup remains required'
}
