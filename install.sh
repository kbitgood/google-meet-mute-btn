#!/bin/bash

# Google Meet Global Mute Button - Install Script
# Creates a toggle script and configures Karabiner-Elements to trigger it with F5

set -e

# Configuration
SCRIPT_DIR="$HOME/.local/bin"
SCRIPT_PATH="$SCRIPT_DIR/toggle-meet-mute.sh"
KARABINER_CONFIG="$HOME/.config/karabiner/karabiner.json"
RULE_DESCRIPTION="Google Meet Mute (F5/Dictation key toggles mute)"

echo "================================================"
echo "Google Meet Global Mute Button - Installer"
echo "================================================"
echo ""

# Check if Karabiner config exists
if [ ! -f "$KARABINER_CONFIG" ]; then
    echo "ERROR: Karabiner-Elements config not found at:"
    echo "  $KARABINER_CONFIG"
    echo ""
    echo "Please install Karabiner-Elements first:"
    echo "  https://karabiner-elements.pqrs.org/"
    exit 1
fi

# Create script directory
mkdir -p "$SCRIPT_DIR"

# Create the main bash script that handles parallelization
echo "Creating toggle script at $SCRIPT_PATH..."
cat > "$SCRIPT_PATH" << 'SCRIPT'
#!/bin/bash
# Google Meet Mute Toggle Script
# Called by Karabiner-Elements
# Sounds: Morse=muted, Pop=unmuted, Basso=error/none
#
# Strategy: Run parallel osascript processes for each window with short timeouts
# Use the first results that come back, ignore slow/stuck windows

TIMEOUT_SEC=0.15
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Suppress job control messages
set +m
exec 2>/dev/null

# Check if Arc is running
if ! pgrep -q "Arc"; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 0
fi

# Phase 1: Get Meet tab locations from all windows (fast, no JS)
# Output format: winNum:tabIdx:meetingURL (one per line)
meet_tabs=$(osascript << 'EOF'
tell application "Arc"
    set output to ""
    set windowCount to count of windows
    repeat with winNum from 1 to windowCount
        try
            set allURLs to URL of every tab of window winNum
            repeat with i from 1 to count of allURLs
                set tabURL to item i of allURLs
                if tabURL contains "meet.google.com" and tabURL does not contain "/landing" then
                    set output to output & winNum & ":" & i & ":" & tabURL & linefeed
                end if
            end repeat
        end try
    end repeat
    return output
end tell
EOF
)

if [ -z "$meet_tabs" ]; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 0
fi

# Save meet tabs to file for processing
echo "$meet_tabs" > "$TMPDIR/meet_tabs.txt"

# Get unique meeting URLs
cut -d: -f3- "$TMPDIR/meet_tabs.txt" | sort -u > "$TMPDIR/unique_meetings.txt"

if [ ! -s "$TMPDIR/unique_meetings.txt" ]; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 0
fi

# Phase 2: For each unique meeting, try all its window locations in parallel
# Launch all processes at once
while IFS=: read -r winNum tabIdx meetingURL; do
    [ -z "$meetingURL" ] && continue
    # Create unique filename from meeting URL
    safe_name=$(echo "$meetingURL" | md5)
    result_file="$TMPDIR/state_${safe_name}"
    
    # Only launch if we haven't already launched for this meeting
    if [ ! -f "$TMPDIR/launched_${safe_name}" ]; then
        touch "$TMPDIR/launched_${safe_name}"
    fi
    
    # Launch in background with osascript timeout
    (
        result=$(osascript 2>/dev/null << INNEREOF
tell application "Arc"
    with timeout of 1 seconds
        tell tab $tabIdx of window $winNum
            execute javascript "(() => { const btn = document.querySelector('[aria-label*=microphone]'); return btn ? btn.getAttribute('aria-label') : 'not-in-meeting'; })()"
        end tell
    end timeout
end tell
INNEREOF
        )
        if [ -n "$result" ] && [[ "$result" != *"not-in-meeting"* ]]; then
            # Only write if no result yet (first wins)
            if [ ! -f "$result_file" ]; then
                if [[ "$result" == *"Turn off"* ]]; then
                    echo "$winNum:$tabIdx:unmuted" > "$result_file"
                else
                    echo "$winNum:$tabIdx:muted" > "$result_file"
                fi
            fi
        fi
    ) 2>/dev/null &
done < "$TMPDIR/meet_tabs.txt"

# Wait for timeout then kill stragglers
sleep $TIMEOUT_SEC
pkill -P $$ 2>/dev/null
wait 2>/dev/null

