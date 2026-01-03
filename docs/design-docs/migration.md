# Design Doc: chezmoi-based Multi-Environment Setup System

## Document Info

| 項目 | 内容 |
|------|------|
| ステータス | Draft |
| 作成日 | 2025-01-03 |
| 最終更新 | 2025-01-03 |

---

## 1. 概要

### 1.1 目的

Ubuntu/Mac/WSL/Windows 向けの開発環境初期セットアップを自動化するシステムを、既存の dotbot ベースから chezmoi ベースに移行・再設計する。

### 1.2 ゴール

- 新規環境のセットアップを **1コマンド** で完了できる
- 複数の OS/環境（ARCH × AREA）で一貫した開発環境を提供
- root 権限での実行（システム設定・パッケージ）と一般ユーザー権限での実行（dotfiles）を明確に分離
- テンプレートシステムにより、環境ごとの差異を宣言的に管理
- AI によるコード生成・保守が容易な構造

### 1.3 非ゴール

- Windows ネイティブ環境のサポート（WSL 経由のみ）
- GUI アプリケーションの設定管理（必要最小限に留める）
- 複数マシン間のリアルタイム同期

---

## 2. 背景

### 2.1 現状（dotbot ベース）

現在のシステムは dotbot を使用し、以下の構成で運用している：

```
.
├── install                      # メインインストールスクリプト
├── install_conf/                # OS別設定定義（ソース）
│   ├── wsl.yaml
│   ├── ubuntu.yaml
│   └── mac.yaml
├── target/                      # 生成された最終設定（自動生成）
├── steps/                       # 実行ステップの詳細定義
│   ├── shell/
│   ├── link/
│   ├── apt/
│   └── brewfile/
├── links/                       # リンク対象dotfiles (submodule)
└── plugins/                     # dotbotプラグイン (submodule)
```

### 2.2 現状の課題

1. **カスタムYAMLタグの複雑さ**: `!shell`, `!link`, `!apt` などのカスタムタグを Python スクリプトで展開する必要がある
2. **生成ステップの必要性**: `utils/generate.py` による前処理が必須
3. **プラグイン依存**: dotbot-apt, dotbot-brewfile など外部プラグインへの依存
4. **テンプレート機能の限界**: 環境ごとの細かい分岐が書きにくい
5. **デバッグの難しさ**: 生成後の YAML を追わないと実際の動作がわからない

### 2.3 chezmoi 移行の利点

1. **ネイティブテンプレートエンジン**: Go の text/template による強力なテンプレート機能
2. **生成不要**: テンプレートは実行時に展開される
3. **組み込み機能の充実**: パッケージ管理、シークレット管理、差分確認など
4. **単一バイナリ**: 依存関係なしで動作
5. **エコシステム**: 活発なコミュニティと豊富なドキュメント

---

## 3. アーキテクチャ

### 3.1 全体構成

```
┌─────────────────────────────────────────────────────────────────┐
│                        dotfiles リポジトリ                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │    root/    │    │   users/    │    │      shared/        │  │
│  │             │    │             │    │                     │  │
│  │ - packages  │    │ - dotfiles  │    │ - packages.yaml     │  │
│  │ - /etc/     │    │ - .config/  │    │ - tools.yaml        │  │
│  │ - services  │    │ - shell     │    │ - templates/        │  │
│  │             │    │ - ssh       │    │                     │  │
│  └──────┬──────┘    └──────┬──────┘    └──────────┬──────────┘  │
│         │                  │                      │             │
│         │    chezmoi       │     chezmoi          │  include    │
│         │    --source      │     --source         │             │
│         ▼                  ▼                      │             │
│  ┌─────────────┐    ┌─────────────┐              │             │
│  │ /root/      │    │ /home/user/ │◄─────────────┘             │
│  │ /etc/       │    │             │                            │
│  └─────────────┘    └─────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 実行フロー

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            ./install all                                  │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │   環境変数チェック             │
                    │   ARCH, AREA の検証           │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │   root 権限チェック           │
                    │   EUID == 0 ?                 │
                    └───────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
        ┌───────────────────┐           ┌───────────────────┐
        │   root として実行   │           │  user として実行   │
        │                   │           │                   │
        │ chezmoi init      │           │ chezmoi init      │
        │ --source=root/    │           │ --source=users/   │
        │ --apply           │           │ --apply           │
        └─────────┬─────────┘           └───────────────────┘
                  │
                  ▼
        ┌───────────────────┐
        │  TARGET_USER 設定  │
        │  されている?       │
        └─────────┬─────────┘
                  │ Yes
                  ▼
        ┌───────────────────┐
        │ su - $TARGET_USER │
        │ chezmoi init      │
        │ --source=users/   │
        │ --apply           │
        └───────────────────┘
```

### 3.3 chezmoi 実行時の内部フロー

