# 変更履歴

## 2026-01-04

### Root 設定

| 項目 | 状態 | 備考 |
|------|------|------|
| 基本パッケージ | ✅ | curl, git, zsh 等 |
| mise | ✅ | バイナリをコピー（symlink ではない） |
| CLI ツール | ✅ | starship, fzf, ghq, lazygit, delta, yq |
| Rust ツール (cargo) | ✅ | rg, fd, bat, eza, zoxide（/usr/local/bin にコピー） |
| Docker | ✅ | docker + compose |
| SSH 設定 | ✅ | sshd/ssh drop-in 設定 |
| UFW | ✅ | 無効化（SG で管理） |
| OCI CLI | ❌ 削除 | 不要 |

### User 設定

| 項目 | 状態 | 備考 |
|------|------|------|
| zshrc | ✅ | zinit プラグイン含む |
| zshenv | ✅ | 環境変数のみ |
| gitconfig | ✅ | delta, ghq, submodule 設定 |
| gitignore_global | ✅ | グローバル ignore |
| tmux | ✅ | prefix C-a |
| starship | ✅ | プロンプト設定 |
| nvim | ✅ | lazy.nvim + plugins |
| gh | ✅ | GitHub CLI 設定 |
| mise | ✅ | node, python, go, zellij, act |
| alacritty | ✅ | macOS only |
| karabiner | ✅ | macOS only |
| fontconfig | ✅ | WSL only |
| Claude hooks | ✅ | stop.sh, notification.sh (実行権限付き) |
| direnv | ❌ 削除 | 不要 |
| user SSH config | ❌ 削除 | システム設定で十分 |

### mise でインストールされるツール

| ツール | バージョン | 備考 |
|--------|-----------|------|
| node | 22 | |
| python | 3.12 | |
| go | 1.23 | |
| zellij | latest | ターミナルマルチプレクサ |
| act | latest | GitHub Actions ローカル実行 |
| ruby | 3.3 | home 環境のみ |
| deno | latest | home 環境のみ |
| bun | latest | home 環境のみ |
| java | 21 | home 環境のみ |

### zinit プラグイン

| プラグイン | 用途 |
|-----------|------|
| zsh-autosuggestions | コマンド補完サジェスト |
| fast-syntax-highlighting | シンタックスハイライト |
| history-search-multi-word | 履歴検索 |
| zsh-completions | 追加補完 |
| forgit | git + fzf |
| git-open | git open でブラウザ起動 |

### 既知の問題・注意点

1. **symlink 問題**: root でインストールしたツールを一般ユーザーが使えるよう、symlink ではなくコピーに変更
2. **cargo install**: Rust ツールは cargo でインストール後、/usr/local/bin にコピー
3. **実行権限**: Claude hooks は `executable_` プレフィックスで実行権限付与