# Collect results
any_unmuted=false
while read -r meetingURL; do
    [ -z "$meetingURL" ] && continue
    safe_name=$(echo "$meetingURL" | md5)
    result_file="$TMPDIR/state_${safe_name}"
    
    if [ -f "$result_file" ]; then
        result=$(cat "$result_file")
        state="${result##*:}"
        if [ "$state" = "unmuted" ]; then
            any_unmuted=true
        fi
    fi
done < "$TMPDIR/unique_meetings.txt"

# Check if we got any results
result_count=$(ls "$TMPDIR"/state_* 2>/dev/null | wc -l)
if [ "$result_count" -eq 0 ]; then
    afplay /System/Library/Sounds/Basso.aiff &
    exit 0
fi

# Phase 3: Toggle tabs that need to change
if $any_unmuted; then
    target_state="muted"
else
    target_state="unmuted"
fi

# Toggle each meeting that needs it
while read -r meetingURL; do
    [ -z "$meetingURL" ] && continue
    safe_name=$(echo "$meetingURL" | md5)
    result_file="$TMPDIR/state_${safe_name}"
    
    if [ -f "$result_file" ]; then
        result=$(cat "$result_file")
        winNum="${result%%:*}"
        rest="${result#*:}"
        tabIdx="${rest%%:*}"
        current_state="${rest##*:}"
        
        if [ "$current_state" != "$target_state" ]; then
            # Fire and forget toggle
            osascript 2>/dev/null << TOGGLEEOF &
tell application "Arc"
    with timeout of 1 seconds
        tell tab $tabIdx of window $winNum
            execute javascript "document.dispatchEvent(new KeyboardEvent('keydown',{key:'d',code:'KeyD',keyCode:68,metaKey:true,bubbles:true}));"
        end tell
    end timeout
end tell
TOGGLEEOF
        fi
    fi
done < "$TMPDIR/unique_meetings.txt"

# Brief wait for toggles
sleep 0.05

# Play sound based on final state
if [ "$target_state" = "muted" ]; then
    afplay /System/Library/Sounds/Morse.aiff &
else
    afplay /System/Library/Sounds/Pop.aiff &
fi
SCRIPT

chmod +x "$SCRIPT_PATH"
echo "  Created: $SCRIPT_PATH"
echo ""

# Check if rule already exists in Karabiner config
echo "Configuring Karabiner-Elements..."

if grep -q "$RULE_DESCRIPTION" "$KARABINER_CONFIG" 2>/dev/null; then
    echo "  Karabiner rule already exists, skipping..."
else
    # Use Python to safely add the rule to the JSON config
    python3 << PYTHON
import json

config_path = "$KARABINER_CONFIG"

with open(config_path, 'r') as f:
    config = json.load(f)

# Find the selected profile
for profile in config.get('profiles', []):
    if profile.get('selected', False):
        # Ensure complex_modifications exists
        if 'complex_modifications' not in profile:
            profile['complex_modifications'] = {'rules': []}
        if 'rules' not in profile['complex_modifications']:
            profile['complex_modifications']['rules'] = []
        
        # Check if rule already exists
        rules = profile['complex_modifications']['rules']
        rule_exists = any(r.get('description') == "$RULE_DESCRIPTION" for r in rules)
        
        if not rule_exists:
            # Add new rule at the beginning
            new_rule = {
                "description": "$RULE_DESCRIPTION",
                "enabled": True,
                "manipulators": [
                    {
                        "from": {
                            "key_code": "f5",
                            "modifiers": {"optional": ["caps_lock"]}
                        },
                        "to": [
                            {"shell_command": "~/.local/bin/toggle-meet-mute.sh"}
                        ],
                        "type": "basic"
                    }
                ]
            }
            rules.insert(0, new_rule)
            print("  Added Karabiner rule")
        else:
            print("  Rule already exists")
        break

with open(config_path, 'w') as f:
    json.dump(config, f, indent=4)
PYTHON

fi

echo ""
echo "================================================"
echo "Installation complete!"
echo "================================================"
echo ""
echo "Keyboard shortcut: F5 (dictation key)"
echo ""
echo "Sound feedback:"
echo "  - Morse (beep): You are now MUTED"
echo "  - Pop: You are now UNMUTED"
echo "  - Basso (low tone): No Meet tab found or error"
echo ""
echo "Files installed:"
echo "  - $SCRIPT_PATH"
echo "  - Karabiner rule in $KARABINER_CONFIG"
echo ""
echo "The shortcut should work immediately."
echo "Press F5 to toggle mute on Google Meet."
echo ""
