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
    '<SETUP_EXPIRY_UTC>' = '2099-01-01T00:00:00Z'
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
        if ($phase75Statement.Effect -notin @('Allow', 'Deny') -or
            (!$phase75Statement.Action -and !$phase75Statement.NotAction) -or
            ($phase75Statement.Action -and $phase75Statement.NotAction) -or
            (!$phase75Statement.Resource -and !$phase75Statement.Principal)) {
            throw "Incomplete statement: $($phase75File.Name)"
        }
        if ($CheckOfficialActions) {
            foreach ($phase75Action in @($phase75Statement.Action) + @($phase75Statement.NotAction) | Where-Object { $_ }) {
                if ($phase75Action -eq '*') { continue }
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
foreach ($phase75Type in @('alert', 'flow')) {
    $phase75Delivery = $phase75Policies["phase75-$phase75Type-log-delivery.resource-policy.json.example"]
    if (!$phase75Delivery -or @($phase75Delivery.Statement).Count -ne 1) {
        throw "Expected one delivery statement: $phase75Type"
    }
    $phase75DeliveryStatement = $phase75Delivery.Statement[0]
    $phase75ExpectedDestination = "arn:aws:logs:ap-northeast-1:${phase75Account}:log-group:/aws/vendedlogs/network-firewall/phase75-${phase75Type}:log-stream:*"
    if ($phase75DeliveryStatement.Effect -ne 'Allow' -or
        $phase75DeliveryStatement.Principal.Service -ne 'delivery.logs.amazonaws.com' -or
        @($phase75DeliveryStatement.Principal.PSObject.Properties).Count -ne 1 -or
        @($phase75DeliveryStatement.Resource).Count -ne 1 -or
        $phase75DeliveryStatement.Resource -ne $phase75ExpectedDestination -or
        @($phase75DeliveryStatement.Action).Count -ne 2 -or
        'logs:CreateLogStream' -notin $phase75DeliveryStatement.Action -or
        'logs:PutLogEvents' -notin $phase75DeliveryStatement.Action -or
        $phase75DeliveryStatement.Condition.StringEquals.'aws:SourceAccount' -ne $phase75Account -or
        $phase75DeliveryStatement.Condition.ArnLike.'aws:SourceArn' -ne "arn:aws:logs:ap-northeast-1:${phase75Account}:*") {
        throw "Unexpected delivery principal, destination, actions or source conditions: $phase75Type"
    }
}
$phase75SetupTrust = $phase75Policies['phase75-log-setup-trust.json.example']
if (@($phase75SetupTrust.Statement).Count -ne 1 -or
    $phase75SetupTrust.Statement[0].Effect -ne 'Allow' -or
    $phase75SetupTrust.Statement[0].Action -ne 'sts:AssumeRole' -or
    $phase75SetupTrust.Statement[0].Principal.AWS -ne "arn:aws:iam::${phase75Account}:user/terraform-operator" -or
    $phase75SetupTrust.Statement[0].Condition.Bool.'aws:MultiFactorAuthPresent' -ne 'true' -or
    [DateTimeOffset]$phase75SetupTrust.Statement[0].Condition.DateLessThan.'aws:CurrentTime' -ne [DateTimeOffset]$phase75Substitutions['<SETUP_EXPIRY_UTC>']) {
    throw 'Unexpected setup trust principal, MFA or expiry.'
}
$phase75Setup = $phase75Policies['phase75-log-setup-permissions.json.example']
$phase75ExpectedSetupActions = @('logs:DescribeResourcePolicies', 'logs:PutResourcePolicy', 'logs:DeleteResourcePolicy')
if (@($phase75Setup.Statement).Count -ne 4) { throw 'Expected four setup permission statements.' }
$phase75SetupAllows = @($phase75Setup.Statement | Where-Object Effect -eq 'Allow')
if ($phase75SetupAllows.Count -ne 1 -or $phase75SetupAllows[0].Resource -ne '*' -or
    @($phase75SetupAllows[0].Action).Count -ne 3 -or
    @($phase75SetupAllows[0].Action | Where-Object { $_ -notin $phase75ExpectedSetupActions }).Count -ne 0 -or
    $phase75SetupAllows[0].Condition.StringEquals.'aws:RequestedRegion' -ne 'ap-northeast-1' -or
    [DateTimeOffset]$phase75SetupAllows[0].Condition.DateLessThan.'aws:CurrentTime' -ne [DateTimeOffset]$phase75Substitutions['<SETUP_EXPIRY_UTC>']) {
    throw 'Unexpected setup allowed actions, Region or expiry.'
}
$phase75DenyOther = @($phase75Setup.Statement | Where-Object Sid -eq 'DenyEveryOtherOperation')
if ($phase75DenyOther.Count -ne 1 -or $phase75DenyOther[0].Effect -ne 'Deny' -or
    $phase75DenyOther[0].Resource -ne '*' -or $phase75DenyOther[0].Condition -or
    @($phase75DenyOther[0].NotAction).Count -ne 3 -or
    @($phase75DenyOther[0].NotAction | Where-Object { $_ -notin $phase75ExpectedSetupActions }).Count -ne 0) {
    throw 'Unexpected setup deny-except statement.'
}
$phase75DenyRegion = @($phase75Setup.Statement | Where-Object Sid -eq 'DenyOutsideTokyo')
$phase75DenyExpiry = @($phase75Setup.Statement | Where-Object Sid -eq 'DenyAfterExpiryIncludingExistingSessions')
if ($phase75DenyRegion.Count -ne 1 -or $phase75DenyRegion[0].Effect -ne 'Deny' -or
    $phase75DenyRegion[0].Action -ne '*' -or $phase75DenyRegion[0].Resource -ne '*' -or
    $phase75DenyRegion[0].Condition.StringNotEquals.'aws:RequestedRegion' -ne 'ap-northeast-1' -or
    $phase75DenyExpiry.Count -ne 1 -or $phase75DenyExpiry[0].Effect -ne 'Deny' -or
    $phase75DenyExpiry[0].Action -ne '*' -or $phase75DenyExpiry[0].Resource -ne '*' -or
    [DateTimeOffset]$phase75DenyExpiry[0].Condition.DateGreaterThanEquals.'aws:CurrentTime' -ne [DateTimeOffset]$phase75Substitutions['<SETUP_EXPIRY_UTC>']) {
    throw 'Unexpected setup Region or expiry deny.'
}
$phase75FirewallSetupTrust = $phase75Policies['phase75-firewall-policy-setup-trust.json.example']
$phase75FirewallSetup = $phase75Policies['phase75-firewall-policy-setup-permissions.json.example']
$phase75FirewallSetupActions = @(
    'network-firewall:CreateFirewallPolicy', 'network-firewall:TagResource',
    'network-firewall:DescribeFirewallPolicy', 'network-firewall:DescribeRuleGroup',
    'network-firewall:ListRuleGroups'
)
if (@($phase75FirewallSetupTrust.Statement).Count -ne 1 -or
    $phase75FirewallSetupTrust.Statement[0].Effect -ne 'Allow' -or
    $phase75FirewallSetupTrust.Statement[0].Action -ne 'sts:AssumeRole' -or
    $phase75FirewallSetupTrust.Statement[0].Principal.AWS -ne "arn:aws:iam::${phase75Account}:user/terraform-operator" -or
    $phase75FirewallSetupTrust.Statement[0].Condition.Bool.'aws:MultiFactorAuthPresent' -ne 'true' -or
    [DateTimeOffset]$phase75FirewallSetupTrust.Statement[0].Condition.DateLessThan.'aws:CurrentTime' -ne [DateTimeOffset]$phase75Substitutions['<SETUP_EXPIRY_UTC>']) {
    throw 'Unexpected firewall policy setup trust.'
}
if (@($phase75FirewallSetup.Statement).Count -ne 7) { throw 'Expected seven firewall policy setup permission statements.' }
$phase75FirewallSetupAllows = @($phase75FirewallSetup.Statement | Where-Object Effect -eq 'Allow')
if ($phase75FirewallSetupAllows.Count -ne 4) { throw 'Unexpected firewall setup Allow count.' }
foreach ($phase75Statement in $phase75FirewallSetupAllows) {
    if ($phase75Statement.Condition.StringEquals.'aws:RequestedRegion' -ne 'ap-northeast-1' -or
        [DateTimeOffset]$phase75Statement.Condition.DateLessThan.'aws:CurrentTime' -ne [DateTimeOffset]$phase75Substitutions['<SETUP_EXPIRY_UTC>']) {
        throw 'Missing firewall setup Region or expiry.'
    }
    foreach ($phase75Action in @($phase75Statement.Action)) {
        if ($phase75Action -notin $phase75FirewallSetupActions) { throw 'Unexpected firewall setup action.' }
    }
    foreach ($phase75Resource in @($phase75Statement.Resource)) {
        if ($phase75Statement.Action -eq 'network-firewall:ListRuleGroups') {
            if ($phase75Resource -ne '*') { throw 'ListRuleGroups requires the documented unscoped exception.' }
        } elseif ($phase75Resource -notin @(
            "arn:aws:network-firewall:ap-northeast-1:${phase75Account}:firewall-policy/terraform-aws-security-baseline-dev-phase75-policy",
            "arn:aws:network-firewall:ap-northeast-1:${phase75Account}:stateful-rulegroup/terraform-aws-security-baseline-dev-phase75-http-rule"
        )) { throw 'Unexpected firewall setup resource.' }
    }
    if ($phase75Statement.Action -in @('network-firewall:CreateFirewallPolicy', 'network-firewall:TagResource') -and
        ($phase75Statement.Condition.StringEquals.'aws:RequestTag/Purpose' -ne 'phase75-firewall-test' -or
         @($phase75Statement.Condition.'ForAllValues:StringEquals'.'aws:TagKeys').Count -ne 5)) {
        throw 'Missing firewall setup creation tags.'
    }
}
$phase75FirewallSetupDenyOther = @($phase75FirewallSetup.Statement | Where-Object Sid -eq 'DenyEveryOtherOperation')
$phase75FirewallSetupDenyRegion = @($phase75FirewallSetup.Statement | Where-Object Sid -eq 'DenyOutsideTokyo')
$phase75FirewallSetupDenyExpiry = @($phase75FirewallSetup.Statement | Where-Object Sid -eq 'DenyAfterExpiryIncludingExistingSessions')
if ($phase75FirewallSetupDenyOther.Count -ne 1 -or $phase75FirewallSetupDenyOther[0].Effect -ne 'Deny' -or
    $phase75FirewallSetupDenyOther[0].Resource -ne '*' -or $phase75FirewallSetupDenyOther[0].Condition -or
    @($phase75FirewallSetupDenyOther[0].NotAction).Count -ne 5 -or
    @($phase75FirewallSetupDenyOther[0].NotAction | Where-Object { $_ -notin $phase75FirewallSetupActions }).Count -ne 0 -or
    $phase75FirewallSetupDenyRegion.Count -ne 1 -or $phase75FirewallSetupDenyRegion[0].Effect -ne 'Deny' -or
    $phase75FirewallSetupDenyRegion[0].Action -ne '*' -or $phase75FirewallSetupDenyRegion[0].Resource -ne '*' -or
    $phase75FirewallSetupDenyRegion[0].Condition.StringNotEquals.'aws:RequestedRegion' -ne 'ap-northeast-1' -or
    $phase75FirewallSetupDenyExpiry.Count -ne 1 -or $phase75FirewallSetupDenyExpiry[0].Effect -ne 'Deny' -or
    $phase75FirewallSetupDenyExpiry[0].Action -ne '*' -or $phase75FirewallSetupDenyExpiry[0].Resource -ne '*' -or
    [DateTimeOffset]$phase75FirewallSetupDenyExpiry[0].Condition.DateGreaterThanEquals.'aws:CurrentTime' -ne [DateTimeOffset]$phase75Substitutions['<SETUP_EXPIRY_UTC>']) {
    throw 'Unexpected firewall setup deny guardrails.'
}
if ('network-firewall:ListRuleGroups' -in $phase75BoundaryAllows) { throw 'Do not grant rule metadata listing to the Lab boundary.' }
$phase75Results
Write-Output 'PASS: JSON, conservative rendered sizes, and Boundary action coverage.'
Write-Output 'PASS: delivery policies restrict service principal, destinations, write actions, source account and Region.'
Write-Output 'PASS: setup trust requires MFA; setup permissions restrict operations, Region and absolute expiry.'
Write-Output 'PASS: firewall policy setup has named write/read resources, one temporary listing exception, MFA and expiry; Lab boundary does not allow listing.'
Write-Output 'This is not IAM simulation: resource/condition compatibility, AWS validation, and API tests remain required.'
