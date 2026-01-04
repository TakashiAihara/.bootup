# Requirements: chezmoi-based Multi-Environment Setup System

## 1. 概要

### 1.1 目的

Ubuntu/Mac/WSL 向けの開発環境初期セットアップを自動化する。新規環境のセットアップを 1 コマンドで完了し、複数の OS/環境で一貫した開発環境を提供する。

### 1.2 設計原則

- **宣言的**: 「何がインストールされているべきか」を定義
- **冪等性**: 何度実行しても同じ結果
- **最小権限**: 必要な権限のみで実行
- **環境分離**: root 設定と user 設定を明確に分離

---

## 2. サポート対象環境

### 2.1 ARCH（アーキテクチャ/OS）

| ARCH | 説明 | 主な用途 |
|------|------|----------|
| `wsl` | Windows Subsystem for Linux (Ubuntu) | Windows 上での開発環境 |
| `ubuntu` | Ubuntu Server/Desktop | 汎用サーバー |
| `ubuntu-dev` | Ubuntu 開発環境（GUI あり） | 開発用デスクトップ |
| `ubuntu_ct` | Ubuntu Container (LXC/Docker) | コンテナ環境 |
| `ubuntu_nat` | Ubuntu NAT 環境 | NAT 配下のサーバー |
| `mac` | macOS | メイン開発マシン |

### 2.2 AREA（環境/ロケーション）

| AREA | 説明 | ネットワーク特性 |
|------|------|------------------|
| `home` | ホーム環境 | フルアクセス、GUI あり |
| `gcp` | Google Cloud Platform | GCP メタデータ利用可能 |
| `oci` | Oracle Cloud Infrastructure | OCI メタデータ利用可能 |
| `conoha` | ConoHa VPS | 汎用 VPS |

### 2.3 環境マトリクス

実際に想定される組み合わせ：

| ARCH \ AREA | home | gcp | oci | conoha |
|-------------|:----:|:---:|:---:|:------:|
| `wsl` | ✅ | - | - | - |
| `ubuntu` | ✅ | ✅ | ✅ | ✅ |
| `ubuntu-dev` | ✅ | - | - | - |
| `ubuntu_ct` | ✅ | ✅ | ✅ | - |
| `ubuntu_nat` | ✅ | - | - | - |
| `mac` | ✅ | - | - | - |

---

## 3. 環境別要件定義

### 3.1 共通要件（全環境）

すべての環境で必要な基本設定：

#### 3.1.1 基本パッケージ

```yaml
packages:
  essential:
    - git
    - curl
    - wget
    - ca-certificates
    - gnupg
```

#### 3.1.2 基本 dotfiles

```yaml
dotfiles:
  - .zshrc          # シェル設定
  - .zshenv         # 環境変数
  - .gitconfig      # Git 設定
  - .vimrc          # Vim 基本設定（fallback）
```

#### 3.1.3 シェル設定

```yaml
shell:
  default: zsh
  prompt: starship
  plugins:
    - zsh-autosuggestions
    - zsh-syntax-highlighting
```

---

### 3.2 ARCH 別要件

#### 3.2.1 WSL (`wsl`)

