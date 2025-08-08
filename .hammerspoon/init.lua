
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
appWatcher = hs.application.watcher.new(function(appName, eventType, app)
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

-- Cmd+숫자 → 해당 번호의 Space로 이동
local spaces = require("hs.spaces")
local screen = require("hs.screen")
local hotkey = require("hs.hotkey")

local function gotoSpaceByIndex(i)
  local all = spaces.allSpaces()                     -- 화면 UUID → space ID 배열
  local uuid = screen.primaryScreen():getUUID()      -- 기본(주) 화면
  local list = all[uuid]
  if list and list[i] then
    spaces.gotoSpace(list[i])                        -- i번째 space로 이동
  else
    hs.alert.show("Space " .. i .. " 없음")
  end
end

for i = 1, 9 do
  hotkey.bind({ "cmd" }, tostring(i), function() gotoSpaceByIndex(i) end)
end


appWatcher:start()