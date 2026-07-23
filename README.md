# codex-image

Claude Code から **Codex CLI 経由で gpt-image-2 画像生成**を行うスキルです。

ChatGPT の有料サブスクリプション（Plus / Pro / Business / Enterprise）の枠内で動作するため、**OpenAI API の従量課金は一切発生しません**。Claude Code に「〜の画像を作って」と頼むだけで、Codex CLI の組み込み image_gen ツール（gpt-image-2）が画像を生成します。

```
Claude Code ──Bash──▶ codex-image.sh ──codex exec──▶ gpt-image-2
```

## できること

- **テキストからの画像生成** — イラスト、モックアップ、OG 画像、ブログのヒーロー画像など
- **既存画像の編集・リミックス** — 参照画像を渡してスタイル変換や部分修正（複数参照可）
- **サイズ指定** — 1024x1024 / 1536x1024（横長）/ 1024x1536（縦長）

## 必要なもの

| 要件 | 備考 |
|---|---|
| ChatGPT 有料プラン | Plus / Pro / Business / Enterprise のいずれか |
| Codex CLI | `npm install -g @openai/codex@latest`（Node.js v18+） |
| ChatGPT 認証 | `codex login` で **OAuth ログイン**（下記の注意参照） |
| Claude Code | スキルの実行環境 |

> [!IMPORTANT]
> `codex login` の際、**API キーは絶対に入力しないでください**。API キーで認証すると従量課金ルートに切り替わります。必ず ChatGPT アカウントの OAuth ログインを使ってください。本スキルのスクリプトは実行前に認証モードを確認し、`chatgpt` モードでない場合は課金防止のため中断します。

## インストール

```bash
git clone https://github.com/Tackrow/codex-image-skill.git
mkdir -p ~/.claude/skills
cp -r codex-image-skill ~/.claude/skills/codex-image
chmod +x ~/.claude/skills/codex-image/scripts/codex-image.sh
```

以降、Claude Code で画像生成を依頼すると自動的にこのスキルがトリガーされます。

## 使い方

### Claude Code から（通常はこちら）

自然言語で依頼するだけです:

> サングラスをかけた柴犬のフラットイラストを作って

### スクリプトを直接実行

```bash
~/.claude/skills/codex-image/scripts/codex-image.sh \
  -o ./output.png \
  [-s 1024x1024|1536x1024|1024x1536] \
  [-i 参照画像.png]... \
  "画像のプロンプト"
```

| オプション | 説明 |
|---|---|
| `-o` | 出力先パス（必須）。成功すると `SAVED: <path>` が出力されます |
| `-s` | 画像サイズ。省略時は自動 |
| `-i` | 参照画像。画像編集・リミックス時に指定。複数回指定可 |

例 — 既存画像の背景だけ差し替え:

```bash
codex-image.sh -o edited.png -i original.png \
  "Change the background to a night sky with stars, keep the subject unchanged"
```

## 仕組みと設計上の工夫

Codex CLI を非対話環境から安定して呼び出すため、スクリプトが以下を吸収しています:

1. **プロンプトは stdin パイプで渡す** — 引数で直接渡すと非対話環境では EOF が届かず無限待機するため
2. **サンドボックスを緩めない** — `--dangerously-bypass-approvals-and-sandbox` は使わず、一時ディレクトリを作業場所（`--cd`）にして `workspace-write` のまま生成し、完了後にスクリプト側で出力先へコピー
3. **保存漏れの自動救出** — Codex の image_gen ツールは一旦 `~/.codex/generated_images/` に書き出してから指定パスへコピーする2段階処理で、まれにコピーが落ちるため、出力が見つからない場合はそこから最新ファイルを救出
4. **課金ガード** — 実行前に `~/.codex/auth.json` の `auth_mode` を確認し、`chatgpt`（サブスク枠）でなければ即座に中断

## よくある質問・トラブルシューティング

**Q. 生成が遅い**
gpt-image-2 は描画前に推論（構図のプランニング）を行うため、1 枚あたり 2〜6 分かかります。仕様です。その分プロンプトへの忠実度が高く、やり直し回数は少なくて済みます。

**Q. `ERROR: codex の認証モードが chatgpt ではありません` と出る**
API キー認証になっています。`codex login` で ChatGPT アカウントの OAuth ログインをやり直してください。

**Q. 画像が生成されずに終わる**
スクリプトが codex のログ末尾を stderr に出力するので原因を確認してください。サブスク枠のレート制限に達している場合は、時間を置いて再実行してください。

**Q. 生成枚数の上限は?**
ChatGPT サブスクリプションの利用枠に準じます。API のような従量課金はありません。

## 動作確認済み環境

- macOS (Apple Silicon) / zsh
- Codex CLI 0.145.0
- Claude Code

## ライセンス

MIT
