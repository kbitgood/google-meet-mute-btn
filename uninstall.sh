#!/bin/bash

# Google Meet Global Mute Button - Uninstall Script
# Removes the macOS Quick Action and keyboard shortcut

set -e

# Configuration
WORKFLOW_NAME="Toggle Google Meet Mute"
WORKFLOW_DIR="$HOME/Library/Services/${WORKFLOW_NAME}.workflow"
PBS_PLIST="$HOME/Library/Preferences/pbs.plist"
SERVICE_KEY="(null) - Toggle Google Meet Mute - runWorkflowAsService"

echo "================================================"
echo "Google Meet Global Mute Button - Uninstaller"
echo "================================================"
echo ""

# Track if anything was removed
REMOVED_ANYTHING=false

# Remove workflow directory if it exists
if [ -d "$WORKFLOW_DIR" ]; then
    echo "Removing workflow directory..."
    rm -rf "$WORKFLOW_DIR"
    echo "  Removed: $WORKFLOW_DIR"
    REMOVED_ANYTHING=true
else
    echo "Workflow not found (already removed or never installed)"
fi

echo ""

# Remove keyboard shortcut from pbs.plist
echo "Removing keyboard shortcut..."
if /usr/libexec/PlistBuddy -c "Print ':NSServicesStatus:$SERVICE_KEY'" "$PBS_PLIST" &>/dev/null; then
    /usr/libexec/PlistBuddy -c "Delete ':NSServicesStatus:$SERVICE_KEY'" "$PBS_PLIST"
    echo "  Removed keyboard shortcut entry from pbs.plist"
    REMOVED_ANYTHING=true
else
    echo "  Keyboard shortcut not found (already removed or never set)"
fi

echo ""

# Refresh macOS services
echo "Refreshing macOS services..."
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo ""
echo "================================================"
if [ "$REMOVED_ANYTHING" = true ]; then
    echo "Uninstallation complete!"
    echo "================================================"
    echo ""
    echo "The Quick Action and keyboard shortcut have been removed."
    echo ""
    echo "NOTE: The shortcut may still appear in System Settings"
    echo "until you log out and back in, or restart your Mac."
else
    echo "Nothing to uninstall"
    echo "================================================"
    echo ""
    echo "Google Meet Global Mute Button was not installed."
fi
echo ""
