# Build one complete, ready-to-carry PuffIME package:
#
#   release/PuffIME-win64.zip   Windows (Weasel / 小狼毫)
#   release/PuffIME-trime.zip   Android (Trime / 同文輸入法)
#   release/PuffIME-all.zip     both zips + 使用說明.txt
#
# By default the Windows package includes the generated dictionary, so the
# target PC does NOT need liu7.cin / boshiamy.lime.  That package contains
# data derived from your own Boshiamy table; keep it for personal use and do
# not redistribute it.
#
#   powershell -ExecutionPolicy Bypass -File tools\package-all.ps1
#
# Options:
#   -OutDir <dir>       output folder (default: release)
#   -Distribution       Windows package without the Boshiamy-derived dictionary
#                       (public-release safe); skips the Trime zip
#   -SkipBuild          reuse the existing dist/ instead of rebuilding
#   -NoBundle           do not create PuffIME-all.zip
#
# Requires Python 3 and data\liu7.cin or data\boshiamy.lime for the build
# (unless -SkipBuild is used with an already built dist/).

param(
    [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "release"),
    [switch]$Distribution,
    [switch]$SkipBuild,
    [switch]$NoBundle
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tools = $PSScriptRoot

function Write-Step($text) {
    Write-Host ""
    Write-Host "==> $text"
}

function Assert-Exists($path, $hint) {
    if (-not (Test-Path $path)) {
        throw "$hint`nMissing: $path"
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

Write-Host "PuffIME full package"
Write-Host "  output: $OutDir"
Write-Host "  mode:   $(if ($Distribution) { 'distribution (no local dictionary)' } else { 'portable (includes local dictionary)' })"

# 1) Build dictionaries and copy src -> dist.
if (-not $SkipBuild) {
    $hasTable = (Test-Path (Join-Path $root "data\liu7.cin")) -or
                (Test-Path (Join-Path $root "data\boshiamy.lime"))
    if (-not $hasTable) {
        throw @"
No Boshiamy table found.

Put your legally obtained liu7.cin or boshiamy.lime in:
  $(Join-Path $root 'data')

Then run this script again.  If dist/ is already built, use -SkipBuild.
"@
    }

    Write-Step "building dictionaries (tools\build.ps1)"
    & (Join-Path $tools "build.ps1")
    if (-not $?) { throw "build.ps1 failed" }
}
else {
    Write-Step "skipping build (-SkipBuild)"
    Assert-Exists (Join-Path $root "dist\puffime.schema.yaml") "dist is not built."
    Assert-Exists (Join-Path $root "dist\puffime.dict.yaml") "dist\puffime.dict.yaml is missing."
    Assert-Exists (Join-Path $root "dist\puffzhuyin.dict.yaml") "dist\puffzhuyin.dict.yaml is missing."
}

# 2) Windows package.
Write-Step "packaging Windows (PuffIME-win64.zip)"
$winArgs = @{ OutDir = $OutDir; SkipBuild = $true }
if (-not $Distribution) { $winArgs['IncludeDict'] = $true }
& (Join-Path $tools "package.ps1") @winArgs
if (-not $?) { throw "package.ps1 failed" }

$winZip = Join-Path $OutDir "PuffIME-win64.zip"
Assert-Exists $winZip "Windows zip was not produced."

# 3) Android / Trime package.  It always contains the generated dictionary
#    (Trime cannot build it on-device), so -Distribution skips it.
$trimeZip = $null
if (-not $Distribution) {
    Write-Step "packaging Android (PuffIME-trime.zip)"
    & (Join-Path $tools "build_trime.ps1") -OutDir $OutDir -SkipBuild
    if (-not $?) { throw "build_trime.ps1 failed" }
    $trimeZip = Join-Path $OutDir "PuffIME-trime.zip"
    Assert-Exists $trimeZip "Trime zip was not produced."
}
else {
    Write-Host "==> -Distribution: skipping Trime zip (it would contain the local dictionary)"
}

# 4) Bundle both zips with instructions.
$allZip = $null
if (-not $NoBundle) {
    Write-Step "bundling PuffIME-all.zip"
    $bundle = Join-Path $OutDir "PuffIME-all"
    if (Test-Path $bundle) { Remove-Item $bundle -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $bundle | Out-Null

    Copy-Item $winZip $bundle -Force
    if ($trimeZip) { Copy-Item $trimeZip $bundle -Force }

    $trimeSection = @'
Android（Trime 同文輸入法）
--------------------------
1. 先安裝 Trime（同文輸入法）。
2. 把 PuffIME-trime.zip 解壓到手機的一般資料夾，例如：
     Download/PuffIME
   檔案要直接放在這個資料夾裡，不要多一層。
3. Trime 設定 → 使用者資料夾 → 選擇 Download/PuffIME
   （或「資料儲存模式 → 從外部存儲同步」），
   回 Trime 按「部署」，選「泡芙輸入法」。
'@
    if (-not $trimeZip) {
        $trimeSection = @'
Android（Trime 同文輸入法）
--------------------------
這是 distribution 模式，沒有附 Trime zip。
請在自己的電腦上執行 tools\build_trime.ps1 產生，
或使用不含自製字典的版本自行部署。
'@
    }

    $contentLine = if ($trimeZip) {
        "  PuffIME-win64.zip   Windows（小狼毫 / Weasel）`r`n  PuffIME-trime.zip   Android（Trime 同文輸入法）"
    }
    else {
        "  PuffIME-win64.zip   Windows（小狼毫 / Weasel）"
    }
    $windowsDictNote = if ($Distribution) {
        "   這個版本不含字典；請先把你自己的 liu7.cin 或 boshiamy.lime`r`n   放進 data\ 資料夾，再執行 install.bat。"
    }
    else {
        "   這個完整包已內含字典，不需要另外準備嘸蝦米字碼表。"
    }
    $distNote = if ($Distribution) {
        "發佈版不含從嘸蝦米字碼表產生的字典。"
    }
    else {
        "這個包裝含有從你自己的嘸蝦米字碼表在本機產生的字典。`r`n請只在自己的裝置使用，不要公開散布字典或字碼表。"
    }

    $notesTemplate = @'
泡芙輸入法 PuffIME 完整包
==========================

這個壓縮檔包含：
__CONTENTS__
  使用說明.txt

Windows
-------
1. 解壓縮 PuffIME-win64.zip。
2. 雙擊裡面的 install.bat。
__WINDOWS_DICT_NOTE__
   安裝程式會安裝／檢查小狼毫（需要網路），並備份原本的 Rime 設定。
3. 在輸入框按 Ctrl+` 或 F4，選「泡芙輸入法」。

__TRIME_SECTION__

注音
----
空白是一聲，Enter 才上屏。
例：先按 ` 再打 ru，按空白，再按 Enter → 機；翻頁可選 稽。
    先按 ` 再打 ru，按空白、t86，再按 Enter → 稽查。

注意
----
__DIST_NOTE__
'@

    $notes = $notesTemplate
    $notes = $notes.Replace('__CONTENTS__', $contentLine)
    $notes = $notes.Replace('__WINDOWS_DICT_NOTE__', $windowsDictNote)
    $notes = $notes.Replace('__TRIME_SECTION__', $trimeSection.TrimEnd())
    $notes = $notes.Replace('__DIST_NOTE__', $distNote)
    $notes | Set-Content (Join-Path $bundle "使用說明.txt") -Encoding UTF8

    $allZip = Join-Path $OutDir "PuffIME-all.zip"
    if (Test-Path $allZip) { Remove-Item $allZip -Force }
    Compress-Archive -Path (Join-Path $bundle "*") -DestinationPath $allZip -Force
}

# 5) Summary.
Write-Host ""
Write-Host "==> done"
Get-ChildItem $OutDir -File -Filter "PuffIME-*.zip" |
    Sort-Object Name |
    ForEach-Object {
        $mb = [math]::Round($_.Length / 1MB, 2)
        Write-Host ("    {0,-24} {1,8} MB" -f $_.Name, $mb)
    }
Write-Host ""
Write-Host "Copy PuffIME-all.zip (or the individual zips) to the other PC / phone."
