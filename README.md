# LayaAir CLI

English | [简体中文](./README.zh-CN.md)

LayaAir CLI is the command-line tool for LayaAir projects. It helps you create projects, build release targets, validate resources, preview projects, and run automation scripts from the terminal.

This repository provides cross-platform install scripts and the `layaair` command entry. It supports installing, switching, and managing multiple LayaAir CLI versions locally.

## Features

- Install, uninstall, and manage multiple LayaAir CLI versions.
- Create projects from built-in, cloud, or locally cached templates.
- Build LayaAir projects for supported target platforms.
- Validate LayaAir resource files.
- Start the built-in project preview server.
- Run registered project or plugin script methods from the command line.
- Select a CLI version explicitly or infer it from a project's `.laya` file.

## Requirements

- Node.js 20 or later.
- macOS, Linux, or Windows.
- `unzip` on macOS/Linux. The install script warns when it is missing; it is required when installing a CLI runtime.
- Network access when installing CLI versions, listing cloud templates, or creating projects from cloud templates.

Supported CPU architectures: `x64`, `arm64`.

## Installation

Use a one-line command to install the command entry and a CLI runtime.

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/layabox/layaair-cli/master/install.sh | bash && ~/.layaair/layaair install
```

Install a specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/layabox/layaair-cli/master/install.sh | bash && ~/.layaair/layaair install 3.4.0
```

Install to a custom directory:

```bash
curl -fsSL https://raw.githubusercontent.com/layabox/layaair-cli/master/install.sh | LAYAAIR_INSTALL_DIR=/opt/layaair bash && /opt/layaair/layaair install
```

### Windows PowerShell

```powershell
iwr https://raw.githubusercontent.com/layabox/layaair-cli/master/install.ps1 | iex; layaair install
```

Install a specific version:

```powershell
iwr https://raw.githubusercontent.com/layabox/layaair-cli/master/install.ps1 | iex; & "$env:USERPROFILE\.layaair\layaair.cmd" install 3.4.0
```

Install to a custom directory:

```powershell
$env:LAYAAIR_INSTALL_DIR = "C:\tools\layaair"; iwr https://raw.githubusercontent.com/layabox/layaair-cli/master/install.ps1 | iex; & "C:\tools\layaair\layaair.cmd" install
```

## Quick Start

```bash
# Install the latest CLI runtime
layaair install

# Print the active runtime version
layaair --version

# Create a project (name as positional arg)
layaair create MyGame

# Start the built-in preview server for the current project
layaair run -p .

# List build platforms supported by the current project
layaair build --list-platforms -p .

# Build for Web
layaair build web -p .
```

## Version Management

CLI runtimes are installed into a local directory. Default paths:

- macOS/Linux: `~/.layaair`
- Windows: `%USERPROFILE%\.layaair`

Common commands:

```bash
layaair install              # Install the latest version
layaair install 3.4.0        # Install a specific version
layaair uninstall 3.4.0      # Uninstall a specific version
layaair list                 # List installed versions
layaair --version            # Print the active version
```

By default, `layaair` uses the newest installed version.

Select a version for one command:

```bash
layaair --version=3.4.0 build web -p .
```

When a command includes `--project` / `-p`, `layaair` tries to read the `.laya` file in that project directory and match its `version` field to an installed CLI runtime. If no matching version is found, it falls back to the newest installed version and prints a warning.

## Usage

### Create a Project

List available templates before creating a project:

```bash
layaair create --list-templates
```

Create a project (name as positional argument):

```bash
layaair create MyGame
```

Create a project with a specific template:

```bash
layaair create MyGame -t "2D empty project"
```

Options:

| Option | Short | Description |
| --- | --- | --- |
| `--create-name=<name>` | `-n` | Project name. Also the `.laya` filename. |
| `--create-path=<path>` | `-p` | Parent directory. Default: current directory. |
| `--create-subdir` | `-s` | Create at `<path>/<name>/`. Default: off. |
| `--create-template=<name>` | `-t` | Template display name. Default: `"3D empty project"`. |
| `--list-templates` | `-l` | List available templates and exit. |

