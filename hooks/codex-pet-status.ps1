param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('running', 'idle', 'awaiting_permission', 'waiting')]
    [string]$Status,

    [string]$Activity = ''
)

$ErrorActionPreference = 'Stop'

$statusFile = Join-Path $env:USERPROFILE '.codex\codex_status.json'
$statusDir = Split-Path -Parent $statusFile
New-Item -ItemType Directory -Force -Path $statusDir | Out-Null

$stdinJson = [Console]::In.ReadToEnd()
$hook = $null
if (-not [string]::IsNullOrWhiteSpace($stdinJson)) {
    try {
        $hook = $stdinJson | ConvertFrom-Json
    } catch {
        $hook = $null
    }
}

if ([string]::IsNullOrWhiteSpace($Activity)) {
    if ($hook -and $hook.hook_event_name) {
        $Activity = "Codex $($hook.hook_event_name)"
    } else {
        $Activity = 'Codex'
    }
}

$now = (Get-Date).ToUniversalTime().ToString('o')
$payload = [ordered]@{
    status = $Status
    timestamp = $now
    updated_at = $now
    model = if ($hook -and $hook.model) { $hook.model } else { 'codex' }
    activity = $Activity
    hook_event_name = if ($hook -and $hook.hook_event_name) { $hook.hook_event_name } else { $null }
    turn_id = if ($hook -and $hook.turn_id) { $hook.turn_id } else { $null }
}

$json = $payload | ConvertTo-Json -Depth 8
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($statusFile, $json, $utf8NoBom)

if ($hook -and $hook.hook_event_name -eq 'Stop') {
    [Console]::Out.Write('{"continue":true,"suppressOutput":true}')
}
