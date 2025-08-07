#!/bin/bash

# Check if argument provided
if [ $# -ne 1 ]; then
	echo "Usage: $0 <git_repo_path>"
	exit 1
fi

REPO_PATH="$1"
ASSETS_DIR="$(dirname "$0")/assets"

# Check if path exists
if [ ! -d "$REPO_PATH" ]; then
	echo "Error: Directory '$REPO_PATH' does not exist"
	exit 1
fi

# Check if it's a git repo
cd "$REPO_PATH" || exit 1
if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo "Error: '$REPO_PATH' is not a git repository"
	exit 1
fi

# Animation frame counter
frame=0

# Function to get mood based on commits
get_mood() {
	# Count commits in last 24 hours
	commits_24h=$(git log --oneline --since="24 hours ago" 2>/dev/null | wc -l | tr -d ' ')

	# Count commits in last hour
	commits_1h=$(git log --oneline --since="1 hour ago" 2>/dev/null | wc -l | tr -d ' ')

	# Determine mood
	if [ "$commits_24h" -eq 0 ]; then
		echo "dead"
		return 0
	elif [ "$commits_24h" -eq 1 ]; then
		echo "sad"
		return 1
	elif [ "$commits_24h" -eq 2 ]; then
		echo "neutral"
		return 2
	elif [ "$commits_24h" -ge 3 ]; then
		# Check if happy but no commits in last hour
		if [ "$commits_1h" -eq 0 ]; then
			echo "neutral"
			return 2
		else
			echo "happy"
			return 3
		fi
	fi
}

# Function to display ASCII art
display_art() {
	local mood="$1"
	local frame_num="$2"

	# Determine which file to use based on frame
	local file_suffix=""
	if [ $((frame_num % 2)) -eq 0 ]; then
		file_suffix=""
	else
		file_suffix="2"
	fi

	local art_file="${ASSETS_DIR}/${mood}${file_suffix}.txt"

	# Check if alternate frame exists, otherwise use base
	if [ ! -f "$art_file" ]; then
		art_file="${ASSETS_DIR}/${mood}.txt"
	fi

	if [ -f "$art_file" ]; then
		cat "$art_file"
	else
		echo "[ASCII art not found: $art_file]"
	fi
}

# Function to get last commit time
get_last_commit() {
	local last_commit=$(git log -1 --format="%ar" 2>/dev/null)
	if [ -z "$last_commit" ]; then
		echo "never"
	else
		echo "$last_commit"
	fi
}

# Function to calculate hunger (time since last commit)
get_hunger_bar() {
	# Get hours since last commit (max 24 for display)
	local last_commit_timestamp=$(git log -1 --format="%at" 2>/dev/null)

	if [ -z "$last_commit_timestamp" ]; then
		# No commits ever
		echo "[##########] 100% hungry"
		return
	fi

	local current_timestamp=$(date +%s)
	local hours_since=$(((current_timestamp - last_commit_timestamp) / 3600))

	# Cap at 24 hours for display
	if [ $hours_since -gt 24 ]; then
		hours_since=24
	fi

	# Calculate percentage (0 hours = 0% hungry, 24 hours = 100% hungry)
	local hunger_percent=$(((hours_since * 100) / 24))

	# Create progress bar (10 chars total)
	local filled=$(((hours_since * 10) / 24))
	local empty=$((10 - filled))

	local bar="["
	for ((i = 0; i < filled; i++)); do
		bar="${bar}#"
	done
	for ((i = 0; i < empty; i++)); do
		bar="${bar}-"
	done
	bar="${bar}]"

	echo "${bar} ${hunger_percent}% hungry (${hours_since}h since last meal)"
}

# Function to get repo name
get_repo_name() {
	basename "$REPO_PATH"
}

# Main loop
while true; do
	# Clear screen
	clear

	# Get current mood
	mood=$(get_mood)

	# Display ASCII art
	display_art "$mood" "$frame"

	# Display info
	echo ""
	echo "================== TAMAGOTCHI STATUS =================="
	echo "Mood:          $mood"
	echo "Repo:          $(get_repo_name)"
	echo "Last commit:   $(get_last_commit)"
	echo "Hungry in:     $(get_hunger_bar)"
	echo "======================================================"
	echo ""
	echo "Press Ctrl+C to exit"

	# Increment frame counter
	frame=$((frame + 1))

	# Wait 1 seconds
	sleep 1
done
