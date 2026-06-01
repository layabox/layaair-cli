# LayaAir CLI

[English](./README.md) | 简体中文

LayaAir CLI 是面向 LayaAir 项目的命令行工具，用于创建项目、构建发布、资源校验、项目预览以及自动化脚本执行。

本仓库提供跨平台安装脚本和 `layaair` 命令入口，支持在本机安装、切换和管理多个 LayaAir CLI 版本。

## 功能特性

- 安装、卸载和管理多个 LayaAir CLI 版本。
- 从内置模板、云端模板或本地缓存模板创建项目。
- 按目标平台构建 LayaAir 项目。
- 校验 LayaAir 资源文件。
- 启动内置项目预览服务器。
- 从命令行调用项目或插件中注册的脚本方法。
- 支持显式指定 CLI 版本，也支持根据项目 `.laya` 文件推断版本。

## 环境要求

- Node.js 20 或更高版本。
- macOS、Linux 或 Windows。
- macOS/Linux 需要 `unzip`。如果缺失，安装脚本会给出警告；后续安装 CLI 运行时需要它解压 CLI 包。
- 安装 CLI 版本、列出云端模板或创建云端模板项目时需要网络访问。

支持的 CPU 架构：`x64`、`arm64`。

## 安装

推荐使用一行命令完成命令入口安装和 CLI 运行时安装。

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/layabox/layaair-cli/master/install.sh | bash && ~/.layaair/layaair install
```

安装指定版本：

```bash
curl -fsSL https://raw.githubusercontent.com/layabox/layaair-cli/master/install.sh | bash && ~/.layaair/layaair install 3.4.0
```

安装到自定义目录：

```bash
curl -fsSL https://raw.githubusercontent.com/layabox/layaair-cli/master/install.sh | LAYAAIR_INSTALL_DIR=/opt/layaair bash && /opt/layaair/layaair install
```

### Windows PowerShell

```powershell
iwr https://raw.githubusercontent.com/layabox/layaair-cli/master/install.ps1 | iex; layaair install
```

安装指定版本：

```powershell
iwr https://raw.githubusercontent.com/layabox/layaair-cli/master/install.ps1 | iex; & "$env:USERPROFILE\.layaair\layaair.cmd" install 3.4.0
```

安装到自定义目录：

```powershell
$env:LAYAAIR_INSTALL_DIR = "C:\tools\layaair"; iwr https://raw.githubusercontent.com/layabox/layaair-cli/master/install.ps1 | iex; & "C:\tools\layaair\layaair.cmd" install
```

## 快速开始

```bash
# 安装最新 CLI 运行时
layaair install

# 查看当前激活的运行时版本
layaair --version

# 创建项目（项目名作为位置参数）
layaair create MyGame

# 启动当前项目的内置预览服务器
layaair run -p .

# 列出当前项目支持的构建平台
layaair build --list-platforms -p .

