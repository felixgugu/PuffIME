# Build PuffIME into dist/
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
#
# Generated files:
#   dist/puffime.dict.yaml   (from data/liu7.cin by default)
#   dist/puffzhuyin.dict.yaml     (from terra_pinyin + essay)
#   dist/lua/boshiamy_completion_data.lua (prefix -> essay-frequency order)
#   dist/lua/boshiamy_homophones.lua      (code -> same-pronunciation chars)
#   dist/lua/zhuyin_completion_data.lua   (zhuyin prefix -> essay-frequency order)
# Copied files:
#   src/*.yaml, src/lua/*.lua

param(
    [ValidateSet("auto", "cin", "lime")]
    [string]$Source = "auto"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "dist"
$src  = Join-Path $root "src"
$win  = Join-Path $root "platforms\windows"
$cin  = Join-Path $root "data\liu7.cin"
$lime = Join-Path $root "data\boshiamy.lime"

$resolved = $Source
if ($Source -eq "auto") {
    if (Test-Path $cin) { $resolved = "cin" }
    elseif (Test-Path $lime) { $resolved = "lime" }
    else {
        throw "No Boshiamy table found. Put data\liu7.cin (CIN) or data\boshiamy.lime (LIME) in data\."
    }
}
if ($resolved -eq "cin" -and -not (Test-Path $cin)) {
    throw "Missing data\liu7.cin. Download it and put it in data\."
}
if ($resolved -eq "lime" -and -not (Test-Path $lime)) {
    throw "Missing data\boshiamy.lime. Download it and put it in data\."
}

Push-Location $root
try {
    Write-Host "==> building boshiamy dictionary (source: $resolved)"
    if ($resolved -eq "cin") {
        python tools\lime2rime.py --input data\liu7.cin
    }
    else {
        python tools\lime2rime.py --input data\boshiamy.lime
    }

    Write-Host "==> building zhuyin dictionary"
    python tools\make_zhuyin.py

    Write-Host "==> building boshiamy hint table"
    if ($resolved -eq "cin") {
        python tools\make_hints.py --input data\liu7.cin
    }
    else {
        python tools\make_hints.py --input data\boshiamy.lime
    }

    Write-Host "==> building homophone table"
    if ($resolved -eq "cin") {
        python tools\make_homophones.py --input data\liu7.cin
    }
    else {
        python tools\make_homophones.py --input data\boshiamy.lime
    }

    Remove-Item (Join-Path $dist "lime-report.txt") -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Force -Path (Join-Path $dist "lua") | Out-Null

    Write-Host "==> copying schema / lua"
    Copy-Item -Path (Join-Path $src "*.yaml") -Destination $dist -Force
    Copy-Item -Path (Join-Path $src "rime.lua") -Destination $dist -Force
    Copy-Item -Path (Join-Path $src "lua\*.lua") -Destination (Join-Path $dist "lua") -Force
    Copy-Item -Path (Join-Path $win "weasel.custom.yaml") -Destination $dist -Force
    Get-ChildItem -Path (Join-Path $win "icons\*.ico") -File -ErrorAction SilentlyContinue |
        Copy-Item -Destination $dist -Force

    $required = @(
        "puffime.schema.yaml",
        "puffzhuyin.schema.yaml",
        "puffime.dict.yaml",
        "puffzhuyin.dict.yaml",
        "puff.ico",
        "puff_ascii.ico",
        "default.custom.yaml",
        "weasel.custom.yaml",
        "rime.lua",
        "lua\boshiamy_hints.lua",
        "lua\boshiamy_prefixes.lua",
        "lua\boshiamy_completion_data.lua",
        "lua\boshiamy_homophones.lua",
        "lua\boshiamy_hint.lua",
        "lua\boshiamy_completion.lua",
        "lua\boshiamy_v.lua",
        "lua\boshiamy_space.lua",
        "lua\symbol_shape.lua",
        "lua\symbol_shape_filter.lua",
        "lua\forgotten.lua",
        "lua\english_raw.lua",
        "lua\grave_guard.lua",
        "lua\zhuyin_digits.lua",
        "lua\zhuyin_partial.lua",
        "lua\zhuyin_completion.lua",
        "lua\zhuyin_completion_data.lua",
        "lua\zhuyin_bopomofo.lua"
    )
    foreach ($name in $required) {
        $p = Join-Path $dist $name
        if (-not (Test-Path $p)) { throw "missing build artifact: $p" }
    }

    Write-Host "==> build complete: $dist"
    Get-ChildItem $dist | Select-Object Name, Length | Format-Table -AutoSize
}
finally {
    Pop-Location
}
