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

# Create a project with the default template
layaair create --create-name=MyGame

# Start the built-in preview server for the current project
layaair --project=.

# List build platforms supported by the current project
layaair build --project=. --list-platforms

# Build for Web
layaair build --project=. --build-platform=web
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
layaair --version=3.4.0 build --project=. --build-platform=web
```

When a command includes `--project`, `layaair` tries to read the `.laya` file in that project directory and match its `version` field to an installed CLI runtime. If no matching version is found, it falls back to the newest installed version and prints a warning.

## Usage

### Create a Project

List available templates before creating a project:

```bash
layaair create --list-templates
```

Create a project with the default template:

```bash
layaair create --create-name=MyGame
```

Create a project with a specific template:

```bash
layaair create \
  --create-name=MyGame \
  --create-template="2D empty project"
```

Common options:

| Option | Description |
| --- | --- |
| `--create-name` | Project name. Required when creating a project. |
| `--create-path` | Target project directory. |
| `--create-subdir` | Create a named subdirectory under the target directory. Defaults to `false`. |
| `--create-template` | Template display name from `--list-templates`. |
| `--list-templates` | Print available templates. |

### Build a Project

List build platforms supported by a project:

```bash
layaair build --project=. --list-platforms
```

Build a project:

```bash
layaair build --project=. --build-platform=web
```

Common options:

| Option | Description |
| --- | --- |
| `--project` | Project directory. |
| `--build-platform` | Target build platform. Required for builds. |
| `--build-out` | Build output directory. |
| `--build-recompile` | Recompile before building. |
| `--list-platforms` | Print build platforms supported by the current project. |

### Validate Resource Files

```bash
layaair validate --validate-files=main.ls,ui.lh
```

`--validate-files` accepts a comma-separated list of resource file paths.

### Preview a Project

Running `layaair` without a subcommand starts the built-in preview server:

```bash
layaair --project=.
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
layaair --project=. --script=BuildTools.exportData --script-args="./dist/data.json"
```

`--script-args` is parsed as a quote-aware argument string and passed to the target method as positional arguments.

## Command Reference

| Command | Purpose |
| --- | --- |
| `layaair install [version]` | Install the latest or specified CLI runtime. |
| `layaair uninstall <version>` | Uninstall a specified CLI runtime. |
| `layaair list` | List installed CLI runtimes. |
| `layaair --version` | Print the active CLI runtime version. |
| `layaair create ...` | Create a LayaAir project. |
| `layaair build ...` | Build a LayaAir project. |
| `layaair validate ...` | Validate resource files. |
| `layaair --project=<path>` | Start the built-in project preview server. |
| `layaair --project=<path> --script=Class.method` | Run a registered script method. |
| `layaair help` | Show the full CLI help for the installed version. |

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
