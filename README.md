# Claude Code Notification System

Claude Codeからの通知をSlack、Discord、macOS通知など複数のサービスに送信する汎用的な通知システムです。

## ✨ 特徴

- 🔌 **プラグイン方式** - 新しい通知サービスを簡単に追加可能
- 🚀 **並列実行** - 複数の通知サービスに同時送信
- 📝 **ログ機能** - デバッグ用のログ記録機能
- 🧪 **テスト完備** - Batsによる自動テスト

## 📁 ディレクトリ構造

```
claude-notify-script/
├── notification-handler.sh       # メイン通知ハンドラー
├── notifiers/                    # アクティブな通知スクリプト（.gitignore）
│   └── slack.sh                 # 例: Slack通知スクリプト
├── notifiers-examples/           # 通知スクリプトのサンプル
│   ├── slack.example.sh         # Slack用サンプル
│   └── osa.example.sh           # macOS通知用サンプル
├── notification-examples/        # テスト用JSONサンプル
│   ├── simple-test.json         # シンプルなテスト
│   ├── important-waiting-input.json  # Claude待機通知
│   └── permission-needed.json   # 許可要求通知
├── test/                        # Batsテストファイル
│   └── notification-handler.bats
└── .shellcheckrc               # ShellCheck設定
```

## 🚀 クイックスタート

### 1. インストール

```bash
# リポジトリのクローン
git clone https://github.com/mmhiyoko/claude-notify-script.git
cd claude-notify-script

# 必要なツールのインストール（オプション）
brew install bats-core shellcheck jq
```

### 2. Claude Code設定

`~/.claude/settings.json`に以下を追加:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-notify-script/notification-handler.sh --log /home/user/.claude/logs/notification.log"
          }
        ]
      }
    ]
  }
}
```

### 3. Slack通知の設定

```bash
# サンプルをコピー
cp notifiers-examples/slack.example.sh notifiers/slack.sh

# Webhook URLを設定
vim notifiers/slack.sh
# 15行目あたりの以下の行を編集:
# SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# 実行権限を付与
chmod +x notifiers/slack.sh
```

### 4. 動作確認

```bash
# シンプルなテスト
echo '{"message":"テスト通知"}' | ./notification-handler.sh

# サンプルファイルでテスト
cat notification-examples/simple-test.json | ./notification-handler.sh
```

## 🔧 設定オプション

### notification-handler.sh の引数

| 引数 | 説明 | 例 |
|------|------|-----|
| `--log FILE` | ログファイルを指定 | `--log /tmp/notify.log` |
| `-l FILE` | `--log`の短縮形 | `-l /tmp/notify.log` |

### 環境変数

| 変数名 | 説明 | デフォルト |
|--------|------|------------|
| `DEBUG_MODE` | デバッグログを/tmpに出力 | false |
| `CLAUDE_TEST_MODE` | テストモード（通知をスキップ） | false |

### Slack通知の環境変数

| 変数名 | 説明 | デフォルト |
|--------|------|------------|
| `SLACK_WEBHOOK_URL` | Slack Webhook URL | なし（必須） |
| `SLACK_CHANNEL` | 投稿先チャンネル | #general |
| `SLACK_BOT_NAME` | Bot表示名 | Claude Code Bot |
| `SLACK_BOT_ICON` | Botアイコン | :robot_face: |
| `SLACK_ENABLED` | 通知の有効/無効 | true |

## 📝 新しい通知サービスの追加

### 最小限の実装

```bash
#!/bin/bash
# notifiers/myservice.sh

# JSON入力を受信
input=$(cat)

# 通知を送信
echo "$input" | curl -X POST https://myservice.example.com/webhook

exit $?
```

### 推奨実装

```bash
#!/bin/bash
# notifiers/myservice.sh

# 設定
WEBHOOK_URL="${MYSERVICE_WEBHOOK_URL:-}"
ENABLED="${MYSERVICE_ENABLED:-true}"

# 無効化チェック
if [[ "$ENABLED" != "true" ]]; then
    exit 0
fi

# URLチェック
if [[ -z "$WEBHOOK_URL" ]]; then
    echo "Error: WEBHOOK_URL not set" >&2
    exit 1
