#!/bin/bash

# Google Meet Global Mute Button - Install Script
# Creates a macOS Quick Action that toggles mute in all Google Meet tabs in Arc browser

set -e

# Configuration
WORKFLOW_NAME="Toggle Google Meet Mute"
WORKFLOW_DIR="$HOME/Library/Services/${WORKFLOW_NAME}.workflow"
CONTENTS_DIR="$WORKFLOW_DIR/Contents"

echo "================================================"
echo "Google Meet Global Mute Button - Installer"
echo "================================================"
echo ""

# Remove existing workflow if present (idempotent)
if [ -d "$WORKFLOW_DIR" ]; then
    echo "Removing existing workflow..."
    rm -rf "$WORKFLOW_DIR"
fi

# Create directory structure
echo "Creating workflow directory structure..."
mkdir -p "$CONTENTS_DIR"

# Create Info.plist
echo "Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Toggle Google Meet Mute</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSRequiredContext</key>
            <dict/>
            <key>NSSendTypes</key>
            <array/>
            <key>NSReturnTypes</key>
            <array/>
        </dict>
    </array>
</dict>
</plist>
INFOPLIST

# Create document.wflow (Automator workflow definition)
# This is a minimal Automator workflow structure with a placeholder for AppleScript
echo "Creating document.wflow..."
cat > "$CONTENTS_DIR/document.wflow" << 'DOCUMENTWFLOW'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <true/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>1.0.2</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMCategory</key>
                <string>AMCategoryUtilities</string>
                <key>AMIconName</key>
                <string>Automator</string>
                <key>AMName</key>
                <string>Run AppleScript</string>
                <key>AMParameters</key>
                <dict>
                    <key>source</key>
                    <string>on run {input, parameters}
    -- Google Meet Global Mute Toggle
    -- Finds all Meet tabs in Arc and toggles them to the same mute state
    
    set appName to "Arc"
    
    -- Check if Arc is running
    if application appName is not running then
        display notification "Arc browser is not running" with title "Google Meet Mute" sound name "Basso"
        return input
    end if
    
    tell application "Arc"
        set meetTabs to {}
        
        -- Iterate all windows and tabs to find active Meet tabs (in a meeting, not landing page)
        try
            repeat with w in windows
                try
                    repeat with t in tabs of w
                        try
                            set tabURL to URL of t
                            -- Only match actual meeting URLs (contain meet.google.com/ followed by meeting code)
                            -- Filter out: landing, new, lookup, etc pages
                            if tabURL contains "meet.google.com/" then
                                -- Check if it's NOT a non-meeting page
                                set isMeetingPage to true
                                if tabURL contains "/landing" then set isMeetingPage to false
                                if tabURL ends with "meet.google.com/" then set isMeetingPage to false
                                if tabURL contains "meet.google.com/?authuser" then set isMeetingPage to false
                                if tabURL contains "/new" then set isMeetingPage to false
                                if tabURL contains "/lookup" then set isMeetingPage to false
                                
                                if isMeetingPage then
                                    set end of meetTabs to t
                                end if
                            end if
                        end try
                    end repeat
                end try
            end repeat
        end try
        
        -- Handle no active Meet tabs found
        if (count of meetTabs) = 0 then
            display notification "No active Google Meet calls found" with title "Google Meet Mute" sound name "Basso"
            return input
        end if
        
        -- JavaScript to check if muted (returns "muted" or "unmuted" or "unknown")
        set checkMuteJS to "
            (function() {
                var btn = document.querySelector('[aria-label*=\"microphone\"]');
                if (!btn) return 'unknown';
                var label = btn.getAttribute('aria-label') || '';
                if (label.includes('Turn on')) return 'muted';
                if (label.includes('Turn off')) return 'unmuted';
                return 'unknown';
            })();
        "
        
        -- JavaScript to toggle mute using Cmd+D keyboard shortcut
        set toggleMuteJS to "
            (function() {
                document.dispatchEvent(new KeyboardEvent('keydown', {
                    key: 'd',
                    code: 'KeyD',
                    keyCode: 68,
                    which: 68,
                    metaKey: true,
                    bubbles: true
                }));
                return 'toggled';
            })();
        "
        
        -- Get the mute state of the first tab to determine target state (with timeout)
        set firstTab to item 1 of meetTabs
        set firstTabState to "unknown"
        try
            with timeout of 3 seconds
                tell firstTab
                    set firstTabState to execute javascript checkMuteJS
                end tell
            end timeout
        on error
            set firstTabState to "unknown"
        end try
        
        -- Determine target state: if first is muted, we unmute all; if unmuted, we mute all
        -- If unknown, we just toggle all
        set targetState to "unknown"
        if firstTabState is "muted" then
            set targetState to "unmuted"
        else if firstTabState is "unmuted" then
            set targetState to "muted"
        end if
        
        -- Process each Meet tab
        set affectedCount to 0
        repeat with meetTab in meetTabs
            try
                with timeout of 3 seconds
                    -- Check current state of this tab
                    set currentState to "unknown"
                    tell meetTab
                        set currentState to execute javascript checkMuteJS
                    end tell
                    
                    -- Only toggle if needed (or if state is unknown)
                    set needsToggle to false
                    if targetState is "unknown" then
                        set needsToggle to true
                    else if currentState is not targetState then
                        set needsToggle to true
                    end if
                    
                    if needsToggle then
                        tell meetTab
                            execute javascript toggleMuteJS
                        end tell
                        set affectedCount to affectedCount + 1
                    end if
                end timeout
            end try
        end repeat
        
        -- Show result notification
        set tabWord to "tab"
        if affectedCount is not 1 then
            set tabWord to "tabs"
        end if
        
        if targetState is "muted" then
            display notification "Muted " &amp; affectedCount &amp; " " &amp; tabWord with title "Google Meet Mute"
        else if targetState is "unmuted" then
            display notification "Unmuted " &amp; affectedCount &amp; " " &amp; tabWord with title "Google Meet Mute"
        else
            display notification "Toggled " &amp; affectedCount &amp; " " &amp; tabWord with title "Google Meet Mute"
        end if
        
    end tell
    
    return input
