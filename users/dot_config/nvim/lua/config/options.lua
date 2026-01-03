-- ~/.config/nvim/lua/config/options.lua
-- Neovim オプション設定

local opt = vim.opt

-- ==================== UI ====================

-- 行番号
opt.number = true
opt.relativenumber = true

-- サインカラム
opt.signcolumn = "yes"

-- カーソル行
opt.cursorline = true

-- カラー
opt.termguicolors = true
opt.background = "dark"

-- ステータスライン
opt.laststatus = 3  -- グローバルステータスライン

-- コマンドライン
opt.cmdheight = 1
opt.showmode = false  -- ステータスラインで表示するので不要

-- スクロール
opt.scrolloff = 8
opt.sidescrolloff = 8

-- 分割
opt.splitbelow = true
opt.splitright = true

-- ポップアップ
opt.pumheight = 10

-- ==================== 編集 ====================

-- インデント
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.autoindent = true

-- 折り返し
opt.wrap = false

-- 検索
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- 置換
opt.inccommand = "split"

-- 補完
opt.completeopt = "menu,menuone,noselect"

-- クリップボード
opt.clipboard = "unnamedplus"

-- マウス
opt.mouse = "a"

-- Undo
opt.undofile = true
opt.undolevels = 10000

-- スワップファイル
opt.swapfile = false
opt.backup = false

-- 更新時間
opt.updatetime = 250
opt.timeoutlen = 300

-- ==================== その他 ====================

-- 不可視文字
opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
}

-- 折りたたみ
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldenable = false

-- ファイルエンコーディング
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"

-- シェル
opt.shell = "zsh"

-- grep
opt.grepprg = "rg --vimgrep --smart-case"
opt.grepformat = "%f:%l:%c:%m"
