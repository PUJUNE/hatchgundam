param(
    [switch]$KeepCodexHook,
    [switch]$KeepAppFiles
)

$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:LOCALAPPDATA 'hatchgundam'
$CodexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'
$CodexHook = Join-Path $env:USERPROFILE '.codex\hooks\codex-hatchgundam-status.ps1'
$StartupCmd = Join-Path ([Environment]::GetFolderPath('Startup')) 'hatchgundam.cmd'

Get-Process | Where-Object { $_.ProcessName -eq 'hatchgundam' -or ($_.ProcessName -match 'python|py' -and $_.MainWindowTitle -eq 'hatchgundam') } |
    Stop-Process -Force -ErrorAction SilentlyContinue

if (Test-Path $StartupCmd) {
    Remove-Item -Force -Path $StartupCmd
}

if (Test-Path $CodexConfig) {
    $backup = "$CodexConfig.bak_uninstall_$(Get-Date -Format 'yyMMdd_HHmmss')"
    Copy-Item -Force -Path $CodexConfig -Destination $backup
    $content = Get-Content -Raw -Path $CodexConfig
    $content = [regex]::Replace(
        $content,
        '(?ms)\r?\n?# BEGIN HATCHGUNDAM CODEX HOOKS.*?# END HATCHGUNDAM CODEX HOOKS\r?\n?',
        "`r`n"
    ).TrimEnd()
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($CodexConfig, ($content + "`r`n"), $utf8NoBom)
    Write-Output "Codex config backup: $backup"
}

if (-not $KeepCodexHook -and (Test-Path $CodexHook)) {
    Remove-Item -Force -Path $CodexHook
}

if (-not $KeepAppFiles -and (Test-Path $InstallDir)) {
    Remove-Item -Recurse -Force -Path $InstallDir
}

Write-Output "Uninstalled hatchgundam."
