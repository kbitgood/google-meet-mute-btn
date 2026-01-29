# Future Enhancements

This document captures planned features beyond the MVP.

## Multi-Browser Support

**Priority:** High (requested by user for sharing with colleagues)

### Browsers to Support
1. **Arc** (current) - AppleScript with `execute javascript`
2. **Google Chrome** - AppleScript (requires "Allow JavaScript from Apple Events" setting)
3. **Safari** - AppleScript with `do JavaScript` command
4. **Firefox** - No native AppleScript support; may need extension approach
5. **Chromium-based** (Brave, Edge, Vivaldi) - Similar to Chrome

### Implementation Approach
- Create browser-specific AppleScript modules
- Add interactive TUI to `install.sh` using `select` or `dialog`
- Let user choose which browsers to enable
- Install separate Quick Actions or a single action that tries all enabled browsers

### Example TUI Flow
```
$ ./install.sh

Google Meet Global Mute - Installation

Which browsers do you use for Google Meet?
  [x] Arc
  [ ] Google Chrome
  [ ] Safari
  [ ] Brave
  [ ] Microsoft Edge
  
(Use arrow keys to navigate, space to toggle, enter to confirm)

Installing for: Arc
✓ Created Quick Action
✓ Registered keyboard shortcut
✓ Done!
```

## Push-to-Talk Mode

**Priority:** Medium

- Hold key to unmute, release to mute
- Requires two keyboard shortcuts or a different approach
- May need a persistent background process to detect key release

## Menu Bar Indicator

**Priority:** Low

- Show microphone icon in menu bar
- Icon changes based on mute state
- Clicking toggles mute
- Would require a proper macOS app (Swift or Electron)

## Audio Feedback

**Priority:** Low

- Play subtle sound on mute/unmute
- Helps confirm action when looking away from screen
- Use `afplay` with system sounds

## Chrome Extension Alternative

**Priority:** Low

For users who want more features than AppleScript can provide:
- Popup showing all Meet tabs and their mute states
- Per-tab mute control
- Keyboard shortcut customization within the extension
- Limitation: Global shortcuts limited to `Ctrl+Shift+[0-9]`

## Cross-Platform Support

**Priority:** Future

- Windows: AutoHotkey script + PowerShell
- Linux: xdotool + shell script
