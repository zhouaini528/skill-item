#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
F="$T/SKILL.md"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
[[ -f "$F" ]] || { bad "SKILL.md 不存在"; exit 1; }
[[ "$(head -1 "$F")" == "---" ]] && ok "frontmatter 开头" || bad "frontmatter 开头"
grep -qx 'name: project-constraints' "$F" && ok "name" || bad "name"
grep -q '^description: ' "$F" && ok "description" || bad "description"
desc=$(grep '^description: ' "$F")
[[ "$desc" != *"init.sh"* && "$desc" != *"adopt.sh"* && "$desc" != *"五步"* ]] && ok "description 不写流程" || bad "description 写流程"
for h in '## 概述' '## 模式判断' '## new 五步' '## adopt 六步' '## 常见错误' '## 自检'; do
  grep -qx "$h" "$F" && ok "标题 $h" || bad "标题 $h"
done
grep -q '<技能目录>/scripts/init.sh' "$F" && ok "init 用技能目录" || bad "init 未用技能目录"
grep -q '<技能目录>/scripts/adopt.sh' "$F" && ok "adopt 用技能目录" || bad "adopt 未用技能目录"
grep -q '<技能目录>/scripts/check.sh' "$F" && ok "check 用技能目录" || bad "check 未用技能目录"
grep -q -- '--env/--role' "$F" && ok "写明 env 参数" || bad "未写 env 参数"
body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$F")
chars=$(printf '%s' "$body" | wc -m)
[[ "$chars" -le 1500 ]] && ok "正文长度 $chars" || bad "正文过长 $chars"
[[ -f "$T/references/conventions.md" ]] && ok "conventions" || bad "conventions"
[[ "$(grep -c '^|' "$T/references/conventions.md" 2>/dev/null || echo 0)" -ge 9 ]] && ok "误区表" || bad "误区表行数"
exit "$fail"