```yaml
wsl:
  description: "Windows 上の Ubuntu 開発環境"
  
  characteristics:
    - Windows ファイルシステムへのアクセス可能
    - Windows アプリとの連携（ブラウザ、VSCode）
    - systemd 利用可能（WSL2）
    - Docker Desktop 連携可能
  
  packages:
    apt:
      - build-essential
      - pkg-config
      - libssl-dev
      - wslu              # WSL ユーティリティ
    brew:
      - ripgrep
      - fd
      - bat
      - eza
      - fzf
      - ghq
      - gh
      - jq
      - yq
      - neovim
      - tmux
      - starship
      - mise
      - direnv
      - lazygit
      - delta
  
  dotfiles:
    standard:
      - .zshrc
      - .zshenv
      - .gitconfig
      - .gitignore_global
      - .tmux.conf
      - .config/nvim/
      - .config/starship.toml
      - .config/mise/config.toml
      - .config/gh/config.yml
      - .ssh/config
    wsl_specific:
      - .config/wsl.conf      # WSL 設定参照用
  
  tools:
    mise:
      - node@22
      - python@3.12
      - go@1.23
      - rust@stable
      - deno@latest
      - bun@latest
    optional:
      - docker              # Docker Desktop 連携
      - kubectl             # Kubernetes CLI
  
  environment:
    DISPLAY: ":0"
    BROWSER: "wslview"
    
  clipboard:
    copy: "clip.exe"
    paste: "powershell.exe -command Get-Clipboard"
  
  features:
    - gui_support           # WSLg または X11 転送
    - vscode_remote         # VSCode Remote WSL
    - docker_desktop        # Docker Desktop 連携
    - windows_integration   # Windows アプリ連携
```

#### 3.2.2 Ubuntu Server (`ubuntu`)

```yaml
ubuntu:
  description: "汎用 Ubuntu サーバー"
  
  characteristics:
    - GUI なし（CUI のみ）
    - systemd 利用可能
    - フル root アクセス
    - Docker 直接インストール
  
  packages:
    apt:
      - build-essential
      - pkg-config
      - libssl-dev
      - libffi-dev
      - zlib1g-dev
      - htop
      - tree
      - unzip
      - rsync
      - fail2ban           # セキュリティ
      - ufw                # ファイアウォール
    brew:
      - ripgrep
      - fd
      - bat
      - eza
      - fzf
      - ghq
      - gh
      - jq
      - yq
      - neovim
      - tmux
      - starship
      - mise
      - direnv
      - lazygit
      - delta
  
  dotfiles:
    - .zshrc
    - .zshenv
    - .gitconfig
    - .gitignore_global
    - .tmux.conf
    - .config/nvim/
    - .config/starship.toml
    - .config/mise/config.toml
    - .ssh/config
  
  tools:
    mise:
      - node@22
      - python@3.12
      - go@1.23
    infrastructure:
      - docker
      - docker-compose
    optional:              # AREA によって変わる
      - kubectl
      - helm
      - terraform
  
  services:
    enable:
      - docker
      - fail2ban
      - ufw
  
  security:
    ufw:
      default_incoming: deny
      default_outgoing: allow
      allow:
        - ssh
    fail2ban:
      enabled: true
      jails:
        - sshd
```

#### 3.2.3 Ubuntu Dev (`ubuntu-dev`)

```yaml
ubuntu-dev:
  description: "Ubuntu 開発環境（GUI あり）"
  
  characteristics:
    - GUI 環境（GNOME/KDE）
    - ローカル開発マシン
    - フルスペック開発ツール
  
  packages:
    apt:
      inherit: ubuntu      # ubuntu の設定を継承
      additional:
        - fonts-noto-cjk
        - fonts-firacode
        - xclip
        - xsel
    brew:
      inherit: ubuntu
      additional:
        - act               # GitHub Actions ローカル実行
  
  dotfiles:
    inherit: ubuntu
    additional:
      - .config/alacritty/
      - .config/wezterm/
  
  tools:
    inherit: ubuntu
    additional:
      mise:
        - ruby@3.3
        - java@21
      gui:
        - vscode            # Visual Studio Code
        - dbeaver           # DB クライアント
  
  features:
    - gui_support
    - docker
    - systemd
```

#### 3.2.4 Ubuntu Container (`ubuntu_ct`)

