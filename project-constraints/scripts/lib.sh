#!/usr/bin/env bash
# 共用函数：渲染、权限、追加。由 init.sh 与 adopt.sh source。

esc() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

render_file() {
  local tmpl=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  sed -e "s|{{PROJECT_NAME}}|$(esc "$PROJECT_NAME")|g" \
      -e "s|{{ONE_LINER}}|$(esc "$ONE_LINER")|g" \
      -e "s|{{STACK}}|$(esc "$STACK")|g" \
      -e "s|{{DATE}}|$(esc "$DATE")|g" \
      "$tmpl" > "$dest"
}

ensure_dir() { mkdir -p "$1"; }
chmod_600() { chmod 600 "$1"; }
chmod_exec() { chmod +x "$@"; }

append_gitignore() {
  local target=$1 file=$2 line
  touch "$target/.gitignore"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    grep -qxF "$line" "$target/.gitignore" || printf '%s\n' "$line" >> "$target/.gitignore"
  done < "$file"
}

echo_item() { printf '  %s\n' "$1"; }
tmpl_for() {
  case "$1" in
    AGENTS.md) printf 'AGENTS.md.tmpl' ;;
    ENVIRONMENTS.md) printf 'ENVIRONMENTS.md.tmpl' ;;
    STATUS.md) printf 'STATUS.md.tmpl' ;;
    README.md) printf 'README.md.tmpl' ;;
    env.example) printf 'env.example' ;;
    docs/spec/README.md) printf 'docs/spec/README.md.tmpl' ;;
    docs/spec/00-overview.md) printf 'docs/spec/00-overview.md.tmpl' ;;
    docs/decisions/README.md) printf 'docs/decisions/README.md.tmpl' ;;
    docs/decisions/D-001.md) printf 'docs/decisions/D-001.md.tmpl' ;;
    docs/evidence/README.md) printf 'docs/evidence/README.md.tmpl' ;;
    docs/ops/README.md) printf 'docs/ops/README.md.tmpl' ;;
    tools/env.sh) printf 'tools/env.sh.tmpl' ;;
    tools/check-links.sh) printf 'tools/check-links.sh.tmpl' ;;
    *) printf '' ;;
  esac
}
