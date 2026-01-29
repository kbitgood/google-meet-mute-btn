# Research Notes

## Approaches Considered

### 1. Chrome Extension

**How it works:**
- Use `chrome.commands` API for global keyboard shortcuts
- Content scripts injected into Meet tabs
- Background service worker coordinates messaging

**Pros:**
- Clean, native browser integration
- Built-in messaging between background and content scripts

**Cons:**
- Global shortcuts limited to `Ctrl+Shift+[0-9]` only
- Requires installing unpacked extension
- Service workers can be suspended

**Conclusion:** Too restrictive on keyboard shortcuts.

### 2. macOS Quick Action + AppleScript

**How it works:**
- Create a Quick Action workflow with embedded AppleScript
- Assign a keyboard shortcut via pbs.plist
- AppleScript finds Meet tabs and toggles mute

**Pros:**
- Native macOS integration
- No external tools needed

**Cons:**
- Automator has sandboxing/permission issues
- Quick Actions often fail silently when controlling other apps
- Keyboard shortcut registration is finicky

**Conclusion:** Didn't work reliably due to Automator permission issues.

### 3. Karabiner-Elements + AppleScript (CHOSEN)

**How it works:**
- Karabiner maps F5 (or any key) to run a shell script
- Shell script executes AppleScript to toggle mute
- AppleScript finds all Meet tabs and dispatches keyboard events

**Pros:**
- Works with Arc and Chrome browsers
- Can be triggered by ANY key via Karabiner
- No sandboxing issues - Karabiner runs scripts with full permissions
- Works on background tabs (not just active tab)

**Cons:**
- Requires Karabiner-Elements
- macOS only
- Chrome requires enabling "Allow JavaScript from Apple Events" setting

**Conclusion:** Best fit for requirements. This is what we implemented.

---

## Google Chrome AppleScript Requirements

Chrome requires a manual setting to be enabled before AppleScript can execute JavaScript in tabs.

### Enabling JavaScript from Apple Events

1. Open Google Chrome
2. Go to menu: **View > Developer > Allow JavaScript from Apple Events**
3. Confirm the prompt

Without this setting, you'll get the error:
```
Executing JavaScript through AppleScript is turned off.
```

### Why Chrome Requires This

This is a security measure. Unlike Arc, Chrome doesn't allow arbitrary JavaScript execution by default. The user must explicitly opt-in.

### AppleScript for Chrome

Chrome's AppleScript is more standard than Arc's. You can iterate tabs directly:

```applescript
tell application "Google Chrome"
    repeat with i from 1 to count of tabs of window 1
        set tabURL to URL of tab i of window 1
        if tabURL contains "meet.google.com" then
            tell tab i of window 1
                execute javascript "document.title"
            end tell
        end if
    end repeat
end tell
```

---

## Google Meet Mute Mechanism

### Keyboard Shortcut
- **Mac:** `Cmd + D` toggles microphone mute
- **Windows/Linux:** `Ctrl + D`

### DOM Selectors (may change with Meet updates)

```javascript
// By aria-label (most reliable)
'[aria-label*="microphone"]'
'[aria-label="Turn off microphone"]'  // when unmuted
'[aria-label="Turn on microphone"]'   // when muted

// By data attributes
'[data-tooltip*="microphone"]'
'[data-is-muted]'

// By role
'[role="button"][aria-label*="microphone"]'
```

### Programmatic Toggle Methods

**Method 1: Simulate Keyboard Shortcut (Most Reliable)**
```javascript
document.dispatchEvent(new KeyboardEvent('keydown', {
  key: 'd',
  code: 'KeyD',
  keyCode: 68,
  which: 68,
  metaKey: true,  // Cmd on Mac
  bubbles: true
}));
```

**Method 2: Click Button**
```javascript
const muteBtn = document.querySelector('[aria-label*="microphone"]');
if (muteBtn) muteBtn.click();
```

### Checking Mute State
```javascript
function isMuted() {
  const btn = document.querySelector('[aria-label*="microphone"]');
  if (btn) {
    return btn.getAttribute('aria-label').includes('Turn on');
  }
  return null;
}
```

---

## Arc Browser AppleScript - Critical Findings

Arc supports AppleScript/JXA for browser automation, but has significant bugs.

### What Works

**Getting active tab:**
```applescript
tell application "Arc"
    tell active tab of window 1
        execute javascript "document.title"
    end tell
end tell
```

**Bulk-fetching all URLs (fast):**
```applescript
tell application "Arc"
    set allURLs to URL of every tab of window 1
end tell
```

**Targeting tab by index:**
```applescript
tell application "Arc"
    tell tab 69 of window 1
        execute javascript "document.title"
    end tell
end tell
```

