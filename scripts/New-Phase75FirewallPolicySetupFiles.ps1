[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d{12}$')][string]$AccountId,
    [ValidateRange(15, 120)][int]$WindowMinutes = 60
)

$ErrorActionPreference = 'Stop'
$phase75Repository = Split-Path $PSScriptRoot -Parent
$phase75Templates = Join-Path $phase75Repository 'iam'
$phase75Expiry = [DateTime]::UtcNow.AddMinutes($WindowMinutes).ToString('yyyy-MM-ddTHH:mm:ssZ')
$phase75Rendered = foreach ($phase75Name in @('phase75-firewall-policy-setup-trust', 'phase75-firewall-policy-setup-permissions')) {
    $phase75Text = Get-Content -LiteralPath (Join-Path $phase75Templates "$phase75Name.json.example") -Raw
    $phase75Text = $phase75Text.Replace('<ACCOUNT_ID>', $AccountId).Replace('<SETUP_EXPIRY_UTC>', $phase75Expiry)
    if ($phase75Text -match '<[A-Z_]+>') { throw "Unresolved placeholder: $phase75Name" }
    $phase75Document = $phase75Text | ConvertFrom-Json
    if ($phase75Document.Version -ne '2012-10-17' -or !$phase75Document.Statement) { throw "Invalid document: $phase75Name" }
    if (($phase75Document | ConvertTo-Json -Depth 30 -Compress).Length -gt 6144) { throw "Policy size exceeded: $phase75Name" }
    [pscustomobject]@{ Name = $phase75Name; Json = $phase75Text }
}
# Only private local documents; no AWS operations or credential changes.
$phase75Destination = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) ('phase75-firewall-policy-setup-' + [guid]::NewGuid())))
$phase75RepositoryPrefix = [System.IO.Path]::GetFullPath($phase75Repository).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($phase75Destination.StartsWith($phase75RepositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Private output must not be inside the repository.' }
if (Test-Path -LiteralPath $phase75Destination) { throw 'Output directory already exists.' }
[void](New-Item -ItemType Directory -Path $phase75Destination)
foreach ($phase75Item in $phase75Rendered) {
    [System.IO.File]::WriteAllText((Join-Path $phase75Destination "$($phase75Item.Name).json"), $phase75Item.Json, [System.Text.UTF8Encoding]::new($false))
}
[pscustomobject]@{
    Directory = $phase75Destination
    RoleName = 'TemporaryPhase75FirewallPolicySetupRole'
    ExpiresAtUtc = $phase75Expiry
    State = 'Private drafts only; AWS validation, role setup and policy creation pending'
}
