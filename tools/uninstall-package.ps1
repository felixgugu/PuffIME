# Remove PuffIME completely from this Windows account.
#
#   powershell -ExecutionPolicy Bypass -File tools\uninstall-package.ps1
#
# By default this removes every file PuffIME installed into the Rime user
# directory (%APPDATA%\Rime), including the generated dictionaries, Lua
# modules, the PuffIME schema list and Weasel theme, plus the user data
# (forgotten list / userdb).  Weasel itself is kept.
#
# Options:
#   -RimeUserDir <dir>   Rime user directory (default: %APPDATA%\Rime)
#   -UninstallWeasel     also uninstall Weasel 0.17.4 with winget
#   -RestoreBackup       restore the newest Rime.backup-* created by the
#                        installer instead of deleting PuffIME files
#   -KeepUserData        keep puffime_forgotten.tsv and puffime.userdb
#   -NoBackup            do not create a safety copy before deleting
#   -Force               do not ask for confirmation
#   -NoDeploy            only delete files; do not redeploy / restart Weasel

param(
    [string]$RimeUserDir = (Join-Path $env:APPDATA "Rime"),
    [switch]$UninstallWeasel,
    [switch]$RestoreBackup,
    [switch]$KeepUserData,
    [switch]$NoBackup,
    [switch]$Force,
    [switch]$NoDeploy
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$pkgRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$deploy = Join-Path $pkgRoot "tools\rime_deploy.exe"

# Files copied into the Rime user directory by install-package.ps1.
$schemaFiles = @(
    "puffime.schema.yaml",
    "puffzhuyin.schema.yaml",
    "puffime.dict.yaml",
    "puffzhuyin.dict.yaml",
    "puff.ico",
    "puff_ascii.ico",
    "rime.lua",
    "default.custom.yaml",
    "weasel.custom.yaml"
)

# Lua modules shipped by PuffIME (dist/lua).
$luaFiles = @(
    "boshiamy_completion_data.lua",
    "boshiamy_completion.lua",
    "boshiamy_hint.lua",
    "boshiamy_hints.lua",
    "boshiamy_prefixes.lua",
    "boshiamy_space.lua",
    "boshiamy_v.lua",
    "english_raw.lua",
    "forgotten.lua",
    "grave_guard.lua",
    "symbol_shape_filter.lua",
    "symbol_shape.lua",
    "zhuyin_bopomofo.lua",
    "zhuyin_completion_data.lua",
    "zhuyin_completion.lua",
    "zhuyin_digits.lua",
    "zhuyin_key.lua",
    "zhuyin_partial.lua"
)

function Remove-OwnedFile([string]$path) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force
        Write-Host "    removed $path"
    }
}

function Get-RimeDirs {
    $roots = @("$env:ProgramFiles\Rime", "${env:ProgramFiles(x86)}\Rime") |
        Where-Object { $_ -and (Test-Path $_) }
    $dll = Get-ChildItem -Path $roots -Recurse -Filter rime.dll -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $server = Get-ChildItem -Path $roots -Recurse -Filter WeaselServer.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1
    return @{ Dll = $dll; Server = $server }
}

function Stop-WeaselServer($server) {
    if ($server) {
        Write-Host "==> stopping WeaselServer"
        Get-Process WeaselServer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Milliseconds 800
    }
}

function Deploy-Rime {
    $rime = Get-RimeDirs
    if (-not $rime.Dll) {
        Write-Host "==> rime.dll not found; skipping redeploy."
        Write-Host "    Start Weasel once and run 'Deploy' from its menu if needed."
        return
    }
    if (-not (Test-Path $deploy)) {
        Write-Host "==> rime_deploy.exe not found; skipping redeploy."
        return
    }

    Stop-WeaselServer $rime.Server

    $env:PUFF_RIME_DLL = $rime.Dll.FullName
    $env:PUFF_RIME_SHARED_DATA = Join-Path $rime.Dll.Directory.FullName "data"
    $env:PUFF_RIME_USER_DIR = $RimeUserDir

    $buildDir = Join-Path $RimeUserDir "build"
    if (Test-Path $buildDir) {
        Write-Host "==> removing old build cache"
        Remove-Item $buildDir -Recurse -Force
    }

    Write-Host "==> redeploying Rime without PuffIME"
    & $deploy
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    warning: rime_deploy failed with exit code $LASTEXITCODE"
    }

    Remove-Item Env:\PUFF_RIME_USER_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:\PUFF_HARNESS_USER_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:\PUFF_RIME_DLL -ErrorAction SilentlyContinue
    Remove-Item Env:\PUFF_RIME_SHARED_DATA -ErrorAction SilentlyContinue

    if ($rime.Server) {
        Write-Host "==> restarting WeaselServer"
        Start-Process -FilePath $rime.Server.FullName | Out-Null
    }
}