```yaml
ubuntu_ct:
  description: "コンテナ内 Ubuntu（LXC/Docker）"
  
  characteristics:
    - 制限された環境
    - systemd なし（多くの場合）
    - Docker-in-Docker 不可（通常）
    - カーネルモジュール操作不可
  
  restrictions:
    - no_docker            # Docker 使用不可
    - no_systemd           # systemd 使用不可
    - no_kernel_modules    # カーネルモジュール不可
    - limited_permissions  # 権限制限
  
  packages:
    apt:
      minimal:
        - git
        - curl
        - wget
        - ca-certificates
        - gnupg
        - jq
        - tmux
        - zsh
      # build-essential は含めない（コンテナサイズ削減）
    brew:
      # Homebrew は使用しない（コンテナでは重い）
      skip: true
  
  dotfiles:
    minimal:
      - .zshrc
      - .zshenv
      - .gitconfig
      - .tmux.conf
      - .vimrc              # neovim の代わりに vim
      - .config/starship.toml
  
  tools:
    # mise も軽量に
    mise:
      - node@22            # 必要な言語のみ
    skip:
      - docker
      - kubectl
      - heavy_tools
  
  features: []              # 特別な機能なし
```

#### 3.2.5 Ubuntu NAT (`ubuntu_nat`)

```yaml
ubuntu_nat:
  description: "NAT 配下の Ubuntu"
  
  characteristics:
    - 直接インバウンド接続不可
    - ポートフォワーディング必要
    - Tailscale/Cloudflare Tunnel 等で接続
  
  packages:
    inherit: ubuntu
    additional:
      apt:
        - tailscale         # または別の VPN ソリューション
  
  dotfiles:
    inherit: ubuntu
  
  tools:
    inherit: ubuntu
  
  network:
    considerations:
      - "直接 SSH 不可の場合あり"
      - "リバースプロキシ経由でのアクセス"
  
  features:
    - docker
    - systemd
```

#### 3.2.6 macOS (`mac`)

```yaml
mac:
  description: "macOS 開発環境"
  
  characteristics:
    - GUI ネイティブ
    - Homebrew がメイン
    - Apple Silicon / Intel 両対応
    - Xcode Command Line Tools 必要
  
  prerequisites:
    - xcode-select --install
  
  packages:
    brew:
      formulae:
        - git
        - curl
        - wget
        - ripgrep
        - fd
        - bat
        - eza
        - fzf
        - ghq
        - gh
        - jq
        - yq
        - neovim
        - tmux
        - starship
        - mise
        - direnv
        - lazygit
        - delta
        - mas               # Mac App Store CLI
        - trash             # ゴミ箱へ移動
        - terminal-notifier # 通知
      casks:
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
          - arc               # ブラウザ
  
  dotfiles:
    - .zshrc
    - .zshenv
    - .gitconfig
    - .gitignore_global
    - .tmux.conf
    - .config/nvim/
    - .config/starship.toml
    - .config/mise/config.toml
    - .config/wezterm/
    - .config/gh/config.yml
    - .ssh/config
  
  tools:
    mise:
      - node@22
      - python@3.12
      - go@1.23
      - rust@stable
      - ruby@3.3
      - deno@latest
      - bun@latest
      - java@21
  
  macos_defaults:
    NSGlobalDomain:
      AppleShowAllExtensions: true
      InitialKeyRepeat: 15
      KeyRepeat: 2
      ApplePressAndHoldEnabled: false
    com.apple.dock:
      autohide: true
      tilesize: 48
      show-recents: false
    com.apple.finder:
      ShowPathbar: true
      ShowStatusBar: true
      AppleShowAllFiles: true
      FXPreferredViewStyle: "Nlsv"   # リスト表示
    com.apple.Safari:
      ShowFullURLInSmartSearchField: true
      IncludeDevelopMenu: true
  
  features:
    - gui_support
    - docker
    - homebrew_native
```

---

### 3.3 AREA 別要件

#### 3.3.1 Home (`home`)

