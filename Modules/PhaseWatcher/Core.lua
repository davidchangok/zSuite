--[[
    PhaseWatcher/Core.lua — 位面 ID 检测引擎
    从 PhaseWatcher 2.1.0 迁移至 zSuite。

    Bug 修复：
    #2 — SetScript("OnEvent") 移至 RegisterEvent 之前

    Security：所有 UnitGUID 调用由 zUI.Security.SafeGet 包裹（GUID 可能是 userdata secret value）。
    使用 pcall 保护 strsplit 等字符串操作。
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

-- ============================================================
--  模块注册
-- ============================================================
local mod = {
    name = "phasewatcher",
    enabled = true,
}
zSuite.RegisterModule("phasewatcher", mod)

local L = mod.L or _G.zSuitePhaseWatcher_L
local Security = zUI.Security

-- ============================================================
--  内部状态
-- ============================================================
local currentPhaseID = nil
local currentPhaseSource = nil
local isSecretValue = false
local lastUpdateTime = 0
local updateTimer = nil

-- ============================================================
--  数据库获取
-- ============================================================
local function GetDB()
    if not zSuite.db or not zSuite.db.modules then return nil end
    return zSuite.db.modules.phasewatcher
end

-- ============================================================
--  GUID 解析（从 Creature/Vehicle/GameObject GUID 提取 ZoneUID）
-- ============================================================
local function ExtractPhaseFromGUID(guid)
    if not guid or guid == "" then
        return nil, "NO_GUID"
    end

    -- pcall 保护——GUID 可能是 userdata 类型（Secret Value）
    local ok, result = pcall(function()
        local unitType = select(1, strsplit("-", guid))
        -- 仅处理 Creature/Vehicle/GameObject（排除 Player/Pet）
        if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "GameObject" then
            return nil, "NO_PHASE_IN_GUID"
        end

        local zoneUID = select(5, strsplit("-", guid))
        if not zoneUID or zoneUID == "" or zoneUID == "0" or zoneUID == "0000000000000000" then
            return nil, "NO_PHASE_IN_GUID"
        end

        local phaseID = tonumber(zoneUID)
        if not phaseID or phaseID <= 0 or phaseID >= 100000000 then
            return nil, "NO_PHASE_IN_GUID"
        end

        return phaseID, "GUID_PARSE"
    end)

    if not ok then
        return nil, "SECRET_VALUE"
    end

    return result
end

-- ============================================================
--  从单位获取位面 ID
-- ============================================================
local function GetPhaseFromUnit(unit)
    if not unit or not _G.UnitExists(unit) then return nil end

    -- Security：UnitGUID 必须用 SafeGet 包裹
    local guid = Security.SafeGet(_G.UnitGUID, unit)
    if not guid then return nil end

    return ExtractPhaseFromGUID(guid)
end

-- ============================================================
--  多源优先级检测
-- ============================================================
local function DetectPhaseID()
    -- 1. mouseover（最高优先级）
    if _G.UnitExists("mouseover") then
        local id, src = GetPhaseFromUnit("mouseover")
        if id then return id, src or "mouseover", false end
    end

    -- 2. target
    if _G.UnitExists("target") then
        local id, src = GetPhaseFromUnit("target")
        if id then return id, src or "target", false end
    end

    -- 3. player（低位面信息，仅作参考）
    local playerGUID = Security.SafeGet(_G.UnitGUID, "player")
    if playerGUID then
        local id, src = ExtractPhaseFromGUID(playerGUID)
        if id then return id, src or "player", false end
    end

    -- 4. focus
    if _G.UnitExists("focus") then
        local id, src = GetPhaseFromUnit("focus")
        if id then return id, src or "focus", false end
    end

    -- 5. 缓存回退
    if currentPhaseID then
        return currentPhaseID, "cached", false
    end

    return nil, nil, false
end

-- ============================================================
--  更新位面状态
-- ============================================================
local function UpdatePhaseID()
    local db = GetDB()
    if not db or not db.enabled then return end

    local phaseID, source, isSecret = DetectPhaseID()

    if isSecret then
        isSecretValue = true
    else
        isSecretValue = false
        if phaseID then
            currentPhaseID = phaseID
            currentPhaseSource = source
            db.lastPhaseID = phaseID
            db.lastPhaseSource = source
        end
    end

    lastUpdateTime = _G.GetTime and _G.GetTime() or 0

    -- 触发 UI 更新
    if mod.UpdateUI then
        mod:UpdateUI()
    end
end

-- ============================================================
--  定时器管理
-- ============================================================
local function StopUpdateTimer()
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
end

local function StartUpdateTimer()
    StopUpdateTimer()
    local db = GetDB()
    local interval = (db and db.updateInterval) or 0.5
    interval = math.max(0.1, math.min(interval, 5.0))

    updateTimer = _G.C_Timer.NewTicker(interval, function()
        pcall(UpdatePhaseID)  -- pcall 防瞬态异常导致定时器停止
    end)
end

-- ============================================================
--  公共 API
-- ============================================================
function mod:GetPhaseID()
    return currentPhaseID
end

function mod:GetPhaseSource()
    return currentPhaseSource
end

function mod:IsSecretValue()
    return isSecretValue
end

function mod:ToggleFormat(forceHex)
    local db = GetDB()
    if not db then return end
    if forceHex ~= nil then
        db.useHexadecimal = forceHex
    else
        db.useHexadecimal = not db.useHexadecimal
    end
    if mod.UpdateUI then mod:UpdateUI() end
end

function mod:ToggleFrame()
    local db = GetDB()
    if not db then return end
    db.showFrame = not db.showFrame
    if mod.UpdateFrameVisibility then mod:UpdateFrameVisibility() end
end

function mod:ToggleLock()
    local db = GetDB()
    if not db then return end
    db.isLocked = not db.isLocked
    if mod.UpdateFrameLock then mod:UpdateFrameLock() end
end

function mod:ResetPosition()
    if mod.ResetFramePosition then mod:ResetFramePosition() end
end

function mod:ClearCache()
    currentPhaseID = nil
    currentPhaseSource = nil
    isSecretValue = false
    UpdatePhaseID()
end

function mod:SetUpdateInterval(interval)
    local db = GetDB()
    if not db then return end
    db.updateInterval = math.max(0.1, math.min(interval or 0.5, 5.0))
    StartUpdateTimer()
end

function mod:FormatPhaseID(phaseID, useHex)
    if not phaseID then return "N/A" end
    if useHex then
        return string.format("0x%X", phaseID)
    else
        return tostring(phaseID)
    end
end

-- ============================================================
--  事件处理（Bug#2 修复：SetScript 在 RegisterEvent 之前）
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        UpdatePhaseID()
        StartUpdateTimer()
        if mod.UpdateFrameVisibility then mod:UpdateFrameVisibility() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdatePhaseID()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        UpdatePhaseID()
    elseif event == "PLAYER_REGEN_DISABLED" then
        local db = GetDB()
        if db and db.autoHideInCombat and mod.UpdateFrameVisibility then
            mod:UpdateFrameVisibility()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local db = GetDB()
        if db and db.autoHideInCombat and mod.UpdateFrameVisibility then
            mod:UpdateFrameVisibility()
        end
        UpdatePhaseID()
    end
end)

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- ============================================================
--  初始化
-- ============================================================
function mod:Init()
    local db = GetDB()
    if not db or not db.enabled then return end
    StartUpdateTimer()
    -- 直接调用 InitializeUI：zSuite Core.lua 保证 Init() 在 DB 就绪后才调用
    -- ADDON_LOADED 事件处理器在所有插件上触发，过滤不可靠
    if mod.InitializeUI then
        mod:InitializeUI()
    end
end

-- ============================================================
--  斜杠命令
-- ============================================================
_G.SLASH_PHASEWATCHER1 = "/pw"
_G.SLASH_PHASEWATCHER2 = "/phasewatcher"
_G.SlashCmdList["PHASEWATCHER"] = function(msg)
    msg = msg or ""
    local cmd = string.match(msg, "^(%S+)%s*(.*)$")
    cmd = cmd or msg:lower()

    if cmd == "" or cmd == "toggle" then
        mod:ToggleFrame()
    elseif cmd == "show" then
        local db = GetDB(); if db then db.showFrame = true end
        if mod.UpdateFrameVisibility then mod:UpdateFrameVisibility() end
    elseif cmd == "hide" then
        local db = GetDB(); if db then db.showFrame = false end
        if mod.UpdateFrameVisibility then mod:UpdateFrameVisibility() end
    elseif cmd == "reset" then
        mod:ResetPosition()
    elseif cmd == "clear" then
        mod:ClearCache()
    elseif cmd == "hex" then
        mod:ToggleFormat(true)
    elseif cmd == "dec" then
        mod:ToggleFormat(false)
    elseif cmd == "lock" then
        mod:ToggleLock()
    elseif cmd == "config" then
        if zSuite.OpenOptions then zSuite.OpenOptions() end
    else
        zUI.Print("PhaseWatcher: show | hide | reset | clear | hex | dec | lock | config")
    end
end

function mod:HandleSlash(msg)
    _G.SlashCmdList["PHASEWATCHER"](msg)
end

-- ============================================================
--  设置面板
-- ============================================================
function mod:BuildOptions(content)
    local db = GetDB()
    if not db then return end

    local yOff = -4

    yOff = zUI.OptionsCheckbox(content, yOff, "显示窗口",
        function() return db.showFrame end,
        function(v) db.showFrame = v; if mod.UpdateFrameVisibility then mod:UpdateFrameVisibility() end end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "十六进制显示",
        function() return db.useHexadecimal end,
        function(v) db.useHexadecimal = v; if mod.UpdateUI then mod:UpdateUI() end end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "锁定窗口",
        function() return db.isLocked end,
        function(v) db.isLocked = v; if mod.UpdateFrameLock then mod:UpdateFrameLock() end end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "战斗中自动隐藏",
        function() return db.autoHideInCombat end,
        function(v) db.autoHideInCombat = v end
    )

    yOff = zUI.OptionsSlider(content, yOff, "更新间隔 (秒)", 0.1, 5.0, 0.1,
        function() return db.updateInterval end,
        function(v) mod:SetUpdateInterval(v) end
    )
    yOff = zUI.OptionsSlider(content, yOff, "窗口透明度", 0.1, 1.0, 0.1,
        function() return db.windowAlpha end,
        function(v) db.windowAlpha = v; if mod.UpdateAppearance then mod:UpdateAppearance() end end
    )
    yOff = zUI.OptionsSlider(content, yOff, "字体大小", 10, 32, 1,
        function() return db.fontSize end,
        function(v) db.fontSize = v; if mod.UpdateAppearance then mod:UpdateAppearance() end end
    )
end
