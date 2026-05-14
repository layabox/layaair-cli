# LayaAir CLI installer for Windows (PowerShell)
# Usage: iwr https://<URL>/install.ps1 | iex
#        $env:LAYAAIR_INSTALL_DIR="C:\tools\layaair"; iwr https://<URL>/install.ps1 | iex
#
# Install a specific version in one go:
#   iwr https://<URL>/install.ps1 | iex; & "$env:USERPROFILE\.layaair\layaair.cmd" install 3.4.0
#
# Installs the `layaair` dispatcher only. After install, manage CLI versions:
#   layaair install [version]        # default: latest
#   layaair list
#   layaair uninstall <version>
#   layaair --version                # print active version and exit
#   layaair --version=3.4.0 <args>   # select a specific installed version
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallDir = if ($env:LAYAAIR_INSTALL_DIR) { $env:LAYAAIR_INSTALL_DIR } else { "$env:USERPROFILE\.layaair" }

# ── node check ────────────────────────────────────────────────
$NodeVer = $null
try { $NodeVer = (& node --version 2>$null) } catch {}
if (-not $NodeVer) {
    Write-Error "[layaair] Node.js v20+ required. Install from https://nodejs.org/"; exit 1
}
$Major = [int](($NodeVer -replace '^v','') -split '\.' | Select-Object -First 1)
if ($Major -lt 20) {
    Write-Error "[layaair] Node.js v20+ required (found: $NodeVer)"; exit 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# ── dispatcher.js content (literal here-string, no interpolation) ─
$DispatcherContent = @'
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');
const https = require('https');
const http = require('http');

const DOWNLOAD_ROOT = 'https://ldc-1251285021.file.myqcloud.com/layaair3';
const LATEST_VERSION_URL = DOWNLOAD_ROOT + '/latest.txt';
const INSTALL_DIR = __dirname;
const VERSIONS_FILE = path.join(INSTALL_DIR, 'versions.json');

function getArg(argv, name) {
    for (let i = 0; i < argv.length; i++) {
        const eqM = argv[i].match(new RegExp('^--' + name + '=(.+)$'));
        if (eqM) return eqM[1];
        if (argv[i] === '--' + name && i + 1 < argv.length && !argv[i + 1].startsWith('--'))
            return argv[i + 1];
    }
    return null;
}

function loadVersions() {
    try { return JSON.parse(fs.readFileSync(VERSIONS_FILE, 'utf8')).versions || []; }
    catch (_) { return []; }
}

function saveVersions(versions) {
    fs.writeFileSync(VERSIONS_FILE, JSON.stringify({ versions }, null, 2) + '\n');
}

function semverParts(v) {
    const main = v.split('-')[0];
    const parts = main.split('.').map(Number);
    return { ma: parts[0] || 0, mi: parts[1] || 0, pa: parts[2] || 0, pre: v.includes('-') ? v.slice(v.indexOf('-') + 1) : '' };
}

function semverCompare(a, b) {
    const p = semverParts(a), q = semverParts(b);
    if (p.ma !== q.ma) return p.ma - q.ma;
    if (p.mi !== q.mi) return p.mi - q.mi;
    if (p.pa !== q.pa) return p.pa - q.pa;
    if (!p.pre && q.pre) return 1;
    if (p.pre && !q.pre) return -1;
    return p.pre < q.pre ? -1 : p.pre > q.pre ? 1 : 0;
}

function downloadBaseForVersion(version) {
    const parts = String(version).split('.');
    if (parts.length < 2 || !parts[0] || !parts[1]) {
        console.error('[layaair] Invalid version: ' + version);
        process.exit(1);
    }
    return DOWNLOAD_ROOT + '/layaair-' + parts[0] + '.' + parts[1] + '/cli';
}

function fuzzyMatch(hint, versions) {
    const sorted = [...versions].sort((a, b) => semverCompare(b.version, a.version));
    const exact = sorted.find(v => v.version === hint);
    if (exact) return exact;
    const hintParts = String(hint).split('.');
    if (hintParts.length >= 2) {
        const hintMinor = hintParts[0] + '.' + hintParts[1];
        const sameMinor = sorted.find(function (v) { const p = semverParts(v.version); return p.ma + '.' + p.mi === hintMinor; });
        if (sameMinor) return sameMinor;
    }
    const dotHint = hint + '.';
    const prefixed = sorted.find(v => v.version.startsWith(dotHint));
    if (prefixed) return prefixed;
    return sorted.find(v => v.version.startsWith(hint));
}

function getVersionHint(argv) {
    const ver = getArg(argv, 'version');
    if (ver) return ver;
    const proj = getArg(argv, 'project');
    if (proj) {
        try {
            const dir = path.resolve(proj);
            const entries = fs.readdirSync(dir);
            const laya = entries.find(f => f.endsWith('.laya'));
            if (laya) {
                const info = JSON.parse(fs.readFileSync(path.join(dir, laya), 'utf8'));
                if (info.version) return String(info.version);
            }
        } catch (_) {}
    }
    return null;
}

function platformInfo() {
    const p = process.platform;
    const osName = p === 'win32' ? 'win32' : p === 'darwin' ? 'darwin' : 'linux';
    const a = process.arch;
    if (a !== 'x64' && a !== 'arm64') {
        console.error('[layaair] Unsupported arch: ' + a);
        process.exit(1);
    }
    return { osName, arch: a };
}

function httpGet(url, onResponse, redirects) {
    redirects = redirects || 0;
    if (redirects > 5) { onResponse(new Error('Too many redirects'), null); return; }
    const mod = url.indexOf('https:') === 0 ? https : http;
    const req = mod.get(url, function (res) {
        const code = res.statusCode;
        if ((code === 301 || code === 302 || code === 303 || code === 307 || code === 308) && res.headers.location) {
            res.resume();
            httpGet(res.headers.location, onResponse, redirects + 1);
            return;
        }
        if (code !== 200) {
            onResponse(new Error('HTTP ' + code + ' for ' + url), null);
            return;
        }
        onResponse(null, res);
    });
    req.on('error', function (e) { onResponse(e, null); });
}

function httpGetText(url) {
    return new Promise(function (resolve, reject) {
        httpGet(url, function (err, res) {
            if (err) return reject(err);
            let data = '';
            res.setEncoding('utf8');
            res.on('data', function (c) { data += c; });
            res.on('end', function () { resolve(data); });
            res.on('error', reject);
        });
    });
}

function httpDownload(url, dest) {
    return new Promise(function (resolve, reject) {
        httpGet(url, function (err, res) {
            if (err) return reject(err);
            const out = fs.createWriteStream(dest);
            res.pipe(out);
            out.on('finish', function () { out.close(function () { resolve(); }); });
            out.on('error', reject);
        });
    });
}

function extractZip(zipFile, destDir) {
    if (process.platform === 'win32') {
        const cmd = 'Expand-Archive -LiteralPath ' + JSON.stringify(zipFile) +
                    ' -DestinationPath ' + JSON.stringify(destDir) + ' -Force';
        cp.execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', cmd], { stdio: 'inherit' });
    } else {
        cp.execFileSync('unzip', ['-q', zipFile, '-d', destDir], { stdio: 'inherit' });
    }
}

async function cmdInstall(versionArg) {
    const info = platformInfo();
    const osName = info.osName, arch = info.arch;

    let version = versionArg;
    if (!version || version === 'latest') {
        process.stdout.write('[layaair] Fetching latest version... ');
        try {
            version = (await httpGetText(LATEST_VERSION_URL)).trim();
        } catch (e) {
            console.error('failed: ' + e.message);
            process.exit(1);
        }
        if (!version) { console.error('failed.'); process.exit(1); }
        console.log(version);
    }

    const downloadBase = downloadBaseForVersion(version);
    const zipName = 'layaair-cli-' + version + '-' + osName + '-' + arch + '.zip';
    const zipUrl  = downloadBase + '/' + zipName;
    const tmpZip  = path.join(os.tmpdir(), 'layaair-cli-install-' + process.pid + '.zip');
    const tmpDir  = path.join(INSTALL_DIR, '.tmp-extract-' + process.pid);

    console.log('Installing LayaAir CLI ' + version + ' for ' + osName + '-' + arch + '...');

    try {
        await httpDownload(zipUrl, tmpZip);
    } catch (e) {
        console.error('[layaair] Download failed: ' + e.message);
        process.exit(1);
    }

    if (fs.existsSync(tmpDir)) fs.rmSync(tmpDir, { recursive: true, force: true });
    fs.mkdirSync(tmpDir, { recursive: true });
    extractZip(tmpZip, tmpDir);
    try { fs.unlinkSync(tmpZip); } catch (_) {}

    const versionDir = path.join(INSTALL_DIR, version);
    if (fs.existsSync(versionDir)) fs.rmSync(versionDir, { recursive: true, force: true });
    fs.renameSync(tmpDir, versionDir);

    if (osName !== 'win32') {
        try { fs.chmodSync(path.join(versionDir, 'layaair'), 0o755); } catch (_) {}
    }

    const versions = loadVersions().filter(function (v) { return v.version !== version; });
    versions.push({ version: version, path: version });
    saveVersions(versions);

    console.log('');
    console.log('✓ LayaAir CLI ' + version + ' installed to: ' + versionDir);
}

function cmdUninstall(version) {
    if (!version) {
        console.error('[layaair] Usage: layaair uninstall <version>');
        process.exit(1);
    }
    const versions = loadVersions();
    const entry = versions.find(function (v) { return v.version === version; });
    if (!entry) {
        console.error('[layaair] Not installed: ' + version);
        process.exit(1);
    }
    const dir = path.join(INSTALL_DIR, entry.path);
    if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
    saveVersions(versions.filter(function (v) { return v.version !== version; }));
    console.log('✓ Uninstalled ' + version);
}

function cmdList() {
    const versions = loadVersions();
    if (!versions.length) {
        console.log('[layaair] No versions installed. Run: layaair install');
        return;
    }
    const sorted = [...versions].sort(function (a, b) { return semverCompare(b.version, a.version); });
    console.log('Installed versions:');
    sorted.forEach(function (v, i) {
        console.log('  ' + (i === 0 ? '* ' : '  ') + v.version);
    });
    console.log('  (* = newest)');
}

(async function () {
    const argv = process.argv.slice(2);
    const sub = argv[0];

    if (sub === 'install')   { await cmdInstall(argv[1]); return; }
    if (sub === 'uninstall') { cmdUninstall(argv[1]); return; }
    if (sub === 'list')      { cmdList(); return; }

    if (argv.includes('--version') && !argv.find(function (a) { return a.startsWith('--version='); })) {
        const vers = loadVersions().sort(function (a, b) { return semverCompare(b.version, a.version); });
        console.log(vers.length ? vers[0].version : '(no CLI versions installed — run: layaair install)');
        return;
    }

    const versions = loadVersions();
    if (!versions.length) {
        console.error('[layaair] No versions installed. Run: layaair install');
        process.exit(1);
    }
    const hint = getVersionHint(argv);
    const sorted = [...versions].sort(function (a, b) { return semverCompare(b.version, a.version); });
    let chosen = hint ? fuzzyMatch(hint, versions) : sorted[0];
    if (!chosen) {
        chosen = sorted[0];
        console.warn('[layaair] Version ' + hint + ' not installed, opening with ' + chosen.version + '.');
    }
    const cliMain = path.join(INSTALL_DIR, chosen.path, 'Resources', 'cli-main.js');
    if (!fs.existsSync(cliMain)) {
        console.error('[layaair] Broken install for ' + chosen.version + ': ' + cliMain + ' not found');
        process.exit(1);
    }
    const result = cp.spawnSync(process.execPath, [cliMain, ...argv], { stdio: 'inherit' });
    process.exit(result.status != null ? result.status : 1);
})().catch(function (e) {
    console.error('[layaair] ' + (e && e.message || e));
    process.exit(1);
});
'@

[System.IO.File]::WriteAllText((Join-Path $InstallDir "dispatcher.js"), $DispatcherContent, [System.Text.Encoding]::UTF8)

# ── write layaair.cmd shim ────────────────────────────────────
$ShimCmdContent = @'
@echo off
setlocal EnableDelayedExpansion
set "DIR=%~dp0"
for /f "tokens=1 delims=." %%v in ('node --version 2^>nul') do (
  set "MAJOR=%%v"
  set "MAJOR=!MAJOR:v=!"
)
if "!MAJOR!"=="" (
  echo [layaair] ERROR: Node.js not found. Install from https://nodejs.org/
  exit /b 1
)
if !MAJOR! LSS 20 (
  echo [layaair] ERROR: Node.js v20+ required ^(found v!MAJOR!^)
  exit /b 1
)
node "%DIR%dispatcher.js" %*
'@
[System.IO.File]::WriteAllText((Join-Path $InstallDir "layaair.cmd"), $ShimCmdContent, [System.Text.Encoding]::ASCII)

# ── ensure versions.json exists ───────────────────────────────
$VersionsFile = Join-Path $InstallDir "versions.json"
if (-not (Test-Path $VersionsFile)) {
    [System.IO.File]::WriteAllText($VersionsFile, '{"versions":[]}' + "`n", [System.Text.Encoding]::UTF8)
}

# ── PATH setup (User scope + current session) ─────────────────
$UserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $UserPath) { $UserPath = '' }
if ($UserPath -notlike "*$InstallDir*") {
    [System.Environment]::SetEnvironmentVariable('Path', "$UserPath;$InstallDir", 'User')
    Write-Host "  Added $InstallDir to User PATH"
}
if ($env:Path -notlike "*$InstallDir*") {
    $env:Path = "$env:Path;$InstallDir"
}

Write-Host ""
Write-Host "✓ LayaAir CLI dispatcher installed to: $InstallDir"
Write-Host ""
Write-Host "  Next: install a CLI version"
Write-Host "    layaair install            # latest"
Write-Host "    layaair install 3.4.0      # specific"