```yaml
home:
  description: "ホーム環境（ローカル開発）"
  
  characteristics:
    - フルスペック開発環境
    - プライベートネットワーク
    - GUI 利用可能（mac, ubuntu-dev, wsl）
    - 個人用 SSH キー使用
  
  git:
    signing: true
    gpg_key: "personal"
  
  ssh:
    keys:
      - personal            # 個人用キー
      - github              # GitHub 用
    config:
      includes:
        - config.d/00-general
        - config.d/10-github
        - config.d/20-home-servers
  
  cloud_tools:
    install:
      - awscli
      - gcloud
      - oci-cli
  
  additional_tools:
    - act                   # GitHub Actions ローカル実行
    - k9s                   # Kubernetes TUI
  
  gui_apps:                 # has_gui の場合のみ
    - vscode
    - dbeaver
    - postman
```

#### 3.3.2 GCP (`gcp`)

```yaml
gcp:
  description: "Google Cloud Platform 環境"
  
  characteristics:
    - GCP メタデータサービス利用可能
    - サービスアカウント認証
    - gcloud CLI プリインストール推奨
  
  metadata:
    service_account: true
    project_id_from_metadata: true
    zone_from_metadata: true
  
  git:
    signing: false          # サーバーでは署名しない
  
  ssh:
    keys:
      - deploy              # デプロイ用キーのみ
    config:
      includes:
        - config.d/00-general
        - config.d/10-github
  
  cloud_tools:
    install:
      - gcloud              # Google Cloud SDK
    skip:
      - awscli
      - oci-cli
  
  infrastructure_tools:
    - kubectl
    - helm
    - terraform
  
  gcp_specific:
    default_region: "asia-northeast1"
    default_zone: "asia-northeast1-a"
```

#### 3.3.3 OCI (`oci`)

```yaml
oci:
  description: "Oracle Cloud Infrastructure 環境"
  
  characteristics:
    - OCI メタデータサービス利用可能
    - Instance Principal 認証可能
    - Always Free tier 考慮
  
  metadata:
    instance_principal: true
    compartment_from_metadata: true
  
  git:
    signing: false
  
  ssh:
    keys:
      - deploy
    config:
      includes:
        - config.d/00-general
        - config.d/10-github
  
  cloud_tools:
    install:
      - oci-cli             # OCI CLI
    skip:
      - awscli
      - gcloud
  
  infrastructure_tools:
    - kubectl
    - helm
  
  oci_specific:
    default_region: "ap-tokyo-1"
```

#### 3.3.4 ConoHa (`conoha`)

```yaml
conoha:
  description: "ConoHa VPS 環境"
  
  characteristics:
    - 汎用 VPS
    - メタデータサービスなし
    - 最小限のセットアップ
  
  git:
    signing: false
  
  ssh:
    keys:
      - deploy
    config:
      includes:
        - config.d/00-general
        - config.d/10-github
  
  cloud_tools:
    skip:                   # クラウド CLI は不要
      - awscli
      - gcloud
      - oci-cli
  
  infrastructure_tools:
    minimal:
      - docker
      - docker-compose
    skip:
      - kubectl             # 必要なら後で追加
      - helm
      - terraform
  
  considerations:
    - "リソースが限られている場合がある"
    - "最小限のツールのみインストール"
```

---

## 4. 機能別要件

### 4.1 dotfiles 管理

#### 4.1.1 管理対象ファイル

