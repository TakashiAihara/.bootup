# .bootup

chezmoi-based multi-environment development setup system.

## Prerequisites

実行前に以下のパッケージが必要です：

```bash
# Ubuntu/Debian
apt-get update && apt-get install -y git curl

# macOS (Xcode Command Line Tools)
xcode-select --install
```

## Quick Start

### 基本的な使い方

```bash
# リポジトリをクローン
git clone https://github.com/TakashiAihara/.bootup.git /tmp/.bootup
cd /tmp/.bootup

# Ubuntu サーバー（root で実行、dev ユーザーを自動作成）
sudo ARCH=ubuntu AREA=home TARGET_USER=dev \
  GITHUB_TOKEN='your_github_token' \
  ./install all
```

### GitHub API Rate Limit 回避

mise が GitHub API を使用するため、rate limit エラーを避けるには `GITHUB_TOKEN` が必要です：

```bash
# gh CLI でログイン済みの場合
GITHUB_TOKEN=$(gh auth token) ./install all

# または GitHub Personal Access Token を直接指定
GITHUB_TOKEN='ghp_xxxxxxxxxxxx' ./install all
```

## Environment Variables

| 変数 | 必須 | 説明 |
|------|------|------|
| `ARCH` | ○ | アーキテクチャ: `wsl`, `ubuntu`, `ubuntu-dev`, `ubuntu_nat`, `mac` |
| `AREA` | ○ | 環境: `home`, `gcp`, `oci`, `conoha` |
| `TARGET_USER` | △ | セットアップ対象ユーザー（デフォルト: `dev`） |
| `GITHUB_TOKEN` | △ | GitHub API トークン（rate limit 回避用） |

## Commands

```bash
# ヘルプ表示
./install --help

# root + user 両方（推奨）
sudo ARCH=ubuntu AREA=home TARGET_USER=dev ./install all

# root のみ（システム設定 + dev ユーザー作成）
sudo ARCH=ubuntu AREA=home ./install root

# user のみ（一般ユーザーとして実行）
ARCH=ubuntu AREA=home ./install user

# ドライラン
./install --dry-run

# 詳細出力
./install --verbose
```

## What Gets Installed

### Root 設定（`./install root`）

| 項目 | 内容 |
|------|------|
| 基本パッケージ | curl, git, zsh, vim, ffmpeg, redis-tools, postgresql-client |
| Locale/Timezone | ja_JP.UTF-8, Asia/Tokyo |
| mise | バイナリを /usr/local/bin にコピー |
| CLI ツール | starship, fzf, ghq, lazygit, delta, yq, ollama |
| Rust ツール | fd, bat, eza, zoxide（cargo → /usr/local/bin にコピー） |
| Docker | docker + compose |
| dev ユーザー | 自動作成、zsh シェル、sudoers、docker グループ |

### User 設定（`./install user` または `all`）

| 項目 | 内容 |
|------|------|
| シェル | zshrc, zshenv（zinit プラグイン） |
| Git | gitconfig, gitignore_global（delta 連携） |
| エディタ | neovim（lazy.nvim + プラグイン） |
| ターミナル | tmux, starship prompt |
| Claude | hooks 設定 |

### mise でインストールされるツール

#### 言語
- node@22, python@3.12, go@1.23, rust@stable
- deno, bun, java@21, dart, zig

#### CLI ツール
- zellij, act, rclone, yt-dlp, yj, ripgrep
- helm, grpcurl, hasura-cli, mongosh

#### Flutter
- flutter@latest

## Supported Environments

### ARCH

| 値 | 説明 |
|------|------|
| `wsl` | Windows Subsystem for Linux |
| `ubuntu` | Ubuntu Server/Desktop |
| `ubuntu-dev` | Ubuntu with GUI |
| `ubuntu_nat` | Ubuntu behind NAT |
| `mac` | macOS |

### AREA

| 値 | 説明 |
|------|------|
| `home` | ホーム環境（フル開発環境） |
| `gcp` | Google Cloud Platform |
| `oci` | Oracle Cloud Infrastructure |
| `conoha` | ConoHa VPS |

## Directory Structure

```
.bootup/
├── install                 # エントリーポイント
├── root/                   # Root chezmoi ソース
│   ├── .chezmoi.toml.tmpl
│   └── .chezmoiscripts/    # システム設定スクリプト
├── users/                  # User chezmoi ソース
│   ├── .chezmoi.toml.tmpl
│   ├── .chezmoiscripts/    # ユーザー設定スクリプト
│   ├── dot_zshrc.tmpl
│   ├── dot_gitconfig
│   └── dot_config/         # ~/.config/
└── docs/
    └── CHANGELOG.md        # 変更履歴
```

## Example: Fresh Ubuntu Container Setup

```bash
# 1. 必要なパッケージをインストール
apt-get update && apt-get install -y git curl

# 2. リポジトリをクローン
git clone https://github.com/TakashiAihara/.bootup.git /tmp/.bootup
cd /tmp/.bootup

# 3. フルインストール実行
ARCH=ubuntu AREA=home \
  TARGET_USER=dev \
  GITHUB_TOKEN=$(gh auth token) \
  ./install all

# 4. dev ユーザーでログイン
su - dev
```

## Troubleshooting

### GitHub API Rate Limit

```
mise ERROR: HTTP status client error (403 rate limit exceeded)
```

→ `GITHUB_TOKEN` を設定してください。

### User does not exist

```
User dev does not exist, skipping user configuration
```

→ `./install root` を先に実行するか、`./install all` を使用してください。


## License

MIT
