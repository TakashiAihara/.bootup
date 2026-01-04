#!/bin/bash
# Claude Code 作業完了時の通知フック

LOG_FILE="/tmp/claude-stop-hook.log"
echo "=== Stop Hook Executed at $(date) ===" >> "$LOG_FILE"

# PATH を設定
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# stdin から JSON を読み込み
INPUT=$(cat)
echo "$INPUT" | jq '.' > /tmp/claude-stop-hook-input.json 2>/dev/null || echo "$INPUT" > /tmp/claude-stop-hook-input.json

# フィールドを抽出
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
PROJECT_DIR=${CLAUDE_PROJECT_DIR:-"unknown"}
PROJECT_NAME=$(basename "$PROJECT_DIR")

# トランスクリプトから最近のツール使用を取得
RECENT_TOOLS=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    RECENT_TOOLS=$(cat "$TRANSCRIPT_PATH" | jq -r 'select(.message.content != null) | .message.content[] | select(.type == "tool_use") | .name' 2>/dev/null | tail -5 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
fi

# 通知メッセージを構築
if [ -n "$RECENT_TOOLS" ]; then
    NOTIFICATION_MESSAGE="🎉 作業完了

プロジェクト: ${PROJECT_NAME}
最近の作業: ${RECENT_TOOLS}
セッションID: ${SESSION_ID:0:8}..."
else
    NOTIFICATION_MESSAGE="🎉 作業完了

プロジェクト: ${PROJECT_NAME}
セッションID: ${SESSION_ID:0:8}..."
fi

# gotify で通知を送信（gotify がインストールされている場合）
if command -v gotify &>/dev/null; then
    gotify push "$NOTIFICATION_MESSAGE" \
        --title "Claude Code - 作業完了" \
        --priority 5 2>&1 >> "$LOG_FILE"
fi

exit 0