```yaml
dotfiles:
  shell:
    files:
      - source: dot_zshrc.tmpl
        target: ~/.zshrc
        template: true
        description: "Zsh メイン設定"
      
      - source: dot_zshenv.tmpl
        target: ~/.zshenv
        template: true
        description: "Zsh 環境変数"
      
      - source: dot_profile.tmpl
        target: ~/.profile
        template: true
        description: "ログインシェル設定"
      
      - source: dot_bashrc.tmpl
        target: ~/.bashrc
        template: true
        description: "Bash 設定（fallback）"
  
  git:
    files:
      - source: dot_gitconfig.tmpl
        target: ~/.gitconfig
        template: true
        variables:
          - name
          - email
          - signing_key
      
      - source: dot_gitignore_global
        target: ~/.gitignore_global
        template: false
  
  editor:
    neovim:
      - source: dot_config/nvim/
        target: ~/.config/nvim/
        exact: true           # ディレクトリ内容を完全同期
        description: "Neovim 設定"
    
    vim:
      - source: dot_vimrc
        target: ~/.vimrc
        description: "Vim 基本設定（fallback）"
  
  terminal:
    tmux:
      - source: dot_tmux.conf.tmpl
        target: ~/.tmux.conf
        template: true
    
    alacritty:
      - source: dot_config/alacritty/
        target: ~/.config/alacritty/
        condition: has_gui
    
    wezterm:
      - source: dot_config/wezterm/
        target: ~/.config/wezterm/
        condition: has_gui
  
  tools:
    starship:
      - source: dot_config/starship.toml.tmpl
        target: ~/.config/starship.toml
        template: true
    
    mise:
      - source: dot_config/mise/config.toml.tmpl
        target: ~/.config/mise/config.toml
        template: true
    
    direnv:
      - source: dot_config/direnv/direnvrc
        target: ~/.config/direnv/direnvrc
    
    gh:
      - source: dot_config/gh/config.yml.tmpl
        target: ~/.config/gh/config.yml
        template: true
  
  ssh:
    - source: private_dot_ssh/config.tmpl
      target: ~/.ssh/config
      template: true
      permission: "0600"
    
    - source: private_dot_ssh/config.d/
      target: ~/.ssh/config.d/
      permission: "0700"
```

#### 4.1.2 テンプレート変数

```yaml
template_variables:
  # 環境検出
  arch: "wsl | ubuntu | ubuntu-dev | ubuntu_ct | ubuntu_nat | mac"
  area: "home | gcp | oci | conoha"
  
  # 派生フラグ
  is_wsl: "arch == 'wsl'"
  is_mac: "arch == 'mac'"
  is_ubuntu: "arch in ['ubuntu', 'ubuntu-dev', 'wsl']"
  is_container: "arch == 'ubuntu_ct'"
  is_server: "area in ['gcp', 'oci', 'conoha']"
  is_home: "area == 'home'"
  has_gui: "is_mac || (is_wsl && is_home) || arch == 'ubuntu-dev'"
  use_homebrew: "is_mac || (is_ubuntu && !is_container)"
  
  # ユーザー情報
  name: "プロンプトで入力"
  email: "プロンプトで入力"
  github_user: "プロンプトで入力"
  
  # Git 設定
  git_signing: "is_home"
  git_gpg_key: "プロンプトで入力（home のみ）"
  
  # パス
  homebrew_prefix: "/opt/homebrew (arm64) | /usr/local (x86_64) | /home/linuxbrew/.linuxbrew (linux)"
```

### 4.2 パッケージ管理

#### 4.2.1 パッケージマネージャー選択

```yaml
package_managers:
  apt:
    use_when:
      - is_ubuntu
      - is_wsl
    purpose: "システムパッケージ"
  
  homebrew:
    use_when:
      - is_mac
      - use_homebrew  # Ubuntu でも使用可能
    purpose: "CLI ツール、開発ツール"
    skip_when:
      - is_container  # コンテナでは重いのでスキップ
  
  mise:
    use_when: "always"
    purpose: "言語ランタイム、バージョン管理ツール"
```

#### 4.2.2 パッケージ分類