### Build a Project

List build platforms supported by a project:

```bash
layaair build --list-platforms
```

Build a project (platform as positional argument):

```bash
layaair build web
```

Build with a specific project directory and output path:

```bash
layaair build web -p /tmp/demo -o /tmp/out
```

Options:

| Option | Short | Description |
| --- | --- | --- |
| `--build-platform=<p>` | `-t` | Target platform name. |
| `--project=<path>` | `-p` | Project root. Default: current directory. |
| `--build-out=<path>` | `-o` | Output directory. Omit to use project build config. |
| `--build-recompile` | `-r` | Skip asset export and rebuild scripts only. |
| `--list-platforms` | `-l` | List available build platforms and exit. |

### Validate Resource Files

Validate files using positional arguments or `--validate-files`:

```bash
layaair validate assets/main.lh assets/player.lprefab
```

Options:

| Option | Short | Description |
| --- | --- | --- |
| `--validate-files=<f1,f2>` | `-f` | Comma-separated list of files. |
| `--project=<path>` | `-p` | Project root. Default: current directory. |

### Preview a Project

The `run` subcommand (or the bare `layaair` entry) starts the built-in preview server:

```bash
layaair run -p .
# equivalent shorthand:
layaair -p .
```

The server reads the project's editor settings and prints the preview URL after startup.

### Run Project Scripts

The CLI can call static methods on registered classes in project or plugin code.

Example TypeScript class:

```ts
@IEditorEnv.regClass()
export class BuildTools {
    static async exportData(outputPath: string): Promise<void> {
        // Custom automation.
    }
}
```

Run it from the command line:

```bash
layaair run -p . --script=BuildTools.exportData --script-args="./dist/data.json"
```

`--script-args` is parsed as a quote-aware argument string and passed to the target method as positional arguments.

## Global Options

These options apply to all commands:

| Option | Short | Description |
| --- | --- | --- |
| `--help` | `-h` | Show help. Use after a command for scoped help (`layaair build -h`). |
| `--debug` | `-d` | Enable debug logging. |
| `--enable-all-panels` | | Load all editor and extension panels in CLI mode. |

## Command Reference

| Command | Purpose |
| --- | --- |
| `layaair install [version]` | Install the latest or specified CLI runtime. |
| `layaair uninstall <version>` | Uninstall a specified CLI runtime. |
| `layaair list` | List installed CLI runtimes. |
| `layaair --version` | Print the active CLI runtime version. |
| `layaair create [name]` | Create a LayaAir project. |
| `layaair build [platform]` | Build a LayaAir project. |
| `layaair validate [files...]` | Validate resource files. |
| `layaair run [-p <path>]` | Start the built-in project preview server. |
| `layaair run -p <path> --script=Class.method` | Run a registered script method. |
| `layaair help [command]` | Show help, optionally scoped to a command. |

## Troubleshooting

### `No versions installed`

No CLI runtime has been installed yet. Run:

```bash
layaair install
```

### `Node.js v20+ required`

Install or activate Node.js 20 or later, then run the command again.

### `unzip not found`

Install `unzip`, then run `layaair install` again.

macOS:

```bash
xcode-select --install
```

Debian/Ubuntu:

```bash
sudo apt-get install unzip
```

### `Version <x> not installed`

Install the requested version:

```bash
layaair install <version>
```

You can also remove `--version=<version>` and let `layaair` use the newest installed version.

### Template or runtime download fails

Check your network connection and confirm that the requested LayaAir version exists. Cloud template listing and CLI runtime installation require access to the LayaAir download service.

## Repository Layout

```text
.
├── install.sh        # macOS/Linux install script
├── install.ps1       # Windows PowerShell install script
├── README.md         # English documentation
├── README.zh-CN.md   # Simplified Chinese documentation
└── LICENSE           # MIT License
```

After installation, the local install directory contains:

- `layaair` or `layaair.cmd`: command-line entry.
- `versions.json`: local CLI runtime version registry.

## License

This project is released under the MIT License. See [LICENSE](./LICENSE).
