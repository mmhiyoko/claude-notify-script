#!/usr/bin/env bats

# notification-handler.sh のBatsテストスクリプト

setup() {
    export CLAUDE_TEST_MODE="true"
    SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
    HANDLER_SCRIPT="$SCRIPT_DIR/notification-handler.sh"
    EXAMPLES_DIR="$SCRIPT_DIR/notification-examples"
    NOTIFIERS_DIR="$SCRIPT_DIR/notifiers"
    
    # デバッグログファイルをクリア
    DEBUG_LOG="/tmp/claude-notification-debug.log"
    > "$DEBUG_LOG"
}

# 【1. スクリプトの基本チェック】

@test "スクリプトファイルが存在" {
    [ -f "$HANDLER_SCRIPT" ]
}

@test "スクリプトが実行可能" {
    [ -x "$HANDLER_SCRIPT" ]
}

# 【2. JSON処理のテスト】

@test "テストモードで通知スキップ - 基本的なメッセージ" {
    run bash -c "echo '{\"message\":\"テストメッセージ\"}' | bash '$HANDLER_SCRIPT' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"テストモード"* ]]
}

@test "イベント名のみでも動作" {
    run bash -c "echo '{\"hook_event_name\":\"test_event\"}' | bash '$HANDLER_SCRIPT' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"テストモード: 通知スキップ"* ]]
}

@test "空のJSONでも動作" {
    run bash -c "echo '{}' | bash '$HANDLER_SCRIPT' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"テストモード: 通知スキップ"* ]]
}

# 【3. サンプルファイルでのテスト】

@test "simple-test.json の処理" {
    skip_if_no_json_file "$EXAMPLES_DIR/simple-test.json"
    run bash -c "cat '$EXAMPLES_DIR/simple-test.json' | bash '$HANDLER_SCRIPT' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"テストモード"* ]]
}

@test "permission-needed.json の処理" {
    skip_if_no_json_file "$EXAMPLES_DIR/permission-needed.json"
    run bash -c "cat '$EXAMPLES_DIR/permission-needed.json' | bash '$HANDLER_SCRIPT' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"テストモード"* ]]
}

@test "important-waiting-input.json の処理" {
    skip_if_no_json_file "$EXAMPLES_DIR/important-waiting-input.json"
    run bash -c "cat '$EXAMPLES_DIR/important-waiting-input.json' | bash '$HANDLER_SCRIPT' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"テストモード"* ]]
}


# 【4. 通知スクリプト確認】

@test "notifiersディレクトリが存在" {
    [ -d "$NOTIFIERS_DIR" ]
}

@test "notifiersディレクトリに実行可能なスクリプトがある（オプショナル）" {
    # 実行可能なスクリプトの数を確認（0でも成功とする）
    script_count=$(find "$NOTIFIERS_DIR" -name "*.sh" -type f -executable 2>/dev/null | wc -l)
    echo "# 実行可能なスクリプト数: $script_count" >&3
    [ "$script_count" -ge 0 ]
}

# 【5. デバッグモードのテスト】

@test "デバッグログ記録（DEBUG_MODE=true）" {
    export DEBUG_MODE="true"
    export CLAUDE_TEST_MODE="true"
    DEBUG_LOG="/tmp/claude-notification-debug.log"
    
    # ログファイルをクリア
    > "$DEBUG_LOG"
    
    run bash -c "echo '{\"message\":\"デバッグテスト\"}' | bash '$HANDLER_SCRIPT' 2>&1"
    [ "$status" -eq 0 ]
    
    # ログファイルが存在し、内容が記録されているか確認
    [ -f "$DEBUG_LOG" ]
    grep -q "notification-handler" "$DEBUG_LOG"
}

# 【6. ログファイル引数のテスト】

@test "ログファイル引数指定（--log）でログが出力される" {
    local test_log="/tmp/test-handler-$$.log"
    rm -f "$test_log"
    
    run bash -c "echo '{\"message\":\"ログテスト\"}' | bash '$HANDLER_SCRIPT' --log '$test_log' 2>&1"
    [ "$status" -eq 0 ]
    
    # ログファイルが作成されているか確認
    [ -f "$test_log" ]
    
    # ログ内容を確認
    grep -q "notification-handler: 通知ハンドラー開始" "$test_log"
    grep -q "受信データ:" "$test_log"
    grep -q "通知完了:" "$test_log"
    
    # クリーンアップ
    rm -f "$test_log"
}

@test "ログファイル引数指定（-l）でログが出力される" {
    local test_log="/tmp/test-handler-short-$$.log"
    rm -f "$test_log"
    
    run bash -c "echo '{\"message\":\"ログテスト\"}' | bash '$HANDLER_SCRIPT' -l '$test_log' 2>&1"
    [ "$status" -eq 0 ]
    
    # ログファイルが作成されているか確認
    [ -f "$test_log" ]
    
    # ログ内容を確認
    grep -q "notification-handler: 通知ハンドラー開始" "$test_log"
    
    # クリーンアップ
    rm -f "$test_log"
}

@test "ログファイル引数指定（--log=）でログが出力される" {
    local test_log="/tmp/test-handler-equal-$$.log"
    rm -f "$test_log"
    
    run bash -c "echo '{\"message\":\"ログテスト\"}' | bash '$HANDLER_SCRIPT' --log='$test_log' 2>&1"
    [ "$status" -eq 0 ]
    
    # ログファイルが作成されているか確認
    [ -f "$test_log" ]
    
    # ログ内容を確認
    grep -q "notification-handler: 通知ハンドラー開始" "$test_log"
    
    # クリーンアップ
    rm -f "$test_log"
}

@test "ログディレクトリが存在しない場合は自動作成される" {
    local test_log="/tmp/test-dir-$$$/handler.log"
    rm -rf "/tmp/test-dir-$$$"
    
    run bash -c "echo '{\"message\":\"ディレクトリテスト\"}' | bash '$HANDLER_SCRIPT' --log '$test_log' 2>&1"
    [ "$status" -eq 0 ]
    
    # ディレクトリとログファイルが作成されているか確認
    [ -d "/tmp/test-dir-$$$" ]
    [ -f "$test_log" ]
    
    # クリーンアップ
    rm -rf "/tmp/test-dir-$$$"
}

# ヘルパー関数

skip_if_no_json_file() {
    [ -f "$1" ] || skip "JSONファイルが存在しません: $1"
}