```yaml
packages:
  # 必須（全環境）
  tier1_essential:
    description: "どの環境でも絶対に必要"
    apt:
      - git
      - curl
      - wget
      - ca-certificates
      - zsh
    brew: []  # apt で入れるので不要
  
  # 開発基盤（ほとんどの環境）
  tier2_development:
    description: "開発に必要な基盤ツール"
    condition: "!is_container"
    apt:
      - build-essential
      - pkg-config
      - libssl-dev
      - libffi-dev
    brew:
      - neovim
      - tmux
      - starship
      - fzf
      - ripgrep
      - fd
      - bat
      - eza
      - jq
      - yq
      - gh
      - ghq
      - delta
      - lazygit
      - direnv
      - mise
  
  # 言語ランタイム
  tier3_languages:
    description: "プログラミング言語"
    mise:
      common:
        - node@22
        - python@3.12
        - go@1.23
      home_additional:
        - rust@stable
        - ruby@3.3
        - deno@latest
        - bun@latest
        - java@21
  
  # インフラツール
  tier4_infrastructure:
    description: "インフラ・クラウドツール"
    condition: "!is_container"
    docker:
      install_when: "!is_container"
    kubernetes:
      - kubectl
      - helm
      condition: "is_server || is_home"
    cloud:
      awscli:
        condition: "area in ['home', 'gcp', 'oci']"
      gcloud:
        condition: "area in ['home', 'gcp']"
      oci-cli:
        condition: "area in ['home', 'oci']"
  
  # GUI アプリ
  tier5_gui:
    description: "GUI アプリケーション"
    condition: "has_gui"
    brew_cask:
      - wezterm
      - visual-studio-code
      - docker
    mac_only:
      - raycast
      - 1password
```

### 4.3 サービス設定

#### 4.3.1 systemd サービス

```yaml
services:
  docker:
    enable_when: "!is_container && has_docker"
    start: true
  
  fail2ban:
    enable_when: "is_server"
    start: true
    config:
      jails:
        - sshd
  
  ufw:
    enable_when: "is_server"
    start: true
    rules:
      - allow: ssh
      - default_incoming: deny
      - default_outgoing: allow
```

### 4.4 セキュリティ設定

#### 4.4.1 SSH 設定

```yaml
ssh:
  config:
    global:
      AddKeysToAgent: "yes"
      IdentitiesOnly: "yes"
    
    github:
      Host: "github.com"
      HostName: "github.com"
      User: "git"
      IdentityFile: "~/.ssh/github"
    
    home_servers:
      condition: "is_home"
      hosts:
        - name: "proxmox"
          hostname: "192.168.1.x"
        - name: "nas"
          hostname: "192.168.1.x"
  
  keys:
    management: "external"  # 1Password, Bitwarden など
    note: "秘密鍵は chezmoi では管理しない"
```

#### 4.4.2 Git 署名

```yaml
git_signing:
  enable_when: "is_home"
  method: "gpg"  # or "ssh"
  key: "from_prompt"
```

---

## 5. 環境マトリクス詳細

### 5.1 WSL + Home

```yaml
wsl_home:
  name: "WSL Home Environment"
  description: "Windows 上のメイン開発環境"
  
  packages:
    apt:
      - tier1_essential
      - tier2_development (apt部分)
    brew:
      - tier2_development (brew部分)
    mise:
      - tier3_languages.common
      - tier3_languages.home_additional
  
  dotfiles:
    - all_shell
    - all_git
    - all_editor
    - all_terminal
    - all_tools
    - all_ssh
  
  tools:
    - docker (via Docker Desktop)
    - tier4_infrastructure.cloud (all)
  
  features:
    - gui_support
    - windows_integration
    - full_development
```

### 5.2 Mac + Home

```yaml
mac_home:
  name: "macOS Home Environment"
  description: "macOS メイン開発環境"
  
  packages:
    brew:
      - tier1_essential (brew版)
      - tier2_development
      - tier5_gui.brew_cask
      - tier5_gui.mac_only
    mise:
      - tier3_languages.common
      - tier3_languages.home_additional
  
  dotfiles:
    - all_shell
    - all_git
    - all_editor
    - all_terminal (wezterm)
    - all_tools
    - all_ssh
  
  tools:
    - docker (Docker Desktop)
    - tier4_infrastructure.cloud (all)
  
  macos:
    - defaults_settings
  
  features:
    - gui_support
    - homebrew_native
    - full_development
```

