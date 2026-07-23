---
name: codex-image
description: Codex CLI（ChatGPT サブスク枠・API 課金なし）経由で gpt-image-2 による画像生成・編集を行う。「codex で画像生成」「サブスクで画像を作って」「gpt-image-2 で」「無料で画像生成」など Codex/サブスク経由を指定された画像生成依頼、または API 課金を避けたい画像生成・画像編集・参照画像ありのリミックスに使用。
---

# codex-image: Codex CLI 経由の gpt-image-2 画像生成

ChatGPT サブスクリプション枠内（API 従量課金なし）で、Codex CLI の組み込み
image_gen ツール（gpt-image-2）を呼び出して画像を生成する。

## 使い方

すべてラッパースクリプト経由で実行する。`codex exec` を直接呼ばないこと。

```bash
~/.claude/skills/codex-image/scripts/codex-image.sh \
  -o /絶対パス/output.png \
  [-s 1024x1024|1536x1024|1024x1536] \
  [-i 参照画像.png]... \
  "画像の詳細なプロンプト"
```

- `-o` 出力先（必須・絶対パス推奨）。成功すると `SAVED: <path>` が出力される。
- `-s` サイズ。省略時は自動。横長=1536x1024、縦長=1024x1536。
- `-i` 参照画像（画像編集・リミックス時）。複数指定可。

### 実行時の注意（重要）

- **生成には 2〜6 分かかる**（codex が推論してから画像ツールを起動するため）。
  Bash ツールは必ず `timeout: 600000` を指定するか、`run_in_background: true` で実行する。
- プロンプトは英語で書くと安定するが、日本語文字を画像内に描く場合は
  「Render the following Japanese text exactly: ...」のように明示する。
- 1 回の実行で 1 枚生成。複数枚必要ならスクリプトを複数回呼ぶ（並列可）。

### 例

テキストから生成:

```bash
~/.claude/skills/codex-image/scripts/codex-image.sh \
  -o ~/Desktop/hero.png -s 1536x1024 \
  "A minimalist blog hero image of a mountain landscape at dawn, soft gradient sky, flat design"
```

既存画像の編集:

```bash
~/.claude/skills/codex-image/scripts/codex-image.sh \
  -o ./edited.png -i ./original.png \
  "Change the background to a night sky with stars, keep the subject unchanged"
```

## 生成後

- `SAVED: <path>` を確認したら、Read ツールで画像を読み込んで結果を検証する。
- 意図と違う場合はプロンプトを具体化して再実行する（サブスク枠内なので試行コストはない）。

## トラブルシューティング

- **ERROR: 認証モードが chatgpt ではない** → 従量課金防止のためスクリプトが中断した状態。
  ユーザーに `codex login`（ChatGPT アカウントで OAuth ログイン。API キーは入力しない）を依頼する。
- **画像が生成されない** → スクリプトが codex ログ末尾を stderr に出すので原因を確認。
  レート制限（サブスク枠の使い切り）の場合は時間を置くようユーザーに伝える。
- **タイムアウト** → `run_in_background: true` で再実行する。
- 保存漏れ（codex が保存パスへのコピーに失敗するケース）はスクリプトが
  `~/.codex/generated_images/` から自動救出するため、通常は意識不要。
