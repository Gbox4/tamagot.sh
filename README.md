# tamagot.sh

A terminal-based Tamagotchi that lives off your git commits.

## Usage

```bash
./tamagot.sh /path/to/your/git/repo
```

## How it works

Your Tamagotchi's mood depends on your commit activity:
- **Dead**: No commits in 24 hours
- **Sad**: 1 commit in 24 hours  
- **Neutral**: 2 commits in 24 hours
- **Happy**: 3+ commits in 24 hours (with recent activity)

The hunger bar starts full after each commit and depletes over 1 hour. Feed your Tamagotchi by making commits.

## Requirements

- Bash
- Git
- A git repository to monitor

## Controls

Press `Ctrl+C` to exit.
