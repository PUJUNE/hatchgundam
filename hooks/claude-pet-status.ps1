param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('running', 'idle', 'awaiting_permission', 'waiting')]
    [string]$Status,

    [string]$Activity = 'Claude'
)

$ErrorActionPreference = 'Stop'

$statusFile = Join-Path $env:USERPROFILE '.claude\claude_status.json'
$statusDir = Split-Path -Parent $statusFile
New-Item -ItemType Directory -Force -Path $statusDir | Out-Null

$now = (Get-Date).ToUniversalTime().ToString('o')
$payload = [ordered]@{
    status     = $Status
    timestamp  = $now
    updated_at = $now
    model      = 'claude'
    activity   = $Activity
}

$json = $payload | ConvertTo-Json -Depth 4
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($statusFile, $json, $utf8NoBom)
