
-- 현재 포커스된 앱 이름 출력
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "I", function()
    local app = hs.application.frontmostApplication()
    hs.alert.show("App Name: " .. app:name())
end)

-- 현재 입력 소스 ID 출력
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "S", function()
    local source = hs.keycodes.currentSourceID()
    hs.alert.show("Current input source: " .. source)
end)
-- Change input source when switching to Ghostty
local inputEnglish = "com.apple.keylayout.ABC"
local targetAppName = "ghostty"
local lastInputSource = hs.keycodes.currentSourceID()
local lastApp = hs.application.frontmostApplication():name()

-- Watch for app focus changes
local appWatcher = hs.application.watcher.new(function(appName, eventType, app)
    if eventType == hs.application.watcher.activated then
        hs.console.printStyledtext("Switched to app: " .. appName)
        if string.lower(appName) == "ghostty" then
            lastInputSource = hs.keycodes.currentSourceID()
            hs.console.printStyledtext("Switching to English input from " .. lastInputSource)
            hs.keycodes.currentSourceID(inputEnglish)
        elseif string.lower(lastApp) == "ghostty" and string.lower(appName) ~= "ghostty" then
            hs.console.printStyledtext("Leaving ghostty: Restoring input source " .. lastInputSource)
            hs.keycodes.currentSourceID(lastInputSource)
        end
        lastApp = appName
    end
end)

appWatcher:start()