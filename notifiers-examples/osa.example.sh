#!/bin/bash

# macOS Notification (osascript) for Claude Code
# 
# セットアップ手順:
# 1. このファイルを notifiers/osa.sh にコピー
# 2. 必要に応じて設定を調整
# 3. 実行権限を付与: chmod +x notifiers/osa.sh

# ==================== 設定 ====================
# 通知を有効にする（true/false）
ENABLED="true"

# 通知のタイトル
NOTIFICATION_TITLE="Claude Code"

# サウンドを再生する（true/false）
PLAY_SOUND="true"

# サウンド名（システムサウンド）
SOUND_NAME="Glass"

# 通知をスティッキーにする（消えるまで表示）
STICKY="false"
# ==================== 設定終了 ====================

# 無効化されている場合は終了
if [[ "$ENABLED" != "true" ]]; then
    exit 0
fi

# macOSでない場合は終了
if [[ "$(uname)" != "Darwin" ]]; then
    exit 0
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

# エスケープ処理（osascript用）
message=$(echo "$message" | sed 's/"/\\"/g')

# osascriptコマンドを構築
script="display notification \"$message\" with title \"$NOTIFICATION_TITLE\""

if [[ "$PLAY_SOUND" == "true" ]]; then
    script="$script sound name \"$SOUND_NAME\""
fi

# 通知を表示
if osascript -e "$script" 2>/dev/null; then
    # 追加でターミナル通知も表示（オプション）
    if [[ "$STICKY" == "true" ]]; then
        osascript -e "display dialog \"$message\" with title \"$NOTIFICATION_TITLE\" buttons {\"OK\"} default button 1" 2>/dev/null &
    fi
    exit 0
else
    echo "❌ macOS通知の表示に失敗しました" >&2
    exit 1
fi