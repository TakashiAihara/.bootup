#!/bin/bash
# Claude Code 確認待ち時の通知フック

LOG_FILE="/tmp/claude-notification-hook.log"
echo "=== $(date) ===" >> "$LOG_FILE"

# PATH を設定
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# stdin から JSON を読み込み
INPUT=$(cat)
echo "$INPUT" > /tmp/claude-notification-hook-input.json

# フィールドを抽出
MESSAGE=$(echo "$INPUT" | jq -r '.message // "確認待ち"')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
PROJECT_DIR=${CLAUDE_PROJECT_DIR:-"unknown"}
PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "Message: $MESSAGE" >> "$LOG_FILE"
echo "Project: $PROJECT_NAME" >> "$LOG_FILE"

# 待機中のツールを取得
PENDING_TOOL=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    PENDING_TOOL=$(cat "$TRANSCRIPT_PATH" | jq -r 'select(.message.content != null) | .message.content[] | select(.type == "tool_use") | .name' 2>/dev/null | tail -1)
fi

# 通知メッセージを構築
NOTIFICATION_MESSAGE="⚠️ 確認待ち

プロジェクト: ${PROJECT_NAME}
メッセージ: ${MESSAGE}"

if [ -n "$PENDING_TOOL" ]; then
    NOTIFICATION_MESSAGE="${NOTIFICATION_MESSAGE}
実行予定: ${PENDING_TOOL}"
fi

# gotify で通知を送信（gotify がインストールされている場合）
if command -v gotify &>/dev/null; then
    gotify push "$NOTIFICATION_MESSAGE" \
        --title "Claude Code - 確認待ち" \
        --priority 8 2>&1 >> "$LOG_FILE"
fi

exit 0
