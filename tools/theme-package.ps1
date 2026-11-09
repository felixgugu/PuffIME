param(
    [string]$Name = "",
    [string]$RimeUserDir = (Join-Path $env:APPDATA "Rime"),
    [switch]$List,
    [switch]$NoDeploy
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$pkgRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$userDir = $RimeUserDir
$target = Join-Path $userDir "weasel.custom.yaml"
$appTarget = Join-Path $pkgRoot "app\weasel.custom.yaml"
$deploy = Join-Path $pkgRoot "tools\rime_deploy.exe"

$order = @(
    "light", "dark", "gray", "macaron", "mediterranean",
    "sakura", "cherry", "ocean", "mint", "lavender",
    "morandi_blue", "morandi_tea", "amber_dark", "forest_dark", "ink_dark"
)
$themes = @{
    light         = @{ key = "puff";                 label = "Puff 淺" }
    dark          = @{ key = "puff_dark";            label = "Puff 深" }
    gray          = @{ key = "puff_gray";            label = "Puff 灰" }
    macaron       = @{ key = "puff_macaron";         label = "Puff 馬卡龍" }
    mediterranean = @{ key = "puff_mediterranean";   label = "Puff 地中海" }
    sakura        = @{ key = "puff_sakura";          label = "Puff 櫻" }
    cherry        = @{ key = "puff_cherry";          label = "Puff 櫻桃" }
    ocean         = @{ key = "puff_ocean";           label = "Puff 海洋" }
    mint          = @{ key = "puff_mint";            label = "Puff 薄荷" }
    lavender      = @{ key = "puff_lavender";        label = "Puff 薰衣草" }
    morandi_blue  = @{ key = "puff_morandi_blue";    label = "Puff 莫蘭迪藍" }
    morandi_tea   = @{ key = "puff_morandi_tea";     label = "Puff 莫蘭迪茶棕" }
    amber_dark    = @{ key = "puff_amber_dark";      label = "Puff 琥珀深" }
    forest_dark   = @{ key = "puff_forest_dark";     label = "Puff 森林深" }
    ink_dark      = @{ key = "puff_ink_dark";        label = "Puff 墨黑高對比" }
}
$aliases = @{
    "puff"               = "light"
    "puff_dark"          = "dark"
    "puff_gray"          = "gray"
    "puff_macaron"       = "macaron"
    "puff_mediterranean" = "mediterranean"
    "puff_sakura"        = "sakura"
    "puff_cherry"        = "cherry"
    "puff_ocean"         = "ocean"
    "puff_mint"          = "mint"
    "puff_lavender"      = "lavender"
    "puff_morandi_blue"  = "morandi_blue"
    "puff_morandi_tea"   = "morandi_tea"
    "puff_amber_dark"    = "amber_dark"
    "puff_forest_dark"   = "forest_dark"
    "puff_ink_dark"      = "ink_dark"
    "amber_dark"         = "amber_dark"
    "forest_dark"        = "forest_dark"
    "ink_dark"           = "ink_dark"
    "morandi_blue"       = "morandi_blue"
    "morandi_tea"        = "morandi_tea"
    "淺"                 = "light"
    "深"                 = "dark"
    "灰"                 = "gray"
    "馬卡龍"             = "macaron"
    "地中海"             = "mediterranean"
    "櫻"                 = "sakura"
    "櫻桃"               = "cherry"
    "海洋"               = "ocean"
    "薄荷"               = "mint"
    "薰衣草"             = "lavender"
    "莫蘭迪藍"           = "morandi_blue"
    "莫蘭迪茶棕"         = "morandi_tea"
    "琥珀深"             = "amber_dark"
    "森林深"             = "forest_dark"
    "墨黑"               = "ink_dark"
    "墨黑高對比"         = "ink_dark"
}

function Show-Themes {
    Write-Host "Available themes:"
    for ($i = 0; $i -lt $order.Count; $i++) {
        $t = $themes[$order[$i]]
        Write-Host ("  {0,2}) {1,-14} {2}" -f ($i + 1), $order[$i], $t.label)
    }
}

if ($List) {
    Show-Themes
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    Show-Themes
    $choice = Read-Host "Choose a theme [1-$($order.Count)] (default 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $Name = "light"
    }
    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $order.Count) {
        $Name = $order[[int]$choice - 1]
    }
    else {
        throw "invalid choice: $choice"
    }
}

$norm = $Name.Trim().ToLowerInvariant()
if ($aliases.ContainsKey($Name)) {
    $norm = $aliases[$Name]
}
elseif ($aliases.ContainsKey($norm)) {
    $norm = $aliases[$norm]
}
if (-not $themes.ContainsKey($norm)) {
    throw "unknown theme '$Name'. Use -List to see all themes (or 淺/深/灰/馬卡龍/地中海/櫻/櫻桃/海洋/薄荷/薰衣草/莫蘭迪藍/莫蘭迪茶棕/琥珀深/森林深/墨黑)"
}

$entry = $themes[$norm]
if (-not (Test-Path $target)) {
    throw "missing $target; run install-package.ps1 first."
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$pattern = '(?m)^(\s*color_scheme:\s*)\S+'
foreach ($file in @($target, $appTarget)) {
    if (-not (Test-Path $file)) { continue }
    $text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
    if ($text -notmatch $pattern) {
        throw "color_scheme line not found in $file"
    }
    $new = $text -replace $pattern, "`${1}$($entry.key)"
    [IO.File]::WriteAllText($file, $new, $utf8)
    Write-Host "==> updated $file"
}

if ($NoDeploy) {
    Write-Host "==> updated files only (-NoDeploy)"
    Write-Host "Theme: $($entry.label)  ($($entry.key))"
    return
}

$roots = @("$env:ProgramFiles\Rime", "${env:ProgramFiles(x86)}\Rime") |
    Where-Object { Test-Path $_ }
$rimeDll = Get-ChildItem -Path $roots -Recurse -Filter rime.dll -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $rimeDll) {
    throw "rime.dll not found. Install Weasel 0.17.4 first."
}
$server = Get-ChildItem -Path $roots -Recurse -Filter WeaselServer.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not (Test-Path $deploy)) {
    throw "package is incomplete: missing $deploy"
}

$env:PUFF_RIME_DLL = $rimeDll.FullName
$env:PUFF_RIME_SHARED_DATA = Join-Path $rimeDll.Directory.FullName "data"
$env:PUFF_RIME_USER_DIR = $userDir

if ($server) {
    Write-Host "==> stopping WeaselServer"
    Get-Process WeaselServer -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 800
}

$buildDir = Join-Path $userDir "build"
if (Test-Path $buildDir) {
    Write-Host "==> removing old build cache"
    Remove-Item $buildDir -Recurse -Force
}

Write-Host "==> deploying with rime_deploy.exe"
& $deploy
if ($LASTEXITCODE -ne 0) {
    throw "rime_deploy failed with exit code $LASTEXITCODE"
}

Remove-Item Env:\PUFF_RIME_USER_DIR -ErrorAction SilentlyContinue
Remove-Item Env:\PUFF_HARNESS_USER_DIR -ErrorAction SilentlyContinue
Remove-Item Env:\PUFF_RIME_DLL -ErrorAction SilentlyContinue
Remove-Item Env:\PUFF_RIME_SHARED_DATA -ErrorAction SilentlyContinue

if ($server) {
    Write-Host "==> starting WeaselServer"
    Start-Process -FilePath $server.FullName | Out-Null
}

Write-Host ""
Write-Host "Theme: $($entry.label)  ($($entry.key))"
Write-Host "Rime user dir: $userDir"
