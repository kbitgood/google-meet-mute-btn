#!/bin/bash
# Google Meet Mute Toggle Script
# Called by the macOS Quick Action

osascript <<'EOF'
tell application "Arc"
    if not running then
        display notification "Arc browser is not running" with title "Google Meet Mute" sound name "Basso"
        return
    end if
    
    set affectedCount to 0
    
    repeat with w in (every window)
        try
            tell active tab of w
                set tabURL to URL
                if tabURL contains "meet.google.com" and tabURL does not contain "/landing" then
                    execute javascript "document.dispatchEvent(new KeyboardEvent('keydown',{key:'d',code:'KeyD',keyCode:68,metaKey:true,bubbles:true}));"
                    set affectedCount to affectedCount + 1
                end if
            end tell
        end try
    end repeat
    
    if affectedCount is 0 then
        display notification "No active Meet tab found" with title "Google Meet Mute" sound name "Basso"
    else if affectedCount is 1 then
        display notification "Toggled mute" with title "Google Meet Mute"
    else
        display notification "Toggled mute in " & affectedCount & " windows" with title "Google Meet Mute"
    end if
end tell
EOF
