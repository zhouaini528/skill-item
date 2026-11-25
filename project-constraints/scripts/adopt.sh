#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$SKILL_DIR/scripts/lib.sh"

usage() {
  printf 'usage: bash %s --target DIR [--scan quick|standard|full] [--report FILE] [--apply] [--name S] [--one-liner S] [--stack S] [--env E] [--role R]\n' "$0" >&2
  exit 2
}

TARGET="."; SCAN="standard"; REPORT=""; APPLY=0
F_NAME=""; F_ONE=""; F_STACK=""; F_ENV=""; F_ROLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || usage; TARGET=$2; shift 2 ;;
    --scan) [ $# -ge 2 ] || usage; SCAN=$2; shift 2 ;;
    --report) [ $# -ge 2 ] || usage; REPORT=$2; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --name) [ $# -ge 2 ] || usage; F_NAME=$2; shift 2 ;;
    --one-liner) [ $# -ge 2 ] || usage; F_ONE=$2; shift 2 ;;
    --stack) [ $# -ge 2 ] || usage; F_STACK=$2; shift 2 ;;
    --env) [ $# -ge 2 ] || usage; F_ENV=$2; shift 2 ;;
    --role) [ $# -ge 2 ] || usage; F_ROLE=$2; shift 2 ;;
    -h|--help) usage ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage ;;
  esac
done

case "$SCAN" in quick|standard|full) ;; *) printf '非法 --scan: %s\n' "$SCAN" >&2; usage ;; esac

[ -d "$TARGET" ] || { printf '目标不存在: %s\n' "$TARGET" >&2; exit 1; }
[ -w "$TARGET" ] || { printf '目标不可写: %s\n' "$TARGET" >&2; exit 1; }

ROOT=$(cd "$TARGET" && pwd)
DATE=$(date +%F)
PROJECT_NAME=${F_NAME:-$(basename "$ROOT")}
ONE_LINER=${F_ONE:-（待补写）}
STACK=${F_STACK:-（待补写）}

if [ "$APPLY" -eq 1 ] && [ ! -f "$ROOT/AGENTS.md" ]; then
  if [ -z "$F_NAME" ] || [ -z "$F_ONE" ] || [ -z "$F_STACK" ]; then
    printf '目标没有 AGENTS.md，--name / --one-liner / --stack 必填\n' >&2
    exit 2
  fi
fi

if [ -n "$REPORT" ] && [ -e "$REPORT" ]; then
  printf '报告已存在，拒绝覆盖: %s\n' "$REPORT" >&2
  exit 1
fi

if [ -n "$REPORT" ]; then exec > "$REPORT"; fi

FILES="AGENTS.md ENVIRONMENTS.md STATUS.md README.md env env.example .gitignore docs/spec/README.md docs/spec/00-overview.md docs/decisions/README.md docs/decisions/D-001.md docs/evidence/README.md docs/ops/README.md tools/env.sh tools/check-links.sh"

printf '# adopt 报告 · %s\n\n' "$PROJECT_NAME"
printf -- '- 生成时间：%s\n' "$DATE"
printf -- '- 扫描级别：%s\n' "$SCAN"
printf -- '- 目标：%s\n' "$ROOT"
if [ -d "$ROOT/.git" ]; then printf -- '- git：是\n'; else printf -- '- git：否\n'; fi
printf '\n'

printf '## 已有（跳过）\n\n'
printf '| 路径 | 行数 | 建议 |\n| --- | --- | --- |\n'
for f in $FILES; do
  [ -e "$ROOT/$f" ] || continue
  lines=$(wc -l < "$ROOT/$f" 2>/dev/null || printf '0')
  case "$f" in
    AGENTS.md) note="保留；与模板八节逐条比对，冲突写进裁决表" ;;
    .gitignore) note="保留；不追加，需自行合并缺失项" ;;
    *) note="保留；确认职责是否与模板重叠" ;;
  esac
  printf '| %s | %s | %s |\n' "$f" "$lines" "$note"
done
printf '\n'

printf '## 将创建（缺失）\n\n'
printf '| 路径 |\n| --- |\n'
for f in $FILES; do
  [ -e "$ROOT/$f" ] || printf '| %s |\n' "$f"
done
printf '\n'

