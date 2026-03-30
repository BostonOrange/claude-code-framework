#!/bin/bash
# Claude Code status line for salesforce-nexus
# 4-line status: model+folder, branch+link, sf org+PR, context bar+cost+duration+changes

input=$(cat)

# Extract fields
model=$(echo "$input" | jq -r '.model.display_name // ""')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Git branch + build full GitHub/ADO branch URL for Warp clickability
git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
remote_url=$(git -C "$cwd" --no-optional-locks remote get-url origin 2>/dev/null)
branch_url=""
if [ -n "$git_branch" ] && [ -n "$remote_url" ]; then
  # Normalize remote URL to HTTPS base (strip .git suffix, convert SSH to HTTPS)
  repo_url=$(echo "$remote_url" | sed -e 's/\.git$//' -e 's|^git@github\.com:|https://github.com/|' -e 's|^git@ssh\.dev\.azure\.com:v3/|https://dev.azure.com/|')
  if echo "$repo_url" | grep -q 'github\.com'; then
    branch_url="${repo_url}/tree/${git_branch}"
  elif echo "$repo_url" | grep -q 'dev\.azure\.com'; then
    branch_url="${repo_url}?version=GB${git_branch}"
  fi
fi

# Salesforce target org
sf_org=$(sf config get target-org --json 2>/dev/null | jq -r '.result[0].value // empty')

# Check for open PR on current branch
pr_url=""
if [ -n "$git_branch" ]; then
  pr_url=$(gh pr view "$git_branch" --json url --jq '.url' -R "$remote_url" 2>/dev/null)
fi

# ANSI colors
RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
BLUE='\033[34m'
DIM='\033[2m'

# Format duration: ms -> Xm Ys
total_secs=$((duration_ms / 1000))
mins=$((total_secs / 60))
secs=$((total_secs % 60))
if [ "$mins" -gt 0 ]; then
  duration_str="${mins}m ${secs}s"
else
  duration_str="${secs}s"
fi

# Format cost
cost_str=$(printf '$%.2f' "$cost")

# --- Line 1: model + folder ---
line1=""
if [ -n "$model" ]; then
  line1="${CYAN}${BOLD}[${model}]${RESET}"
fi
line1="${line1}  📂 ${BOLD}${BLUE}${cwd}${RESET}"

# --- Line 2: branch ---
if [ -n "$git_branch" ]; then
  if [ -n "$branch_url" ]; then
    line2="🌿 ${GREEN}${git_branch}${RESET} 🔗 ${GREEN}${branch_url}${RESET}"
  else
    line2="🌿 ${GREEN}${git_branch}${RESET}"
  fi
else
  line2=""
fi

# --- Line 3: SF org + PR ---
if [ -n "$sf_org" ]; then
  line3="☁️  ${YELLOW}${sf_org}${RESET}"
else
  line3="☁️  ${DIM}no org${RESET}"
fi
if [ -n "$pr_url" ]; then
  line3="${line3}  |  🔀 ${CYAN}${pr_url}${RESET}"
else
  line3="${line3}  |  🔀 ${DIM}no PR${RESET}"
fi

# --- Line 4: context bar, cost, duration, additions/deletions ---
bar_width=20
filled=$((used_pct * bar_width / 100))
empty=$((bar_width - filled))

if [ "$used_pct" -ge 80 ]; then
  BAR_COLOR="${RED}"
elif [ "$used_pct" -ge 50 ]; then
  BAR_COLOR="${YELLOW}"
else
  BAR_COLOR="${GREEN}"
fi

bar="${BAR_COLOR}"
i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i + 1)); done
bar="${bar}${DIM}"
i=0; while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i + 1)); done
bar="${bar}${RESET}"

line4="${bar} ${used_pct}%%"
line4="${line4}  |  💰 ${cost_str}"
line4="${line4}  |  ⏱️  ${duration_str}"
line4="${line4}  |  ${GREEN}+${lines_added}${RESET} ${RED}-${lines_removed}${RESET}"

printf "${line1}\n"
printf "${line2}\n"
printf "${line3}\n"
printf "${line4}\n"
