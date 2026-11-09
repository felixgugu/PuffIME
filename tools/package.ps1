param(
    [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "release"),
    [switch]$NoZip,
    # Skip tools/build.ps1 when dist/ is already up to date.
    [switch]$SkipBuild,
    # Include the generated puffime dictionary and Boshiamy-derived helper
    # tables so the package works on another PC without the user's table.
    # The default (off) is the distribution-safe package.
    [switch]$IncludeDict
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not $SkipBuild) {
    Write-Host "==> building dist"
    & (Join-Path $PSScriptRoot "build.ps1")
}
else {
    if (-not (Test-Path (Join-Path $root "dist\puffime.schema.yaml"))) {
        throw "dist is not built; run tools\build.ps1 first."
    }
    Write-Host "==> skipping build (-SkipBuild)"
}

$deploy = Join-Path $PSScriptRoot "rime_deploy.exe"
if (-not (Test-Path $deploy)) {
    Write-Host "==> building rime_deploy.exe"
    cmd /c (Join-Path $PSScriptRoot "build_deploy.bat")
}
if (-not (Test-Path $deploy)) {
    throw "rime_deploy.exe missing; run tools\build_deploy.bat first."
}

$makeDict = Join-Path $PSScriptRoot "make_dict.exe"
if (-not (Test-Path $makeDict)) {
    Write-Host "==> building make_dict.exe"
    & (Join-Path $PSScriptRoot "build_make_dict.ps1")
}
if (-not (Test-Path $makeDict)) {
    throw "make_dict.exe missing; run tools\build_make_dict.ps1 first."
}

$pkgName = "PuffIME-win64"
$pkg = Join-Path $OutDir $pkgName
if (Test-Path $pkg) {
    Remove-Item $pkg -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $pkg "app") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $pkg "tools") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $pkg "data") | Out-Null

Write-Host "==> collecting files"
Copy-Item (Join-Path $root "dist\*") (Join-Path $pkg "app") -Recurse -Force

# By default, never ship data derived from the user's Boshiamy table.
# install.bat builds these files locally from data\liu7.cin or
# data\boshiamy.lime.  With -IncludeDict they are kept so the package is
# self-contained (personal use only; do not redistribute the dictionary).
$derived = @(
    "app\puffime.dict.yaml",
    "app\lua\boshiamy_hints.lua",
    "app\lua\boshiamy_prefixes.lua",
    "app\lua\boshiamy_completion_data.lua"
)
if (-not $IncludeDict) {
    foreach ($rel in $derived) {
        $path = Join-Path $pkg $rel
        if (Test-Path $path) { Remove-Item $path -Force }
    }
}
Get-ChildItem (Join-Path $pkg "app") -Filter "*-report.txt" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force
Get-ChildItem (Join-Path $pkg "app\lua") -Filter "*-report.txt" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force

Copy-Item $deploy (Join-Path $pkg "tools\rime_deploy.exe") -Force
Copy-Item $makeDict (Join-Path $pkg "tools\make_dict.exe") -Force
Copy-Item (Join-Path $root "data\essay.txt") (Join-Path $pkg "data\essay.txt") -Force
Copy-Item (Join-Path $root "data\terra_pinyin.dict.yaml") (Join-Path $pkg "data\terra_pinyin.dict.yaml") -Force
Copy-Item (Join-Path $root "data\README.md") (Join-Path $pkg "data\README.md") -Force
Copy-Item (Join-Path $PSScriptRoot "install.bat") $pkg -Force
Copy-Item (Join-Path $PSScriptRoot "install-package.ps1") $pkg -Force
Copy-Item (Join-Path $PSScriptRoot "theme-package.ps1") $pkg -Force
Copy-Item (Join-Path $root "README.md") (Join-Path $pkg "README.md") -Force

if (-not $IncludeDict) {
    foreach ($rel in $derived) {
        if (Test-Path (Join-Path $pkg $rel)) {
            throw "package still contains Boshiamy-derived file: $rel"
        }
    }
}

$licenses = @'
PuffIME package

