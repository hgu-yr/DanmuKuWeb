#!/usr/bin/env bash
#
# 一键推送到 GitHub（hgu-yr）：两个子模块 + 根 umbrella 仓库。
#
# 用法：
#   ./scripts/push-to-github.sh
#
# 行为：
#   1. 两个子模块必须没有未提交改动（有则中止，提示你先提交），然后 push
#   2. 根仓库自动提交「子模块指针变化」等改动，再 push
#
# 首次推送根仓库前，请先在 GitHub 上创建空的 DanmuKuWeb 仓库（别勾初始化 README）。
#
set -euo pipefail

OWNER="hgu-yr"
ROOT_REPO="DanmuKuWeb"
SUBMODULES=(DanmuKuWeb-Server DanmuKuWeb-Web)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "==> 1/3 检查子模块工作区"
for dir in "${SUBMODULES[@]}"; do
  if [[ -n "$(git -C "${dir}" status --porcelain)" ]]; then
    echo "!! ${dir} 还有未提交的改动，请先提交后再运行本脚本：" >&2
    git -C "${dir}" status -sb | head -20 >&2
    exit 1
  fi
done

echo "==> 2/3 推送子模块"
for dir in "${SUBMODULES[@]}"; do
  echo "    ${dir} -> origin/main"
  git -C "${dir}" push origin main
done

echo "==> 3/3 提交并推送根仓库"
git add -A
if git diff --cached --quiet; then
  echo "    根仓库没有需要提交的改动"
else
  git commit -q -m "chore: update submodule pointers"
  echo "    已提交：$(git log --oneline -1)"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo
  echo "!! 根仓库还没有 origin。请先在 GitHub 上创建空的 ${OWNER}/${ROOT_REPO}，然后：" >&2
  echo "     git remote add origin git@github.com:${OWNER}/${ROOT_REPO}.git" >&2
  echo "     git push -u origin main" >&2
  exit 1
fi

git push origin main
echo
echo "✅ 完成。"
