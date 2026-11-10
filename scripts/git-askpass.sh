#!/bin/sh
#
# Git askpass helper：从环境变量读取凭据，避免把 token 拼进 URL / 命令行。
# 用法：
#   GIT_ASKPASS=/path/to/git-askpass.sh GIT_TERMINAL_PROMPT=0 git <command>
# 环境变量：
#   GITEE_USER    用户名，默认 yr007
#   MIRROR_TOKEN  子模块镜像/主仓库只读凭据（CI 使用）
#   GITEE_TOKEN   本地推送脚本使用的 Gitee 令牌（优先于 MIRROR_TOKEN）
case "$1" in
  *Username*)
    printf '%s\n' "${GITEE_USER:-yr007}"
    ;;
  *Password*)
    printf '%s\n' "${GITEE_TOKEN:-${MIRROR_TOKEN:-}}"
    ;;
esac
