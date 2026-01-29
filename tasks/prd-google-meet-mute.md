# PRD: Google Meet Global Mute Button

## Introduction

A global keyboard shortcut utility for macOS that toggles mute in ALL Google Meet tabs across Arc browser windows, regardless of which application is currently focused. Users with Karabiner-Elements can map a single key (like the dictation key) to trigger this shortcut.

## Problem Statement

Google Meet's mute keyboard shortcut (Cmd+D) only works when the Meet tab is focused. Users in meetings often switch to other apps (notes, presentations, code editors) and need a way to quickly mute/unmute without navigating back to the Meet tab. Unlike Zoom, which supports global hotkeys natively, Google Meet requires a custom solution.

## Goals

- Provide a global keyboard shortcut that works regardless of focused application
- Toggle mute across ALL open Google Meet tabs simultaneously
- Sync all tabs to the same mute state (all muted or all unmuted)
- Install with a single command (no manual Automator setup)
- Provide visual feedback via macOS notifications
- Support clean uninstallation

## Target User

- macOS users with Arc browser
- Users who multitask during Google Meet calls
- Users comfortable with terminal/command line installation
- (Future) Users of other browsers who want the same functionality

## User Stories

### US-001: Install the mute toggle utility
**Description:** As a user, I want to run a single command to install the global mute shortcut so I don't have to manually configure Automator.

**Acceptance Criteria:**
- [ ] Running `./install.sh` creates the Quick Action at `~/Library/Services/Toggle Google Meet Mute.workflow/`
- [ ] The workflow bundle contains valid `Info.plist` and `document.wflow` files
- [ ] Keyboard shortcut `Ctrl+Shift+Option+Cmd+M` is registered in the system
- [ ] Script displays success message with instructions
- [ ] Script is idempotent (safe to run multiple times)

---

### US-002: Toggle mute with keyboard shortcut
**Description:** As a user, I want to press a keyboard shortcut from any application and have all my Google Meet tabs toggle mute.

**Acceptance Criteria:**
- [ ] Pressing `Ctrl+Shift+Option+Cmd+M` triggers the Quick Action
- [ ] Works when Arc is focused
- [ ] Works when Arc is NOT focused (global shortcut)
- [ ] All Google Meet tabs receive the mute toggle command
- [ ] Tabs sync to the same state (all muted or all unmuted, based on first tab's state)

---

### US-003: Receive notification feedback
**Description:** As a user, I want to see a notification confirming the mute state so I know the shortcut worked.

**Acceptance Criteria:**
- [ ] Shows "Muted" or "Unmuted" with count of affected tabs
- [ ] Shows "No Google Meet tabs found" when no Meet tabs exist
- [ ] Shows appropriate message when Arc is not running
- [ ] Notification appears within 1 second of shortcut press

---

### US-004: Uninstall the utility
**Description:** As a user, I want to cleanly remove the utility when I no longer need it.

**Acceptance Criteria:**
- [ ] Running `./uninstall.sh` removes the Quick Action workflow
- [ ] Keyboard shortcut binding is removed
- [ ] Script displays success message
- [ ] No leftover files in `~/Library/Services/`

---

## Functional Requirements

- FR-1: `install.sh` must create a valid macOS Quick Action (.workflow bundle) in `~/Library/Services/`
- FR-2: The Quick Action must contain AppleScript that iterates all Arc windows and tabs
- FR-3: The AppleScript must find tabs with URLs containing "meet.google.com"
- FR-4: The AppleScript must query the first Meet tab's mute state before toggling
- FR-5: The AppleScript must execute JavaScript to toggle mute (dispatch Cmd+D keydown event) in each Meet tab
- FR-6: All tabs must be synced to the same final state (based on toggling first tab's state)
- FR-7: The AppleScript must display a macOS notification with the result
- FR-8: `install.sh` must register keyboard shortcut `Ctrl+Shift+Option+Cmd+M` via `defaults write pbs`
- FR-9: `install.sh` must refresh services via `/System/Library/CoreServices/pbs -update`
- FR-10: `uninstall.sh` must remove the workflow and keyboard binding completely

## Non-Goals (Out of Scope for MVP)

- Support for browsers other than Arc (Chrome, Safari, Firefox) - see FUTURE.md
- Interactive TUI for browser selection during install
- Push-to-talk mode (hold to unmute, release to mute)
- Menu bar indicator showing current mute state
- Audio feedback (sounds on mute/unmute)
- Auto-detection of Karabiner and suggested key mappings
- Windows or Linux support

## Technical Considerations

### Quick Action Bundle Structure
```
Toggle Google Meet Mute.workflow/
└── Contents/
    ├── Info.plist          # Service metadata (XML plist)
    └── document.wflow      # Workflow definition with embedded AppleScript
```

### Key Technical Details
- **Shortcut encoding:** `^$~@m` (Control+Shift+Option+Cmd+M)
- **Shortcut storage:** `~/Library/Preferences/pbs.plist` under `NSServicesStatus`
- **Service registration:** `/System/Library/CoreServices/pbs -update`
- **Meet mute trigger:** JavaScript dispatching `Cmd+D` keydown event
- **Mute state detection:** Query `aria-label` attribute of microphone button

### Arc Browser AppleScript
Arc supports `execute javascript` on tab objects without requiring special settings (unlike Chrome which needs "Allow JavaScript from Apple Events" enabled).

## Success Metrics

- Install completes in under 5 seconds
- Keyboard shortcut triggers mute within 1 second
- Works reliably across 1-10 simultaneous Meet tabs
- Zero manual Automator or System Settings configuration required

## Open Questions

1. Should we detect if the keyboard shortcut conflicts with an existing binding?
2. Should we support an alternative shortcut if the default conflicts?
3. How should we handle Meet tabs that are still loading (no mute button yet)?