```
chezmoi init --source=root/ --apply
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. .chezmoi.toml.tmpl の処理                                     │
│    - 環境変数 (ARCH, AREA) の読み込み                             │
│    - インタラクティブプロンプト（未設定の場合）                      │
│    - .chezmoi.toml 生成 → ~/.config/chezmoi/chezmoi.toml        │
└─────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. run_once_before_* スクリプトの実行                            │
│    - テンプレート展開 (.tmpl → .sh)                              │
│    - 実行 (bash)                                                │
│    - 実行済みハッシュを記録                                       │
└─────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. ファイル/ディレクトリの配置                                    │
│    - dot_* → .* へのリネーム                                    │
│    - private_* → 権限 0600 で配置                               │
│    - .tmpl → テンプレート展開                                    │
│    - exact_* → ディレクトリ内容を完全同期                         │
└─────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. run_once_after_* スクリプトの実行                             │
│    - テンプレート展開                                            │
│    - 実行                                                       │
└─────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. run_onchange_* スクリプトの実行（変更があった場合）             │
│    - ハッシュ比較で変更検知                                       │
│    - 変更があれば実行                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. ディレクトリ構成

### 4.1 トップレベル構成

```
dotfiles/
├── README.md                          # プロジェクト説明
├── LICENSE
├── install                            # エントリーポイントスクリプト
├── .gitignore
├── .github/
│   └── workflows/
│       ├── ci.yaml                    # CI テスト
│       └── release.yaml               # リリース自動化
│
├── root/                              # root 用 chezmoi source directory
│   └── ...
│
├── users/                             # 一般ユーザー用 chezmoi source directory
│   └── ...
│
└── shared/                            # 共通リソース
    └── ...
```

### 4.2 root/ ディレクトリ詳細

```
root/
├── .chezmoiroot                       # chezmoi source root マーカー（空ファイル）
├── .chezmoi.toml.tmpl                 # chezmoi 設定テンプレート
├── .chezmoidata.yaml                  # 静的データ定義
├── .chezmoiignore                     # 無視パターン
├── .chezmoiexternal.toml              # 外部リソース定義
│
├── .chezmoiscripts/                   # 実行スクリプト
│   │
│   │  # ========== before スクリプト（ファイル配置前） ==========
│   │
│   ├── run_once_before_00-validate-env.sh.tmpl
│   │   # 環境変数検証、前提条件チェック
│   │
│   ├── run_once_before_10-install-base-packages.sh.tmpl
│   │   # 基本パッケージ (git, curl, wget, etc.)
│   │
│   ├── run_once_before_20-install-homebrew.sh.tmpl
│   │   # Homebrew インストール (mac/linux)
│   │
│   ├── run_once_before_30-install-packages-apt.sh.tmpl
│   │   # APT パッケージインストール
│   │
│   ├── run_once_before_31-install-packages-brew.sh.tmpl
│   │   # Homebrew パッケージインストール
│   │
│   ├── run_once_before_40-install-mise.sh.tmpl
│   │   # mise インストール
│   │
│   ├── run_once_before_50-install-docker.sh.tmpl
│   │   # Docker インストール
│   │
│   ├── run_once_before_60-install-cloud-tools.sh.tmpl
│   │   # AWS CLI, gcloud, etc.
│   │
│   │  # ========== after スクリプト（ファイル配置後） ==========
│   │
│   ├── run_once_after_80-configure-services.sh.tmpl
│   │   # サービス設定・有効化
│   │
│   ├── run_once_after_90-setup-user.sh.tmpl
│   │   # 一般ユーザーのセットアップ呼び出し
│   │
│   │  # ========== onchange スクリプト（変更時のみ） ==========
│   │
│   └── run_onchange_99-reload-config.sh.tmpl
│       # 設定変更時のリロード処理
│
├── .chezmoitemplates/                 # 再利用可能テンプレート
│   ├── apt-install.tmpl               # APT インストールコマンド生成
│   ├── brew-install.tmpl              # Brew インストールコマンド生成
│   └── systemd-enable.tmpl            # systemd 有効化コマンド生成
│
└── etc/                               # /etc/ 配下の設定ファイル
    │  # chezmoi の target は / になる（要設定）
    │
    ├── private_dot_config/            # /etc/.config/ (あまり使わない)
    └── ...
