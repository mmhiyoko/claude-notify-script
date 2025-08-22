#!/bin/bash

# Claude Code 通知ハンドラー
# 
# 使用方法:
# 1. notifiersディレクトリに通知スクリプトを配置
# 2. スクリプトに実行権限を付与: chmod +x notifiers/*.sh
# 3. Claude Code settings.jsonで設定:
#    echo '{"message":"test"}' | ./notification-handler.sh
#
# ログ出力オプション:
#   --log /path/to/logfile    : ログファイルを指定
#   -l /path/to/logfile       : ログファイルを指定（短縮形）
#   --log=/path/to/logfile    : ログファイルを指定（=形式）

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFIERS_DIR="${SCRIPT_DIR}/notifiers"
LOG_FILE=""

# 引数パース
while [[ $# -gt 0 ]]; do
    case $1 in
        --log|-l)
            LOG_FILE="$2"
            shift 2
            ;;
        --log=*)
            LOG_FILE="${1#*=}"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

log_message() {
    local message="$1"
    local timestamp
    timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    
    # 引数で指定されたログファイルに出力
    if [[ -n "$LOG_FILE" ]]; then
        # ディレクトリが存在しない場合は作成
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"
        echo "$timestamp $message" >> "$LOG_FILE"
    fi
    
    # デバッグモードの場合は標準エラー出力にも出力
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        echo "$timestamp $message" >&2
    fi
}

# ハンドラー開始ログ
log_message "notification-handler: 通知ハンドラー開始"

# jqの必須チェック
if ! command -v jq &> /dev/null; then
    echo "❌ エラー: jqがインストールされていません" >&2
    echo "  インストール方法: brew install jq または apt-get install jq" >&2
    exit 1
fi

# JSON入力を受信
input=$(cat)

# 受信データログ
log_message "受信データ: $input"

# テストモードの確認
if [[ "${CLAUDE_TEST_MODE:-}" == "true" ]] || [[ "${TEST_MODE:-}" == "true" ]]; then
    echo "🧪 テストモード: 通知スキップ" >&2
    log_message "通知完了: 0 個実行, 0 個失敗 (テストモード)"
    exit 0
fi

# notifiersディレクトリの存在確認
if [[ ! -d "$NOTIFIERS_DIR" ]]; then
    log_message "エラー: notifiersディレクトリが存在しません"
    exit 0
fi

# 実行可能な通知スクリプトを処理
any_executed=false
any_succeeded=false

for notifier in "$NOTIFIERS_DIR"/*.sh; do
    # ファイルが存在しない場合はスキップ
    [[ ! -f "$notifier" ]] && continue
    
    # 実行権限がない場合はスキップ
    if [[ ! -x "$notifier" ]]; then
        log_message "スキップ: $(basename "$notifier") (実行権限なし)"
        continue
    fi
    
    notifier_name=$(basename "$notifier")
    any_executed=true
    
    # 各通知スクリプトにJSONを渡して実行
    # || true を使ってエラーでも継続
    if echo "$input" | "$notifier" 2>&1; then
        log_message "成功: $notifier_name"
        any_succeeded=true
    else
        log_message "失敗: $notifier_name (exit: $?)"
    fi
done

# 結果をログ
if [[ "$any_executed" == "true" ]]; then
    if [[ "$any_succeeded" == "true" ]]; then
        log_message "通知完了: 成功"
    else
        log_message "通知完了: 全て失敗"
    fi
else
    log_message "通知完了: 実行可能な通知スクリプトなし"
fi

# 少なくとも1つの通知が成功していれば正常終了
if [[ "$any_succeeded" == "true" ]]; then
    exit 0
else
    exit 1
fi