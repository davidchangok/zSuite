--[[
    LorisID Locale — enUS + zhCN
    从原 LorisID 10 语言本地化精简为仅保留英文和简体中文。
--]]

local addonName, addonTable = ...

-- 获取 zSuite 模块表
local zSuite = _G.zSuite
if not zSuite then return end

local L = setmetatable({}, { __index = function(t, k) return k end })

-- ============================================================
--  enUS（默认语言——同时作为 __index 回退）
-- ============================================================
if _G.GetLocale() == "enUS" or true then  -- 始终先设置英文作为默认
    L.AddonName             = "zSuite LorisID |cFF00FF00[Midnight]|r"
    L.Enable                = "Enable"
    L.Disable               = "Disable"
    L.EnableDesc            = "Enable or disable LorisID module"
    L.DebugMode             = "Debug Mode"
    L.DebugModeDesc         = "Show debug messages in chat"
    L.ShowIcons             = "Show Related Icons"
    L.ShowIconsDesc         = "Show item icon ID and associated spell ID"
    L.PerfThreshold         = "Performance Threshold (ms)"
    L.PerfThresholdDesc     = "Alert when CPU usage exceeds this value"
    L.CacheEnable           = "Enable Cache"
    L.CacheEnableDesc       = "Cache query results for faster access"
    L.CacheSize             = "Cache Size"
    L.CacheSizeDesc         = "Maximum entries per cache type"
    L.CacheCleared          = "Cache cleared"
    L.CacheClearedType      = "Cache cleared: "
    L.CacheItem             = "Items"
    L.CacheSpell            = "Spells"
    L.CacheUnit             = "Units"
    L.CacheAchievement      = "Achievements"
    L.CacheAll              = "All"
    L.IDSettings            = "ID Display Settings"
    L.IDItem                = "Item"
    L.IDSpell               = "Spell"
    L.IDPetSpell            = "Pet Spell"
    L.IDUnit                = "Unit"
    L.IDQuest               = "Quest"
    L.IDAchievement         = "Achievement"
    L.IDCurrency            = "Currency"
    L.IDMount               = "Mount"
    L.IDToy                 = "Toy"
    L.IDTalent              = "Talent"
    L.IDEquipmentSet        = "Equipment Set"
    L.IDTransmog            = "Transmog"
    L.IDCompanion           = "Companion"
    L.IDObject              = "Object"
    L.IDBattlePet           = "Battle Pet"
    L.IDInstance            = "Instance"
    L.IDRecipe              = "Recipe"
    L.IDMacro               = "Macro"
    L.IDPvP                 = "PvP"
    L.IDMinimap             = "Minimap"
    L.IDIcon                = "Icon"
    L.IconID                = "Icon ID"
    L.SpellID               = "Spell ID"
    L.ItemID                = "Item ID"
    L.UnitID                = "Unit ID"
    L.QuestID               = "Quest ID"
    L.AchievementID         = "Achievement ID"
    L.CurrencyID            = "Currency ID"
    L.MountID               = "Mount ID"
    L.ToyID                 = "Toy ID"
    L.TalentID              = "Talent ID"
    L.SecretValueBlocked    = "Action Blocked"
    L.RestrictedEnvironment = "Restricted environment detected"
    L.CombatEnded           = "Combat ended, resuming operations"
    L.CommandHelp           = "Usage: /lid [config|cache|debug|version]"
    L.VersionInfo           = "zSuite LorisID v%s by %s"
    L.PerfAlert             = "Performance alert: %dms exceeded threshold %dms"
    L.NotInitialized        = "LorisID not yet initialized"
    L.SettingsOpen          = "Opening settings..."
end

-- ============================================================
--  zhCN（简体中文覆盖）
-- ============================================================
if _G.GetLocale() == "zhCN" then
    L.AddonName             = "zSuite LorisID |cFF00FF00[至暗之夜]|r"
    L.Enable                = "启用"
    L.Disable               = "禁用"
    L.EnableDesc            = "启用或禁用 LorisID 模块"
    L.DebugMode             = "调试模式"
    L.DebugModeDesc         = "在聊天框中显示调试信息"
    L.ShowIcons             = "显示关联图标"
    L.ShowIconsDesc         = "显示物品图标 ID 和关联法术 ID"
    L.PerfThreshold         = "性能阈值（毫秒）"
    L.PerfThresholdDesc     = "当 CPU 使用超过此值时告警"
    L.CacheEnable           = "启用缓存"
    L.CacheEnableDesc       = "缓存查询结果以加速访问"
    L.CacheSize             = "缓存大小"
    L.CacheSizeDesc         = "每种类型的最大缓存条目数"
    L.CacheCleared          = "缓存已清除"
    L.CacheClearedType      = "缓存已清除："
    L.CacheItem             = "物品"
    L.CacheSpell            = "法术"
    L.CacheUnit             = "单位"
    L.CacheAchievement      = "成就"
    L.CacheAll              = "全部"
    L.IDSettings            = "ID 显示设置"
    L.IDItem                = "物品"
    L.IDSpell               = "法术"
    L.IDPetSpell            = "宠物技能"
    L.IDUnit                = "单位"
    L.IDQuest               = "任务"
    L.IDAchievement         = "成就"
    L.IDCurrency            = "货币"
    L.IDMount               = "坐骑"
    L.IDToy                 = "玩具"
    L.IDTalent              = "天赋"
    L.IDEquipmentSet        = "装备方案"
    L.IDTransmog            = "幻化"
    L.IDCompanion           = "伙伴"
    L.IDObject              = "物件"
    L.IDBattlePet           = "战宠"
    L.IDInstance            = "副本"
    L.IDRecipe              = "配方"
    L.IDMacro               = "宏"
    L.IDPvP                 = "PvP"
    L.IDMinimap             = "小地图"
    L.IDIcon                = "图标"
    L.IconID                = "图标 ID"
    L.SpellID               = "法术 ID"
    L.ItemID                = "物品 ID"
    L.UnitID                = "单位 ID"
    L.QuestID               = "任务 ID"
    L.AchievementID         = "成就 ID"
    L.CurrencyID            = "货币 ID"
    L.MountID               = "坐骑 ID"
    L.ToyID                 = "玩具 ID"
    L.TalentID              = "天赋 ID"
    L.SecretValueBlocked    = "动作被拦截"
    L.RestrictedEnvironment = "检测到受限环境"
    L.CombatEnded           = "战斗结束，恢复运行"
    L.CommandHelp           = "用法：/lid [config|cache|debug|version]"
    L.VersionInfo           = "zSuite LorisID v%s 作者：%s"
    L.PerfAlert             = "性能告警：%dms 超过阈值 %dms"
    L.NotInitialized        = "LorisID 尚未初始化"
    L.SettingsOpen          = "打开设置..."
end

-- 注册到模块的 locale
local mod = (zSuite.modules and zSuite.modules.lorisid)
if mod then
    mod.L = L
end

-- 同时注册为模块全局
_G.zSuiteLorisID_L = L
