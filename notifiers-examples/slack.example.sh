#!/bin/bash

# Slack Notifier for Claude Code
# 
# セットアップ手順:
# 1. このファイルを notifiers/slack.sh にコピー
# 2. SLACK_WEBHOOK_URL を設定
# 3. 実行権限を付与: chmod +x notifiers/slack.sh

# ==================== 設定 ====================
# Slack Webhook URL (必須)
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# チャンネル設定（オプション）
SLACK_CHANNEL="#general"

# Bot表示設定（オプション）
SLACK_BOT_NAME="Claude Code Bot"
SLACK_BOT_ICON=":robot_face:"

# 通知を有効にする（true/false）
ENABLED="true"
# ==================== 設定終了 ====================

# 無効化されている場合は終了
if [[ "$ENABLED" != "true" ]]; then
    exit 0
fi

# WebhookURLの確認
if [[ -z "$SLACK_WEBHOOK_URL" ]] || [[ "$SLACK_WEBHOOK_URL" == *"YOUR/WEBHOOK/URL"* ]]; then
    echo "⚠️ Slack Webhook URLが設定されていません" >&2
    exit 1
fi

# JSON入力を受信
input=$(cat)

# JSONからメッセージを抽出
if command -v jq &> /dev/null; then
    message=$(echo "$input" | jq -r '.message // .hook_event_name // "Claude Code通知"')
    event=$(echo "$input" | jq -r '.hook_event_name // "unknown"')
else
    message="Claude Code通知"
    event="unknown"
fi

# Slack通知を送信
payload=$(cat <<EOF
{
    "channel": "$SLACK_CHANNEL",
    "username": "$SLACK_BOT_NAME",
    "icon_emoji": "$SLACK_BOT_ICON",
    "text": "*Claude Code通知*\n$message\n_$(date '+%Y-%m-%d %H:%M:%S')_"
}
EOF
)

response=$(curl -s -X POST \
    -H "Content-type: application/json" \
    --data "$payload" \
    "$SLACK_WEBHOOK_URL" 2>/dev/null)

if [[ "$response" == "ok" ]]; then
    exit 0
else
    echo "❌ Slack通知送信失敗: $response" >&2
    exit 1
fi