- Weasel / Rime: GPLv3 (https://rime.im/)
- terra_pinyin.dict.yaml / essay.txt: Rime project data (see their headers/licences)
- boshiamy.lime / liu7.cin: Boshiamy input-method tables.
  They are NOT included in this package.  The user supplies their own
  legally obtained table; install.bat builds the dictionary locally.
- make_dict.exe: PyInstaller one-file build; bundles Python (PSF License)
  and the PyInstaller bootloader (GPLv2 with exception).
- PuffIME scripts/config: see the project README.

Install: double-click install.bat
'@
if ($IncludeDict) {
    $licenses = @'
PuffIME portable package (personal use)

- Weasel / Rime: GPLv3 (https://rime.im/)
- terra_pinyin.dict.yaml / essay.txt: Rime project data (see their headers/licences)
- This package contains puffime.dict.yaml and Boshiamy-derived helper tables
  generated locally from the user's own Boshiamy input table.  They are for
  personal use on the owner's devices only.  Do not redistribute them.
- make_dict.exe: PyInstaller one-file build; bundles Python (PSF License)
  and the PyInstaller bootloader (GPLv2 with exception).
- PuffIME scripts/config: see the project README.

Install: double-click install.bat
'@
}
$licenses | Set-Content (Join-Path $pkg "LICENSES.txt") -Encoding UTF8

$install_notes = @'
泡芙輸入法 安裝說明
==================

1. 把這個資料夾解壓縮。
2. 先取得嘸蝦米字碼表（liu7.cin 或 boshiamy.lime），
   放到 data 資料夾。
3. 雙擊 install.bat。
   安裝程式會用你的字碼表在本機 build 字典，然後安裝。
4. 如果 Windows 跳出「已保護您的電腦」：
   按「更多資訊」→「仍要執行」。
   如果跳出「開啟檔案」警告：按「執行」。
   如果防毒軟體誤擋 make_dict.exe：請允許執行。
5. 看到 Done. 就完成了。
6. 在輸入框按 Ctrl + ` 或 F4，選「泡芙輸入法」。

安裝程式會自動安裝小狼毫（需要網路），並備份原本的 Rime 設定。
字碼表只留在你的電腦上，不會上傳。

如果語言列沒有小狼毫：
到 C:\Program Files\Rime\weasel-0.17.4\ 執行 WeaselSetup.exe，
把它加入鍵盤。
'@
if ($IncludeDict) {
    $install_notes = @'
泡芙輸入法 可攜安裝包（個人使用）
================================

這個版本已內含字典，不需要另外準備嘸蝦米字碼表。

1. 把這個資料夾解壓縮。
2. 雙擊 install.bat。
   安裝程式會安裝／檢查小狼毫（需要網路），
   備份原本的 Rime 設定，然後直接安裝。
3. 如果 Windows 跳出「已保護您的電腦」：
   按「更多資訊」→「仍要執行」。
   如果跳出「開啟檔案」警告：按「執行」。
4. 看到 Done. 就完成了。
5. 在輸入框按 Ctrl + ` 或 F4，選「泡芙輸入法」。

注音：空白是一聲，Enter 才上屏。
例：`ru` + 空白 + Enter → 機；翻頁可選 稽。

注意：這個包裝含有從你自己的嘸蝦米字碼表在本機產生的字典，
請只在自己的裝置使用，不要公開散布字典或字碼表。

如果語言列沒有小狼毫：
到 C:\Program Files\Rime\weasel-0.17.4\ 執行 WeaselSetup.exe，
把它加入鍵盤。
'@
}
$install_notes | Set-Content (Join-Path $pkg "INSTALL.txt") -Encoding UTF8

if (-not $NoZip) {
    $zip = Join-Path $OutDir "$pkgName.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Write-Host "==> creating $zip"
    Compress-Archive -Path $pkg -DestinationPath $zip -Force
}

Write-Host "==> package: $pkg"
if (-not $NoZip) { Write-Host "==> zip:     $(Join-Path $OutDir "$pkgName.zip")" }