```

### 4.3 users/ ディレクトリ詳細

```
users/
├── .chezmoiroot                       # chezmoi source root マーカー
├── .chezmoi.toml.tmpl                 # chezmoi 設定テンプレート
├── .chezmoidata.yaml                  # 静的データ定義
├── .chezmoiignore.tmpl                # 無視パターン（テンプレート）
├── .chezmoiexternal.toml              # 外部リソース（フォントなど）
│
├── .chezmoiscripts/
│   │
│   │  # ========== before スクリプト ==========
│   │
│   ├── run_once_before_00-validate-env.sh.tmpl
│   │   # 環境検証
│   │
│   ├── run_once_before_10-install-user-packages.sh.tmpl
│   │   # ユーザー権限で入れられるパッケージ
│   │
│   │  # ========== after スクリプト ==========
│   │
│   ├── run_once_after_50-setup-mise-tools.sh.tmpl
│   │   # mise で言語ランタイムをインストール
│   │
│   ├── run_once_after_60-setup-shell.sh.tmpl
│   │   # シェル設定（デフォルトシェル変更など）
│   │
│   ├── run_once_after_70-setup-neovim.sh.tmpl
│   │   # Neovim プラグインインストール
│   │
│   │  # ========== onchange スクリプト ==========
│   │
│   ├── run_onchange_after_mise-config.sh.tmpl
│   │   # mise 設定変更時に再インストール
│   │   # hash: {{ include "dot_config/mise/config.toml.tmpl" | sha256sum }}
│   │
│   └── run_onchange_after_brew-bundle.sh.tmpl
│       # Brewfile 変更時に再実行
│       # hash: {{ include "Brewfile.tmpl" | sha256sum }}
│
├── .chezmoitemplates/
│   └── shell-path.tmpl                # PATH 設定生成
│
│  # ========== dotfiles ==========
│
├── dot_zshrc.tmpl                     # ~/.zshrc
├── dot_zshenv.tmpl                    # ~/.zshenv
├── dot_bashrc.tmpl                    # ~/.bashrc (fallback)
├── dot_profile.tmpl                   # ~/.profile
│
├── dot_gitconfig.tmpl                 # ~/.gitconfig
├── dot_gitignore_global               # ~/.gitignore_global
│
├── dot_tmux.conf.tmpl                 # ~/.tmux.conf
├── dot_vimrc                          # ~/.vimrc (minimal fallback)
│
├── Brewfile.tmpl                      # ~/Brewfile (mac/linux-brew用)
│
│  # ========== .config/ ==========
│
├── dot_config/
│   │
│   ├── nvim/
│   │   ├── init.lua.tmpl
│   │   ├── lua/
│   │   │   ├── plugins/
│   │   │   │   └── ...
│   │   │   └── config/
│   │   │       └── ...
│   │   └── .chezmoiignore             # lazy-lock.json など除外
│   │
│   ├── starship.toml.tmpl             # Starship プロンプト
│   │
│   ├── mise/
│   │   └── config.toml.tmpl           # mise 設定
│   │
│   ├── alacritty/
│   │   └── alacritty.toml.tmpl        # Alacritty 設定
│   │
│   ├── wezterm/
│   │   └── wezterm.lua.tmpl           # WezTerm 設定
│   │
│   ├── gh/
│   │   └── config.yml.tmpl            # GitHub CLI 設定
│   │
│   ├── direnv/
│   │   └── direnvrc                   # direnv 設定
│   │
│   └── git/
│       └── ignore                     # グローバル gitignore
│
│  # ========== .ssh/ ==========
│
├── private_dot_ssh/                   # ~/.ssh/ (権限 0700)
│   ├── config.tmpl                    # SSH config
│   ├── private_config.d/              # config.d/ (権限 0700)
│   │   ├── 00-general.tmpl
│   │   ├── 10-github.tmpl
│   │   └── 20-servers.tmpl
│   └── .chezmoiignore                 # 秘密鍵は除外（別管理）
│
│  # ========== scripts/ ==========
│
├── exact_dot_local/
│   └── exact_bin/                     # ~/.local/bin/ (完全同期)
│       ├── executable_git-cleanup     # カスタムスクリプト
│       └── ...
│
│  # ========== private files ==========
│
└── private_dot_netrc.tmpl             # ~/.netrc (認証情報)
```

### 4.4 shared/ ディレクトリ詳細

```
shared/
│
├── data/
│   │
│   ├── packages.yaml                  # パッケージ定義
│   │   # 構造:
│   │   # apt:
│   │   #   common: [git, curl, ...]
│   │   #   server: [htop, ...]
│   │   #   desktop: [...]
│   │   # brew:
│   │   #   common: [...]
│   │   #   cask: [...]
│   │
│   ├── tools.yaml                     # 開発ツール定義
│   │   # 構造:
│   │   # mise:
│   │   #   node: "22"
│   │   #   python: "3.12"
│   │   # cloud:
│   │   #   - awscli
│   │   #   - gcloud
│   │
│   ├── arch.yaml                      # ARCH 別設定
│   │   # 構造:
│   │   # wsl:
│   │   #   display: ":0"
│   │   #   features: [...]
│   │   # mac:
│   │   #   features: [...]
│   │
│   └── area.yaml                      # AREA 別設定
│       # 構造:
│       # home:
│       #   network: "192.168.1.0/24"
│       # gcp:
│       #   project: "my-project"
│
├── templates/                         # 共通テンプレート断片
│   ├── _helpers.tmpl                  # ヘルパー関数
│   ├── apt-packages.tmpl              # APT パッケージリスト生成
│   ├── brew-packages.tmpl             # Brew パッケージリスト生成
│   └── path-setup.tmpl                # PATH 設定生成
│
└── scripts/                           # スタンドアロンスクリプト
    ├── detect-arch.sh                 # ARCH 自動検出
    ├── detect-area.sh                 # AREA 自動検出（IP等から）
    └── bootstrap.sh                   # 最小限のブートストラップ
```

---

## 5. 設定ファイル詳細

### 5.1 .chezmoi.toml.tmpl (root/)

```toml
# root/.chezmoi.toml.tmpl
# chezmoi 設定ファイルテンプレート（root 用）

{{/* ==================== 環境変数の取得 ==================== */}}

{{- $arch := "" -}}
{{- $area := "" -}}

{{/* ARCH の決定 */}}
{{- if env "ARCH" -}}
{{-   $arch = env "ARCH" -}}
{{- else if stat "/proc/sys/fs/binfmt_misc/WSLInterop" -}}
{{-   $arch = "wsl" -}}
{{- else if eq .chezmoi.os "darwin" -}}
{{-   $arch = "mac" -}}
{{- else -}}
{{-   $arch = promptStringOnce . "arch" "Architecture (wsl/ubuntu/ubuntu-dev/ubuntu_ct/ubuntu_nat/mac)" -}}
{{- end -}}

{{/* AREA の決定 */}}
{{- if env "AREA" -}}
{{-   $area = env "AREA" -}}
{{- else -}}
{{-   $area = promptStringOnce . "area" "Area (home/gcp/oci/conoha)" -}}
{{- end -}}

{{/* ==================== 派生フラグの計算 ==================== */}}

{{- $isWsl := eq $arch "wsl" -}}
{{- $isMac := eq $arch "mac" -}}
{{- $isUbuntu := or (eq $arch "ubuntu") (eq $arch "ubuntu-dev") (eq $arch "wsl") -}}
{{- $isContainer := eq $arch "ubuntu_ct" -}}
{{- $isServer := or (eq $area "gcp") (eq $area "oci") (eq $area "conoha") -}}
{{- $isHome := eq $area "home" -}}
{{- $hasGui := or $isMac (and $isWsl $isHome) (eq $arch "ubuntu-dev") -}}
{{- $useHomebrew := or $isMac (and $isUbuntu (not $isContainer)) -}}

