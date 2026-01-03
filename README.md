# .bootup

chezmoi-based multi-environment development setup system.

## Features

- **Single Command Setup**: Initialize your development environment with one command
- **Multi-Platform Support**: WSL, Ubuntu, macOS
- **Multi-Environment Support**: Home, GCP, OCI, ConoHa
- **Root/User Separation**: Clear separation between system configuration and user dotfiles
- **Template-Based**: Declarative configuration using Go templates

## Quick Start

```bash
# Clone the repository
git clone https://github.com/TakashiAihara/.bootup.git
cd .bootup

# WSL + Home environment
ARCH=wsl AREA=home ./install

# macOS
ARCH=mac AREA=home ./install

# Ubuntu on GCP (as root with target user)
sudo ARCH=ubuntu AREA=gcp TARGET_USER=yourname ./install
```

## Supported Environments

### ARCH (Architecture/OS)

| ARCH | Description |
|------|-------------|
| `wsl` | Windows Subsystem for Linux (Ubuntu) |
| `ubuntu` | Ubuntu Server/Desktop |
| `ubuntu-dev` | Ubuntu with GUI |
| `ubuntu_ct` | Ubuntu Container (LXC/Docker) |
| `ubuntu_nat` | Ubuntu behind NAT |
| `mac` | macOS |

### AREA (Environment/Location)

| AREA | Description |
|------|-------------|
| `home` | Home environment (full development) |
| `gcp` | Google Cloud Platform |
| `oci` | Oracle Cloud Infrastructure |
| `conoha` | ConoHa VPS |

## Usage

```bash
# Show help
./install --help

# Dry run
ARCH=ubuntu AREA=gcp ./install --dry-run

# Verbose output
ARCH=mac AREA=home ./install --verbose

# Root configuration only
sudo ARCH=ubuntu AREA=oci ./install root

# User configuration only
ARCH=wsl AREA=home ./install user
```

## Directory Structure

```
.bootup/
├── install                 # Entry point script
├── root/                   # Root chezmoi source directory
│   ├── .chezmoi.toml.tmpl  # chezmoi config template
│   ├── .chezmoiignore      # Ignore patterns
│   └── .chezmoiscripts/    # Installation scripts
├── users/                  # User chezmoi source directory
│   ├── .chezmoi.toml.tmpl  # chezmoi config template
│   ├── .chezmoiignore.tmpl # Ignore patterns (template)
│   ├── .chezmoiscripts/    # User setup scripts
│   ├── dot_zshrc.tmpl      # ~/.zshrc
│   ├── dot_zshenv.tmpl     # ~/.zshenv
│   ├── dot_gitconfig.tmpl  # ~/.gitconfig
│   └── dot_config/         # ~/.config/
└── shared/                 # Shared resources
    └── data/               # Data files (packages, tools, etc.)
```

## What Gets Installed

### Packages

- **Essential**: git, curl, wget, zsh
- **CLI Tools**: ripgrep, fd, bat, eza, fzf, jq, yq, tmux, neovim
- **Development**: mise, direnv, gh, ghq, lazygit, delta
- **Languages** (via mise): Node.js, Python, Go, Rust, etc.

### Dotfiles

- Shell: `.zshrc`, `.zshenv`
- Git: `.gitconfig`, `.gitignore_global`
- Editor: neovim config
- Terminal: tmux, starship prompt
- Tools: mise config

## Requirements

- Internet connection
- sudo privileges (for root configuration)
- On Ubuntu: `apt update` completed
- On macOS: Xcode Command Line Tools

## License

MIT