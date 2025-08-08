#!/bin/bash

# Function to clear terminal and reset cursor to upper left
clear_and_home() {
	printf "\033[2J\033[H"
}

# Function to hide cursor
hide_cursor() {
	printf "\033[?25l"
}

# Function to show cursor
show_cursor() {
	printf "\033[?25h"
}

# Function to print frame from file with 31 rows and 61 cols
print_frame() {
	local filepath="$1"

	# Save cursor position
	printf "\033[s"

	# Read file into array if it exists
	local lines=()
	if [ -f "$filepath" ]; then
		while IFS= read -r line; do
			lines+=("$line")
		done <"$filepath"
	fi

	# Print frame by positioning cursor for each line
	for i in {1..31}; do
		# Move cursor to beginning of line i
		printf "\033[${i};1H"

		# Get the line from file (array is 0-indexed, display is 1-indexed)
		local line_index=$((i - 1))
		local line=""
		if [ $line_index -lt ${#lines[@]} ]; then
			line="${lines[$line_index]}"
		fi

		# Print the line content (it will naturally be truncated by terminal width)
		if [ -n "$line" ]; then
			printf "%s" "$line"
			# Calculate visual width and pad if needed
			local line_length=${#line}
			if [ $line_length -lt 61 ]; then
				printf "%*s" $((61 - line_length)) ""
			fi
		else
			# Print 61 spaces for empty lines
			printf "%61s" ""
		fi
	done

	# Print status after frame
	# Position cursor below the frame (line 32)
	printf "\033[32;1H"

	# Print dividing line
	printf "═════════════════════════════════════════════════════════════════════════════\n"

	# Get commit counts for display
	local commits_24h=$(cd "$REPO_PATH" && git log --since="24 hours ago" --oneline 2>/dev/null | wc -l | tr -d ' ')

	# Get last commit time
	local last_commit=$(cd "$REPO_PATH" && git log -1 --format="%ar" 2>/dev/null)
	if [ -z "$last_commit" ]; then
		last_commit="never"
	fi

	# Get happiness level
	local happiness=$(calculate_happiness "$REPO_PATH")

	# Calculate time until hungry (1 hour since last commit)
	local minutes_since_commit=0
	if [ "$last_commit" != "never" ]; then
		# Get timestamp of last commit
		local last_commit_timestamp=$(cd "$REPO_PATH" && git log -1 --format="%at" 2>/dev/null)
		local current_timestamp=$(date +%s)
		local seconds_since=$((current_timestamp - last_commit_timestamp))
		minutes_since_commit=$((seconds_since / 60))
	fi

	# Calculate minutes remaining until hungry (60 minutes = hungry)
	local hungry_in_minutes=$((60 - minutes_since_commit))
	if [ $hungry_in_minutes -lt 0 ]; then
		hungry_in_minutes=0
	fi

	# Create braille progress bar (60 minutes = 12 segments, 5 minutes each)
	# Bar starts full and depletes
	local segments_empty=$((minutes_since_commit / 5))
	if [ $segments_empty -gt 12 ]; then
		segments_empty=12
	fi
	local segments_filled=$((12 - segments_empty))

	local progress_bar=""
	for i in {1..12}; do
		if [ $i -le $segments_filled ]; then
			progress_bar="${progress_bar}⣿"
		else
			progress_bar="${progress_bar}⣀"
		fi
	done

	# Format time display
	local time_display
	if [ $hungry_in_minutes -ge 60 ]; then
		time_display="1h"
	elif [ $hungry_in_minutes -gt 0 ]; then
		time_display="${hungry_in_minutes}m"
	else
		time_display="0m"
	fi

	# Print status lines with padding to 61 columns
	printf "Repo: %-55s\n" "$(basename "$REPO_PATH")"
	printf "Mood: %-55s\n" "$happiness"
	printf "Commits (24h): %-46d\n" "$commits_24h"
	printf "Last committed: %-45s\n" "$last_commit"
	printf "Hunger: %s %-40s\n" "$progress_bar" "$time_display"

	# Restore cursor position
	printf "\033[u"
}

# Cleanup function to restore cursor on exit
cleanup() {
	show_cursor
	clear_and_home
	exit 0
}

# Set trap to handle Ctrl+C and restore cursor
trap cleanup INT TERM

# Validate script arguments
if [ $# -ne 1 ]; then
	echo "Usage: $0 <git-repository-path>"
	exit 1
fi

# Check if the provided path is a git repository
if [ ! -d "$1/.git" ]; then
	echo "Error: '$1' is not a git repository"
	exit 1
fi

# Store the git repo path
REPO_PATH="$1"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Frame counter for toggling
FRAME_COUNT=0

# Function to calculate happiness level based on commits
calculate_happiness() {
	local repo_path="$1"

	# Get commits in last 24 hours
	local commits_24h=$(cd "$repo_path" && git log --since="24 hours ago" --oneline 2>/dev/null | wc -l | tr -d ' ')

	# Get commits in last hour
	local commits_1h=$(cd "$repo_path" && git log --since="1 hour ago" --oneline 2>/dev/null | wc -l | tr -d ' ')

	# Determine happiness level
	local happiness_level
	if [ "$commits_24h" -eq 0 ]; then
		happiness_level="dead"
	elif [ "$commits_24h" -eq 1 ]; then
		happiness_level="sad"
	elif [ "$commits_24h" -eq 2 ]; then
		happiness_level="neutral"
	else
		# 3 or more commits
		if [ "$commits_1h" -eq 0 ]; then
			# Curveball: if happy but no commits in last hour, max out at neutral
			happiness_level="neutral"
		else
			happiness_level="happy"
		fi
	fi

	echo "$happiness_level"
}

# Function to get asset files based on happiness
get_asset_files() {
	local happiness="$1"
	local frame_num="$2"

	# Determine which file to use (1 or 2) based on frame
	local file_suffix
	if [ $((frame_num % 2)) -eq 0 ]; then
		file_suffix=""
	else
		file_suffix="2"
	fi

	echo "$SCRIPT_DIR/assets/${happiness}${file_suffix}.txt"
}

# Hide cursor at start
hide_cursor

# Clear screen once at the beginning
clear_and_home

# Main loop - refresh every second
while true; do
	# Calculate current happiness level
	HAPPINESS=$(calculate_happiness "$REPO_PATH")

	# Get the appropriate asset file for this frame
	ASSET_FILE=$(get_asset_files "$HAPPINESS" "$FRAME_COUNT")

	# Store in DEFAULT_ASSET for status display
	DEFAULT_ASSET="$ASSET_FILE"

	print_frame "$ASSET_FILE"

	# Increment frame counter
	FRAME_COUNT=$((FRAME_COUNT + 1))

	sleep 1
done
