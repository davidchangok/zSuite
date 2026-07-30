--[[
    PhaseWatcher/UI.lua — 位面 ID 显示窗口
    一个简单的可拖动窗口：居中显示、拖动保存位置、右键菜单。
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

local mod = zSuite.modules.phasewatcher
if not mod then return end

local L = mod.L or _G.zSuitePhaseWatcher_L

local mainFrame, phaseText

-- ============================================================
--  快速 DB 访问
-- ============================================================
local function DB()
    if zSuite.db and zSuite.db.modules then
        return zSuite.db.modules.phasewatcher
    end
end

-- ============================================================
--  创建窗口
-- ============================================================
local function CreateWindow()
    local db = DB()
    if not db then return end

    -- zUI 暗色风格窗体
    mainFrame = zUI.StyledFrame(nil, nil, "HIGH", 50)
    mainFrame:SetSize(220, 60)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetClampedToScreen(true)

    -- 标题栏
    local titleBar = zUI.TitleBar(mainFrame, 22)

    -- 关闭按钮
    zUI.CloseButton(titleBar, function()
        db.showFrame = false
        mainFrame:Hide()
    end)

    -- 顶部绿线
    zUI.TopAccent(mainFrame, 0.20, 0.66, 0.63)

    -- 文字
    phaseText = mainFrame:CreateFontString(nil, "OVERLAY")
    phaseText:SetPoint("CENTER")
    phaseText:SetJustifyH("CENTER")

    -- 右键菜单
    mainFrame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and _G.MenuUtil then
            _G.MenuUtil.CreateContextMenu(self, function(root)
                local d = DB()
                if not d then return end
                root:CreateCheckbox(L.SETTINGS_HEX_FORMAT, d.useHexadecimal, function() mod:ToggleFormat() end)
                root:CreateCheckbox(L.SETTINGS_LOCK_FRAME, d.isLocked, function() mod:ToggleLock() end)
                root:CreateDivider()
                root:CreateButton(L.CMD_CLEAR, function() mod:ClearCache() end)
                root:CreateButton(L.SETTINGS_RESET_POS, function()
                    mainFrame:ClearAllPoints()
                    mainFrame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
                    db.posX = nil; db.posY = nil
                end)
                root:CreateDivider()
                root:CreateButton(L.CMD_CONFIG, function()
                    if zSuite.OpenOptions then zSuite.OpenOptions() end
                end)
            end)
        end
    end)

    -- 拖动：保存位置到 DB
    mainFrame:SetScript("OnDragStart", function()
        if not db.isLocked then mainFrame:StartMoving() end
    end)
    mainFrame:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        local x, y = mainFrame:GetCenter()
        local cx, cy = _G.UIParent:GetCenter()
        if x and cx then
            db.posX = math.floor(x - cx)
            db.posY = math.floor(y - cy)
        end
    end)

    -- 恢复保存的位置，否则居中
    mainFrame:ClearAllPoints()
    if db.posX and db.posY then
        mainFrame:SetPoint("CENTER", _G.UIParent, "CENTER", db.posX, db.posY)
    else
        mainFrame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    end

    -- 窗口背景透明度（仅背景，不影响文字）
    mainFrame:SetBackdropColor(zUI.COLORS.bg[1], zUI.COLORS.bg[2], zUI.COLORS.bg[3], db.windowAlpha or 1.0)
    -- 锁定
    if db.isLocked then mainFrame:SetMovable(false) end

    mainFrame:Show()
end

-- ============================================================
--  UI 更新
-- ============================================================
function mod:UpdateUI()
    if not mainFrame or not phaseText then return end
    local db = DB()
    if not db then return end

    local id, src, secret = mod:GetPhaseID(), mod:GetPhaseSource(), mod:IsSecretValue()
    local text, r, g, b

    if secret then
        text = L.SECRET_VALUE or "Hidden"
        r, g, b = 1, 0.4, 0
    elseif id then
        text = "Phase: " .. mod:FormatPhaseID(id, db.useHexadecimal)
        r, g, b = 0.20, 1, 0.60
    elseif src == "cached" then
        text = L.CACHED or "Cached"
        r, g, b = 0.5, 0.5, 0.5
    else
        text = L.NOT_DETECTED or "Not Detected"
        r, g, b = 1, 0.27, 0.27
    end

    phaseText:SetFont(zUI.GetDefaultFontTexture(), db.fontSize or 16, zUI.GetFontFlags())
    phaseText:SetText(text)
    phaseText:SetTextColor(r, g, b, db.textAlpha or 1.0)

    local w = phaseText:GetStringWidth()
    if w and w > 0 then mainFrame:SetWidth(math.max(140, w + 40)) end
end

function mod:UpdateFrameVisibility()
    if not mainFrame then return end
    local db = DB()
    if not db then return end
    if not db.showFrame then mainFrame:Hide(); return end
    if db.autoHideInCombat and _G.InCombatLockdown and _G.InCombatLockdown() then mainFrame:Hide(); return end
    mainFrame:Show()
end

function mod:UpdateFrameLock()
    if mainFrame then mainFrame:SetMovable(not (DB() and DB().isLocked)) end
end

function mod:UpdateAppearance()
    if mainFrame then
        local db = DB()
        if db then
            -- 窗口透明度：只改 backdrop 背景 alpha，文字不受影响
            local bg = zUI.COLORS.bg
            mainFrame:SetBackdropColor(bg[1], bg[2], bg[3], db.windowAlpha or 1.0)
        end
    end
end

function mod:ResetFramePosition()
    if not mainFrame then return end
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    local db = DB(); if db then db.posX = nil; db.posY = nil end
end

-- ============================================================
--  初始化
-- ============================================================
function mod:InitializeUI()
    if DB() and DB().showFrame and not mainFrame then
        CreateWindow()
        mod:UpdateUI()
    end
end