### 5.3 Ubuntu + GCP

```yaml
ubuntu_gcp:
  name: "Ubuntu on GCP"
  description: "GCP 上の Ubuntu サーバー"
  
  packages:
    apt:
      - tier1_essential
      - tier2_development (apt部分)
      - server_security (fail2ban, ufw)
    brew:
      - tier2_development (brew部分)
    mise:
      - tier3_languages.common
  
  dotfiles:
    - all_shell
    - all_git (signing: false)
    - all_editor
    - terminal_tmux_only
    - all_tools
    - ssh_minimal
  
  tools:
    - docker
    - tier4_infrastructure.kubernetes
    - tier4_infrastructure.cloud.gcloud
  
  services:
    - docker
    - fail2ban
    - ufw
  
  features:
    - server_only
    - gcp_integration
```

### 5.4 Ubuntu + OCI

```yaml
ubuntu_oci:
  name: "Ubuntu on OCI"
  description: "OCI 上の Ubuntu サーバー"
  
  packages:
    apt:
      - tier1_essential
      - tier2_development (apt部分)
      - server_security
    brew:
      - tier2_development (brew部分)
    mise:
      - tier3_languages.common
  
  dotfiles:
    - all_shell
    - all_git (signing: false)
    - all_editor
    - terminal_tmux_only
    - all_tools
    - ssh_minimal
  
  tools:
    - docker
    - tier4_infrastructure.kubernetes
    - tier4_infrastructure.cloud.oci-cli
  
  services:
    - docker
    - fail2ban
    - ufw
  
  features:
    - server_only
    - oci_integration
```

### 5.5 Ubuntu Container

```yaml
ubuntu_ct:
  name: "Ubuntu Container"
  description: "コンテナ内の最小限環境"
  
  packages:
    apt:
      - tier1_essential
      - minimal_tools (jq, tmux)
    brew:
      skip: true
    mise:
      - node@22  # 必要最小限
  
  dotfiles:
    - shell_minimal
    - git_minimal
    - vim_only (neovim の代わり)
    - starship
  
  tools:
    skip:
      - docker
      - kubernetes
      - cloud_tools
  
  features: []
  
  restrictions:
    - no_systemd
    - no_docker
    - no_heavy_tools
```

### 5.6 ConoHa

```yaml
ubuntu_conoha:
  name: "Ubuntu on ConoHa"
  description: "ConoHa VPS 上の最小限サーバー"
  
  packages:
    apt:
      - tier1_essential
      - tier2_development (apt部分)
      - server_security
    brew:
      - tier2_development (minimal)
    mise:
      - tier3_languages.common
  
  dotfiles:
    - all_shell
    - all_git (signing: false)
    - all_editor
    - terminal_tmux_only
    - tools_minimal
    - ssh_minimal
  
  tools:
    - docker
    - docker-compose
    skip:
      - kubernetes
      - cloud_tools
  
  services:
    - docker
    - fail2ban
    - ufw
  
  features:
    - server_only
    - minimal_install
```

---

## 6. 実行要件

### 6.1 前提条件

```yaml
prerequisites:
  all:
    - "インターネット接続"
    - "sudo 権限（root 設定用）"
  
  ubuntu:
    - "apt update 済み"
    - "python3 インストール済み"
  
  mac:
    - "Xcode Command Line Tools インストール済み"
    - "xcode-select --install"
  
  wsl:
    - "WSL2 セットアップ済み"
    - "Windows Terminal 推奨"
```

### 6.2 実行コマンド

```bash
# 基本的な使い方
ARCH=<arch> AREA=<area> ./install

# 例: WSL + home
ARCH=wsl AREA=home ./install

# 例: GCP Ubuntu (root で実行し、ユーザーも設定)
sudo ARCH=ubuntu AREA=gcp TARGET_USER=<username> ./install

# 例: macOS
ARCH=mac AREA=home ./install

# dry-run で確認
ARCH=ubuntu AREA=oci ./install --dry-run
```

