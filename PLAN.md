# Google Meet Global Mute Button - Implementation Plan

## Goal

Create a global keyboard shortcut that toggles mute in ALL Google Meet tabs in Arc browser, regardless of which window is currently focused.

## Final Solution: Karabiner-Elements + AppleScript

After exploring multiple approaches, we settled on **Karabiner-Elements directly executing a shell script** because:

1. **No sandboxing issues** - Unlike Automator Quick Actions, Karabiner runs scripts with full permissions
2. **Arc browser support** - Arc allows JavaScript execution via AppleScript without special settings
3. **Simple single-key trigger** - F5 (dictation key) directly runs the script
4. **Works on background tabs** - Using the bulk-fetch URL approach (see below)

### Why Not Automator Quick Actions?

We initially tried creating a macOS Quick Action triggered by `Ctrl+Shift+Option+Cmd+M`, but Automator has permission/sandboxing issues that prevent it from controlling Arc browser reliably.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Karabiner-Elements                                             │
│  F5 (dictation key) ──runs──▶ ~/.local/bin/toggle-meet-mute.sh │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│  Bash Script (~/.local/bin/toggle-meet-mute.sh)                 │
│  1. Calls AppleScript via osascript                             │
│  2. Gets result: "muted", "unmuted", "error", or "none"         │
│  3. Plays appropriate macOS system sound                        │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│  AppleScript (~/.local/bin/toggle-meet-mute.scpt)               │
│  1. Try each Arc window with 0.1s timeout (avoids hangs)        │
│  2. Bulk-fetch all tab URLs per window (fast)                   │
│  3. Find Meet tabs by URL, check mute state                     │
│  4. Execute JavaScript to dispatch Cmd+D keyboard event         │
│  5. Return result string to bash script                         │
└─────────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `~/.local/bin/toggle-meet-mute.sh` | Bash wrapper that calls AppleScript and plays sounds |
| `~/.local/bin/toggle-meet-mute.scpt` | AppleScript that finds Meet tabs and toggles mute |
| `~/.config/karabiner/karabiner.json` | Karabiner config with F5 → script binding |
| `install.sh` | Creates both scripts and updates Karabiner config |
| `uninstall.sh` | Removes the scripts and Karabiner rule |

## Keyboard Shortcut

**F5 (dictation key)** - Single key press toggles mute on all Meet tabs

The user can customize this in `~/.config/karabiner/karabiner.json`.

## Sound Feedback

The script plays macOS system sounds for instant feedback:

| Sound | Meaning |
|-------|---------|
| **Morse** (beep) | You are now MUTED |
| **Pop** | You are now UNMUTED |
| **Basso** (low tone) | No Meet tab found or error |

We chose sounds over notifications because notifications were "super delayed" (several seconds), while sounds are instant.

## Critical Technical Discoveries

### 1. Arc AppleScript Tab Iteration Bug

Arc's AppleScript implementation has a bug where iterating through tabs directly is extremely slow and unreliable:

```applescript
-- THIS DOES NOT WORK RELIABLY (slow, returns wrong results)
repeat with t in (every tab of window 1)
    set tabURL to URL of t  -- Often fails or times out
end repeat
```

**Solution:** Bulk-fetch all URLs as a list, find indexes, then target tabs by index:

```applescript
-- THIS WORKS (fast and reliable)
set allURLs to URL of every tab of window 1  -- Single fast call
repeat with i from 1 to count of allURLs
    if item i of allURLs contains "meet.google.com" then
        tell tab i of window 1  -- Target by index
            execute javascript "..."
        end tell
    end if
end repeat
```

### 2. Arc Shares Tabs Across Windows

Arc's "Spaces" feature means the same tab can appear in multiple windows. If you execute JavaScript on a tab from window 1, then try to access the same tab from window 2, Arc can hang or crash.

**Solution:** Only process one window successfully, then return immediately. Don't iterate all windows.

### 3. Arc Windows Can Get Stuck

Sometimes an Arc window becomes unresponsive to AppleScript commands, causing the script to hang indefinitely.

**Solution:** Use timeouts to fail fast and try the next window:

```applescript
try
    with timeout of 0.1 seconds
        set allURLs to URL of every tab of window 1
        -- process tabs...
    end timeout
end try
-- If window 1 times out, try window 2...
```

### 4. Bash Heredocs + AppleScript + JavaScript = Crashes

Embedding AppleScript with JavaScript inside bash heredocs caused intermittent crashes and weird quoting issues.

**Solution:** Use a separate `.scpt` file for the AppleScript, called by the bash wrapper via `osascript`.

## Google Meet Mute Toggle Method

The script dispatches a `Cmd+D` keyboard event to toggle mute:

```javascript
document.dispatchEvent(new KeyboardEvent('keydown', {
  key: 'd',
  code: 'KeyD',
  keyCode: 68,
  metaKey: true,  // Cmd on Mac
  bubbles: true
}));
```

This is more reliable than clicking the mute button via DOM selectors, which can break when Google updates Meet's UI.

## Determining Mute State

Before toggling, we check the current state by reading the mute button's aria-label:

```javascript
document.querySelector('[aria-label*=microphone]').getAttribute('aria-label')
// Returns "Turn off microphone" if currently unmuted
// Returns "Turn on microphone" if currently muted
```

This allows us to play the correct sound AFTER toggling (if it was "Turn off", we're now muted).
