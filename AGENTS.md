# AGENTS.md - Google Meet Global Mute Button

## Project Overview

A global keyboard shortcut utility for macOS that toggles mute in ALL Google Meet tabs across Arc and Google Chrome browser windows, regardless of which application is currently focused.

**Status:** Complete and working.

## How It Works

1. **Karabiner-Elements** intercepts F5 (dictation key) and runs `~/.local/bin/toggle-meet-mute.sh`
2. The script detects which browsers are running (Arc and/or Chrome)
3. Bulk-fetches all tab URLs per browser window (fast)
4. Finds Meet tabs by URL, then targets them by index
5. Dispatches `Cmd+D` keyboard event via JavaScript to toggle mute
6. Plays a sound to indicate the new mute state (Morse=muted, Pop=unmuted, Basso=error)

## Supported Browsers

| Browser | Support | Setup Required |
|---------|---------|----------------|
| Arc | Full | None |
| Google Chrome | Full | Enable "Allow JavaScript from Apple Events" in View > Developer menu |

## Project Structure

```
google-meet-mute-btn/
├── install.sh              # Creates toggle script, adds Karabiner rule
├── uninstall.sh            # Removes toggle script and Karabiner rule
├── PLAN.md                 # Implementation plan and architecture
├── RESEARCH.md             # Technical research notes (including Arc bugs)
├── TODO.md                 # Implementation checklist (complete)
├── AGENTS.md               # This file - project context for AI agents
├── FUTURE.md               # Future enhancement ideas
└── tasks/
    ├── prd-*.md            # Product requirements document
    └── ralph-tasks.md      # Task breakdown for implementation
```

## Key Files (Installed)

| Location | Purpose |
|----------|---------|
| `~/.local/bin/toggle-meet-mute.sh` | Main toggle script (handles both Arc and Chrome) |
| `~/.config/karabiner/karabiner.json` | Karabiner config with F5 → script binding |

## Technology Stack

- **Karabiner-Elements** - Global keyboard shortcut handling
- **AppleScript** - Browser automation via `osascript`
- **JavaScript** - Injected into Google Meet tabs to trigger mute (Cmd+D)
- **Shell scripting (bash)** - Wrapper for install/uninstall

## Critical Technical Discovery

Arc's AppleScript has a bug where iterating tabs directly is slow and unreliable. The solution:

```applescript
-- WORKS: Bulk-fetch URLs, then target by index
set allURLs to URL of every tab of window 1
repeat with i from 1 to count of allURLs
    if item i of allURLs contains "meet.google.com" then
        tell tab i of window 1
            execute javascript "..."
        end tell
    end if
end repeat
```

**Arc shares tabs across windows** - The same tab can appear in multiple windows (via Spaces). Executing JavaScript on the same tab twice in quick succession can cause hangs. The solution is to use timeouts and try each window separately.

See `RESEARCH.md` for full details.

## For AI Agents

When working on this project:
1. Read `PLAN.md` for the implementation approach
2. Read `RESEARCH.md` for technical details and Arc AppleScript bugs
3. The install.sh script must be idempotent (safe to run multiple times)
4. Test with both Arc and Chrome browsers
5. Never iterate Arc tabs directly - use the bulk-fetch URL approach
6. Use timeouts when executing JavaScript on tabs - Arc windows can get stuck
7. Never execute JavaScript on the same tab from multiple windows - it causes hangs
