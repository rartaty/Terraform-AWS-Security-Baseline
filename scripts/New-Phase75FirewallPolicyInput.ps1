[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d{12}$')][string]$AccountId,
    [Parameter(Mandatory = $true)][string]$RuleGroupArn
)

$ErrorActionPreference = 'Stop'
$phase75Prefix = 'terraform-aws-security-baseline-dev-phase75'
$phase75ExpectedRuleArn = "arn:aws:network-firewall:ap-northeast-1:${AccountId}:stateful-rulegroup/${phase75Prefix}-http-rule"
if ($RuleGroupArn -cne $phase75ExpectedRuleArn) { throw 'Expected the exact same-account Tokyo Lab rule group ARN.' }

# Match envs/phase75/firewall.tf and provider default tags; this script never calls AWS.
$phase75Payload = [ordered]@{
    FirewallPolicyName = "${phase75Prefix}-policy"
    FirewallPolicy = [ordered]@{
        StatelessDefaultActions = @('aws:forward_to_sfe')
        StatelessFragmentDefaultActions = @('aws:forward_to_sfe')
        StatefulDefaultActions = @('aws:alert_established')
        StatefulEngineOptions = @{ RuleOrder = 'STRICT_ORDER' }
        StatefulRuleGroupReferences = @(@{ ResourceArn = $RuleGroupArn; Priority = 1 })
    }
    Tags = @(
        @{ Key = 'Project'; Value = 'terraform-aws-security-baseline' }
        @{ Key = 'Environment'; Value = 'dev' }
        @{ Key = 'ManagedBy'; Value = 'Terraform' }
        @{ Key = 'Purpose'; Value = 'phase75-firewall-test' }
        @{ Key = 'Name'; Value = "${phase75Prefix}-policy" }
    )
}
$phase75Json = $phase75Payload | ConvertTo-Json -Depth 20
[void]($phase75Json | ConvertFrom-Json)
$phase75Repository = [System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$phase75Destination = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) ('phase75-firewall-policy-input-' + [guid]::NewGuid())))
if ($phase75Destination.StartsWith($phase75Repository, [StringComparison]::OrdinalIgnoreCase)) { throw 'Private output must not be inside the repository.' }
if (Test-Path -LiteralPath $phase75Destination) { throw 'Output directory already exists.' }
[void](New-Item -ItemType Directory -Path $phase75Destination)
$phase75PayloadPath = Join-Path $phase75Destination 'create-firewall-policy.json'
[System.IO.File]::WriteAllText($phase75PayloadPath, $phase75Json, [System.Text.UTF8Encoding]::new($false))
[pscustomobject]@{
    InputPath = $phase75PayloadPath
    PolicyName = $phase75Payload.FirewallPolicyName
    Sha256 = (Get-FileHash -LiteralPath $phase75PayloadPath -Algorithm SHA256).Hash
    State = 'Private local CLI input only; no AWS calls or resource creation'
}
