#!/usr/bin/env bash
#
# 校验文档里提到的 DANMAKU_* 环境变量都出现在 DanmuKuWeb-Server/.env.example。
#
# 约定：变量名在文档中用反引号包裹（`DANMAKU_XXX`），脚本只匹配这种形式，
# 避免「不要配置 `DANMAKU_FOO`」这类历史/反面说明被当成必须存在的变量。
# 扫描仓库内所有 markdown（含子模块 README），跳过依赖与构建产物目录。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT/README.md"
ENV_EXAMPLE="$ROOT/DanmuKuWeb-Server/.env.example"

for f in "$README" "$ENV_EXAMPLE"; do
  if [ ! -f "$f" ]; then
    echo "缺少文件：$f（子模块是否已初始化？）" >&2
    exit 1
  fi
done

doc_vars="$(
  find "$ROOT" -name '*.md' \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/coverage/*' \
    -not -path '*/vendor/*' \
    -not -path '*/target/*' \
    -not -path '*/.venv/*' \
    -not -path '*/.git/*' \
    -print0 |
    xargs -0 perl -ne 'while (/`(DANMAKU_[A-Z0-9_]+)`/g) { print "$1\n" }' |
    sort -u
)"
env_vars="$(grep -oE '^DANMAKU_[A-Z0-9_]+' "$ENV_EXAMPLE" | sort -u || true)"

missing="$(comm -23 <(printf '%s\n' "$doc_vars") <(printf '%s\n' "$env_vars") | sed '/^$/d')"

if [ -n "$missing" ]; then
  echo "文档提到但 .env.example 缺少的环境变量："
  echo "$missing" | sed 's/^/  - /'
  exit 1
fi

echo "文档与 .env.example 的 DANMAKU_* 变量一致"