end run</string>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.string</string>
                    </array>
                </dict>
                <key>AMRequiredResources</key>
                <array/>
                <key>AMTag</key>
                <string>RunAppleScript</string>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run AppleScript.action</string>
                <key>ActionName</key>
                <string>Run AppleScript</string>
                <key>ActionParameters</key>
                <dict/>
                <key>BundleIdentifier</key>
                <string>com.apple.Automator.RunScript</string>
                <key>CFBundleVersion</key>
                <string>1.0.2</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunScriptAction</string>
                <key>InputUUID</key>
                <string>BFCA72F3-8E3E-4F9C-A9B7-7E8A1234ABCD</string>
                <key>Keywords</key>
                <array>
                    <string>Run</string>
                </array>
                <key>OutputUUID</key>
                <string>BFCA72F3-8E3E-4F9C-A9B7-7E8A5678EFGH</string>
                <key>UUID</key>
                <string>BFCA72F3-8E3E-4F9C-A9B7-7E8AABCDEFGH</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>arguments</key>
                <dict>
                    <key>0</key>
                    <dict>
                        <key>default value</key>
                        <string>on run {input, parameters}
    return input
end run</string>
                        <key>name</key>
                        <string>source</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>0</string>
                    </dict>
                </dict>
                <key>isViewVisible</key>
                <integer>1</integer>
                <key>location</key>
                <string>449.500000:305.000000</string>
                <key>nibPath</key>
                <string>/System/Library/Automator/Run AppleScript.action/Contents/Resources/Base.lproj/main.nib</string>
            </dict>
            <key>isViewVisible</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>applicationBundleID</key>
        <string>com.apple.Automator</string>
        <key>applicationBundleIDsByPath</key>
        <dict/>
        <key>applicationPath</key>
        <string>/System/Applications/Automator.app</string>
        <key>applicationPaths</key>
        <array/>
        <key>backgroundColor</key>
        <data>
        YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9i
        amVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGjCwwTVSRu
        dWxs0w0ODxARElVuc1JHQlxOU0NvbG9yU3BhY2VWJGNsYXNzTxAnMC43MDU5
        MzEzNzI1IDAuNzA1OTMxMzcyNSAwLjcwNTkzMTM3MjUAEAGAAtIUFRYXWiRj
        bGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqIWGFhOU09iamVjdAgRGiQpMjdJ
        TFFTVltiaXB9kJKXorO2vgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAA
        AADH
        </data>
        <key>inputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>outputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>presentationMode</key>
        <integer>15</integer>
        <key>processesInput</key>
        <integer>0</integer>
        <key>serviceApplicationBundleID</key>
        <string>com.apple.finder</string>
        <key>serviceApplicationPath</key>
        <string>/System/Library/CoreServices/Finder.app</string>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key>
        <integer>0</integer>
        <key>systemImageName</key>
        <string>NSTouchBarDownload</string>
        <key>useAutomaticInputType</key>
        <integer>0</integer>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
DOCUMENTWFLOW

echo ""
echo "Workflow created at: $WORKFLOW_DIR"
echo ""

# Register keyboard shortcut
echo "Registering keyboard shortcut (Ctrl+Shift+Option+Cmd+M)..."

# Refresh services first so pbs knows about the new workflow
/System/Library/CoreServices/pbs -update 2>/dev/null || true

# Wait a moment for pbs to update
sleep 1

# Register the keyboard shortcut using PlistBuddy
# Modifier encoding: ^ = Control, $ = Shift, ~ = Option, @ = Command
# ^$~@m = Ctrl+Shift+Option+Cmd+M
PBS_PLIST="$HOME/Library/Preferences/pbs.plist"
SERVICE_KEY="(null) - Toggle Google Meet Mute - runWorkflowAsService"

# Remove existing entry if present (for idempotency)
/usr/libexec/PlistBuddy -c "Delete ':NSServicesStatus:$SERVICE_KEY'" "$PBS_PLIST" 2>/dev/null || true

# Add new entry with keyboard shortcut
/usr/libexec/PlistBuddy -c "Add ':NSServicesStatus:$SERVICE_KEY' dict" "$PBS_PLIST"
/usr/libexec/PlistBuddy -c 'Add ":NSServicesStatus:(null) - Toggle Google Meet Mute - runWorkflowAsService:key_equivalent" string "^$~@m"' "$PBS_PLIST"

# Refresh services again to apply the shortcut
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo ""
echo "================================================"
echo "Installation complete!"
echo "================================================"
echo ""
echo "Keyboard shortcut: Ctrl + Shift + Option + Cmd + M"
echo ""
echo "The shortcut should be active now. You can verify it at:"
echo "  System Settings > Keyboard > Keyboard Shortcuts > Services"
echo "  Look for 'Toggle Google Meet Mute' under 'General'"
echo ""
echo "NOTE: If the shortcut doesn't work immediately, try:"
echo "  - Log out and log back in"
echo "  - Or restart your Mac"
echo ""
