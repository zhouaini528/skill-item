#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$SKILL_DIR/scripts/lib.sh"

usage() {
  printf 'usage: bash %s --target DIR --name S --one-liner S --stack S [--date D] [--apply]\n' "$0" >&2
  exit 2
}

TARGET="."; PROJECT_NAME=""; ONE_LINER=""; STACK=""; DATE=""; APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || usage; TARGET=$2; shift 2 ;;
    --name) [ $# -ge 2 ] || usage; PROJECT_NAME=$2; shift 2 ;;
    --one-liner) [ $# -ge 2 ] || usage; ONE_LINER=$2; shift 2 ;;
    --stack) [ $# -ge 2 ] || usage; STACK=$2; shift 2 ;;
    --date) [ $# -ge 2 ] || usage; DATE=$2; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage ;;
  esac
done

[ -n "$PROJECT_NAME" ] && [ -n "$ONE_LINER" ] && [ -n "$STACK" ] || usage
[ -n "$DATE" ] || DATE=$(date +%F)

FILES="AGENTS.md ENVIRONMENTS.md STATUS.md README.md env env.example .gitignore docs/spec/README.md docs/spec/00-overview.md docs/decisions/README.md docs/decisions/D-001.md docs/evidence/README.md docs/ops/README.md tools/env.sh tools/check-links.sh"


existing=""
for f in $FILES; do
  if [ "$f" = ".gitignore" ]; then continue; fi
  if [ -e "$TARGET/$f" ]; then existing="$existing $f"; fi
done

if [ "$APPLY" -eq 0 ]; then
  printf '将创建（dry-run，不会写入）：\n'
  for f in $FILES; do echo_item "$TARGET/$f"; done
  printf '\n加 --apply 才会写入。\n'
  exit 0
fi

if [ -n "$existing" ]; then
  printf '已存在以下文件，拒绝覆盖：\n' >&2
  for f in $existing; do printf '  %s\n' "$f" >&2; done
  printf '目标：%s\n' "$TARGET" >&2
  exit 1
fi

mkdir -p "$TARGET"
ROOT=$(cd "$TARGET" && pwd)

for f in $FILES; do
  if [ "$f" = ".gitignore" ]; then continue; fi
  if [ "$f" = "env" ]; then continue; fi
  tmpl=$(tmpl_for "$f")
  if [ -z "$tmpl" ]; then printf 'no template for %s\n' "$f" >&2; exit 1; fi
  render_file "$SKILL_DIR/templates/$tmpl" "$TARGET/$f"
done

printf 'ENV=local\nROLE=authoring\nROOT=%s\n' "$ROOT" > "$TARGET/env"
chmod_600 "$TARGET/env"
chmod_exec "$TARGET/tools/env.sh" "$TARGET/tools/check-links.sh"
append_gitignore "$TARGET" "$SKILL_DIR/templates/gitignore.append"

n=0
for f in $FILES; do n=$((n+1)); done
printf '已创建 %s 个文件：\n' "$n"
for f in $FILES; do echo_item "$TARGET/$f"; done
printf '\n下一步：\n'
printf '  1. 补写 README 文档地图、AGENTS §1/§4、docs/spec/00-overview.md\n'
printf '  2. bash scripts/check.sh %s\n' "$TARGET"