[CmdletBinding()]
param(
    [string]$Profile = 'terraform-operator',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

$auditRepository = [System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$auditPrivateRoot = Join-Path $auditRepository 'learning-records/evidence'
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $auditPrivateRoot ('baseline-boundary-audit-' + [guid]::NewGuid().ToString())
}
$auditDestination = [System.IO.Path]::GetFullPath($OutputDirectory)
$auditPrivatePrefix = [System.IO.Path]::GetFullPath($auditPrivateRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $auditDestination.StartsWith($auditPrivatePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Store audit evidence under learning-records/evidence.'
}
& git -C $auditRepository check-ignore --quiet -- $auditDestination
if ($LASTEXITCODE -ne 0) { throw 'Audit destination must be ignored by Git before collection.' }
$auditTrackedEvidence = @(& git -C $auditRepository ls-files -- $auditDestination)
if ($LASTEXITCODE -ne 0 -or $auditTrackedEvidence.Count -ne 0) { throw 'Cannot verify an untracked audit destination.' }
if (Test-Path -LiteralPath $auditDestination) {
    throw 'Output directory already exists. Choose a new directory to preserve prior evidence.'
}

function Invoke-AuditAws {
    param([string[]]$Arguments)
    $response = & aws @Arguments --profile $Profile --output json --no-cli-pager
    if ($LASTEXITCODE -ne 0) {
        throw "AWS read failed: $($Arguments[0]) $($Arguments[1]). Audit is incomplete."
    }
    return (($response -join "`n") | ConvertFrom-Json)
}

$caller = Invoke-AuditAws -Arguments @('sts', 'get-caller-identity')
if ($caller.Arn -notmatch ':user/terraform-operator$') {
    throw 'Use the terraform-operator IAM user profile for this temporary audit.'
}

$roles = @()
$managedArns = [System.Collections.Generic.HashSet[string]]::new()
foreach ($roleName in @(
    'TerraformExecutionRole', 'BudgetActionExecutionRole',
    'CloudTrailLogReadRole', 'ConfigEvidenceReadRole'
)) {
    $role = Invoke-AuditAws -Arguments @('iam', 'get-role', '--role-name', $roleName)
    $inlineNames = Invoke-AuditAws -Arguments @('iam', 'list-role-policies', '--role-name', $roleName)
    $inlinePolicies = @()
    foreach ($policyName in $inlineNames.PolicyNames) {
        $inlinePolicies += Invoke-AuditAws -Arguments @(
            'iam', 'get-role-policy', '--role-name', $roleName, '--policy-name', $policyName
        )
    }
    $attached = Invoke-AuditAws -Arguments @('iam', 'list-attached-role-policies', '--role-name', $roleName)
    foreach ($policy in $attached.AttachedPolicies) { [void]$managedArns.Add($policy.PolicyArn) }
    if ($role.Role.PermissionsBoundary) {
        [void]$managedArns.Add($role.Role.PermissionsBoundary.PermissionsBoundaryArn)
    }
    $roles += [pscustomobject]@{
        Role = $role.Role
        InlinePolicies = $inlinePolicies
        AttachedPolicies = @($attached.AttachedPolicies)
    }
}

$operator = Invoke-AuditAws -Arguments @('iam', 'get-user', '--user-name', 'terraform-operator')
$operatorInlineNames = Invoke-AuditAws -Arguments @('iam', 'list-user-policies', '--user-name', 'terraform-operator')
$operatorInline = @()
foreach ($policyName in $operatorInlineNames.PolicyNames) {
    $operatorInline += Invoke-AuditAws -Arguments @(
        'iam', 'get-user-policy', '--user-name', 'terraform-operator', '--policy-name', $policyName
    )
}
$operatorAttached = Invoke-AuditAws -Arguments @('iam', 'list-attached-user-policies', '--user-name', 'terraform-operator')
$operatorGroups = Invoke-AuditAws -Arguments @('iam', 'list-groups-for-user', '--user-name', 'terraform-operator')
if (@($operatorGroups.Groups).Count -gt 0) {
    throw 'Operator inherits group policies. Review those separately before finalizing the boundary; this audit is incomplete.'
}
foreach ($policy in $operatorAttached.AttachedPolicies) { [void]$managedArns.Add($policy.PolicyArn) }
if ($operator.User.PermissionsBoundary) {
    [void]$managedArns.Add($operator.User.PermissionsBoundary.PermissionsBoundaryArn)
}

$managedPolicies = @()
foreach ($policyArn in ($managedArns | Sort-Object)) {
    $metadata = Invoke-AuditAws -Arguments @('iam', 'get-policy', '--policy-arn', $policyArn)
    $version = Invoke-AuditAws -Arguments @(
        'iam', 'get-policy-version', '--policy-arn', $policyArn,
        '--version-id', $metadata.Policy.DefaultVersionId
    )
    $managedPolicies += [pscustomobject]@{ Policy = $metadata.Policy; DefaultVersion = $version.PolicyVersion }
}

$audit = [pscustomobject]@{
    RecordedAtUtc = [DateTime]::UtcNow.ToString('o')
    CallerArn = $caller.Arn
    AccountId = $caller.Account
    Roles = $roles
    Operator = [pscustomobject]@{
        User = $operator.User
        InlinePolicies = $operatorInline
        AttachedPolicies = @($operatorAttached.AttachedPolicies)
        Groups = @($operatorGroups.Groups)
    }
    ManagedPolicies = $managedPolicies
    Limitations = @(
        'Read calls are sequential, not an atomic snapshot.',
        'Resource policies, SCPs and session policies are not included.',
        'This inventory is not an effective-permission or privilege-escalation proof.'
    )
}
[void](New-Item -ItemType Directory -Path $auditDestination -Force)
$auditFile = Join-Path $auditDestination 'iam-boundary-audit.json'
$audit | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $auditFile -Encoding utf8
Get-FileHash -LiteralPath $auditFile -Algorithm SHA256 |
    Select-Object Algorithm, Hash |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditDestination 'sha256.json') -Encoding utf8
Write-Output "Audit saved privately: $auditFile"
Write-Output "Roles: $($roles.Count); managed policies: $($managedPolicies.Count)"