printf '## 结构发现\n\n'
printf '| 类型 | 路径 | 说明 |\n| --- | --- | --- |\n'
row() { printf '| %s | %s | %s |\n' "$1" "$2" "$3"; }
maybe_row() { if [ -e "$ROOT/$1" ]; then row "$2" "$1" "$3"; fi; }

maybe_row CLAUDE.md "文档" "另一份 agent 规则，需比对"
maybe_row CONTRIBUTING.md "文档" "贡献规则，与提交/验证规则比对"
maybe_row docs "文档" "已有文档结构，确认是否与 spec/decisions/evidence 重叠"

if [ "$SCAN" != "quick" ]; then
  maybe_row .cursorrules "AI 规则" "另一套 AI 约束，逐条比对"
  maybe_row .cursor/rules "AI 规则" "另一套 AI 约束，逐条比对"
  maybe_row .github/copilot-instructions.md "AI 规则" "另一套 AI 约束，逐条比对"
  maybe_row .env "环境" "已有环境变量文件，只读键名，不读值"
  maybe_row .github/workflows "CI" "确认验证在哪跑"
  maybe_row .gitlab-ci.yml "CI" "确认验证在哪跑"
  maybe_row package.json "构建" "scripts 决定本地能跑什么"
  maybe_row Makefile "构建" "确认验证入口"
fi

if [ "$SCAN" = "full" ]; then
  maybe_row .editorconfig "格式" "只登记，不判冲突"
  for p in .eslintrc .eslintrc.js .eslintrc.json ruff.toml .prettierrc pyproject.toml; do
    maybe_row "$p" "格式" "只登记，不判冲突"
  done
  for p in package-lock.json pnpm-lock.yaml yarn.lock go.sum Cargo.lock; do
    maybe_row "$p" "依赖" "只登记，不判冲突"
  done
fi
printf '\n'

printf '## 冲突裁决\n\n'
printf '由 Agent 读取上方文件后逐行填写；每行必须有现有原文、选项与建议。\n\n'
printf '| # | 冲突点 | 现有原文 | 模板要求 | 选项 | 建议 | 状态 |\n'
printf '| --- | --- | --- | --- | --- | --- | --- |\n\n'

printf '## 阻塞项\n\n'
blockers=0
if [ ! -f "$ROOT/env" ]; then
  printf -- '- env 未建立：暂用 ENV=%s，需补写 ROLE/ROOT\n' "${F_ENV:-unknown}"
  blockers=$((blockers+1))
fi
if [ ! -f "$ROOT/STATUS.md" ]; then
  printf -- '- 没有 STATUS：新会话无法判断当前阶段\n'
  blockers=$((blockers+1))
fi
if [ "$blockers" -eq 0 ]; then printf -- '- 无。\n'; fi
printf '\n'

printf '## 下一步\n\n'
printf '1. 逐条裁决冲突，选 A 保留 / B 合并 / C 旁路 / D 替换。\n'
printf '2. 选 B 时先备份，再在现有文件末尾追加引用段。\n'
printf '3. 补写 README 的一句话与技术栈（若显示"待补写"）。\n'
printf '4. 运行 bash scripts/check.sh <目标>。\n'

if [ "$APPLY" -eq 1 ]; then
  printf '\n## 本次写入\n\n'
  created=0; skipped=0
  for f in $FILES; do
    if [ -e "$ROOT/$f" ]; then skipped=$((skipped+1)); continue; fi
    case "$f" in
      .gitignore) cp "$SKILL_DIR/templates/gitignore.append" "$ROOT/.gitignore" ;;
      env)
        printf 'ENV=%s\nROLE=%s\nROOT=%s\n' "${F_ENV:-unknown}" "${F_ROLE:-authoring}" "$ROOT" > "$ROOT/env"
        chmod_600 "$ROOT/env"
        ;;
      *)
        tmpl=$(tmpl_for "$f")
        if [ -z "$tmpl" ]; then printf 'no template for %s\n' "$f" >&2; exit 1; fi
        render_file "$SKILL_DIR/templates/$tmpl" "$ROOT/$f"
        case "$f" in tools/*) chmod +x "$ROOT/$f" ;; esac
        ;;
    esac
    created=$((created+1))
  done
  printf -- '- created=%d skipped=%d\n' "$created" "$skipped"
fi
