# 変更履歴

## 2026-01-04

### Root 設定

| 項目 | 状態 | 備考 |
|------|------|------|
| 基本パッケージ | ✅ | curl, git, zsh, vim, ffmpeg, redis-tools 等 |
| Locale/Timezone | ✅ | ja_JP.UTF-8, Asia/Tokyo |
| mise | ✅ | バイナリをコピー（symlink ではない） |
| CLI ツール | ✅ | starship, fzf, ghq, lazygit, delta, yq, ollama |
| Rust ツール (cargo) | ✅ | fd, bat, eza, zoxide（/usr/local/bin にコピー） |
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
| mise | ✅ | 多数のツール (下記参照) |
| alacritty | ✅ | macOS only |
| karabiner | ✅ | macOS only |
| fontconfig | ✅ | WSL only |
| Claude hooks | ✅ | stop.sh, notification.sh (実行権限付き) |
| direnv | ❌ 削除 | 不要 |
| user SSH config | ❌ 削除 | システム設定で十分 |

### mise でインストールされるツール

#### 言語
| ツール | バージョン |
|--------|-----------|
| node | 22 |
| python | 3.12 |
| go | 1.23 |
| ruby | 3.3 |
| deno | latest |
| bun | latest |
| java | 21 |
| dart | latest |
| zig | latest |

#### Python ツール
| ツール | バージョン |
|--------|-----------|
| poetry | latest |
| uv | latest |

#### CLI ツール
| ツール | バージョン | 備考 |
|--------|-----------|------|
| zellij | latest | ターミナルマルチプレクサ |
| act | latest | GitHub Actions ローカル実行 |
| rclone | latest | クラウドストレージ同期 |
| yt-dlp | latest | 動画ダウンロード |
| yj | latest | YAML/JSON 変換 |
| ripgrep | latest | 高速 grep (rg コマンド) |

#### インフラ/クラウド
| ツール | バージョン |
|--------|-----------|
| helm | latest |
| grpcurl | latest |
| hasura-cli | latest |

#### データベース
| ツール | バージョン |
|--------|-----------|
| mongosh | latest |
| postgres | latest |

#### モバイル/Flutter
| ツール | バージョン |
|--------|-----------|
| flutter | latest |

### APT でインストールされるツール

| ツール | 備考 |
|--------|------|
| vim | エディタ |
| ffmpeg | 動画処理 |
| redis-tools | redis-cli 等 |
| locales | ロケール設定 |

### root スクリプトでインストール

| ツール | 備考 |
|--------|------|
| ollama | LLM ローカル実行 |

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
4. **Locale**: ja_JP.UTF-8 に設定、Timezone は Asia/Tokyo