# 构建 Web 平台
layaair build web -p .
```

## 版本管理

CLI 运行时会安装到本地目录。默认路径如下：

- macOS/Linux：`~/.layaair`
- Windows：`%USERPROFILE%\.layaair`

常用命令：

```bash
layaair install              # 安装最新版本
layaair install 3.4.0        # 安装指定版本
layaair uninstall 3.4.0      # 卸载指定版本
layaair list                 # 查看已安装版本
layaair --version            # 输出当前激活版本
```

默认情况下，`layaair` 会使用已安装版本中最新的一个。

也可以为单次命令显式指定版本：

```bash
layaair --version=3.4.0 build web -p .
```

当命令包含 `--project` / `-p` 时，`layaair` 会尝试读取项目目录下的 `.laya` 文件，并根据其中的 `version` 字段匹配本机已安装的 CLI 运行时。如果没有找到匹配版本，会回退到最新已安装版本并输出警告。

## 命令用法

### 创建项目

创建项目前建议先查看可用模板：

```bash
layaair create --list-templates
```

创建项目（项目名作为位置参数）：

```bash
layaair create MyGame
```

使用指定模板创建项目：

```bash
layaair create MyGame -t "2D empty project"
```

常用参数：

| 参数 | 短参数 | 说明 |
| --- | --- | --- |
| `--create-name=<name>` | `-n` | 项目名称，同时作为 `.laya` 文件名。 |
| `--create-path=<path>` | `-p` | 父目录，默认为当前目录。 |
| `--create-subdir` | `-s` | 在 `<path>/<name>/` 下创建项目，默认关闭。 |
| `--create-template=<name>` | `-t` | 模板显示名称，默认 `"3D empty project"`。 |
| `--list-templates` | `-l` | 输出可用模板列表后退出。 |

### 构建项目

查看项目支持的构建平台：

```bash
layaair build --list-platforms
```

构建项目（平台名作为位置参数）：

```bash
layaair build web
```

指定项目目录和输出目录：

```bash
layaair build web -p /tmp/demo -o /tmp/out
```

常用参数：

| 参数 | 短参数 | 说明 |
| --- | --- | --- |
| `--build-platform=<p>` | `-t` | 构建目标平台名称。 |
| `--project=<path>` | `-p` | 项目根目录，默认为当前目录。 |
| `--build-out=<path>` | `-o` | 构建输出目录，省略则使用项目构建配置。 |
| `--build-recompile` | `-r` | 跳过资源导出，仅重新编译脚本。 |
| `--list-platforms` | `-l` | 输出可用构建平台列表后退出。 |

### 校验资源文件

使用位置参数或 `--validate-files` 传入文件路径：

```bash
layaair validate assets/main.lh assets/player.lprefab
```

常用参数：

| 参数 | 短参数 | 说明 |
| --- | --- | --- |
| `--validate-files=<f1,f2>` | `-f` | 逗号分隔的资源文件路径列表。 |
| `--project=<path>` | `-p` | 项目根目录，默认为当前目录。 |

### 预览项目

使用 `run` 子命令（或裸 `layaair` 入口）启动内置预览服务器：

```bash
layaair run -p .
# 等效简写：
layaair -p .
```

服务器会读取项目的编辑器设置，并在启动后输出可访问的预览地址。

### 执行项目脚本

CLI 可以调用项目或插件代码中已注册类的静态方法。

示例 TypeScript 类：

```ts
@IEditorEnv.regClass()
export class BuildTools {
    static async exportData(outputPath: string): Promise<void> {
        // Custom automation.
    }
}
```

命令行调用：

```bash
layaair run -p . --script=BuildTools.exportData --script-args="./dist/data.json"
```

`--script-args` 会按支持引号的参数字符串解析，并作为位置参数传入目标方法。

## 全局选项

以下选项适用于所有命令：

| 选项 | 短参数 | 说明 |
| --- | --- | --- |
| `--help` | `-h` | 显示帮助。在命令后使用可查看该命令的专项帮助（如 `layaair build -h`）。 |
| `--debug` | `-d` | 启用调试日志。 |
| `--enable-all-panels` | | 在 CLI 模式下加载所有编辑器和扩展面板。 |

## 命令速查

| 命令 | 用途 |
| --- | --- |
| `layaair install [version]` | 安装最新或指定 CLI 运行时。 |
| `layaair uninstall <version>` | 卸载指定 CLI 运行时。 |
| `layaair list` | 查看已安装 CLI 运行时。 |
| `layaair --version` | 输出当前激活的 CLI 运行时版本。 |
| `layaair create [name]` | 创建 LayaAir 项目。 |
| `layaair build [platform]` | 构建 LayaAir 项目。 |
| `layaair validate [files...]` | 校验资源文件。 |
| `layaair run [-p <path>]` | 启动项目内置预览服务器。 |
| `layaair run -p <path> --script=Class.method` | 执行已注册脚本方法。 |
| `layaair help [command]` | 查看帮助，可指定命令获取专项帮助。 |

## 常见问题

### 提示 `No versions installed`

表示当前还没有安装任何 CLI 运行时。执行：

```bash
layaair install
```

### 提示 `Node.js v20+ required`

安装或切换到 Node.js 20 及以上版本后重新执行命令。

### 提示 `unzip not found`

安装 `unzip` 后重新执行 `layaair install`。

macOS：

```bash
xcode-select --install
```

Debian/Ubuntu：

```bash
sudo apt-get install unzip
```

### 提示 `Version <x> not installed`

安装对应版本：

```bash
layaair install <version>
```

也可以去掉 `--version=<version>`，让 `layaair` 使用最新已安装版本。

### 模板或运行时下载失败

检查网络连接，并确认请求的 LayaAir 版本存在。云端模板列表和 CLI 运行时安装都需要访问 LayaAir 下载服务。

## 仓库结构

```text
.
├── install.sh        # macOS/Linux 安装脚本
├── install.ps1       # Windows PowerShell 安装脚本
├── README.md         # 英文文档
├── README.zh-CN.md   # 简体中文文档
└── LICENSE           # MIT License
```

安装完成后，本机安装目录中会包含：

- `layaair` 或 `layaair.cmd`：命令行入口。
- `versions.json`：本机 CLI 运行时版本注册表。

## 许可证

本项目基于 MIT License 发布，详见 [LICENSE](./LICENSE)。
