# Ralph Tasks: Google Meet Global Mute Button

Create a global keyboard shortcut utility for macOS that toggles mute in ALL Google Meet tabs across Arc browser windows.

---

## Task Dependency Graph

```
P0-1 (Create install.sh with workflow bundle structure)
    └── P0-2 (Implement AppleScript for mute toggle)
            └── P0-3 (Add keyboard shortcut registration)
                    └── P0-4 (Create uninstall.sh)
                            └── P0-5 (Test and fix edge cases)
```

---

## Tasks

### P0-1: Create install.sh with workflow bundle structure

Create the basic install.sh script that generates the macOS Quick Action workflow bundle structure.

**What to do:**
- Create `install.sh` as a bash script with proper shebang
- Generate the directory structure at `~/Library/Services/Toggle Google Meet Mute.workflow/Contents/`
- Create a valid `Info.plist` with service metadata (NSServices, NSMenuItem, NSMessage)
- Create a placeholder `document.wflow` with correct plist structure (will add AppleScript in next task)
- Make the script idempotent (remove existing workflow before creating new one)
- Add echo statements showing progress

**Files to create:**
- install.sh

**Acceptance criteria:**
- Running `./install.sh` creates `~/Library/Services/Toggle Google Meet Mute.workflow/`
- The `Contents/Info.plist` file is valid XML plist
- The `Contents/document.wflow` file is valid XML plist with correct Automator structure
- Running `./install.sh` twice doesn't cause errors (idempotent)
- Script is executable (`chmod +x`)

**Depends on:** Nothing

---

### P0-2: Implement AppleScript for mute toggle

Add the AppleScript code to the workflow that finds all Google Meet tabs in Arc and toggles mute.

**What to do:**
- Update install.sh to embed the AppleScript code in document.wflow
- AppleScript should iterate all Arc windows and tabs
- Find tabs where URL contains "meet.google.com"
- For first Meet tab found, check current mute state via JavaScript (query aria-label of microphone button)
- Determine target state: if first tab is muted, target is unmuted; if unmuted, target is muted
- For each Meet tab, execute JavaScript to either mute or unmute to reach target state
- JavaScript should dispatch keyboard event (Cmd+D) to toggle mute
- Collect count of tabs affected
- Display macOS notification with result ("Muted 3 tabs" or "Unmuted 3 tabs")
- Handle case where Arc is not running (show notification)
- Handle case where no Meet tabs found (show notification)

**Files to modify:**
- install.sh (add AppleScript to document.wflow generation)

**Acceptance criteria:**
- AppleScript correctly iterates Arc windows and tabs
- AppleScript finds tabs with "meet.google.com" in URL
- JavaScript is executed in each Meet tab
- All tabs end up in the same mute state (synced)
- Notification shows "Muted X tab(s)" or "Unmuted X tab(s)"
- Notification shows "No Google Meet tabs found" when appropriate
- Notification shows error when Arc is not running

**Depends on:** P0-1

---

### P0-3: Add keyboard shortcut registration

Add keyboard shortcut registration to install.sh so the Quick Action is triggered by Ctrl+Shift+Option+Cmd+M.

**What to do:**
- Add command to install.sh that registers the keyboard shortcut using `defaults write pbs`
- Use shortcut encoding `^$~@m` (Control+Shift+Option+Cmd+M)
- Register under `NSServicesStatus` with key `(null) - Toggle Google Meet Mute - runWorkflowAsService`
- Run `/System/Library/CoreServices/pbs -update` to refresh services
- Display success message with instructions about the keyboard shortcut
- Mention that user may need to log out/in if shortcut doesn't work immediately

**Files to modify:**
- install.sh

**Acceptance criteria:**
- After running install.sh, keyboard shortcut appears in System Settings > Keyboard > Keyboard Shortcuts > Services
- The shortcut is set to `Ctrl+Shift+Option+Cmd+M`
- Running `defaults read pbs NSServicesStatus` shows the service entry
- Success message displays the keyboard shortcut to use

**Depends on:** P0-2

---

### P0-4: Create uninstall.sh

Create the uninstall script that removes the Quick Action and keyboard shortcut.

**What to do:**
- Create `uninstall.sh` as a bash script
- Remove the workflow directory `~/Library/Services/Toggle Google Meet Mute.workflow/`
- Remove the keyboard shortcut from pbs.plist using `defaults delete` or by writing an empty dict
- Run `/System/Library/CoreServices/pbs -update` to refresh services
- Display success message confirming removal
- Handle case where workflow doesn't exist (already uninstalled)

**Files to create:**
- uninstall.sh

**Acceptance criteria:**
- Running `./uninstall.sh` removes `~/Library/Services/Toggle Google Meet Mute.workflow/`
- Keyboard shortcut no longer appears in System Settings
- Running uninstall.sh when already uninstalled shows appropriate message (not an error)
- Script is executable (`chmod +x`)

**Depends on:** P0-3

---

### P0-5: Test and fix edge cases

Verify the complete flow works end-to-end and handle edge cases discovered during testing.

**What to do:**
- Test the complete install → use → uninstall flow
- Test with Arc running with no Meet tabs
- Test with Arc running with one Meet tab
- Test with Arc running with multiple Meet tabs in different windows
- Test with Arc not running
- Test keyboard shortcut works when Arc is focused
- Test keyboard shortcut works when another app is focused (global)
- Verify notifications appear correctly for all scenarios
- Verify mute state syncing works (all tabs end up in same state)
- Fix any issues discovered during testing
- Update progress.txt with any patterns or issues discovered

**Files to modify:**
- install.sh (if fixes needed)
- uninstall.sh (if fixes needed)
- scripts/ralph/progress.txt (document findings)

**Acceptance criteria:**
- Install completes without errors
- Keyboard shortcut triggers mute toggle from any focused app
- All Meet tabs sync to same mute state
- Notifications display correct information
- Uninstall removes all components cleanly
- Re-running install after uninstall works correctly

**Depends on:** P0-4

---