{{/* ==================== chezmoi 基本設定 ==================== */}}

sourceDir = {{ .chezmoi.sourceDir | quote }}

[edit]
    command = "nvim"

[diff]
    pager = "delta"

[merge]
    command = "nvim"
    args = ["-d", "{{ "{{" }} .Destination {{ "}}" }}", "{{ "{{" }} .Source {{ "}}" }}", "{{ "{{" }} .Target {{ "}}" }}"]

{{/* ==================== データセクション ==================== */}}

[data]
    # 基本情報
    arch = {{ $arch | quote }}
    area = {{ $area | quote }}
    
    # フラグ
    is_wsl = {{ $isWsl }}
    is_mac = {{ $isMac }}
    is_ubuntu = {{ $isUbuntu }}
    is_container = {{ $isContainer }}
    is_server = {{ $isServer }}
    is_home = {{ $isHome }}
    has_gui = {{ $hasGui }}
    use_homebrew = {{ $useHomebrew }}
    
    # root 固有設定
    is_root_config = true
    target_user = {{ env "TARGET_USER" | default "" | quote }}

{{/* ==================== インタープリタ設定 ==================== */}}

[interpreters.sh]
    command = "bash"
    args = ["-eu"]

[interpreters.py]
    command = "python3"
```

### 5.2 .chezmoi.toml.tmpl (users/)

```toml
# users/.chezmoi.toml.tmpl
# chezmoi 設定ファイルテンプレート（一般ユーザー用）

{{/* ==================== 環境変数の取得 ==================== */}}

{{- $arch := "" -}}
{{- $area := "" -}}

{{/* ARCH の決定 */}}
{{- if env "ARCH" -}}
{{-   $arch = env "ARCH" -}}
{{- else if stat "/proc/sys/fs/binfmt_misc/WSLInterop" -}}
{{-   $arch = "wsl" -}}
{{- else if eq .chezmoi.os "darwin" -}}
{{-   $arch = "mac" -}}
{{- else -}}
{{-   $arch = promptStringOnce . "arch" "Architecture (wsl/ubuntu/ubuntu-dev/ubuntu_ct/ubuntu_nat/mac)" -}}
{{- end -}}

{{/* AREA の決定 */}}
{{- if env "AREA" -}}
{{-   $area = env "AREA" -}}
{{- else -}}
{{-   $area = promptStringOnce . "area" "Area (home/gcp/oci/conoha)" -}}
{{- end -}}

{{/* ==================== 派生フラグの計算 ==================== */}}

{{- $isWsl := eq $arch "wsl" -}}
{{- $isMac := eq $arch "mac" -}}
{{- $isUbuntu := or (eq $arch "ubuntu") (eq $arch "ubuntu-dev") (eq $arch "wsl") -}}
{{- $isContainer := eq $arch "ubuntu_ct" -}}
{{- $isServer := or (eq $area "gcp") (eq $area "oci") (eq $area "conoha") -}}
{{- $isHome := eq $area "home" -}}
{{- $hasGui := or $isMac (and $isWsl $isHome) (eq $arch "ubuntu-dev") -}}
{{- $useHomebrew := or $isMac (and $isUbuntu (not $isContainer)) -}}

{{/* ユーザー情報 */}}
{{- $email := promptStringOnce . "email" "Email address" -}}
{{- $name := promptStringOnce . "name" "Full name" -}}
{{- $githubUser := promptStringOnce . "github_user" "GitHub username" -}}

{{/* ==================== chezmoi 基本設定 ==================== */}}

sourceDir = {{ .chezmoi.sourceDir | quote }}

[edit]
    command = "nvim"

[diff]
    pager = "delta"
    exclude = ["scripts"]

[merge]
    command = "nvim"
    args = ["-d", "{{ "{{" }} .Destination {{ "}}" }}", "{{ "{{" }} .Source {{ "}}" }}", "{{ "{{" }} .Target {{ "}}" }}"]

{{/* ==================== データセクション ==================== */}}

[data]
    # 基本情報
    arch = {{ $arch | quote }}
    area = {{ $area | quote }}
    
    # フラグ
    is_wsl = {{ $isWsl }}
    is_mac = {{ $isMac }}
    is_ubuntu = {{ $isUbuntu }}
    is_container = {{ $isContainer }}
    is_server = {{ $isServer }}
    is_home = {{ $isHome }}
    has_gui = {{ $hasGui }}
    use_homebrew = {{ $useHomebrew }}
    
    # ユーザー情報
    email = {{ $email | quote }}
    name = {{ $name | quote }}
    github_user = {{ $githubUser | quote }}
    
    # users 固有設定
    is_root_config = false

{{/* ==================== Git 設定 ==================== */}}

[data.git]
    email = {{ $email | quote }}
    name = {{ $name | quote }}
    defaultBranch = "main"

{{/* ==================== インタープリタ設定 ==================== */}}

[interpreters.sh]
    command = "bash"
    args = ["-eu"]

[interpreters.py]
    command = "python3"
```

### 5.3 shared/data/packages.yaml

```yaml
# shared/data/packages.yaml
# パッケージ定義

