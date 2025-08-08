#!/usr/bin/env bash

# Tamagot.sh — Git activity tamagotchi
# Requirements: bash (macOS default 3.2+ is fine), git available on PATH

set -u

# --- Helpers ---------------------------------------------------------------

die() {
  printf "%s\n" "$1" >&2
  exit "${2:-1}"
}

show_cursor_and_exit() {
  # Show cursor, reset attributes, and exit
  printf "\e[?25h\e[0m\n"
  exit 0
}

hide_cursor() {
  printf "\e[?25l"
}

clear_and_home() {
  # Move cursor to top-left without full clear to minimize flicker
  printf "\e[H"
}

full_clear() {
  # Clear the screen and move cursor home once at start
  printf "\e[2J\e[H"
}

secs_to_hms() {
  local s=$1
  if [ "$s" -lt 0 ]; then s=0; fi
  local h=$(( s / 3600 ))
  local m=$(( (s % 3600) / 60 ))
  local sec=$(( s % 60 ))
  if [ $h -gt 0 ]; then
    printf "%dh %02dm %02ds" "$h" "$m" "$sec"
  elif [ $m -gt 0 ]; then
    printf "%dm %02ds" "$m" "$sec"
  else
    printf "%ds" "$sec"
  fi
}

repeat_char() {
  # repeat_char "#" 5 -> #####
  local ch=$1
  local n=${2:-0}
  if [ "$n" -le 0 ]; then
    printf ""
    return
  fi
  local i
  for ((i=0; i<n; i++)); do printf "%s" "$ch"; done
}

progress_bar() {
  # progress_bar REMAINING TOTAL WIDTH
  local remaining=$1
  local total=$2
  local width=$3
  if [ "$total" -le 0 ]; then
    repeat_char "-" "$width"
    return
  fi
  if [ "$remaining" -lt 0 ]; then remaining=0; fi
  if [ "$remaining" -gt "$total" ]; then remaining=$total; fi
  # Filled represents time remaining
  local filled=$(( (remaining * width) / total ))
  local empty=$(( width - filled ))
  repeat_char "#" "$filled"
  repeat_char "-" "$empty"
}

string_length() {
  # Best-effort display width using character count (unicode width may vary)
  # Usage: len=$(string_length "$str")
  local s="$1"
  printf "%s" "$s" | awk '{print length}'
}

file_max_line_length() {
  awk '{ if (length>max) max=length } END{ print max+0 }' "$1"
}

file_line_count() {
  awk 'END{ print NR+0 }' "$1"
}

