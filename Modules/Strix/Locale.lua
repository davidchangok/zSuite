--[[
    Strix Locale — enUS + zhCN
]]

local addonName, addonTable = ...

local zSuite = _G.zSuite
if not zSuite then return end

local L = setmetatable({}, { __index = function(_, k) return k end })

-- enUS (default)
L.TOOLTIP_TITLE          = "Strix - Mail Recipient"
L.TOOLTIP_HINT           = "|cFF888888Right-click|r for context menu"
L.HEADER_MY_ALTS         = "My Alts"
L.HEADER_RECENT_RECIPIENTS = "Recent Recipients"
L.MENU_NO_RECORDS        = "No records"
L.MENU_MANAGE_LIST       = "Manage List..."
L.OPTIONS_SLIDER_ALTS    = "Alts displayed: %d"
L.OPTIONS_SLIDER_RECENT  = "Recent displayed: %d"
L.TAB_MY_ALTS            = "My Alts"
L.TAB_RECENT             = "Recent"
L.LEVEL_FORMAT           = "Lv.%d"
L.AUTO_REMOVE_IF_ALT     = "Auto-remove when registered as alt"

-- zhCN
if _G.GetLocale() == "zhCN" then
    L.TOOLTIP_TITLE          = "Strix - 邮件收件人"
    L.TOOLTIP_HINT           = "|cFF888888右键|r 打开菜单"
    L.HEADER_MY_ALTS         = "我的小号"
    L.HEADER_RECENT_RECIPIENTS = "最近收件人"
    L.MENU_NO_RECORDS        = "暂无记录"
    L.MENU_MANAGE_LIST       = "管理列表..."
    L.OPTIONS_SLIDER_ALTS    = "小号显示: %d"
    L.OPTIONS_SLIDER_RECENT  = "最近显示: %d"
    L.TAB_MY_ALTS            = "我的小号"
    L.TAB_RECENT             = "最近收件人"
    L.LEVEL_FORMAT           = "Lv.%d"
    L.AUTO_REMOVE_IF_ALT     = "登录小号时自动从最近移除"
end

if zSuite.modules and zSuite.modules.strix then
    zSuite.modules.strix.L = L
end
_G.zSuiteStrix_L = L
