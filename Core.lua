--[[
    zSuite/Core.lua — 顶层整合管理器
    负责：模块扫描、DB 初始化、zUI.config 构造与注入、斜杠命令路由、全局调度
--]]

local addonName, addonTable = ...

_G.zSuite = _G.zSuite or {}
local zSuite = _G.zSuite

-- ============================================================
--  模块注册表
-- ============================================================
zSuite.Name = "zSuite"
zSuite.Version = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata("zSuite", "Version") or "1.0.0"
zSuite.modules = {}

-- ============================================================
--  zSuiteDB 默认值
-- ============================================================
local DB_DEFAULTS = {
    version = 1,
    ui = {
        fontMedia = nil,
        fontMediaPath = nil,
        fontSize = 13,
        fontFlags = "OUTLINE",
        backgroundMedia = nil,
        backgroundMediaPath = nil,
        colors = nil,
        characterWindowLayout = false,
    },
    windowLayout = {},       -- { [key] = {point, relPoint, x, y} }
    charWindowLayout = {},   -- 角色级窗口布局
    modules = {
        lorisid = {
            enabled = true,
            debugMode = false,
            showIcons = true,
            perfThreshold = 10,
            cache = { enabled = true, maxSize = 1000 },
            ids = {
                item = true, spell = true, petspell = true, unit = true,
                quest = true, achievement = true, currency = true, mount = true,
                toy = true, talent = true, set = true, visual = true,
                companion = true, object = true, battlepet = true, instance = true,
                recipe = true, macro = true, pvp = true, minimap = true, icon = true,
            },
        },
        strix = {
            enabled = true,
            displayLimit = 99,
            recentDisplayLimit = 10,
            autoRemoveIfAlt = true,
            alts = {},
            recentRecipients = {},
        },
        phasewatcher = {
            enabled = true,
            showFrame = true,
            posX = nil,
            posY = nil,
            isLocked = false,
            useHexadecimal = false,
            autoHideInCombat = false,
            fontFace = nil,
            fontSize = 16,
            windowAlpha = 1.0,
            textAlpha = 1.0,
            textR = 0.20, textG = 1.0, textB = 0.60,
            frameless = false,
            updateInterval = 0.5,
        },
    },
}

-- ============================================================
--  DB 初始化
-- ============================================================
function zSuite.InitializeDB()
    _G.zSuiteDB = _G.zSuiteDB or {}
    zUI.MergeDefaults(_G.zSuiteDB, DB_DEFAULTS)
    zSuite.db = _G.zSuiteDB
end

-- ============================================================
--  zUI.config 构造与注入
-- ============================================================
function zSuite.ApplyUIConfig()
    local db = zSuite.db
    if not db or not db.ui then return end

    zUI.ApplyConfig({
        fontMedia = db.ui.fontMedia,
        fontMediaPath = db.ui.fontMediaPath,
        fontSize = db.ui.fontSize,
        fontFlags = db.ui.fontFlags,
        backgroundMedia = db.ui.backgroundMedia,
        backgroundMediaPath = db.ui.backgroundMediaPath,
        colors = db.ui.colors,
        characterWindowLayout = db.ui.characterWindowLayout,

        -- 窗口位置回调（每次调用时实时读取 db.ui.characterWindowLayout，而非捕获快照）
        getWindowLayoutValue = function(key)
            if db.ui.characterWindowLayout and db.charWindowLayout[key] then
                return db.charWindowLayout[key]
            end
            return db.windowLayout[key]
        end,
        setWindowLayoutValue = function(key, value)
            if db.ui.characterWindowLayout then
                db.charWindowLayout[key] = value
            else
                db.windowLayout[key] = value
            end
        end,

        -- 动画开关（默认关闭——各模块可覆盖）
        isAnimatedMinimizeEnabled = function() return false end,
        getHeaderPosition = function() return "top" end,
    })

    -- 注入 Security 本地化
    local locale = _G.GetLocale and _G.GetLocale() or "enUS"
    if locale == "zhCN" then
        zUI.Security.SetLocale("动作被拦截", "FFFF6600")
    end
end

-- ============================================================
--  斜杠命令路由
-- ============================================================
local function HandleSlash(msg)
    msg = msg or ""
    local cmd, arg = string.match(msg, "^(%S+)%s*(.*)$")
    cmd = cmd or msg

    if cmd == "" or cmd == "config" then
        if zSuite.OpenOptions then zSuite.OpenOptions() end
    elseif cmd == "version" then
        zUI.Print("zSuite v" .. (zSuite.Version or "1.0.0"))
    else
        zUI.Print("zSuite: /zs | /zs config | /zs version")
    end
end

_G.SLASH_ZSUITE1 = "/zsuite"
_G.SLASH_ZSUITE2 = "/zs"
_G.SlashCmdList["ZSUITE"] = HandleSlash

-- ============================================================
--  事件处理
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 初始化 DB
        zSuite.InitializeDB()
        -- 注入 UI 配置
        zSuite.ApplyUIConfig()
        -- 触发各模块初始化（模块在各自 Core.lua 中注册到 zSuite.modules）
        for name, mod in pairs(zSuite.modules) do
            if mod and mod.Init and mod.enabled ~= false then
                local ok, err = pcall(mod.Init, mod)
                if not ok then
                    zUI.Print("|cFFFF0000[" .. name .. "]|r 初始化失败: " .. tostring(err))
                end
            end
        end
        -- 不再需要 ADDON_LOADED
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ============================================================
--  公共 API
-- ============================================================

--- 注册一个模块到 zSuite
--- @param name string
--- @param module table {enabled, Init, BuildOptions, HandleSlash}[, ...]
function zSuite.RegisterModule(name, module)
    zSuite.modules[name] = module
end

--- 设置模块启用/禁用
--- @param name string
--- @param enabled boolean
function zSuite.SetModuleEnabled(name, enabled)
    local mod = zSuite.modules[name]
    if not mod then return end
    mod.enabled = enabled
    if zSuite.db then
        local modCfg = zSuite.db.modules[name]
        if modCfg then
            modCfg.enabled = enabled
        end
    end
end

--- 获取模块是否启用
--- @param name string
--- @return boolean
function zSuite.IsModuleEnabled(name)
    local mod = zSuite.modules[name]
    if not mod then return false end
    return mod.enabled ~= false
end