if ($RestoreBackup) {
    $parent = Split-Path -Parent $RimeUserDir
    $leaf = Split-Path -Leaf $RimeUserDir
    $backups = @(Get-ChildItem -Path $parent -Directory -Filter "$leaf.backup-*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending)
    if ($backups.Count -eq 0) {
        throw "no backup found next to $RimeUserDir (looked for $leaf.backup-*)"
    }
    $chosen = $backups[0].FullName
    Write-Host "PuffIME uninstall: restore Rime backup"
    Write-Host "  user dir: $RimeUserDir"
    Write-Host "  restore:  $chosen"
}
else {
    Write-Host "PuffIME uninstall"
    Write-Host "  user dir: $RimeUserDir"
    if ($UninstallWeasel) { Write-Host "  Weasel:   will be uninstalled with winget" }
    if ($KeepUserData)    { Write-Host "  user data: kept" }
}

if (-not $Force) {
    Write-Host ""
    $answer = Read-Host "Continue? [y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        Write-Host "Cancelled."
        return
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ($RestoreBackup) {
    if (-not $NoBackup) {
        $safety = "$RimeUserDir.before-restore-$stamp"
        Write-Host "==> saving current settings to $safety"
        Copy-Item $RimeUserDir $safety -Recurse -Force
    }
    if (Test-Path $RimeUserDir) {
        Remove-Item $RimeUserDir -Recurse -Force
    }
    Copy-Item $chosen $RimeUserDir -Recurse -Force
    Write-Host "==> restored $chosen"
}
else {
    if (Test-Path $RimeUserDir) {
        if (-not $NoBackup) {
            $backup = "$RimeUserDir.puffime-uninstall-backup-$stamp"
            Write-Host "==> backing up $RimeUserDir -> $backup"
            Copy-Item $RimeUserDir $backup -Recurse -Force
        }

        Write-Host "==> removing PuffIME files"
        foreach ($name in $schemaFiles) {
            Remove-OwnedFile (Join-Path $RimeUserDir $name)
        }

        $luaDir = Join-Path $RimeUserDir "lua"
        foreach ($name in $luaFiles) {
            Remove-OwnedFile (Join-Path $luaDir $name)
        }
        if ((Test-Path $luaDir) -and -not (Get-ChildItem $luaDir -Force)) {
            Remove-Item $luaDir -Force
            Write-Host "    removed $luaDir"
        }

        Write-Host "==> removing PuffIME user data"
        Get-ChildItem $RimeUserDir -File -Filter "puffime.*" -ErrorAction SilentlyContinue |
            Remove-Item -Force
        Get-ChildItem $RimeUserDir -File -Filter "puffboshiamy.*" -ErrorAction SilentlyContinue |
            Remove-Item -Force
        Remove-OwnedFile (Join-Path $RimeUserDir "puffboshiamy.userdb")
        if (-not $KeepUserData) {
            Remove-OwnedFile (Join-Path $RimeUserDir "puffime.userdb")
            Remove-OwnedFile (Join-Path $RimeUserDir "puffime_forgotten.tsv")
            Remove-OwnedFile (Join-Path $RimeUserDir "puffboshiamy_forgotten.tsv")
        }

        Write-Host "==> removing old build cache"
        Remove-OwnedFile (Join-Path $RimeUserDir "build")
    }
    else {
        Write-Host "==> $RimeUserDir does not exist; nothing to delete there."
    }
}

if ($UninstallWeasel) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "==> winget not found; remove Weasel from Settings > Apps."
    }
    else {
        $list = (& winget list --id Rime.Weasel --exact --accept-source-agreements 2>$null | Out-String)
        if ($list -match [regex]::Escape("Rime.Weasel")) {
            Write-Host "==> uninstalling Rime.Weasel (UAC may appear)"
            & winget uninstall --id Rime.Weasel --exact --accept-source-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    warning: winget uninstall failed with exit code $LASTEXITCODE"
                Write-Host "    Remove Weasel manually from Settings > Apps."
            }
        }
        else {
            Write-Host "==> Rime.Weasel is not installed"
        }
    }
}
elseif (-not $NoDeploy) {
    Deploy-Rime
}

if ($RestoreBackup) {
    Write-Host ""
    Write-Host "Restored the Rime settings saved by the PuffIME installer."
}
else {
    Write-Host ""
    Write-Host "Removed PuffIME."
    if (-not $NoBackup) {
        Write-Host "A safety copy of the old Rime user directory was kept next to it."
    }
    Write-Host "You can close this window."
}