apt:
  # すべての環境で必要な基本パッケージ
  essential:
    - git
    - curl
    - wget
    - ca-certificates
    - gnupg
    - lsb-release
  
  # 開発に必要な基本パッケージ
  common:
    - build-essential
    - pkg-config
    - libssl-dev
    - libffi-dev
    - zlib1g-dev
    - libbz2-dev
    - libreadline-dev
    - libsqlite3-dev
    - libncurses5-dev
    - libncursesw5-dev
    - xz-utils
    - tk-dev
    - libxml2-dev
    - libxmlsec1-dev
    - liblzma-dev
  
  # CLI ツール
  cli:
    - jq
    - tmux
    - htop
    - tree
    - unzip
    - zip
    - rsync
    - socat
  
  # シェル関連
  shell:
    - zsh
    - zsh-autosuggestions
    - zsh-syntax-highlighting
  
  # サーバー環境向け追加
  server:
    - fail2ban
    - ufw
    - logrotate
  
  # 開発環境向け追加
  dev:
    - shellcheck
    - python3-pip
    - python3-venv
  
  # GUI 環境向け追加
  gui:
    - fonts-noto-cjk
    - fonts-firacode
    - xclip
    - xsel

brew:
  # CLI ツール（共通）
  common:
    - ripgrep
    - fd
    - bat
    - eza
    - zoxide
    - fzf
    - gh
    - ghq
    - jq
    - yq
    - direnv
    - starship
    - tmux
    - neovim
    - lazygit
    - delta
  
  # 開発ツール
  dev:
    - mise
    - act
    - shellcheck
    - shfmt
  
  # ネットワークツール
  network:
    - httpie
    - grpcurl
    - websocat
  
  # macOS 専用
  mac_only:
    - mas
    - trash
    - terminal-notifier
  
  # Cask (macOS GUI アプリ)
  cask:
    common:
      - wezterm
      - raycast
      - 1password
      - visual-studio-code
      - docker
    
    home_only:
      - discord
      - slack
      - zoom
      - spotify
```

### 5.4 shared/data/tools.yaml

```yaml
# shared/data/tools.yaml
# 開発ツール定義

mise:
  # 言語ランタイム
  node:
    version: "22"
    default: true
  
  python:
    version: "3.12"
    default: true
  
  ruby:
    version: "3.3"
    default: false
    server_only: false
  
  go:
    version: "1.23"
    default: true
  
  rust:
    version: "stable"
    default: true
  
  deno:
    version: "latest"
    default: false
  
  bun:
    version: "latest"
    default: false
  
  java:
    version: "21"
    default: false
    server_only: false

  # ツール
  terraform:
    version: "latest"
    server_only: true
  
  kubectl:
    version: "latest"
    server_only: true
  
  helm:
    version: "latest"
    server_only: true

cloud:
  # AWS
  awscli:
    install: true
    areas:
      - home
      - gcp
      - oci
  
  # Google Cloud
  gcloud:
    install: true
    areas:
      - home
      - gcp
  
  # Oracle Cloud
  oci_cli:
    install: true
    areas:
      - home
      - oci

container:
  docker:
    install: true
    exclude_arch:
      - ubuntu_ct  # コンテナ内ではスキップ
  
  docker_compose:
    install: true
    exclude_arch:
      - ubuntu_ct
```

### 5.5 shared/data/arch.yaml

```yaml
# shared/data/arch.yaml
# ARCH 別設定

wsl:
  display: ":0"
  browser: "wslview"
  clipboard:
    copy: "clip.exe"
    paste: "powershell.exe -command Get-Clipboard"
  features:
    - docker
    - gui_support
    - vscode_remote
  shell: zsh
  font_dir: "/mnt/c/Windows/Fonts"

ubuntu:
  display: ""
  browser: ""
  clipboard:
    copy: "xclip -selection clipboard"
    paste: "xclip -selection clipboard -o"
  features:
    - docker
    - systemd
  shell: zsh

ubuntu-dev:
  display: ":0"
  browser: "xdg-open"
  clipboard:
    copy: "xclip -selection clipboard"
    paste: "xclip -selection clipboard -o"
  features:
    - docker
    - gui_support
    - systemd
  shell: zsh

ubuntu_ct:
  display: ""
  browser: ""
  clipboard:
    copy: ""
    paste: ""
  features: []
  shell: zsh
  # コンテナ固有の制限
  restrictions:
    - no_docker
    - no_systemd
    - no_kernel_modules

ubuntu_nat:
  display: ""
  browser: ""
  clipboard:
    copy: ""
    paste: ""
  features:
    - docker
    - systemd
  shell: zsh

mac:
  display: ""
  browser: "open"
  clipboard:
    copy: "pbcopy"
    paste: "pbpaste"
  features:
    - docker
    - gui_support
    - homebrew_native
  shell: zsh
  defaults:
    # macOS システム設定
    NSGlobalDomain:
      AppleShowAllExtensions: true
      InitialKeyRepeat: 15
      KeyRepeat: 2
    com.apple.dock:
      autohide: true
      tilesize: 48
    com.apple.finder:
      ShowPathbar: true
      ShowStatusBar: true
```

### 5.6 shared/data/area.yaml

```yaml
# shared/data/area.yaml
# AREA 別設定

home:
  network:
    subnet: "192.168.1.0/24"
    gateway: "192.168.1.1"
    dns:
      - "1.1.1.1"
      - "8.8.8.8"
  
  proxy:
    enabled: false
  
  git:
    signing: true
    gpg_key: ""  # 別途設定
  
  features:
    - personal_ssh_keys
    - full_dev_tools
    - gui_apps

gcp:
  network:
    # GCP のネットワークは自動
    dns:
      - "169.254.169.254"  # GCP metadata server
  
  proxy:
    enabled: false
  
  git:
    signing: false
  
  features:
    - server_only
    - gcloud_integration
  
  metadata:
    service_account: true
    project_id_from_metadata: true

oci:
  network:
    dns:
      - "169.254.169.254"
  
  proxy:
    enabled: false
  
  git:
    signing: false
  
  features:
    - server_only
    - oci_integration
  
  metadata:
    instance_principal: true

