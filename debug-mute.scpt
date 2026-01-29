-- Google Meet Global Mute Toggle - Debug Version
-- Run this with: osascript debug-mute.scpt

set appName to "Arc"

-- Check if Arc is running
if application appName is not running then
    log "Arc browser is not running"
    return "Arc not running"
end if

tell application "Arc"
    set meetTabs to {}
    set debugInfo to {}
    
    -- Iterate all windows and tabs to find Meet tabs
    try
        set windowCount to count of windows
        set end of debugInfo to "Found " & windowCount & " windows"
        
        repeat with w in windows
            try
                set tabCount to count of tabs of w
                set end of debugInfo to "Window has " & tabCount & " tabs"
                
                repeat with t in tabs of w
                    try
                        set tabURL to URL of t
                        set end of debugInfo to "Tab URL: " & tabURL
                        
                        if tabURL contains "meet.google.com/" then
                            set end of debugInfo to "  -> This is a Meet URL!"
                            
                            -- Check if it's a meeting page
                            set isMeetingPage to true
                            if tabURL contains "/landing" then set isMeetingPage to false
                            if tabURL ends with "meet.google.com/" then set isMeetingPage to false
                            if tabURL contains "meet.google.com/?authuser" then set isMeetingPage to false
                            if tabURL contains "/new" then set isMeetingPage to false
                            if tabURL contains "/lookup" then set isMeetingPage to false
                            
                            if isMeetingPage then
                                set end of debugInfo to "  -> Is a meeting page, adding to list"
                                set end of meetTabs to t
                            else
                                set end of debugInfo to "  -> Filtered out (landing/new/lookup page)"
                            end if
                        end if
                    on error errMsg
                        set end of debugInfo to "Error getting tab URL: " & errMsg
                    end try
                end repeat
            on error errMsg
                set end of debugInfo to "Error with window: " & errMsg
            end try
        end repeat
    on error errMsg
        set end of debugInfo to "Error iterating windows: " & errMsg
    end try
    
    set end of debugInfo to "Total Meet tabs found: " & (count of meetTabs)
    
    -- Try to execute JavaScript on first Meet tab
    if (count of meetTabs) > 0 then
        set firstTab to item 1 of meetTabs
        
        -- Try simple JS first
        try
            set end of debugInfo to "Attempting to execute JavaScript..."
            tell firstTab
                set jsResult to execute javascript "document.title"
                set end of debugInfo to "Document title: " & jsResult
            end tell
        on error errMsg
            set end of debugInfo to "JavaScript error: " & errMsg
        end try
        
        -- Try to find mute button
        try
            tell firstTab
                set muteCheck to execute javascript "
                    (function() {
                        var btn = document.querySelector('[aria-label*=\"microphone\"]');
                        if (!btn) return 'Button not found';
                        return 'Button found: ' + btn.getAttribute('aria-label');
                    })();
                "
                set end of debugInfo to "Mute button check: " & muteCheck
            end tell
        on error errMsg
            set end of debugInfo to "Mute button check error: " & errMsg
        end try
    end if
    
    return debugInfo
end tell