gather_frames() {
  # Print absolute paths to frames for a prefix (dead|sad|neutral|happy), sorted unique
  local prefix=$1
  local dir=$2
  local list=()
  shopt -s nullglob
  list+=( "$dir/${prefix}.txt" )
  list+=( "$dir/${prefix}2.txt" )
  list+=( "$dir/${prefix}_1.txt" )
  list+=( "$dir/${prefix}_2.txt" )
  list+=( "$dir/${prefix}"*.txt )
  shopt -u nullglob
  if [ ${#list[@]} -gt 0 ]; then
    printf '%s\n' "${list[@]}" | awk 'NF' | sort -u
  fi
}

center_and_print_frame() {
  # center_and_print_frame FILE MAX_W MAX_H LEFT_PAD
  local file=$1
  local max_w=$2
  local max_h=$3
  local left_screen_pad=${4:-0}

  local h
  h=$(file_line_count "$file")
  local top_pad=$(( (max_h - h) / 2 ))
  local bottom_pad=$(( max_h - h - top_pad ))

  local i line
  # Top padding lines (fill padded space and clear to end of line)
  for ((i=0; i<top_pad; i++)); do
    repeat_char " " "$left_screen_pad"
    repeat_char " " "$max_w"
    printf "\e[K\n"
  done

  # File content centered by line
  # Preserve leading/trailing spaces and unicode chars
  while IFS='' read -r line || [ -n "$line" ]; do
    # Compute per-line left pad
    local ll
    ll=$(string_length "$line")
    local lp=$(( (max_w - ll) / 2 ))
    local rp=$(( max_w - ll - lp ))
    repeat_char " " "$left_screen_pad"
    repeat_char " " "$lp"
    printf "%s" "$line"
    repeat_char " " "$rp"
    printf "\e[K\n"
  done < "$file"

  # Bottom padding lines (fill padded space and clear to end of line)
  for ((i=0; i<bottom_pad; i++)); do
    repeat_char " " "$left_screen_pad"
    repeat_char " " "$max_w"
    printf "\e[K\n"
  done
}

# --- Argument & Setup ------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets"

[ -d "$ASSETS_DIR" ] || die "Assets directory not found at $ASSETS_DIR"

REPO_PATH=${1:-}
[ -n "$REPO_PATH" ] || die "Usage: tamagot.sh /path/to/git/repo"

if ! git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "Error: $REPO_PATH is not a git repository."
fi

# Pre-calc maximum frame width/height across all assets
MAX_W=0
MAX_H=0
shopt -s nullglob
for f in "$ASSETS_DIR"/*.txt; do
  [ -f "$f" ] || continue
  fw=$(file_max_line_length "$f")
  fh=$(file_line_count "$f")
  if [ "$fw" -gt "$MAX_W" ]; then MAX_W=$fw; fi
  if [ "$fh" -gt "$MAX_H" ]; then MAX_H=$fh; fi
done
shopt -u nullglob

[ "$MAX_W" -gt 0 ] || die "No frames found in assets."

# Gather frames per mood
mapfile_compat() {
  # Bash 3 compatibility for capturing function stdout into an array
  local __out="$1"; shift
  local __data
  __data=$("$@")
  eval "$__out=(\$__data)"
}

readarray_fallback() {
  # Fills the named array var with lines from stdin
  # Usage: readarray_fallback arr <<< "lines..."
  local __arr_name=$1
  local __line
  local __buffer=()
  while IFS= read -r __line; do __buffer+=("$__line"); done
  eval "$__arr_name=(\"\${__buffer[@]}\")"
}

dead_list=$(gather_frames dead "$ASSETS_DIR")
sad_list=$(gather_frames sad "$ASSETS_DIR")
neutral_list=$(gather_frames neutral "$ASSETS_DIR")
happy_list=$(gather_frames happy "$ASSETS_DIR")

dead_frames=(); readarray_fallback dead_frames <<< "$dead_list"
sad_frames=(); readarray_fallback sad_frames <<< "$sad_list"
neutral_frames=(); readarray_fallback neutral_frames <<< "$neutral_list"
happy_frames=(); readarray_fallback happy_frames <<< "$happy_list"

# Fallback if some arrays are empty: at least try to use any available
if [ ${#dead_frames[@]} -eq 0 ]; then dead_frames=("$ASSETS_DIR/dead.txt"); fi
if [ ${#sad_frames[@]} -eq 0 ]; then sad_frames=("$ASSETS_DIR/sad.txt"); fi
if [ ${#neutral_frames[@]} -eq 0 ]; then neutral_frames=("$ASSETS_DIR/neutral.txt"); fi
if [ ${#happy_frames[@]} -eq 0 ]; then happy_frames=("$ASSETS_DIR/happy.txt"); fi

# --- Main Loop -------------------------------------------------------------

trap show_cursor_and_exit INT TERM
full_clear
hide_cursor

while :; do
  clear_and_home

  # Calculate mood based on commits
  commits_24h=$(git -C "$REPO_PATH" rev-list --count --since='24 hours ago' HEAD 2>/dev/null || printf "0")
  commits_1h=$(git -C "$REPO_PATH" rev-list --count --since='1 hour ago' HEAD 2>/dev/null || printf "0")

  # Determine mood level and name
  mood_level=0
  mood_name="dead"
  if [ "$commits_24h" -eq 0 ]; then
    mood_level=0; mood_name="dead"
  elif [ "$commits_24h" -eq 1 ]; then
    mood_level=1; mood_name="sad"
  elif [ "$commits_24h" -eq 2 ]; then
    mood_level=2; mood_name="neutral"
  else
    # >=3 in 24h
    if [ "$commits_1h" -eq 0 ]; then
      mood_level=2; mood_name="neutral"  # curveball cap
    else
      mood_level=3; mood_name="happy"
    fi
  fi

  # Select frames per mood
  frames=( )
  case "$mood_name" in
    dead) frames=("${dead_frames[@]}") ;;
    sad) frames=("${sad_frames[@]}") ;;
    neutral) frames=("${neutral_frames[@]}") ;;
    happy) frames=("${happy_frames[@]}") ;;
  esac
  nframes=${#frames[@]}
  if [ "$nframes" -eq 0 ]; then
    printf "No frames for mood '%s'\n" "$mood_name"
    sleep 1
    continue
  fi

  # Frame index based on epoch seconds to ensure a change every second
  now_epoch=$(date +%s)
  frame_idx=$(( now_epoch % nframes ))
  frame_file="${frames[$frame_idx]}"

  # Optionally center the entire block horizontally in terminal
  term_cols=$(tput cols 2>/dev/null || echo 80)
  total_width=$MAX_W
  left_pad=0
  if [ "$term_cols" -gt "$total_width" ]; then
    left_pad=$(( (term_cols - total_width) / 2 ))
  fi

  # Render centered frame
  center_and_print_frame "$frame_file" "$MAX_W" "$MAX_H" "$left_pad"

  # Info lines under the frame
  last_commit_rel=$(git -C "$REPO_PATH" log -1 --format=%cr 2>/dev/null || echo "No commits yet")
  last_commit_ts=$(git -C "$REPO_PATH" log -1 --format=%ct 2>/dev/null || echo 0)
  if [ -z "$last_commit_rel" ]; then last_commit_rel="No commits yet"; fi
  if [ -z "$last_commit_ts" ]; then last_commit_ts=0; fi

  # Hungry in: time until 1 hour since last commit, if last commit < 1h ago, else 0
  hungry_total=3600
  hungry_remaining=0
  if [ "$last_commit_ts" -gt 0 ]; then
    since_last=$(( now_epoch - last_commit_ts ))
    if [ "$since_last" -lt "$hungry_total" ]; then
      hungry_remaining=$(( hungry_total - since_last ))
    else
      hungry_remaining=0
    fi
  else
    hungry_remaining=0
  fi

  bar_width=30
  bar=$(progress_bar "$hungry_remaining" "$hungry_total" "$bar_width")

  # Print info lines, padded left to align with frame
  repeat_char " " "$left_pad"; printf "================================================\n"
  repeat_char " " "$left_pad"; printf "Mood: %s\e[K\n" "$mood_name"
  repeat_char " " "$left_pad"; printf "Repo: %s\e[K\n" "$REPO_PATH"
  repeat_char " " "$left_pad"; printf "Last committed: %s\e[K\n" "$last_commit_rel"
  repeat_char " " "$left_pad"; printf "Hungry in: [%s] %s\e[K\n" "$bar" "$(secs_to_hms "$hungry_remaining")"
  repeat_char " " "$left_pad"; printf "================================================"

  # Sleep ~1s before next refresh
  sleep 1
done


