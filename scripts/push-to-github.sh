#!/usr/bin/env bash
#
# 一键推送到 GitHub（hgu-yr）：两个子模块 + 根 umbrella 仓库。
#
# 用法：
#   ./scripts/push-to-github.sh
#
# 行为：
#   1. 两个子模块必须没有未提交改动（有则中止，提示你先提交），然后各自推送「当前分支」
#   2. 推送后自动把远端 main 合并进当前分支，再把当前分支推成远端 main
#   3. 根仓库自动提交「子模块指针变化」等改动，同样推送当前分支并合并到 main
#
# 注意：合并的是远端 main，本地主工作区里检出的 main 不会自动更新；
# 需要时在主工作区执行 git pull --ff-only 即可。
#
# 首次推送根仓库前，请先在 GitHub 上创建空的 DanmuKuWeb 仓库（别勾初始化 README）。

set -euo pipefail

OWNER="hgu-yr"
ROOT_REPO="DanmuKuWeb"
SUBMODULES=(DanmuKuWeb-Server DanmuKuWeb-Web)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# 当前分支名；detached HEAD 无法安全推送，直接中止
current_branch() {
  local dir="$1"
  local branch
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" == "HEAD" ]]; then
    echo "!! $(basename "$dir") 处于 detached HEAD，请先切到开发分支" >&2
    exit 1
  fi
  printf '%s' "$branch"
}

# 推送当前分支；把远端 main 合进来（保证可快进），再推送当前分支到 main。
# 全程不切换本地分支，因此可以在任意 worktree 里安全执行。
push_branch_and_main() {
  local dir="$1"
  local label="$2"
  local branch
  branch="$(current_branch "$dir")"

  echo "    ${label}: push ${branch} -> origin/${branch}"
  git -C "$dir" push -u origin "$branch"

  echo "    ${label}: merge origin/main -> ${branch}"
  if git -C "$dir" fetch origin main >/dev/null 2>&1; then
    if git -C "$dir" rev-parse --verify --quiet refs/remotes/origin/main >/dev/null; then
      if ! git -C "$dir" merge --no-edit origin/main; then
        echo "!! ${label} 合并 origin/main 时冲突，请解决后再运行本脚本" >&2
        exit 1
      fi
      # 合并可能带出新提交（例如远端 main 上有别人的改动），同步推一次当前分支
      git -C "$dir" push origin "$branch"
    fi
  fi

  if [[ "$branch" != "main" ]]; then
    echo "    ${label}: merge ${branch} -> origin/main"
    git -C "$dir" push origin "${branch}:main"
  fi
}

echo "==> 1/3 检查子模块工作区"
for dir in "${SUBMODULES[@]}"; do
  if [[ -n "$(git -C "${dir}" status --porcelain)" ]]; then
    echo "!! ${dir} 还有未提交的改动，请先提交后再运行本脚本：" >&2
    git -C "${dir}" status -sb | head -20 >&2
    exit 1
  fi
done

echo "==> 2/3 推送子模块（当前分支 -> 同名远端分支 -> main）"
for dir in "${SUBMODULES[@]}"; do
  push_branch_and_main "${dir}" "${dir}"
done

echo "==> 3/3 提交并推送根仓库（当前分支 -> 同名远端分支 -> main）"
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

push_branch_and_main "${ROOT_DIR}" "${ROOT_REPO}"
echo
echo "✅ 完成：$(current_branch "${ROOT_DIR}") 已推送，origin/main 已同步。"
