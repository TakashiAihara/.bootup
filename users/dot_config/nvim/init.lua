-- ~/.config/nvim/init.lua
-- Neovim メイン設定ファイル

-- ==================== リーダーキー ====================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ==================== 基本設定 ====================
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- ==================== プラグイン ====================
require("config.lazy")