fi

# JSON処理
input=$(cat)
if command -v jq &> /dev/null; then
    message=$(echo "$input" | jq -r '.message // "通知"')
    event=$(echo "$input" | jq -r '.hook_event_name // "unknown"')
else
    message="通知"
    event="unknown"
fi

# 通知送信
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"$message\",\"event\":\"$event\"}" \
    "$WEBHOOK_URL")

# 結果確認
if [[ "$response" == *"ok"* ]]; then
    exit 0
else
    echo "Error: $response" >&2
    exit 1
fi
```

## 🧪 テスト

### 自動テスト（Bats）

```bash
# すべてのテストを実行
bats test/notification-handler.bats

# 特定のテストのみ実行
bats test/notification-handler.bats --filter "ログファイル"
```

### 手動テスト

```bash
# 基本テスト
echo '{"message":"テスト"}' | ./notification-handler.sh

# ログ付きテスト
echo '{"message":"ログテスト"}' | ./notification-handler.sh --log /tmp/test.log
cat /tmp/test.log

# テストモード（通知をスキップ）
CLAUDE_TEST_MODE=true echo '{"message":"テスト"}' | ./notification-handler.sh
```

### ShellCheckによる静的解析

```bash
# 単一ファイルのチェック
shellcheck notification-handler.sh

# すべてのシェルスクリプトをチェック
shellcheck *.sh notifiers/*.sh
```

## 🔍 トラブルシューティング

### 通知が届かない

1. **通知スクリプトの確認**
```bash
ls -la notifiers/
# 実行可能な.shファイルが存在することを確認
```

2. **実行権限の確認**
```bash
chmod +x notifiers/*.sh
```

3. **Webhook URLの確認**
```bash
grep WEBHOOK notifiers/slack.sh
# URLが正しく設定されているか確認
```

4. **デバッグモードで実行**
```bash
echo '{"message":"デバッグ"}' | ./notification-handler.sh --log /tmp/debug.log
cat /tmp/debug.log
```

### 特定のサービスだけ動作しない

```bash
# 個別にテスト
echo '{"message":"test"}' | ./notifiers/slack.sh
echo "Exit code: $?"

# エラー出力を確認
echo '{"message":"test"}' | ./notifiers/slack.sh 2>&1
```

### Claude Codeから通知が来ない

1. **設定ファイルの確認**
```bash
cat ~/.claude/settings.json | jq '.hooks.Notification'
```

2. **パスの確認**
```bash
# settings.jsonに記載されたパスが正しいか確認
ls -la /path/to/notification-handler.sh
```

3. **Claude Codeの再起動**
- settings.json変更後はClaude Codeの再起動が必要

## 📊 JSON形式

Claude Codeから送信される実際のJSON形式:

```json
{
  "session_id": "640549cd-a434-4dcd-a712-4d1ad2247014",
  "transcript_path": "/home/user/.claude/projects/...",
  "cwd": "/home/user/projects/example",
  "hook_event_name": "Notification",
  "message": "Claude is waiting for your input"
}
```

## 🛠️ 開発

### 必要なツール

- **bash** 4.0以上
- **jq** （オプション、JSON処理用）
- **curl** （Webhook通知用）
- **bats-core** （テスト用）
- **shellcheck** （静的解析用）

### コントリビューション

1. このリポジトリをフォーク
2. 新しいブランチを作成 (`git checkout -b feature/amazing-notification`)
3. 変更をコミット (`git commit -m 'Add amazing notification service'`)
4. ブランチにプッシュ (`git push origin feature/amazing-notification`)
5. Pull Requestを作成

## 📄 ライセンス

MIT License

## 🔗 関連リンク

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Bats Testing Framework](https://github.com/bats-core/bats-core)
- [ShellCheck](https://www.shellcheck.net/)

## 👥 作者

[@mmhiyoko](https://github.com/mmhiyoko)

---

⚠️ **注意**: `notifiers/`ディレクトリ内のファイルには実際のWebhook URLやトークンが含まれる可能性があるため、`.gitignore`で除外されています。機密情報を誤ってコミットしないよう注意してください。