# Work Log: Remove Homebrew Dependency for Ubuntu

**Date:** 2026-01-04
**Commits:** 1c3a59b (initial), 9e996f6, e960b12, 3cee3d5, d88ead2
**Type:** Architecture Change

## Summary

Removed Homebrew dependency for Ubuntu environments to enable true one-command installation without requiring manual package manager setup. Ubuntu systems now use apt and official installers directly.

## Background

### Original Issue
The initial `.bootup` implementation had Ubuntu depending on Homebrew (Linuxbrew), which:
- Required root privileges for installation
- Failed when run as root (Homebrew doesn't allow root execution)
- Contradicted the goal of one-command automated setup
- Added unnecessary complexity for Ubuntu users

### Comparison with Existing System
The previous dotbot-based system (`~/.install` on remote machines) successfully used:
- `apt` for system packages
- Official installers for individual tools (80+ scripts in `steps/shell/`)
- No Homebrew dependency on Linux

## Changes Made

### 1. Configuration Template Changes

**Files Modified:**
- `root/.chezmoi.toml.tmpl`
- `users/.chezmoi.toml.tmpl`

**Change:**
```diff
-{{- $useHomebrew := or $isMac (and $isUbuntu (not $isContainer)) -}}
+{{- $useHomebrew := $isMac -}}
```

**Impact:** `use_homebrew` flag is now `true` only for macOS, `false` for all Linux/Ubuntu variants.

### 2. New Installation Scripts

#### a. mise Installer (`run_once_before_25-install-mise.sh.tmpl`)

**Purpose:** Install mise (modern version manager) using official installer

**Method:**
```bash
curl https://mise.run | sh
```

**Features:**
- Skip if Homebrew environment (macOS)
- Skip if non-Ubuntu
- Idempotent (checks if already installed)
- Creates symlink to `/usr/local/bin/mise`

#### b. CLI Tools Installer (`run_once_before_35-install-cli-tools.sh.tmpl`)

**Purpose:** Install essential CLI development tools without Homebrew

**Tools Installed:**
1. **GitHub CLI (gh)** - via apt repository
2. **starship** - via GitHub releases (musl binary direct download)
3. **neovim** - via PPA (neovim-ppa/unstable)
4. **fzf** - via git clone + manual install
5. **ghq** - via GitHub releases
6. **lazygit** - via GitHub releases
7. **delta (git-delta)** - via GitHub releases
8. **Rust-based tools** - via cargo:
   - ripgrep
   - fd-find
   - bat
   - eza
   - zoxide

**Method:**
- Each tool has version detection via GitHub API
- Downloads latest release binaries
- Installs to `/usr/local/bin`
- Fully automated, no user interaction required

### 3. Existing Scripts (Unchanged)

The following scripts already had proper guards:
- `run_once_before_20-install-homebrew.sh.tmpl` - Skips if `!use_homebrew`
- `run_once_before_31-install-packages-brew.sh.tmpl` - Skips if `!use_homebrew`

## Execution Flow

### macOS (unchanged)
1. Install Homebrew
2. Install packages via `brew install`
3. Install language runtimes via `mise` (from Homebrew)

### Ubuntu (new flow)
1. Install base packages via apt (step 30)
2. **Install mise via official installer (step 25)**
3. **Install CLI tools via official installers (step 35)**
4. Install Docker (step 50)
5. Install cloud tools (step 60)

## Benefits

1. **True One-Command Setup** - No manual Homebrew installation needed
2. **No Root/User Conflicts** - All installers work correctly with sudo
3. **Faster Installation** - Official binaries install faster than compiling via Homebrew
4. **Simpler Maintenance** - No Homebrew-specific issues on Linux
5. **Consistent with Best Practices** - Uses native package manager (apt) for base system

## Additional Fixes

### Starship Installation Fix
The official starship installer didn't work on Ubuntu 22.04 (error: "ubuntu builds for unknown-linux-musl are not yet available"). Fixed by downloading the musl binary directly from GitHub releases:

```bash
STARSHIP_VERSION=$(curl -s https://api.github.com/repos/starship/starship/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz" | tar xz -C /tmp
mv /tmp/starship /usr/local/bin/starship
```

### Removed ubuntu_ct Configuration
Removed the `ubuntu_ct` architecture type as it's no longer needed:
- Removed from `install` script (VALID_ARCHS, detect_arch)
- Removed from `.chezmoi.toml.tmpl` files (both root and users)
- Removed from `shared/data/arch.yaml`
- Removed from `shared/data/tools.yaml` (exclude_arch sections)
- Removed from validation script
- Updated README.md and CI workflow

Containers now use the standard `ubuntu` arch type.

Note: `is_container` flag is kept with hardcoded `false` value for template compatibility.

### software-properties-common Fix
Added `software-properties-common` to APT packages for `add-apt-repository` command (required for neovim PPA).

### yq Installation Fix
Changed yq installation from apt (not available in Ubuntu 22.04) to GitHub releases:

```bash
YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq
```

## Testing Recommendations

Test on clean Ubuntu installations:
```bash
# Ubuntu 24.04 LTS
sudo ARCH=ubuntu AREA=home ./install root

# Ubuntu Server (GCP)
sudo ARCH=ubuntu AREA=gcp ./install root

# Ubuntu in container (use standard ubuntu arch)
sudo ARCH=ubuntu AREA=home ./install root
```

Verified on Ubuntu 22.04 LXC container (192.168.0.41):
- ✓ All tools install successfully
- ✓ No Homebrew installation attempted
- ✓ mise, CLI tools, and cloud tools properly installed
- ✓ Scripts are idempotent (safe to run multiple times)

### Installed Tool Versions (verified)
- starship 1.24.2
- nvim 0.12.0-dev
- gh 2.83.2
- fzf 0.67.0
- ghq 1.8.0
- lazygit 0.58.0
- delta 0.18.2
- mise 2025.12.13
- yq 4.50.1
- ripgrep 15.1.0
- fd 10.3.0
- bat 0.26.1
- eza
- zoxide 0.9.8
- aws cli
- gcloud
- oci cli 3.71.4

## Future Work

Consider adding:
1. Additional CLI tools as needed (from existing dotbot implementation)
2. Version pinning for critical tools
3. Fallback mechanisms if official installers change
4. Verification checksums for downloaded binaries

## References

- Original dotbot implementation: `~/.install` on production machines
- Design document: `docs/design-docs/migration.md`
- Requirements document: `docs/design-docs/requirements.md`