conoha:
  network:
    dns:
      - "1.1.1.1"
      - "8.8.8.8"
  
  proxy:
    enabled: false
  
  git:
    signing: false
  
  features:
    - server_only
    - minimal_install
```

---

## 6. スクリプト詳細

### 6.1 install（エントリーポイント）

```bash
#!/usr/bin/env bash
# install - dotfiles セットアップエントリーポイント

set -euo pipefail

# ==================== 定数 ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_VERSION="2.47.0"

# 有効な ARCH / AREA の一覧
VALID_ARCHS=("wsl" "ubuntu" "ubuntu-dev" "ubuntu_ct" "ubuntu_nat" "mac")
VALID_AREAS=("home" "gcp" "oci" "conoha")

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==================== ユーティリティ関数 ====================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

die() {
    log_error "$1"
    exit 1
}

# 配列に要素が含まれるか確認
contains() {
    local element="$1"
    shift
    local arr=("$@")
    for e in "${arr[@]}"; do
        [[ "$e" == "$element" ]] && return 0
    done
    return 1
}

# ==================== 環境検出 ====================

detect_arch() {
    if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
        echo "wsl"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "mac"
    elif [[ -f /run/systemd/container ]]; then
        echo "ubuntu_ct"
    else
        echo "ubuntu"
    fi
}

detect_area() {
    # メタデータサービスから検出を試みる
    
    # GCP
    if curl -sf -H "Metadata-Flavor: Google" \
       "http://metadata.google.internal/computeMetadata/v1/instance/zone" \
       --connect-timeout 1 &>/dev/null; then
        echo "gcp"
        return
    fi
    
    # OCI
    if curl -sf -H "Authorization: Bearer Oracle" \
       "http://169.254.169.254/opc/v2/instance/" \
       --connect-timeout 1 &>/dev/null; then
        echo "oci"
        return
    fi
    
    # デフォルト
    echo "home"
}

# ==================== chezmoi インストール ====================

ensure_chezmoi() {
    if command -v chezmoi &>/dev/null; then
        local current_version
        current_version=$(chezmoi --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        log_info "chezmoi ${current_version} is already installed"
        return 0
    fi
    
    log_info "Installing chezmoi..."
    
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS: Homebrew を使用
        if command -v brew &>/dev/null; then
            brew install chezmoi
        else
            # Homebrew がない場合は公式インストーラー
            sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
        fi
    else
        # Linux: 公式インストーラー
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
    fi
    
    log_success "chezmoi installed successfully"
}

# ==================== メイン処理 ====================

usage() {
    cat <<EOF
Usage: ARCH=<arch> AREA=<area> ./install [OPTIONS] [COMMAND]

Commands:
    root    - Install root configuration only (requires root)
    user    - Install user configuration only
    all     - Install both root and user (default)

Options:
    -h, --help              Show this help
    -n, --dry-run           Show what would be done
    -v, --verbose           Verbose output
    --target-user=USER      User to setup (when running as root)

Environment Variables:
    ARCH    - Architecture: ${VALID_ARCHS[*]}
    AREA    - Area: ${VALID_AREAS[*]}

Examples:
    # WSL home environment
    ARCH=wsl AREA=home ./install

    # GCP Ubuntu server
    ARCH=ubuntu AREA=gcp ./install

    # macOS
    ARCH=mac AREA=home ./install

    # Root only
    sudo ARCH=ubuntu AREA=oci ./install root

    # With target user
    sudo ARCH=ubuntu AREA=home TARGET_USER=takashi ./install all
EOF
}

main() {
    local dry_run=false
    local verbose=false
    local command="all"
    
    # 引数パース
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --target-user=*)
                export TARGET_USER="${1#*=}"
                shift
                ;;
            root|user|all)
                command="$1"
                shift
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
    
    # ARCH 検証/検出
    if [[ -z "${ARCH:-}" ]]; then
        ARCH=$(detect_arch)
        log_info "Auto-detected ARCH: ${ARCH}"
    fi
    
    if ! contains "$ARCH" "${VALID_ARCHS[@]}"; then
        die "Invalid ARCH: ${ARCH}. Valid values: ${VALID_ARCHS[*]}"
    fi
    export ARCH
    
    # AREA 検証/検出
    if [[ -z "${AREA:-}" ]]; then
        AREA=$(detect_area)
        log_info "Auto-detected AREA: ${AREA}"
    fi
    
    if ! contains "$AREA" "${VALID_AREAS[@]}"; then
        die "Invalid AREA: ${AREA}. Valid values: ${VALID_AREAS[*]}"
    fi
    export AREA
    
    log_info "Configuration: ARCH=${ARCH}, AREA=${AREA}"
    
    # chezmoi インストール確認
    ensure_chezmoi
    
    # chezmoi オプション構築
    local chezmoi_opts=()
    if [[ "$dry_run" == "true" ]]; then
        chezmoi_opts+=("--dry-run")
    fi
    if [[ "$verbose" == "true" ]]; then
        chezmoi_opts+=("--verbose")
    fi
    
    # コマンド実行
    case "$command" in
        root)
            if [[ $EUID -ne 0 ]]; then
                die "root command requires root privileges. Use sudo."
            fi
            log_info "Applying root configuration..."
            chezmoi init --source="${SCRIPT_DIR}/root" "${chezmoi_opts[@]}" --apply
            log_success "Root configuration applied"
            ;;
        
        user)
            if [[ $EUID -eq 0 ]]; then
                die "user command should not be run as root"
            fi
            log_info "Applying user configuration..."
            chezmoi init --source="${SCRIPT_DIR}/users" "${chezmoi_opts[@]}" --apply
            log_success "User configuration applied"
            ;;
        
        all)
            if [[ $EUID -eq 0 ]]; then
                # root として実行
                log_info "Applying root configuration..."
                chezmoi init --source="${SCRIPT_DIR}/root" "${chezmoi_opts[@]}" --apply
                log_success "Root configuration applied"
                
                # TARGET_USER が指定されていれば、そのユーザーの設定も適用
                if [[ -n "${TARGET_USER:-}" ]]; then
                    if id "$TARGET_USER" &>/dev/null; then
                        log_info "Applying user configuration for ${TARGET_USER}..."
                        su - "$TARGET_USER" -c "ARCH='$ARCH' AREA='$AREA' chezmoi init --source='${SCRIPT_DIR}/users' ${chezmoi_opts[*]} --apply"
                        log_success "User configuration applied for ${TARGET_USER}"
                    else
                        log_warn "User ${TARGET_USER} does not exist, skipping user configuration"
                    fi
                else
                    log_warn "TARGET_USER not set, skipping user configuration"
                    log_info "To setup a user, run: TARGET_USER=<username> ./install all"
                fi
            else
                # 一般ユーザーとして実行
                log_info "Applying user configuration..."
                chezmoi init --source="${SCRIPT_DIR}/users" "${chezmoi_opts[@]}" --apply
                log_success "User configuration applied"
                
                log_warn "Root configuration skipped (not running as root)"
                log_info "To apply root configuration, run: sudo ARCH=$ARCH AREA=$AREA ./install root"
            fi
            ;;
    esac
    
    log_success "Setup complete!"
}

