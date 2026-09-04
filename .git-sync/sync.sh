#!/usr/bin/env bash
# Obsidian 仓库自动同步脚本（WorkBuddy 定时任务调用）
# 流程：提交本地改动 -> 拉取远端 -> 推送到 GitHub
set -uo pipefail

VAULT="D:/ObsidianStore"
BRANCH="main"
REMOTE="origin"

cd "$VAULT" || { echo "错误：仓库目录不存在 $VAULT"; exit 1; }

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { log "错误：$VAULT 不是 Git 仓库"; exit 1; }

# 1. 有未提交改动就先提交
if [ -n "$(git status --porcelain)" ]; then
  CHANGED=$(git status --porcelain | wc -l | tr -d ' ')
  log "检测到 $CHANGED 处改动，提交中"
  git add -A
  if ! git commit -m "chore(notes): 自动同步 $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1; then
    log "错误：提交失败"
    exit 1
  fi
else
  log "工作区无未提交改动"
fi

# 2. 拉取远端最新（远端分支不存在则跳过，属于首次推送场景）
if git rev-parse --verify --quiet "$REMOTE/$BRANCH" >/dev/null 2>&1; then
  log "拉取远端最新内容"
  if ! git pull --rebase --autostash "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
    git rebase --abort 2>/dev/null
    log "错误：变基出现冲突，已中止，请手动处理"
    exit 1
  fi
fi

# 3. 只要本地领先远端就推送（含上次推送失败堆积的提交）
if git rev-parse --verify --quiet "$REMOTE/$BRANCH" >/dev/null 2>&1; then
  AHEAD=$(git rev-list --count "$REMOTE/$BRANCH..HEAD")
else
  AHEAD=1
fi

if [ "$AHEAD" -eq 0 ]; then
  log "本地与远端一致，无需推送"
  exit 0
fi

log "本地领先 $AHEAD 个提交，推送到 GitHub"
if git push "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
  log "同步完成"
else
  log "错误：推送失败，请检查网络或 SSH 认证"
  exit 1
fi
