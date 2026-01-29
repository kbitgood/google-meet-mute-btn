#!/bin/bash

# Google Meet Global Mute Button - Uninstall Script
# Removes the toggle script and Karabiner-Elements rule

set -e

# Configuration
SCRIPT_PATH="$HOME/.local/bin/toggle-meet-mute.sh"
SCPT_PATH="$HOME/.local/bin/toggle-meet-mute.scpt"
KARABINER_CONFIG="$HOME/.config/karabiner/karabiner.json"
RULE_DESCRIPTION="Google Meet Mute (F5/Dictation key toggles mute)"

# Legacy Quick Action (remove if exists from old installation)
WORKFLOW_DIR="$HOME/Library/Services/Toggle Google Meet Mute.workflow"
PBS_PLIST="$HOME/Library/Preferences/pbs.plist"
SERVICE_KEY="(null) - Toggle Google Meet Mute - runWorkflowAsService"

echo "================================================"
echo "Google Meet Global Mute Button - Uninstaller"
echo "================================================"
echo ""

# Track if anything was removed
REMOVED_ANYTHING=false

# Remove toggle script
if [ -f "$SCRIPT_PATH" ]; then
    echo "Removing toggle script..."
    rm -f "$SCRIPT_PATH"
    echo "  Removed: $SCRIPT_PATH"
    REMOVED_ANYTHING=true
else
    echo "Toggle script not found (already removed or never installed)"
fi

# Remove AppleScript file
if [ -f "$SCPT_PATH" ]; then
    echo "Removing AppleScript..."
    rm -f "$SCPT_PATH"
    echo "  Removed: $SCPT_PATH"
    REMOVED_ANYTHING=true
fi

echo ""

# Remove Karabiner rule
if [ -f "$KARABINER_CONFIG" ]; then
    echo "Removing Karabiner-Elements rule..."
    
    if grep -q "$RULE_DESCRIPTION" "$KARABINER_CONFIG" 2>/dev/null; then
        python3 << PYTHON
import json

config_path = "$KARABINER_CONFIG"

with open(config_path, 'r') as f:
    config = json.load(f)

# Find and remove the rule from all profiles
for profile in config.get('profiles', []):
    rules = profile.get('complex_modifications', {}).get('rules', [])
    original_count = len(rules)
    profile['complex_modifications']['rules'] = [
        r for r in rules if r.get('description') != "$RULE_DESCRIPTION"
    ]
    if len(profile['complex_modifications']['rules']) < original_count:
        print("  Removed Karabiner rule")

with open(config_path, 'w') as f:
    json.dump(config, f, indent=4)
PYTHON
        REMOVED_ANYTHING=true
    else
        echo "  Karabiner rule not found (already removed or never set)"
    fi
else
    echo "Karabiner config not found, skipping..."
fi

echo ""

# Remove legacy Quick Action if it exists
if [ -d "$WORKFLOW_DIR" ]; then
    echo "Removing legacy Quick Action..."
    rm -rf "$WORKFLOW_DIR"
    echo "  Removed: $WORKFLOW_DIR"
    REMOVED_ANYTHING=true
fi

# Remove legacy keyboard shortcut from pbs.plist
if /usr/libexec/PlistBuddy -c "Print ':NSServicesStatus:$SERVICE_KEY'" "$PBS_PLIST" &>/dev/null; then
    echo "Removing legacy keyboard shortcut..."
    /usr/libexec/PlistBuddy -c "Delete ':NSServicesStatus:$SERVICE_KEY'" "$PBS_PLIST"
    echo "  Removed keyboard shortcut entry from pbs.plist"
    /System/Library/CoreServices/pbs -update 2>/dev/null || true
    REMOVED_ANYTHING=true
fi

echo ""
echo "================================================"
if [ "$REMOVED_ANYTHING" = true ]; then
    echo "Uninstallation complete!"
    echo "================================================"
    echo ""
    echo "The toggle script and Karabiner rule have been removed."
    echo "F5 key will return to its default behavior."
else
    echo "Nothing to uninstall"
    echo "================================================"
    echo ""
    echo "Google Meet Global Mute Button was not installed."
fi
echo ""
