--[[
    PhaseWatcher/UI.lua — 位面 ID 显示窗口
    基于 zUI 完全重建，替换原 PhaseWatcher 2.1.0 的 834 行 UI.lua。

    Bug 修复：
    #1 (高危) — Lua 5.1 闭包变量复用：使用工厂函数模式捕获循环变量
    #3 — 硬编码像素常量 → zUI 动态字号驱动
    #4 — 窗口不显示: 关闭按钮 Hide() 不改 showFrame → 永远隐藏; PEW 不恢复可见性
         修复: closeBtn 设 showFrame=false; ADDON_LOADED 自初始化; PEW 恢复可见性; 初始文字

    窗口风格映射 (Standard/Tooltip/Flat/None → zUI SurfaceVariant)：
    - Standard → PANEL
    - Tooltip  → RAISED
    - Flat     → SOFT
    - None     → BASE (仅文字，背景完全透明)
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

local mod = zSuite.modules.phasewatcher
if not mod then return end

local L = mod.L or _G.zSuitePhaseWatcher_L

-- ============================================================
--  内部
-- ============================================================
local GetDB do
    GetDB = function()
        if not zSuite.db or not zSuite.db.modules then return nil end
        return zSuite.db.modules.phasewatcher
    end
end

-- ============================================================
--  主窗口创建
-- ============================================================
local mainFrame, phaseText

local function CreateMainFrame()
    local db = GetDB()
    if not db then return nil end

    mainFrame = zUI.StyledFrame(nil, nil, "LOW", 15)
    mainFrame:SetSize(220, 60)
    mainFrame:SetMinResize(120, 32)

    -- 标题栏（可拖动）
    local titleBar = zUI.TitleBar(mainFrame, 24)
    zUI.SetupDrag(mainFrame, titleBar, "phasewatcher")

    -- 关闭按钮 —— 设 showFrame = false 后隐藏，与原始 /pw hide 行为一致
    -- Bug#4 修复: 原关闭按钮只 Hide() 不改 showFrame，导致 PEW 重载后窗口永久消失
    local closeBtn = zUI.CloseButton(titleBar, function()
        local d = GetDB()
        if d then d.showFrame = false end
        mainFrame:Hide()
    end)

    -- 顶部强调线
    zUI.TopAccent(mainFrame, 0.20, 0.66, 0.63)

    -- 位面 ID 文字 —— 初始文字避免空窗口
    phaseText = mainFrame:CreateFontString(nil, "OVERLAY")
    phaseText:SetFont(zUI.GetDefaultFontTexture(), db.fontSize or 16, zUI.GetFontFlags())
    phaseText:SetPoint("CENTER", mainFrame, "CENTER", 0, -2)
    phaseText:SetJustifyH("CENTER")
    phaseText:SetText(L.INITIALIZING or "Initializing...")
    phaseText:SetTextColor(0.5, 0.5, 0.5)

    -- 右键菜单
    mainFrame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            ShowContextMenu(self)
        end
    end)

    -- 恢复位置
    zUI.RestoreFramePos(mainFrame, "phasewatcher", 0, -200)

    -- 拖动结束保存位置
    local origDragStop = titleBar:GetScript("OnDragStop")
    titleBar:SetScript("OnDragStop", function()
        if origDragStop then origDragStop() end
        zUI.SaveFramePos(mainFrame, "phasewatcher")
    end)

    return mainFrame
end

-- ============================================================
--  右键菜单（保留 12.0 MenuUtil API）
-- ============================================================
local function ShowContextMenu(owner)
    if not _G.MenuUtil then return end

    _G.MenuUtil.CreateContextMenu(owner, function(root)
        local db = GetDB()
        if not db then return end

        -- 十六进制切换
        root:CreateCheckbox(L.SETTINGS_HEX_FORMAT, db.useHexadecimal, function()
            mod:ToggleFormat()
        end)

        -- 锁定
        root:CreateCheckbox(L.SETTINGS_LOCK_FRAME, db.isLocked, function()
            mod:ToggleLock()
        end)

        root:CreateDivider()

        -- 清除缓存
        root:CreateButton(L.CMD_CLEAR, function() mod:ClearCache() end)

        -- 重置位置
        root:CreateButton(L.SETTINGS_RESET_POS, function() mod:ResetPosition() end)

        root:CreateDivider()

        -- 打开设置
        root:CreateButton(L.CMD_CONFIG, function()
            if zSuite.OpenOptions then zSuite.OpenOptions() end
        end)
    end)
end

-- ============================================================
--  UI 更新
-- ============================================================
function mod:UpdateUI()
    if not mainFrame or not phaseText then return end
    local db = GetDB()
    if not db then return end

    local phaseID = mod:GetPhaseID()
    local source = mod:GetPhaseSource()
    local isSecret = mod:IsSecretValue()

    local displayText
    local r, g, b = 0.5, 0.5, 0.5  -- 默认灰色

    if isSecret then
        displayText = "|cFFFF6600" .. (L.SECRET_VALUE or "Hidden") .. "|r"
        r, g, b = 1.0, 0.4, 0.0
    elseif phaseID then
        local formatted = mod:FormatPhaseID(phaseID, db.useHexadecimal)
        displayText = "|cFF33FF99Phase: " .. formatted .. "|r"
        r, g, b = 0.20, 1.0, 0.60
    elseif source == "cached" then
        displayText = "|cFF888888" .. (L.CACHED or "Cached") .. "|r"
        r, g, b = 0.5, 0.5, 0.5
    else
        displayText = "|cFFFF4444" .. (L.NOT_DETECTED or "Not Detected") .. "|r"
        r, g, b = 1.0, 0.27, 0.27
    end

    phaseText:SetText(displayText)
    phaseText:SetTextColor(r, g, b)

    -- 自适应窗口大小
    local textW = phaseText:GetStringWidth()
    if textW and textW > 0 then
        mainFrame:SetWidth(math.max(140, textW + 40))
    end
end

function mod:UpdateFrameVisibility()
    if not mainFrame then return end
    local db = GetDB()
    if not db then return end

    if not db.showFrame then
        mainFrame:Hide()
        return
    end

    local inCombat = _G.InCombatLockdown and _G.InCombatLockdown()
    if db.autoHideInCombat and inCombat then
        mainFrame:Hide()
        return
    end

    mainFrame:Show()
end

function mod:UpdateFrameLock()
    if not mainFrame then return end
    local db = GetDB()
    if not db then return end
    mainFrame:SetMovable(not db.isLocked)
end

function mod:UpdateAppearance()
    if not mainFrame or not phaseText then return end
    local db = GetDB()
    if not db then return end

    -- 窗口风格 → zUI SurfaceVariant 映射
    local variantMap = {
        Standard = "PANEL",
        Tooltip = "RAISED",
        Flat = "SOFT",
        None = "BASE",
    }
    local variant = variantMap[db.windowStyle or "Standard"] or "PANEL"

    -- 应用表面
    if db.windowStyle == "None" then
        zUI.ApplySurface(mainFrame, "BASE", 0)
    else
        zUI.ApplySurface(mainFrame, variant, db.windowAlpha)
    end

    -- 字体
    phaseText:SetFont(zUI.GetDefaultFontTexture(), db.fontSize or 16, zUI.GetFontFlags())

    mod:UpdateUI()
end

function mod:ResetFramePosition()
    if not mainFrame then return end
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, -200)
    zUI.SaveFramePos(mainFrame, "phasewatcher")
end

-- ============================================================
--  初始化 (公开 — 由 Core.lua 的 ADDON_LOADED 调用)
-- ============================================================
function mod:InitializeUI()
    local db = GetDB()
    if not db or not db.showFrame then return end

    if not mainFrame then
        CreateMainFrame()
    end

    if mainFrame then
        mod:UpdateAppearance()
        mod:UpdateUI()
        mod:UpdateFrameVisibility()
    end
end
