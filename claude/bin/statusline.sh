#!/usr/bin/env bash
# Claude Code status line script
# ~/.claude/bin/statusline.sh
#
# settings.json への追加方法:
#   "statusLine": {
#     "type": "command",
#     "command": "bash ~/.claude/bin/statusline.sh"
#   }

input=$(cat)

# --- JSON から各値を取得 ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"')

# コスト・時間情報（直接取得）
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
total_api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# コンテキスト情報
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cur_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- effortLevel を settings.json から動的取得 ---
effort_level=$(jq -r '.effortLevel // "unknown"' ~/.claude/settings.json 2>/dev/null || echo "unknown")

# --- 作業フォルダ名（basename） ---
folder=$(basename "$cwd")

# --- 経過時間の計算 ---
elapsed_sec=$(( total_duration_ms / 1000 ))
elapsed_h=$(( elapsed_sec / 3600 ))
elapsed_m=$(( (elapsed_sec % 3600) / 60 ))
elapsed_s=$(( elapsed_sec % 60 ))
if [ "$elapsed_h" -gt 0 ]; then
  elapsed_str=$(printf "%dh%02dm%02ds" "$elapsed_h" "$elapsed_m" "$elapsed_s")
else
  elapsed_str=$(printf "%dm%02ds" "$elapsed_m" "$elapsed_s")
fi

# --- API% の計算 ---
if [ "$total_duration_ms" -gt 0 ] 2>/dev/null; then
  api_pct=$(awk "BEGIN { printf \"%.0f\", ($total_api_duration_ms / $total_duration_ms * 100) }")
else
  api_pct=0
fi

# --- コスト（直接取得、小数4桁） ---
cost=$(awk "BEGIN { printf \"%.4f\", $total_cost }")

# --- モデル別単価ラベル (per million tokens) ---
model_lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')
if echo "$model_lower" | grep -q "opus"; then
  price_in=15; price_out=75
elif echo "$model_lower" | grep -q "haiku"; then
  price_in=0.80; price_out=4
else
  price_in=3; price_out=15
fi

# --- ANSI カラー定義 ---
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[90m"
WHITE="\033[37m"
CYAN="\033[36m"
YELLOW="\033[33m"
BLUE="\033[34m"
GREEN="\033[32m"
RED="\033[31m"
MAGENTA="\033[35m"

# --- Line 1: セッション情報 ---
printf "${DIM}dir:${RESET}${BOLD}${WHITE}%s${RESET}" "$folder"
printf "  ${DIM}model:${RESET}${CYAN}%s${RESET}" "$model"
printf "  ${DIM}Effort:${RESET}${YELLOW}%s${RESET}" "$effort_level"
printf "  ${DIM}cost:${RESET}${GREEN}\$%s${RESET}${DIM} (in:\$%s/out:\$%s)${RESET}" "$cost" "$price_in" "$price_out"
printf "  ${DIM}elapsed:${RESET}${WHITE}%s${RESET}${DIM} (API:%s%%)${RESET}" "$elapsed_str" "$api_pct"
printf "\n"

# --- Line 2: コンテキスト使用率バー ---
if [ -n "$used_pct" ]; then
  pct_int=$(printf "%.0f" "$used_pct")
  if [ "$pct_int" -lt 50 ]; then
    bar_color=$GREEN
  elif [ "$pct_int" -lt 80 ]; then
    bar_color=$YELLOW
  else
    bar_color=$RED
  fi
  bar_width=20
  filled=$(( pct_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))
  bar_filled=$(printf '%0.s#' $(seq 1 $filled) 2>/dev/null || printf '%*s' "$filled" '' | tr ' ' '#')
  bar_empty=$(printf '%*s' "$empty" '' | tr ' ' '-')
  printf "${DIM}ctx${RESET} ${bar_color}[%s%s]${RESET} ${BOLD}%s%%${RESET}" \
    "$bar_filled" "$bar_empty" "$pct_int"
else
  printf "${DIM}ctx${RESET} ${DIM}[--------------------]${RESET} ${DIM}--%${RESET}"
fi

# IN/OUT トークン数
printf "  ${DIM}IN${RESET}:${BLUE}%s${RESET}  ${DIM}OUT${RESET}:${MAGENTA}%s${RESET}" \
  "$total_input" "$total_output"

# キャッシュヒット率（直近ターン）
if [ "$cur_input" -gt 0 ] 2>/dev/null; then
  cache_total=$(( cur_input + cur_cache_read ))
  if [ "$cache_total" -gt 0 ]; then
    cache_pct=$(awk "BEGIN { printf \"%.0f\", ($cur_cache_read / $cache_total * 100) }")
    printf "  ${DIM}cache${RESET}:${CYAN}%s%%${RESET}" "$cache_pct"
  fi
fi
printf "\n"

# --- Line 3-4: サブスク使用率 ---
if [ -n "$five_pct" ]; then
  five_int=$(printf "%.0f" "$five_pct")
  if [ "$five_int" -lt 50 ]; then five_color=$GREEN
  elif [ "$five_int" -lt 80 ]; then five_color=$YELLOW
  else five_color=$RED; fi
  printf "${DIM}ses${RESET} ${five_color}%s%%${RESET}" "$five_int"
  if [ -n "$five_resets" ]; then
    resets_in=$(( five_resets - $(date +%s) ))
    if [ "$resets_in" -gt 0 ]; then
      resets_min=$(( resets_in / 60 ))
      printf " ${DIM}(resets in %dm)${RESET}" "$resets_min"
    fi
  fi
  printf "\n"
fi

if [ -n "$week_pct" ]; then
  week_int=$(printf "%.0f" "$week_pct")
  if [ "$week_int" -lt 50 ]; then week_color=$GREEN
  elif [ "$week_int" -lt 80 ]; then week_color=$YELLOW
  else week_color=$RED; fi
  printf "${DIM}wk${RESET}  ${week_color}%s%%${RESET}" "$week_int"
  if [ -n "$week_resets" ]; then
    resets_in=$(( week_resets - $(date +%s) ))
    if [ "$resets_in" -gt 0 ]; then
      resets_days=$(( resets_in / 86400 ))
      resets_hrs=$(( (resets_in % 86400) / 3600 ))
      printf " ${DIM}(resets in %dd %dh)${RESET}" "$resets_days" "$resets_hrs"
    fi
  fi
  printf "\n"
fi

# --- 最終行: git 情報（branch / diff）---
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  printf "${DIM}branch:${RESET}${CYAN}%s${RESET}" "${branch:-detached}"

  # diff統計はJSONから直接取得
  if [ "${lines_added:-0}" -gt 0 ] || [ "${lines_removed:-0}" -gt 0 ] 2>/dev/null; then
    delta=$(( lines_added - lines_removed ))
    if [ "$delta" -ge 0 ]; then
      delta_str="+${delta}"
      delta_color=$GREEN
    else
      delta_str="${delta}"
      delta_color=$RED
    fi
    printf "  ${DIM}diff:${RESET} ${GREEN}+%s${RESET} ${RED}-%s${RESET} ${DIM}(Δ${RESET}${delta_color}%s${RESET}${DIM})${RESET}" \
      "$lines_added" "$lines_removed" "$delta_str"
  fi
  printf "\n"
fi
