--[[
    LorisID Locale — enUS + zhCN
    键名使用带空格的完整字符串，与 Core.lua 中 ID_LABELS 表一致。
]]

local addonName, addonTable = ...

local zSuite = _G.zSuite
if not zSuite then return end

local L = setmetatable({}, { __index = function(t, k) return k end })

-- ============================================================
--  ID 标签（被 Core.lua 通过 L[key] 查询）
--  键名必须和 ID_LABELS 表中的值完全一致（含空格）
-- ============================================================
L["Item ID"]           = "Item ID"
L["Spell ID"]          = "Spell ID"
L["Pet Spell ID"]      = "Pet Spell ID"
L["Unit ID"]           = "Unit ID"
L["Quest ID"]          = "Quest ID"
L["Achievement ID"]    = "Achievement ID"
L["Currency ID"]       = "Currency ID"
L["Mount ID"]          = "Mount ID"
L["Toy ID"]            = "Toy ID"
L["Talent ID"]         = "Talent ID"
L["Equipment Set ID"]  = "Equipment Set ID"
L["Visual ID"]         = "Visual ID"
L["Companion ID"]      = "Companion ID"
L["Object ID"]         = "Object ID"
L["Battle Pet ID"]     = "Battle Pet ID"
L["Instance ID"]       = "Instance ID"
L["Recipe ID"]         = "Recipe ID"
L["Macro ID"]          = "Macro ID"
L["PvP Brawl ID"]      = "PvP Brawl ID"
L["Minimap ID"]        = "Minimap ID"
L["Icon ID"]           = "Icon ID"

-- ============================================================
--  Security / 通用（被 AuraScanner / Core 使用）
-- ============================================================
L["SecretValueBlocked"]    = "Action Blocked"
L["RestrictedEnvironment"] = "Restricted environment detected"
L["CombatEnded"]           = "Combat ended, resuming operations"
L["CommandHelp"]           = "Usage: /lid [config|cache|debug|version]"
L["VersionInfo"]           = "zSuite LorisID v%s by %s"
L["PerfAlert"]             = "Performance alert"
L["NotInitialized"]        = "LorisID not yet initialized"

-- ============================================================
--  zhCN
-- ============================================================
if _G.GetLocale() == "zhCN" then
    L["Item ID"]           = "物品 ID"
    L["Spell ID"]          = "法术 ID"
    L["Pet Spell ID"]      = "宠物技能 ID"
    L["Unit ID"]           = "单位 ID"
    L["Quest ID"]          = "任务 ID"
    L["Achievement ID"]    = "成就 ID"
    L["Currency ID"]       = "货币 ID"
    L["Mount ID"]          = "坐骑 ID"
    L["Toy ID"]            = "玩具 ID"
    L["Talent ID"]         = "天赋 ID"
    L["Equipment Set ID"]  = "装备方案 ID"
    L["Visual ID"]         = "幻象 ID"
    L["Companion ID"]      = "伙伴 ID"
    L["Object ID"]         = "物件 ID"
    L["Battle Pet ID"]     = "战宠 ID"
    L["Instance ID"]       = "副本 ID"
    L["Recipe ID"]         = "配方 ID"
    L["Macro ID"]          = "宏 ID"
    L["PvP Brawl ID"]      = "PvP ID"
    L["Minimap ID"]        = "小地图 ID"
    L["Icon ID"]           = "图标 ID"

    L["SecretValueBlocked"]    = "动作被拦截"
    L["RestrictedEnvironment"] = "检测到受限环境"
    L["CombatEnded"]           = "战斗结束，恢复运行"
    L["CommandHelp"]           = "用法：/lid [config|cache|debug|version]"
    L["VersionInfo"]           = "zSuite LorisID v%s 作者：%s"
    L["PerfAlert"]             = "性能告警"
    L["NotInitialized"]        = "LorisID 尚未初始化"
end

local mod = (zSuite.modules and zSuite.modules.lorisid)
if mod then mod.L = L end
_G.zSuiteLorisID_L = L