main "$@"
```

### 6.2 run_once_before スクリプト例

```bash
#!/bin/bash
# root/.chezmoiscripts/run_once_before_30-install-packages-apt.sh.tmpl
# APT パッケージのインストール

set -eu

{{ if not .is_ubuntu -}}
# Ubuntu 系以外ではスキップ
exit 0
{{ end -}}

echo "=== Installing APT packages ==="

# パッケージリストの更新
apt-get update

# Essential packages
apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release

# Common development packages
{{ if not .is_container -}}
apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    libffi-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    liblzma-dev
{{ end -}}

# CLI tools
apt-get install -y \
    jq \
    tmux \
    htop \
    tree \
    unzip \
    zip \
    rsync

# Shell
apt-get install -y \
    zsh

{{ if .is_server -}}
# Server-specific packages
apt-get install -y \
    fail2ban \
    ufw \
    logrotate
{{ end -}}

{{ if .has_gui -}}
# GUI-related packages
apt-get install -y \
    fonts-noto-cjk \
    fonts-firacode \
    xclip \
    xsel
{{ end -}}

echo "=== APT packages installed ==="
```

### 6.3 run_onchange スクリプト例

```bash
#!/bin/bash
# users/.chezmoiscripts/run_onchange_after_mise-config.sh.tmpl
# mise 設定変更時にツールを再インストール

# hash: {{ include "dot_config/mise/config.toml.tmpl" | sha256sum }}

set -eu

echo "=== mise configuration changed, updating tools ==="

if ! command -v mise &>/dev/null; then
    echo "mise not found, skipping"
    exit 0
fi

# mise trust for current directory
mise trust {{ .chezmoi.homeDir }}/.config/mise/config.toml 2>/dev/null || true

# Install all tools defined in config
mise install

echo "=== mise tools updated ==="
```

---

## 7. テンプレート規約

### 7.1 ファイル命名規則

| Prefix/Suffix | 意味 | 例 |
|---------------|------|-----|
| `dot_` | `.` に変換される | `dot_zshrc` → `.zshrc` |
| `private_` | パーミッション 0600 | `private_dot_ssh/` |
| `exact_` | ディレクトリ内容を完全同期 | `exact_dot_local/` |
| `empty_` | 空ファイルを作成 | `empty_dot_gitkeep` |
| `executable_` | 実行権限を付与 | `executable_script` |
| `readonly_` | 読み取り専用 | `readonly_config` |
| `.tmpl` | テンプレートとして処理 | `dot_zshrc.tmpl` |
| `run_once_` | 一度だけ実行 | `run_once_install.sh` |
| `run_onchange_` | 変更時に実行 | `run_onchange_reload.sh` |
| `run_before_` | ファイル配置前に実行 | 組み合わせで使用 |
| `run_after_` | ファイル配置後に実行 | 組み合わせで使用 |

### 7.2 スクリプト命名規則

```
run_{once|onchange}_{before|after}_{number}-{description}.sh.tmpl
```

例:
- `run_once_before_00-validate-env.sh.tmpl`
- `run_once_before_10-install-packages.sh.tmpl`
- `run_once_after_90-setup-shell.sh.tmpl`
- `run_onchange_after_mise-config.sh.tmpl`

番号の意味:
- `00-09`: 環境検証・前提条件チェック
- `10-29`: パッケージインストール
- `30-49`: ツールセットアップ
- `50-69`: 設定適用
- `70-89`: 追加設定
- `90-99`: 最終処理・クリーンアップ

### 7.3 テンプレート構文

```go-template
{{/* コメント */}}

{{/* 変数定義 */}}
{{- $variable := "value" -}}

{{/* 条件分岐 */}}
{{ if .is_mac -}}
# macOS specific
{{ else if .is_ubuntu -}}
# Ubuntu specific
{{ end -}}

{{/* ループ */}}
{{ range .packages -}}
apt install -y {{ . }}
{{ end -}}

{{/* 空白制御: - で前後の空白を削除 */}}
{{- "no leading space" -}}

