#!/bin/bash
# codex-image.sh — Codex CLI (ChatGPT サブスク枠) 経由で gpt-image-2 画像を生成する
#
# 使い方:
#   codex-image.sh -o /path/to/output.png [-s 1024x1024|1536x1024|1024x1536] \
#                  [-i 参照画像.png]... "プロンプト"
#
# 仕組み:
#   - プロンプトは stdin パイプで codex exec に渡す（引数直渡しは非対話環境でハングする）
#   - 一時ディレクトリを作業場所にし、生成後に出力先へコピー（サンドボックス対策）
#   - 出力が見つからない場合は ~/.codex/generated_images/ から救出

set -u

SIZE=""
OUTPUT=""
INPUTS=()

while getopts "o:s:i:" opt; do
  case "$opt" in
    o) OUTPUT="$OPTARG" ;;
    s) SIZE="$OPTARG" ;;
    i) INPUTS+=("$OPTARG") ;;
    *) echo "usage: $0 -o output.png [-s WxH] [-i ref.png]... \"prompt\"" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

PROMPT="${1:-}"
if [ -z "$PROMPT" ] || [ -z "$OUTPUT" ]; then
  echo "usage: $0 -o output.png [-s WxH] [-i ref.png]... \"prompt\"" >&2
  exit 2
fi

# 認証モード確認（api_key モードだと従量課金になるため中断）
AUTH_MODE=$(python3 -c "import json;print(json.load(open('$HOME/.codex/auth.json')).get('auth_mode',''))" 2>/dev/null)
if [ "$AUTH_MODE" != "chatgpt" ]; then
  echo "ERROR: codex の認証モードが chatgpt ではありません (auth_mode=$AUTH_MODE)。" >&2
  echo "従量課金を避けるため中断します。'codex login' で ChatGPT アカウントにログインしてください。" >&2
  exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
START_MARKER="$WORKDIR/.start"
touch "$START_MARKER"

# 参照画像があれば作業ディレクトリへコピー
REF_NOTE=""
if [ ${#INPUTS[@]} -gt 0 ]; then
  n=1
  for f in "${INPUTS[@]}"; do
    if [ ! -f "$f" ]; then
      echo "ERROR: 参照画像が見つかりません: $f" >&2
      exit 1
    fi
    ext="${f##*.}"
    cp "$f" "$WORKDIR/ref_$n.$ext"
    REF_NOTE="$REF_NOTE Reference image: ./ref_$n.$ext."
    n=$((n + 1))
  done
fi

SIZE_NOTE=""
[ -n "$SIZE" ] && SIZE_NOTE=" Image size: $SIZE."

FULL_PROMPT="Use your built-in image generation tool (gpt-image-2) to create an image.${SIZE_NOTE}${REF_NOTE}
Prompt: ${PROMPT}
Save the generated image as ./out.png in the current working directory. Do not do anything else. When the file is saved, reply with exactly: SAVED"

# stdin パイプで渡す（引数直渡しは "Reading additional input from stdin..." でハングする）
printf '%s' "$FULL_PROMPT" | codex exec \
  --skip-git-repo-check \
  --sandbox workspace-write \
  --cd "$WORKDIR" \
  --output-last-message "$WORKDIR/.last_message" \
  > "$WORKDIR/.codex_log" 2>&1
CODEX_STATUS=$?

FOUND=""
if [ -f "$WORKDIR/out.png" ]; then
  FOUND="$WORKDIR/out.png"
else
  # 保存漏れ時の救出: image_gen は一旦 ~/.codex/generated_images/ に書き出すため、
  # 実行開始以降に作られた最新ファイルを探す
  FOUND=$(find "$HOME/.codex/generated_images" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) -newer "$START_MARKER" 2>/dev/null | tail -1)
fi

if [ -z "$FOUND" ]; then
  echo "ERROR: 画像が生成されませんでした (codex exit=$CODEX_STATUS)" >&2
  echo "--- codex log (末尾) ---" >&2
  tail -30 "$WORKDIR/.codex_log" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
cp "$FOUND" "$OUTPUT"
echo "SAVED: $OUTPUT"
