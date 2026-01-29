# Implementation TODO

## Status: COMPLETE

The project is fully implemented and working.

## Phase 1: Core Implementation

- [x] Create toggle script at `~/.local/bin/toggle-meet-mute.sh`
  - [x] Bash wrapper calls AppleScript via osascript
  - [x] AppleScript bulk-fetches tab URLs per window (fast)
  - [x] Find tabs with URLs containing "meet.google.com"
  - [x] Execute JavaScript to dispatch Cmd+D keydown event
  - [x] Play sound feedback (Morse=muted, Pop=unmuted, Basso=error)

- [x] Create AppleScript at `~/.local/bin/toggle-meet-mute.scpt`
  - [x] Use 0.1s timeout per window to avoid hangs
  - [x] Try window 1, then window 2 as fallback
  - [x] Return mute state for sound feedback

- [x] Configure Karabiner-Elements
  - [x] Add rule to map F5 (dictation key) to run toggle script
  - [x] Ensure rule is enabled

- [x] Create `install.sh`
  - [x] Create bash wrapper script
  - [x] Create AppleScript file
  - [x] Add/update Karabiner rule (idempotent)
  - [x] Display success message

- [x] Create `uninstall.sh`
  - [x] Remove toggle script (.sh)
  - [x] Remove AppleScript file (.scpt)
  - [x] Remove Karabiner rule
  - [x] Display success message

## Phase 2: Testing

- [x] Test toggle script works when run directly
- [x] Test F5 key triggers the script via Karabiner
- [x] Test shortcut works when Arc is NOT focused (global)
- [x] Test with Google Meet tab in background (not active tab)
- [x] Test sound feedback plays correctly

## Phase 3: Edge Cases

- [x] Handle case where Arc is not running
- [x] Handle case where no Meet tabs are open
- [x] Handle Arc window becoming unresponsive (timeout workaround)
- [x] Handle shared tabs across windows (Spaces bug)

## Known Limitations

- Only works with Arc browser (not Chrome/Firefox)
- Requires Karabiner-Elements to be installed and running
- Only checks first 2 windows (could miss tabs in window 3+)

## Future Enhancements (Optional)

- [ ] Add support for Chrome browser (in addition to Arc)
- [ ] Add push-to-talk mode (hold to unmute, release to mute)
- [ ] Add menu bar indicator showing current mute state
- [ ] Support more than 2 Arc windows