{{/* 関数 */}}
{{ .chezmoi.homeDir }}              // ホームディレクトリ
{{ .chezmoi.sourceDir }}            // ソースディレクトリ
{{ env "VAR" }}                     // 環境変数
{{ include "file" }}                // ファイル読み込み
{{ include "file" | sha256sum }}    // ハッシュ計算
{{ output "command" "arg" }}        // コマンド実行結果

{{/* データファイル読み込み */}}
{{- $packages := include "../shared/data/packages.yaml" | fromYaml -}}
```

### 7.4 .chezmoiignore 規約

```gitignore
# users/.chezmoiignore.tmpl

# OS 固有のファイルを除外
{{ if not .is_mac }}
# macOS 以外では除外
Brewfile.tmpl
.chezmoiscripts/*brew*
{{ end }}

{{ if not .is_ubuntu }}
# Ubuntu 以外では除外
.chezmoiscripts/*apt*
{{ end }}

{{ if .is_server }}
# サーバーでは GUI 関連を除外
dot_config/alacritty/
dot_config/wezterm/
{{ end }}

{{ if .is_container }}
# コンテナでは重い設定を除外
dot_config/nvim/
{{ end }}

# 常に除外
README.md
LICENSE
.git/
```

---

## 8. 移行計画

### 8.1 フェーズ1: 基盤構築（Week 1）

1. **リポジトリ構造の作成**
   - [ ] ディレクトリ構造を作成
   - [ ] install スクリプトを作成
   - [ ] .chezmoi.toml.tmpl を作成（root/users 両方）
   - [ ] shared/data/*.yaml を作成

2. **基本的なスクリプト移植**
   - [ ] パッケージインストールスクリプト
   - [ ] 環境検証スクリプト

### 8.2 フェーズ2: dotfiles 移植（Week 2）

1. **シェル設定**
   - [ ] .zshrc
   - [ ] .zshenv
   - [ ] .profile

2. **Git 設定**
   - [ ] .gitconfig
   - [ ] .gitignore_global

3. **エディタ設定**
   - [ ] neovim
   - [ ] vim (fallback)

### 8.3 フェーズ3: ツールセットアップ（Week 3）

1. **mise 設定**
   - [ ] config.toml
   - [ ] インストールスクリプト

2. **その他ツール**
   - [ ] starship
   - [ ] tmux
   - [ ] direnv

### 8.4 フェーズ4: 高度な機能（Week 4）

1. **SSH 設定**
   - [ ] config
   - [ ] config.d/

2. **外部リソース**
   - [ ] .chezmoiexternal.toml（フォントなど）

3. **CI/CD**
   - [ ] GitHub Actions 設定
   - [ ] テストマトリクス

### 8.5 フェーズ5: 検証・最適化（Week 5）

1. **各環境でのテスト**
   - [ ] WSL
   - [ ] Ubuntu Server (GCP)
   - [ ] Ubuntu Server (OCI)
   - [ ] macOS

2. **ドキュメント整備**
   - [ ] README.md
   - [ ] CONTRIBUTING.md

---

## 9. CI/CD

### 9.1 GitHub Actions ワークフロー

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install chezmoi
        run: |
          sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
      
      - name: Validate templates
        run: |
          chezmoi execute-template --init < root/.chezmoi.toml.tmpl > /dev/null
          chezmoi execute-template --init < users/.chezmoi.toml.tmpl > /dev/null
      
      - name: Shellcheck
        run: |
          find . -name "*.sh" -o -name "*.sh.tmpl" | xargs shellcheck -e SC1091

  test-ubuntu:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [ubuntu, ubuntu-dev]
        area: [home, gcp]
    steps:
      - uses: actions/checkout@v4
      
      - name: Install chezmoi
        run: |
          sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
      
      - name: Test install (dry-run)
        run: |
          ARCH=${{ matrix.arch }} AREA=${{ matrix.area }} ./install --dry-run user
      
      - name: Test install (actual)
        run: |
          ARCH=${{ matrix.arch }} AREA=${{ matrix.area }} ./install user

  test-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install chezmoi
        run: brew install chezmoi
      
      - name: Test install (dry-run)
        run: |
          ARCH=mac AREA=home ./install --dry-run user
      
      - name: Test install (actual)
        run: |
          ARCH=mac AREA=home ./install user
```

---

## 10. セキュリティ考慮事項

### 10.1 機密情報の管理

1. **SSH 秘密鍵**: chezmoi の外部で管理（1Password, Bitwarden など）
2. **API キー**: 環境変数または chezmoi のテンプレートでマスク
3. **パスワード**: `.chezmoiignore` で除外

### 10.2 権限管理

1. **private_ prefix**: 自動的に 0600 権限
2. **private_dot_ssh/**: ディレクトリ全体を 0700
3. **スクリプト実行**: 必要最小限の権限で実行

### 10.3 検証

1. **dry-run**: 実行前に必ず確認
2. **diff**: 変更内容の確認
3. **CI**: 自動テストで問題を早期発見

---

## 11. FAQ

### Q: 複数マシン間で設定を同期するには？

A: Git リポジトリを共有することで同期できます。`chezmoi update` で最新の設定を取得できます。

### Q: 環境ごとに異なる設定を持つには？

A: `.chezmoi.toml.tmpl` の `[data]` セクションで環境フラグを定義し、各テンプレートで分岐させます。

### Q: プライベートな設定とパブリックな設定を分けるには？

A: 方法は複数あります:
1. プライベートリポジトリを使用
2. `.chezmoiexternal.toml` で別リポジトリを参照
3. 機密情報はテンプレート変数として外部から注入
