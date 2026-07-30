--[[
    Strix Locale — enUS + zhCN
    邮件收件人地址簿模块本地化。
--]]

local addonName, addonTable = ...

local zSuite = _G.zSuite
if not zSuite then return end

local L = setmetatable({}, { __index = function(t, k) return k end })

-- enUS (default)
L.TOOLTIP_TITLE          = "Strix - Mail Recipient"
L.TOOLTIP_HINT           = "|cFF888888Right-click|r for context menu"
L.HEADER_MY_ALTS         = "My Alts"
L.HEADER_RECENT_RECIPIENTS = "Recent Recipients"
L.MENU_NO_RECORDS        = "No records"
L.MENU_MANAGE_LIST       = "Manage List..."
L.OPTIONS_HEADER         = "Strix Settings"
L.OPTIONS_SLIDER_ALTS    = "Alt Display Count"
L.OPTIONS_SLIDER_RECENT  = "Recent Display Count"
L.TAB_MY_ALTS            = "My Alts"
L.TAB_RECENT             = "Recent"
L.LEVEL_FORMAT           = "Lv.%d"
L.LEVEL_UNKNOWN          = "Lv.?"
L.RECENT_NOTE            = "Mailed on %s"
L.AUTO_REMOVE_IF_ALT     = "Auto-remove if Alt"
L.ACTION_MOVE_TO_ALTS    = "Move to Alts"
L.ACTION_DELETE          = "Delete"
L.CONFIRM_DELETE         = "Remove this entry?"
L.ADDON_TITLE            = "Strix"
L.MSG_RECIPIENT_SAVED    = "Recipient saved."
L.MSG_MOVED_TO_ALTS      = "Moved to alts list."
L.OPTIONS_DESC           = "Mail recipient address book settings."

-- zhCN
if _G.GetLocale() == "zhCN" then
    L.TOOLTIP_TITLE          = "Strix - 邮件收件人"
    L.TOOLTIP_HINT           = "|cFF888888右键|r 打开菜单"
    L.HEADER_MY_ALTS         = "我的小号"
    L.HEADER_RECENT_RECIPIENTS = "最近收件人"
    L.MENU_NO_RECORDS        = "暂无记录"
    L.MENU_MANAGE_LIST       = "管理列表..."
    L.OPTIONS_HEADER         = "Strix 设置"
    L.OPTIONS_SLIDER_ALTS    = "小号显示数量"
    L.OPTIONS_SLIDER_RECENT  = "最近显示数量"
    L.TAB_MY_ALTS            = "我的小号"
    L.TAB_RECENT             = "最近收件人"
    L.LEVEL_FORMAT           = "Lv.%d"
    L.LEVEL_UNKNOWN          = "Lv.?"
    L.RECENT_NOTE            = "寄信于 %s"
    L.AUTO_REMOVE_IF_ALT     = "成为小号时自动移除"
    L.ACTION_MOVE_TO_ALTS    = "移入小号列表"
    L.ACTION_DELETE          = "删除"
    L.CONFIRM_DELETE         = "确定删除此条目？"
    L.ADDON_TITLE            = "Strix"
    L.MSG_RECIPIENT_SAVED    = "收件人已保存。"
    L.MSG_MOVED_TO_ALTS      = "已移入小号列表。"
    L.OPTIONS_DESC           = "邮件收件人地址簿设置。"
end

if zSuite.modules and zSuite.modules.strix then
    zSuite.modules.strix.L = L
end

_G.zSuiteStrix_L = L
