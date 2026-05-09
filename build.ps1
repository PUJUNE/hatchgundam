$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $Root 'src\hatchgundam_overlay.py'
$Assets = Join-Path $Root 'assets'
$BuildDir = Join-Path $Root 'build'
$DistDir = Join-Path $Root 'dist'

python -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --windowed `
    --name hatchgundam `
    --distpath $DistDir `
    --workpath $BuildDir `
    --specpath $BuildDir `
    --add-data "$Assets;assets" `
    $Src

Copy-Item -Force -Path (Join-Path $DistDir 'hatchgundam.exe') -Destination (Join-Path $Root 'hatchgundam.exe')
Write-Output "Built: $(Join-Path $Root 'hatchgundam.exe')"
