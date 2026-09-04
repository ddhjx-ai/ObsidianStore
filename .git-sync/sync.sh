#!/usr/bin/env bash
# Obsidian 仓库自动同步脚本（WorkBuddy 定时任务调用）
# 用途：检测本地笔记改动 -> 提交 -> 拉取远端 -> 推送到 GitHub
set -uo pipefail

VAULT="D:/ObsidianStore"
BRANCH="main"

cd "$VAULT" || { echo "错误：仓库目录不存在 $VAULT"; exit 1; }

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { log "错误：$VAULT 不是 Git 仓库"; exit 1; }

# 无改动直接退出，不产生空 commit
if [ -z "$(git status --porcelain)" ]; then
  log "没有检测到改动，跳过同步"
  exit 0
fi

CHANGED=$(git status --porcelain | wc -l | tr -d ' ')
log "检测到 $CHANGED 处改动，开始提交"

git add -A
if ! git commit -m "chore(notes): 自动同步 $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1; then
  log "错误：提交失败"
  exit 1
fi

# 先拉后推，--autostash 自动收起未提交内容，--rebase 保持线性历史
log "拉取远端最新内容"
if ! git pull --rebase --autostash origin "$BRANCH" >/dev/null 2>&1; then
  log "警告：变基出现冲突，已中止，请手动处理"
  git rebase --abort 2>/dev/null
  exit 1
fi

log "推送到 GitHub"
if git push origin "$BRANCH" >/dev/null 2>&1; then
  log "同步完成，共 $CHANGED 处改动已上传"
else
  log "错误：推送失败，请检查网络或 SSH 认证"
  exit 1
fi
