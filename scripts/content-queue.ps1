param(
    [ValidateSet('validate', 'ready-to-publish')]
    [string]$Mode = 'validate'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$queuePath = Join-Path $root 'ops/CONTENT_QUEUE.md'
$integrationPath = Join-Path $root 'ops/INTEGRATIONS.md'

if (-not (Test-Path -LiteralPath $queuePath)) { throw "Missing content queue: $queuePath" }
if (-not (Test-Path -LiteralPath $integrationPath)) { throw "Missing integration gate: $integrationPath" }

$queue = Get-Content -LiteralPath $queuePath -Raw -Encoding utf8
$integrations = Get-Content -LiteralPath $integrationPath -Raw -Encoding utf8

if ($queue -notmatch 'campaign') { throw 'Each content item needs a unique Apple campaign token before it can be published.' }
if ($Mode -eq 'ready-to-publish') {
    if ($integrations -notmatch '\| YouTube Shorts \| approved \|' -or $integrations -notmatch '\| TikTok \| approved \|') {
        throw 'Publishing remains disabled until both official provider audits are recorded as approved in ops/INTEGRATIONS.md.'
    }
    throw 'No publisher is configured yet. Connect official OAuth credentials and add a reviewed publisher implementation before enabling external posts.'
}

Write-Output 'Content queue is present. External publishing is intentionally disabled until the official audit gate is approved.'
