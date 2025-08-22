#!/bin/bash

# Slack Notifier for Claude Code
# 
# セットアップ手順:
# 1. 環境変数 SLACK_WEBHOOK_URL を設定
# 2. または、このファイル内で直接URLを設定
# 3. 実行権限を付与: chmod +x notifiers/slack.sh

# ==================== 設定 ====================
# Slack Webhook URL (環境変数から取得、なければデフォルト値)
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# ファイル内でURLを直接設定する場合はここに記入（推奨）
# SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# ↑ コメントアウトを外して、実際のWebhook URLを設定してください

# チャンネル設定（環境変数から取得、なければデフォルト値）
SLACK_CHANNEL="${SLACK_CHANNEL:-#general}"

# Bot表示設定（環境変数から取得、なければデフォルト値）
SLACK_BOT_NAME="${SLACK_BOT_NAME:-Claude Code Bot}"
SLACK_BOT_ICON="${SLACK_BOT_ICON:-:robot_face:}"

# 通知を有効にする（環境変数から取得、なければtrue）
ENABLED="${SLACK_ENABLED:-true}"
# ==================== 設定終了 ====================

# 無効化されている場合は終了
if [[ "$ENABLED" != "true" ]]; then
    exit 0
fi

# WebhookURLの確認
if [[ -z "$SLACK_WEBHOOK_URL" ]] || [[ "$SLACK_WEBHOOK_URL" == *"YOUR/WEBHOOK/URL"* ]]; then
    echo "⚠️ Slack Webhook URLが設定されていません" >&2
    echo "  環境変数 SLACK_WEBHOOK_URL を設定するか、" >&2
    echo "  このファイル内で直接URLを設定してください" >&2
    exit 1
fi

# JSON入力を受信
input=$(cat)

# jqの必須チェック
if ! command -v jq &> /dev/null; then
    echo "❌ エラー: jqがインストールされていません" >&2
    echo "  インストール方法: brew install jq または apt-get install jq" >&2
    exit 1
fi

# JSONからデータを抽出
message=$(echo "$input" | jq -r '.message // ""')
event=$(echo "$input" | jq -r '.hook_event_name // "unknown"')
session_id=$(echo "$input" | jq -r '.session_id // ""')
cwd=$(echo "$input" | jq -r '.cwd // ""')

# プロジェクト名を抽出（cwdの最後のディレクトリ名）
project_name=$(basename "$cwd")

# イベントタイプに応じた絵文字とタイトル
case "$event" in
    "Notification")
        emoji="🔔"
        title=""  # タイトルを空に
        color="#FFA500"
        ;;
    "Error")
        emoji="❌"
        title="Error"
        color="#FF0000"
        ;;
    "Success")
        emoji="✅"
        title=""
        color="#00FF00"
        ;;
    *)
        emoji="📌"
        title="$event"
        color="#808080"
        ;;
esac

# メッセージにプロジェクト名を追加（1行目用）
if [[ -n "$project_name" ]]; then
    text_message="$message [$project_name]"
else
    text_message="$message"
fi

# Slack通知を送信（リッチな形式）
payload=$(cat <<EOF
{
    "channel": "$SLACK_CHANNEL",
    "username": "$SLACK_BOT_NAME",
    "icon_emoji": "$SLACK_BOT_ICON",
    "text": "$text_message",
    "attachments": [
        {
            "color": "$color",
            "fallback": "$text_message",
            "title": "$emoji $event",
            "fields": [
                {
                    "title": "メッセージ",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "プロジェクト",
                    "value": "$project_name",
                    "short": true
                },
                {
                    "title": "ディレクトリ",
                    "value": "$cwd",
                    "short": true
                }
            ],
            "footer": "Claude Code",
            "footer_icon": "https://www.anthropic.com/favicon.ico",
            "ts": $(date +%s)
        }
    ]
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