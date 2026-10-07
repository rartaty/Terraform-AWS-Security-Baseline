[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{12}$')]
    [string]$AccountId,
    [ValidateRange(15, 120)]
    [int]$WindowMinutes = 60
)

$ErrorActionPreference = 'Stop'
$phase75Repository = Split-Path $PSScriptRoot -Parent
$phase75Templates = Join-Path $phase75Repository 'iam'
$phase75Expiry = [DateTime]::UtcNow.AddMinutes($WindowMinutes).ToString('yyyy-MM-ddTHH:mm:ssZ')
$phase75Names = @(
    'phase75-log-setup-trust', 'phase75-log-setup-permissions',
    'phase75-alert-log-delivery.resource-policy', 'phase75-flow-log-delivery.resource-policy'
)

# Validate all documents before writing. No AWS operations are performed by this script.
$phase75Rendered = foreach ($phase75Name in $phase75Names) {
    $phase75Text = Get-Content -LiteralPath (Join-Path $phase75Templates "$phase75Name.json.example") -Raw
    $phase75Text = $phase75Text.Replace('<ACCOUNT_ID>', $AccountId).Replace('<SETUP_EXPIRY_UTC>', $phase75Expiry)
    if ($phase75Text -match '<[A-Z_]+>') { throw "Unresolved placeholder: $phase75Name" }
    $phase75Document = $phase75Text | ConvertFrom-Json
    if (($phase75Document | ConvertTo-Json -Depth 30 -Compress).Length -gt 6144) {
        throw "Policy size exceeded: $phase75Name"
    }
    [pscustomobject]@{ Name = $phase75Name; Json = $phase75Text }
}
$phase75Destination = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) ('phase75-log-setup-' + [guid]::NewGuid())))
$phase75RepositoryPrefix = [System.IO.Path]::GetFullPath($phase75Repository).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($phase75Destination.StartsWith($phase75RepositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Private output must not be inside the repository.'
}
if (Test-Path -LiteralPath $phase75Destination) { throw 'Output directory already exists.' }
[void](New-Item -ItemType Directory -Path $phase75Destination)
foreach ($phase75Item in $phase75Rendered) {
    [System.IO.File]::WriteAllText((Join-Path $phase75Destination "$($phase75Item.Name).json"), $phase75Item.Json, [System.Text.UTF8Encoding]::new($false))
}
[pscustomobject]@{
    Directory = $phase75Destination
    RoleName = 'TemporaryPhase75LogDeliverySetupRole'
    ExpiresAtUtc = $phase75Expiry
    State = 'Local documents only; IAM validation, role creation and log policy application pending'
}