### What Does NOT Work

**Iterating tabs directly (BUGGY):**
```applescript
-- THIS IS SLOW AND UNRELIABLE - DO NOT USE
tell application "Arc"
    repeat with t in (every tab of window 1)
        set tabURL to URL of t  -- Often fails or returns wrong data
    end repeat
end tell
```

**Using `whose` filter (BUGGY):**
```applescript
-- THIS RETURNS UNUSABLE TAB REFERENCES - DO NOT USE
tell application "Arc"
    set meetTabs to (tabs of window 1 whose URL contains "meet.google.com")
end tell
```

**Iterating windows directly (CAUSES HANGS):**
```applescript
-- THIS HANGS WHEN THE SAME TAB IS IN MULTIPLE WINDOWS - DO NOT USE
tell application "Arc"
    repeat with w in (every window)
        -- If a tab exists in multiple windows (via Spaces),
        -- executing JS on it from the second window causes a hang
    end repeat
end tell
```

### The Working Pattern

The solution is to:
1. Bulk-fetch all URLs in one call (fast)
2. Find indexes of matching URLs in AppleScript
3. Target tabs by index
4. **Use timeouts** to fail fast if a window is unresponsive
5. **Process only one window** - don't iterate all windows due to shared tabs

```applescript
tell application "Arc"
    -- Try window 1 with timeout
    try
        with timeout of 0.1 seconds
            set allURLs to URL of every tab of window 1
            repeat with i from 1 to count of allURLs
                if item i of allURLs contains "meet.google.com" then
                    tell tab i of window 1
                        execute javascript "..."
                    end tell
                    return "success"  -- Return immediately after first match
                end if
            end repeat
        end timeout
    end try
    
    -- If window 1 failed/timed out, try window 2
    try
        with timeout of 0.1 seconds
            -- same pattern...
        end timeout
    end try
end tell
```

### Arc Shares Tabs Across Windows (Spaces Bug)

Arc's "Spaces" feature means a tab can appear in multiple windows simultaneously. This causes a critical issue:

1. You execute JavaScript on tab X in window 1
2. Tab X also exists in window 2 (shared via Spaces)
3. You try to execute JavaScript on the same tab X via window 2
4. **Arc hangs or crashes**

**Solution:** Return immediately after successfully processing ONE Meet tab. Don't try to process all windows.

### Arc Windows Can Become Unresponsive

Sometimes an Arc window becomes unresponsive to AppleScript commands (reason unknown). Without a timeout, the script hangs indefinitely.

**Solution:** Use `with timeout of 0.1 seconds` around all window operations. If a window times out, catch the error and try the next window.

---

## Karabiner-Elements Configuration

### Shell Command Execution

Karabiner can run shell scripts directly via `shell_command`:

```json
{
  "description": "Google Meet Mute (F5 toggles mute)",
  "manipulators": [{
    "from": { "key_code": "f5" },
    "to": [{ "shell_command": "~/.local/bin/toggle-meet-mute.sh" }],
    "type": "basic"
  }]
}
```

### Config Location
`~/.config/karabiner/karabiner.json`

---

## macOS Quick Action Details (Legacy - Not Used)

These notes are kept for reference, but Quick Actions are not used in the final solution due to permission issues.

### Storage Location
`~/Library/Services/*.workflow`

### Bundle Structure
```
MyAction.workflow/
└── Contents/
    ├── Info.plist          # Service metadata
    ├── document.wflow      # Workflow definition (plist)
    └── QuickLook/
        └── Thumbnail.png   # Optional
```

### Keyboard Shortcut Assignment

**Storage:** `~/Library/Preferences/pbs.plist`

**Key format:** `(null) - SERVICE_NAME - runWorkflowAsService`

**Modifier encoding:**
- `^` = Control
- `$` = Shift
- `@` = Command
- `~` = Option

**Example:** `^$~@m` = Ctrl+Shift+Option+Cmd+M

**Set via command:**
```bash
defaults write pbs NSServicesStatus -dict-add \
    "(null) - Toggle Google Meet Mute - runWorkflowAsService" \
    '{ "key_equivalent" = "^$~@m"; }'
```

**Refresh services:**
```bash
/System/Library/CoreServices/pbs -update
```

### Why Quick Actions Failed

When triggered via keyboard shortcut, the Quick Action would show a gear icon in the menu bar but fail to execute the AppleScript. This appears to be a sandboxing/permission issue where Automator workflows cannot control Arc browser when run as a service.

Running the same AppleScript via `osascript` directly works fine, confirming the issue is with Automator's execution context.