### 6.3 実行順序

```yaml
execution_order:
  root:
    - "00: 環境検証"
    - "10: 基本パッケージ (apt)"
    - "20: Homebrew インストール"
    - "30: APT パッケージ"
    - "31: Homebrew パッケージ"
    - "40: mise インストール"
    - "50: Docker インストール"
    - "60: クラウドツール"
    - "80: サービス設定"
    - "90: ユーザー設定呼び出し"
  
  user:
    - "00: 環境検証"
    - "10: ユーザーパッケージ"
    - "-- dotfiles 配置 --"
    - "50: mise ツールインストール"
    - "60: シェル設定"
    - "70: Neovim プラグイン"
```

---

## 7. テスト要件

### 7.1 CI テストマトリクス

```yaml
ci_tests:
  ubuntu:
    archs: [ubuntu, ubuntu-dev]
    areas: [home, gcp]
    runner: ubuntu-latest
  
  macos:
    archs: [mac]
    areas: [home]
    runner: macos-latest
  
  container:
    archs: [ubuntu_ct]
    areas: [home]
    runner: ubuntu-latest
    container: ubuntu:24.04
```

### 7.2 検証項目

```yaml
validation:
  templates:
    - "すべての .tmpl ファイルが正しく展開される"
    - "無効な変数参照がない"
  
  scripts:
    - "shellcheck による構文チェック"
    - "実行権限の確認"
  
  packages:
    - "パッケージが正しくインストールされる"
    - "バージョン制約が満たされる"
  
  dotfiles:
    - "シンボリックリンクが正しく作成される"
    - "パーミッションが正しい"
  
  idempotency:
    - "2回実行しても結果が変わらない"
```

---

## 8. 今後の拡張

### 8.1 検討中の機能

```yaml
future:
  secrets_management:
    description: "1Password / Bitwarden 連携"
    priority: medium
  
  remote_apply:
    description: "SSH 経由でリモートマシンに適用"
    priority: low
  
  rollback:
    description: "設定のロールバック機能"
    priority: low
  
  windows_native:
    description: "Windows ネイティブ対応"
    priority: low
```

---

## Appendix A: ファイル一覧

### dotfiles

| ファイル | 説明 | テンプレート | 条件 |
|----------|------|:------------:|------|
| `.zshrc` | Zsh 設定 | ✅ | 全環境 |
| `.zshenv` | Zsh 環境変数 | ✅ | 全環境 |
| `.bashrc` | Bash 設定 | ✅ | 全環境 |
| `.profile` | ログインシェル | ✅ | 全環境 |
| `.gitconfig` | Git 設定 | ✅ | 全環境 |
| `.gitignore_global` | グローバル gitignore | ❌ | 全環境 |
| `.tmux.conf` | tmux 設定 | ✅ | 全環境 |
| `.vimrc` | Vim 設定 | ❌ | 全環境 |
| `.config/nvim/` | Neovim 設定 | 一部 | !container |
| `.config/starship.toml` | プロンプト | ✅ | 全環境 |
| `.config/mise/config.toml` | mise 設定 | ✅ | 全環境 |
| `.config/alacritty/` | Alacritty | ✅ | has_gui |
| `.config/wezterm/` | WezTerm | ✅ | has_gui |
| `.config/gh/config.yml` | GitHub CLI | ✅ | 全環境 |
| `.config/direnv/direnvrc` | direnv | ❌ | 全環境 |
| `.ssh/config` | SSH 設定 | ✅ | 全環境 |

### パッケージ

省略（上記セクション参照）

---

## Appendix B: 変更履歴

| 日付 | 変更内容 |
|------|----------|
| 2025-01-03 | 初版作成 |