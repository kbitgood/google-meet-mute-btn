-- Test mute toggle directly
tell application "Arc"
    repeat with w in windows
        repeat with t in tabs of w
            try
                set tabURL to URL of t
                if tabURL contains "meet.google.com/" and tabURL does not contain "/landing" then
                    log "Found Meet tab: " & tabURL
                    
                    -- Try the keyboard event approach
                    tell t
                        set result1 to execute javascript "
                            (function() {
                                // Method 1: Keyboard event
                                var event = new KeyboardEvent('keydown', {
                                    key: 'd',
                                    code: 'KeyD',
                                    keyCode: 68,
                                    which: 68,
                                    metaKey: true,
                                    bubbles: true,
                                    cancelable: true
                                });
                                document.dispatchEvent(event);
                                return 'Dispatched keyboard event';
                            })();
                        "
                        log "Keyboard result: " & result1
                    end tell
                    
                    delay 0.5
                    
                    -- Check state after
                    tell t
                        set afterState to execute javascript "
                            (function() {
                                var btn = document.querySelector('[aria-label*=\"microphone\"]');
                                if (!btn) return 'Button not found';
                                return btn.getAttribute('aria-label');
                            })();
                        "
                        log "After state: " & afterState
                    end tell
                    
                    return "Done"
                end if
            end try
        end repeat
    end repeat
end tell
