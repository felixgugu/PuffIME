param(
    [string]$RimeUserDir = (Join-Path $env:APPDATA "Rime"),
    [switch]$SkipWeaselInstall,
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$pkgRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Join-Path $pkgRoot "app"
$deploy = Join-Path $pkgRoot "tools\rime_deploy.exe"

if (-not (Test-Path $app)) {
    throw "package is incomplete: missing $app"
}
if (-not (Test-Path $deploy)) {
    throw "package is incomplete: missing $deploy"
}

# The release package intentionally does not contain the Boshiamy-derived
# dictionary.  Build it locally from the user's own table on first install.
$dataDir = Join-Path $pkgRoot "data"
$dict = Join-Path $app "puffime.dict.yaml"
if (-not (Test-Path $dict)) {
    $table = $null
    foreach ($name in @("liu7.cin", "boshiamy.lime")) {
        $candidate = Join-Path $dataDir $name
        if (Test-Path $candidate) {
            $table = $candidate
            break
        }
    }
    if (-not $table) {
        Write-Host ""
        Write-Host "No Boshiamy table found."
        Write-Host "Put liu7.cin or boshiamy.lime in the data folder:"
        Write-Host "  $dataDir"
        Write-Host "Then run install.bat again."
        Write-Host ""
        Start-Process -FilePath explorer.exe -ArgumentList $dataDir
        throw "Boshiamy table missing."
    }

    $builder = Join-Path $pkgRoot "tools\make_dict.exe"
    $essay = Join-Path $dataDir "essay.txt"
    if (-not (Test-Path $builder)) {
        throw "package is incomplete: missing $builder"
    }
    if (-not (Test-Path $essay)) {
        throw "package is incomplete: missing $essay"
    }

    Write-Host "==> building dictionary from $table"
    $terra = Join-Path $dataDir "terra_pinyin.dict.yaml"
    $buildArgs = @("--input", $table, "--essay", $essay, "--out", $app)
    if (Test-Path $terra) { $buildArgs += @("--terra", $terra) }
    & $builder @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "dictionary build failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path $dict)) {
        throw "dictionary build did not produce $dict"
    }
}

if (-not $SkipWeaselInstall) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install Weasel 0.17.4 manually, then run this script with -SkipWeaselInstall."
    }
    Write-Host "==> checking Rime.Weasel"
    $list = (& winget list --id Rime.Weasel --exact --accept-source-agreements 2>$null | Out-String)
    if ($list -notmatch [regex]::Escape("Rime.Weasel")) {
        Write-Host "==> installing Rime.Weasel 0.17.4 (UAC may appear)"
        & winget install --id Rime.Weasel --exact --version 0.17.4 `
            --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "winget install failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Host "==> Rime.Weasel already installed"
    }
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

if (-not $NoBackup -and (Test-Path $RimeUserDir)) {
    $backup = "$RimeUserDir.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "==> backing up $RimeUserDir -> $backup"
    Copy-Item $RimeUserDir $backup -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $RimeUserDir | Out-Null

# Migrate the old PuffBoshiamy user data to the PuffIME name.
$oldForgotten = Join-Path $RimeUserDir "puffboshiamy_forgotten.tsv"
$newForgotten = Join-Path $RimeUserDir "puffime_forgotten.tsv"
if ((Test-Path $oldForgotten) -and -not (Test-Path $newForgotten)) {
    Copy-Item $oldForgotten $newForgotten -Force
}
if (Test-Path $oldForgotten) { Remove-Item $oldForgotten -Force }
Get-ChildItem $RimeUserDir -Filter "puffboshiamy.*" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force
$oldUserDb = Join-Path $RimeUserDir "puffboshiamy.userdb"
if (Test-Path $oldUserDb) { Remove-Item $oldUserDb -Recurse -Force }

Write-Host "==> copying app -> $RimeUserDir"
Copy-Item (Join-Path $app "*") $RimeUserDir -Recurse -Force

$env:PUFF_RIME_DLL = $rimeDll.FullName
$env:PUFF_RIME_SHARED_DATA = Join-Path $rimeDll.Directory.FullName "data"
$env:PUFF_RIME_USER_DIR = $RimeUserDir

if ($server) {
    Write-Host "==> stopping WeaselServer"
    Get-Process WeaselServer -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 800
}

$buildDir = Join-Path $RimeUserDir "build"
if (Test-Path $buildDir) {
    Write-Host "==> removing old build cache"
    Remove-Item $buildDir -Recurse -Force
}

Write-Host "==> deploying with rime_deploy.exe"
& $deploy
if ($LASTEXITCODE -ne 0) {
    throw "rime_deploy failed with exit code $LASTEXITCODE"
}

if ($server) {
    Write-Host "==> starting WeaselServer"
    # rime_deploy.exe needed PUFF_RIME_USER_DIR; the real IME must use its
    # normal Rime user directory, otherwise ,,fk reads a test/deleted path.
    Remove-Item Env:\PUFF_RIME_USER_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:\PUFF_HARNESS_USER_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:\PUFF_RIME_DLL -ErrorAction SilentlyContinue
    Remove-Item Env:\PUFF_RIME_SHARED_DATA -ErrorAction SilentlyContinue
    Start-Process -FilePath $server.FullName | Out-Null
}

Write-Host ""
Write-Host "Installed PuffIME."
Write-Host "1. Click into a text box."
Write-Host '2. Press Ctrl+` or F4, then select PuffIME.'
Write-Host "3. If Weasel is not in the language bar, run WeaselSetup.exe from the Weasel folder."
Write-Host ""
Write-Host "Rime user dir: $RimeUserDir"
Write-Host "Forgotten list: $RimeUserDir\puffime_forgotten.tsv"
