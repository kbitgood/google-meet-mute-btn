# Google Meet Global Mute Button

A global keyboard shortcut for macOS that toggles mute in **all** Google Meet tabs across Arc browser windows, regardless of which application is currently focused.

Press **F5** from anywhere and all your Meet tabs instantly mute/unmute with audio feedback.

## Features

- **Global shortcut** - Works from any application, no need to switch to Arc
- **Multi-tab support** - Toggles mute on ALL Meet tabs simultaneously
- **Audio feedback** - Distinct sounds for muted, unmuted, and error states
- **Fast** - Responds in under 200ms
- **Simple** - One script to install, one to uninstall

## Requirements

- **macOS**
- **[Arc browser](https://arc.net/)**
- **[Karabiner-Elements](https://karabiner-elements.pqrs.org/)** - For global keyboard shortcuts

## Installation

1. Install Karabiner-Elements if you haven't already
2. Clone this repo and run the install script:

```bash
git clone https://github.com/kbitgood/google-meet-mute-btn.git
cd google-meet-mute-btn
./install.sh
```

The shortcut works immediately - no restart required.

## Usage

| Key | Action |
|-----|--------|
| **F5** | Toggle mute on all Google Meet tabs |

### Audio Feedback

| Sound | Meaning |
|-------|---------|
| **Morse** (beep) | You are now MUTED |
| **Pop** | You are now UNMUTED |
| **Basso** (low tone) | No Meet tab found, not in meeting, or Arc not running |

## Uninstallation

```bash
./uninstall.sh
```

This removes the toggle script and the Karabiner rule.

## How It Works

1. **Karabiner-Elements** intercepts F5 and runs `~/.local/bin/toggle-meet-mute.sh`
2. The script uses AppleScript to bulk-fetch all tab URLs from Arc
3. Finds Google Meet tabs and checks their mute state via JavaScript
4. Dispatches `Cmd+D` keyboard event to toggle mute (Meet's native shortcut)
5. Plays a sound to indicate the new state

## Customization

### Change the keyboard shortcut

Edit `~/.config/karabiner/karabiner.json` and find the rule "Google Meet Mute (F5/Dictation key toggles mute)". Change the `key_code` to your preferred key.

### Change the sounds

Edit `~/.local/bin/toggle-meet-mute.sh` and replace the `afplay` commands with different system sounds from `/System/Library/Sounds/`.

## Troubleshooting

**Shortcut doesn't work**
- Make sure Karabiner-Elements is running
- Check System Settings > Privacy & Security > Accessibility - Karabiner needs permission

**"No Meet tab found" sound plays but I'm in a meeting**
- Make sure you've actually joined the meeting (not just on the landing page)
- The script filters out `/landing` URLs

**Script is slow or unresponsive**
- Some Arc windows can get stuck. Close and reopen Arc if this persists

## Technical Notes

This project documents several quirks with Arc's AppleScript implementation - see [RESEARCH.md](RESEARCH.md) for details if you're working on similar Arc automation.

## License

MIT
