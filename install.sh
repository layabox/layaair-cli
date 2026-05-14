#!/usr/bin/env bash
# LayaAir CLI installer for macOS and Linux
# Usage: curl -fsSL <URL>/install.sh | bash
#        LAYAAIR_INSTALL_DIR=/custom/path curl -fsSL <URL>/install.sh | bash
#
# Install a specific version in one go:
#   curl -fsSL <URL>/install.sh | bash && ~/.layaair/layaair install 3.4.0
#
# Installs the `layaair` dispatcher only. After install, manage CLI versions:
#   layaair install [version]        # default: latest
#   layaair list
#   layaair uninstall <version>
#   layaair --version                # print active version and exit
#   layaair --version=3.4.0 <args>   # select a specific installed version
set -e

INSTALL_DIR="${LAYAAIR_INSTALL_DIR:-$HOME/.layaair}"

# ── node check ───────────────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
  echo "[layaair] ERROR: Node.js v20+ required. Install from https://nodejs.org/"
  exit 1
fi
NODE_VER=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 20 ]; then
  echo "[layaair] ERROR: Node.js v20+ required (found: v$NODE_VER)"
  exit 1
fi

# ── unzip check (used by `layaair install`) ──────────────────
if ! command -v unzip >/dev/null 2>&1; then
  echo "[layaair] WARNING: 'unzip' not found — 'layaair install' will fail until it's installed."
fi

mkdir -p "$INSTALL_DIR"

# ── write dispatcher.js ──────────────────────────────────────
cat > "$INSTALL_DIR/dispatcher.js" << 'DISPATCHER_EOF'
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
DISPATCHER_EOF

# ── write layaair shim ───────────────────────────────────────
cat > "$INSTALL_DIR/layaair" << 'SHIM_EOF'
#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
REQUIRED="20"
NODE_VER=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [ -z "$NODE_VER" ] || [ "$NODE_VER" -lt "$REQUIRED" ]; then
  echo "[layaair] ERROR: Node.js v${REQUIRED}+ required (found: $(node --version 2>/dev/null || echo 'not found'))"
  echo "  Install: https://nodejs.org/ or use nvm / fnm / volta"
  exit 1
fi
exec node "$DIR/dispatcher.js" "$@"
SHIM_EOF
chmod +x "$INSTALL_DIR/layaair"

# ── ensure versions.json exists ──────────────────────────────
if [ ! -f "$INSTALL_DIR/versions.json" ]; then
  echo '{"versions":[]}' > "$INSTALL_DIR/versions.json"
fi

# ── PATH setup ───────────────────────────────────────────────
PATH_LINE="export PATH=\"\$PATH:$INSTALL_DIR\""
add_to_profile() {
  local profile="$1"
  if [ -f "$profile" ] && ! grep -qF "$INSTALL_DIR" "$profile"; then
    echo "" >> "$profile"
    echo "# LayaAir CLI" >> "$profile"
    echo "$PATH_LINE" >> "$profile"
    echo "  Added to $profile"
  fi
}

case "$SHELL" in
  */zsh)  add_to_profile "$HOME/.zshrc" ;;
  */fish) add_to_profile "$HOME/.config/fish/config.fish" ;;
  *)      add_to_profile "$HOME/.bashrc"
          add_to_profile "$HOME/.bash_profile" ;;
esac

echo ""
echo "✓ LayaAir CLI dispatcher installed to: $INSTALL_DIR"
echo ""
echo "  Next: install a CLI version"
echo "    $INSTALL_DIR/layaair install            # latest"
echo "    $INSTALL_DIR/layaair install 3.4.0      # specific"
echo ""
echo "  (Open a new terminal — or 'export PATH=\"\$PATH:$INSTALL_DIR\"' — to use 'layaair' directly.)"
