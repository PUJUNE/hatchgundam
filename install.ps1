param(
    [switch]$NoStartup,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path $env:LOCALAPPDATA 'hatchgundam'
$ExeSource = Join-Path $Root 'hatchgundam.exe'
$ExeTarget = Join-Path $InstallDir 'hatchgundam.exe'
$AssetsSource = Join-Path $Root 'assets'
$AssetsTarget = Join-Path $InstallDir 'assets'

# Codex
$CodexHookSource = Join-Path $Root 'hooks\codex-pet-status.ps1'
$CodexDir = Join-Path $env:USERPROFILE '.codex'
$CodexHooksDir = Join-Path $CodexDir 'hooks'
$CodexHookTarget = Join-Path $CodexHooksDir 'codex-hatchgundam-status.ps1'
$CodexConfig = Join-Path $CodexDir 'config.toml'

# Claude Code
$ClaudeHookSource = Join-Path $Root 'hooks\claude-pet-status.ps1'
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$ClaudeHooksDir = Join-Path $ClaudeDir 'hooks'
$ClaudeHookTarget = Join-Path $ClaudeHooksDir 'claude-pet-status.ps1'
$ClaudeSettings = Join-Path $ClaudeDir 'settings.json'

$StartupDir = [Environment]::GetFolderPath('Startup')
$StartupCmd = Join-Path $StartupDir 'hatchgundam.cmd'

if (-not (Test-Path $ExeSource)) {
    throw "hatchgundam.exe not found. Run build.ps1 first."
}

# --- 파일 복사 ---
New-Item -ItemType Directory -Force -Path $InstallDir, $AssetsTarget, $CodexHooksDir, $ClaudeHooksDir | Out-Null
Copy-Item -Force -Path $ExeSource -Destination $ExeTarget
Copy-Item -Force -Path (Join-Path $AssetsSource 'spritesheet.webp') -Destination (Join-Path $AssetsTarget 'spritesheet.webp')
Copy-Item -Force -Path $CodexHookSource -Destination $CodexHookTarget
Copy-Item -Force -Path $ClaudeHookSource -Destination $ClaudeHookTarget

# --- Codex config.toml 업데이트 ---
if (-not (Test-Path $CodexConfig)) {
    New-Item -ItemType File -Force -Path $CodexConfig | Out-Null
}

$codexBackup = "$CodexConfig.bak_$(Get-Date -Format 'yyMMdd_HHmmss')"
Copy-Item -Force -Path $CodexConfig -Destination $codexBackup

$content = Get-Content -Raw -Path $CodexConfig
$content = [regex]::Replace(
    $content,
    '(?ms)\r?\n?# BEGIN HATCHGUNDAM CODEX HOOKS.*?# END HATCHGUNDAM CODEX HOOKS\r?\n?',
    "`r`n"
).TrimEnd()
if ($content -match '(?m)^\[features\]\s*$') {
    $featuresMatch = [regex]::Match($content, '(?ms)^\[features\]\s*(.*?)(?=^\[|\z)')
    $featuresBlock = $featuresMatch.Value
    if ($featuresBlock -match '(?m)^codex_hooks\s*=') {
        $newFeaturesBlock = [regex]::Replace($featuresBlock, '(?m)^codex_hooks\s*=.*$', 'codex_hooks = true')
    } else {
        $newFeaturesBlock = $featuresBlock.TrimEnd() + "`r`ncodex_hooks = true`r`n"
    }
    $content = $content.Remove($featuresMatch.Index, $featuresMatch.Length).Insert($featuresMatch.Index, $newFeaturesBlock)
} else {
    $content = $content.TrimEnd() + "`r`n`r`n[features]`r`ncodex_hooks = true`r`n"
}

$hookBlock = @"

# BEGIN HATCHGUNDAM CODEX HOOKS
[[hooks.SessionStart]]
matcher = "startup|resume|clear"
[[hooks.SessionStart.hooks]]
type = "command"
command = 'cmd.exe /d /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.codex\hooks\codex-hatchgundam-status.ps1" -Status idle -Activity "Codex session"'
timeout = 5
statusMessage = "Updating hatchgundam status"

[[hooks.UserPromptSubmit]]
[[hooks.UserPromptSubmit.hooks]]
type = "command"
command = 'cmd.exe /d /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.codex\hooks\codex-hatchgundam-status.ps1" -Status running -Activity "Codex running"'
timeout = 5
statusMessage = "Updating hatchgundam status"

[[hooks.PreToolUse]]
matcher = ".*"
[[hooks.PreToolUse.hooks]]
type = "command"
command = 'cmd.exe /d /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.codex\hooks\codex-hatchgundam-status.ps1" -Status running -Activity "Codex tool"'
timeout = 5
statusMessage = "Updating hatchgundam status"

[[hooks.PermissionRequest]]
matcher = ".*"
[[hooks.PermissionRequest.hooks]]
type = "command"
command = 'cmd.exe /d /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.codex\hooks\codex-hatchgundam-status.ps1" -Status awaiting_permission -Activity "Codex permission"'
timeout = 5
statusMessage = "Updating hatchgundam status"

[[hooks.Stop]]
[[hooks.Stop.hooks]]
type = "command"
command = 'cmd.exe /d /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.codex\hooks\codex-hatchgundam-status.ps1" -Status idle -Activity "Codex idle"'
timeout = 5
statusMessage = "Updating hatchgundam status"
# END HATCHGUNDAM CODEX HOOKS
"@

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($CodexConfig, ($content.TrimEnd() + "`r`n" + $hookBlock.TrimStart()), $utf8NoBom)

# --- Claude Code settings.json 업데이트 ---
if (-not (Test-Path $ClaudeSettings)) {
    [System.IO.File]::WriteAllText($ClaudeSettings, '{}', $utf8NoBom)
}

$claudeSettingsContent = Get-Content -Raw -Path $ClaudeSettings
$claudeJson = $claudeSettingsContent | ConvertFrom-Json

$hatchgundamHooks = @{
    UserPromptSubmit = @(
        @{ hooks = @(@{ type = "command"; command = 'powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/hooks/claude-pet-status.ps1" -Status running -Activity claude-running' }) }
    )
    PreToolUse = @(
        @{ matcher = ""; hooks = @(@{ type = "command"; command = 'powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/hooks/claude-pet-status.ps1" -Status running -Activity claude-tool' }) }
    )
    Notification = @(
        @{ hooks = @(@{ type = "command"; command = 'powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/hooks/claude-pet-status.ps1" -Status waiting -Activity claude-wait' }) }
    )
    Stop = @(
        @{ hooks = @(@{ type = "command"; command = 'powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/hooks/claude-pet-status.ps1" -Status idle -Activity claude-idle' }) }
    )
}

$claudeJson | Add-Member -Force -NotePropertyName 'hooks' -NotePropertyValue $hatchgundamHooks

$claudeSettingsJson = $claudeJson | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ClaudeSettings, $claudeSettingsJson, $utf8NoBom)

# --- 시작 프로그램 등록 ---
if (-not $NoStartup) {
    $cmd = "@echo off`r`nstart """" ""$ExeTarget""`r`n"
    Set-Content -Path $StartupCmd -Value $cmd -Encoding ASCII
}

# --- 재실행 ---
if (-not $NoLaunch) {
    Get-Process | Where-Object { $_.ProcessName -eq 'hatchgundam' -or ($_.ProcessName -match 'python|py' -and $_.MainWindowTitle -eq 'hatchgundam') } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath $ExeTarget
}

Write-Output "Installed hatchgundam to $InstallDir"
Write-Output "Codex config backup: $codexBackup"
Write-Output "Restart Codex for Codex hook changes to take effect."
Write-Output "Claude Code hooks active immediately (no restart needed)."
