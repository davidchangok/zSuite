--[[
    Strix/Core.lua — 邮件收件人地址簿模块
    从 Strix 1.1.1 迁移至 zSuite。

    Bug 修复：
    #2 — 私人 tooltip 重命名为 zSuiteStrixTooltip，避免跨插件碰撞

    功能：
    - 邮箱打开时自动注册当前角色为小号
    - 收件人输入框旁下拉按钮 + 右键菜单（MenuUtil.CreateContextMenu）
    - MAIL_SEND_SUCCESS 追踪最近收件人
    - MAIL_INBOX_UPDATE 自动提升小号排序
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

-- ============================================================
--  模块注册
-- ============================================================
local mod = {
    name = "strix",
    enabled = true,
}
zSuite.RegisterModule("strix", mod)

local L = mod.L or _G.zSuiteStrix_L
local Data = mod.Data

-- ============================================================
--  图标辅助函数
-- ============================================================
local raceCorrections = { scourge = "undead" }

local function GetRaceAtlas(race, sex)
    if not race then return "raceicon128-human-male" end
    local raceFile = raceCorrections[race] or race
    local sexStr = (sex == 2 and "female") or "male"
    -- 使用 Blizzard 12.0 标准纹理路径
    return "raceicon128-" .. raceFile:gsub("%s+", ""):lower() .. "-" .. sexStr
end

local function GetFactionIconString(faction)
    if not faction then return "" end
    if faction == "Alliance" then
        return "|TInterface\\PVPFrame\\PVP-Currency-Alliance:14:14:0:0|t "
    elseif faction == "Horde" then
        return "|TInterface\\PVPFrame\\PVP-Currency-Horde:14:14:0:0|t "
    end
    return ""
end

local function GetLevelString(level)
    return level and ("Lv." .. tostring(level)) or "Lv.?"
end

local function GetFormattedName(alt)
    if not alt then return "?" end
    return GetFactionIconString(alt.faction) ..
           (alt.classFile and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[alt.classFile]
            and zUI.WrapColor(_G.RAID_CLASS_COLORS[alt.classFile].colorStr, alt.name or "?")
            or alt.name or "?")
end

-- ============================================================
--  Tooltip（Bug#2 修复：唯一名称）
-- ============================================================
local StrixTooltip
local function GetOrCreateTooltip()
    if StrixTooltip then return StrixTooltip end
    StrixTooltip = CreateFrame("GameTooltip", "zSuiteStrixTooltip", _G.UIParent, "GameTooltipTemplate")
    StrixTooltip:SetOwner(_G.UIParent, "ANCHOR_NONE")
    return StrixTooltip
end

-- ============================================================
--  上下文菜单
-- ============================================================
local function BuildMenu(rootDescription)
    local alts = Data:GetAlts()
    local recent = Data:GetRecentRecipients()
    local altLimit = Data:GetDisplayLimit()
    local recentLimit = Data:GetRecentDisplayLimit()

    -- My Alts
    rootDescription:CreateTitle(L.HEADER_MY_ALTS)
    local altCount = 0
    for i, alt in ipairs(alts) do
        if altCount >= altLimit then break end
        local text = GetFormattedName(alt) .. "  |cFF888888" .. GetLevelString(alt.level) .. "|r"
        rootDescription:CreateButton(text, function()
            if _G.SendMailNameEditBox then
                _G.SendMailNameEditBox:SetText(alt.name .. "-" .. (alt.realm or ""))
                _G.SendMailFrame and _G.SendMailFrame.SendMailButton and _G.SendMailFrame.SendMailButton:Click()
            end
        end)
        altCount = altCount + 1
    end
    if altCount == 0 then
        rootDescription:CreateTitle(L.MENU_NO_RECORDS)
    end

    -- Recent Recipients
    rootDescription:CreateDivider()
    rootDescription:CreateTitle(L.HEADER_RECENT_RECIPIENTS)
    local recCount = 0
    for i, r in ipairs(recent) do
        if recCount >= recentLimit then break end
        rootDescription:CreateButton(r.name .. "-" .. (r.realm or ""), function()
            if _G.SendMailNameEditBox then
                _G.SendMailNameEditBox:SetText(r.name .. "-" .. (r.realm or ""))
                _G.SendMailFrame and _G.SendMailFrame.SendMailButton and _G.SendMailFrame.SendMailButton:Click()
            end
        end)
        recCount = recCount + 1
    end
    if recCount == 0 then
        rootDescription:CreateTitle(L.MENU_NO_RECORDS)
    end

    -- Manage
    rootDescription:CreateDivider()
    rootDescription:CreateButton(L.MENU_MANAGE_LIST, function()
        if zSuite.OpenOptions then zSuite.OpenOptions() end
    end)
end

local function ShowContextMenu()
    if not _G.MenuUtil then return end
    _G.MenuUtil.CreateContextMenu(_G.UIParent, BuildMenu)
end

-- ============================================================
--  邮箱钩子
-- ============================================================
local isHooked = false

local function HookMailBox()
    if isHooked then return end
    if not _G.SendMailNameEditBox then return end

    isHooked = true

    -- 下拉按钮
    local dropdownBtn = CreateFrame("Button", nil, _G.SendMailNameEditBox)
    dropdownBtn:SetSize(20, 20)
    dropdownBtn:SetPoint("LEFT", _G.SendMailNameEditBox, "RIGHT", 2, 0)

    local btnTex = dropdownBtn:CreateTexture(nil, "OVERLAY")
    btnTex:SetAllPoints()
    btnTex:SetColorTexture(0.10, 0.20, 0.30, 0.8)
    dropdownBtn:SetScript("OnClick", ShowContextMenu)
    dropdownBtn:SetScript("OnEnter", function()
        btnTex:SetColorTexture(0.20, 0.66, 0.63, 0.9)
    end)
    dropdownBtn:SetScript("OnLeave", function()
        btnTex:SetColorTexture(0.10, 0.20, 0.30, 0.8)
    end)

    -- 右键菜单
    _G.SendMailNameEditBox:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            ShowContextMenu()
        end
    end)

    -- 悬停提示
    _G.SendMailNameEditBox:SetScript("OnEnter", function(self)
        local tip = GetOrCreateTooltip()
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:SetText(L.TOOLTIP_TITLE, 0.20, 0.66, 0.63)
        tip:AddLine(L.TOOLTIP_HINT, 1, 1, 1)
        tip:Show()
    end)
    _G.SendMailNameEditBox:SetScript("OnLeave", function()
        local tip = GetOrCreateTooltip()
        tip:Hide()
    end)
end

-- ============================================================
--  邮件发送追踪
-- ============================================================
local function OnMailSent()
    if not _G.SendMailNameEditBox then return end
    local text = _G.SendMailNameEditBox:GetText()
    if not text or text == "" then return end
    local name, realm = string.match(text, "^([^%-]+)%-?(.*)$")
    if name then
        Data:AddRecentRecipient(name, realm ~= "" and realm or _G.GetRealmName())
    end
end

-- ============================================================
--  收件箱检测（自动提升小号排序）
-- ============================================================
local lastInboxCheck = 0
local function CheckInboxForAlts()
    -- 5 秒冷却
    local now = _G.GetTime and _G.GetTime() or 0
    if now - lastInboxCheck < 5 then return end
    lastInboxCheck = now

    local numItems = _G.GetInboxNumItems and _G.GetInboxNumItems() or 0
    for i = 1, math.min(numItems, 50) do
        local _, _, _, _, _, _, _, _, _, _, senderName = _G.GetInboxHeaderInfo(i)
        if senderName then
            local name = string.match(senderName, "^([^%-]+)")
            local realm = string.match(senderName, "%-(.+)$")
            local key = (name and name:gsub("%s+", ""):lower() or "") .. "-" ..
                        (realm and realm:gsub("%s+", ""):lower() or _G.GetRealmName and _G.GetRealmName():gsub("%s+", ""):lower() or "")
            if Data:IsMyAlt(key) then
                Data:PromoteAltToFirst(key)
                break  -- 每次只提升一个
            end
        end
    end
end

-- ============================================================
--  事件处理
-- ============================================================
local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        -- 等待 zSuite DB 就绪
    elseif event == "PLAYER_LOGIN" then
        Data:RegisterCurrentCharacter()
    elseif event == "MAIL_SHOW" then
        HookMailBox()
        Data:RegisterCurrentCharacter()
    elseif event == "MAIL_SEND_SUCCESS" then
        OnMailSent()
    elseif event == "MAIL_INBOX_UPDATE" then
        CheckInboxForAlts()
    end
end)

-- ============================================================
--  初始化
-- ============================================================
function mod:Init()
    if not mod.enabled then return end
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
    eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
end

-- ============================================================
--  斜杠命令
-- ============================================================
_G.SLASH_STRIX1 = "/strix"
_G.SlashCmdList["STRIX"] = function()
    if zSuite.OpenOptions then zSuite.OpenOptions() end
end

function mod:HandleSlash(msg)
    if zSuite.OpenOptions then zSuite.OpenOptions() end
end

-- ============================================================
--  设置面板
-- ============================================================
function mod:BuildOptions(content)
    local db = zSuite.db and zSuite.db.modules and zSuite.db.modules.strix
    if not db then return end

    local yOff = -4

    yOff = zUI.OptionsCheckbox(content, yOff, "启用 Strix",
        function() return db.enabled end,
        function(v) db.enabled = v end
    )
    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8
    yOff = zUI.OptionsSlider(content, yOff, "小号显示数量", 1, 99, 1,
        function() return db.displayLimit end,
        function(v) Data:SetDisplayLimit(v) end
    )
    yOff = zUI.OptionsSlider(content, yOff, "最近收件人数量", 1, 50, 1,
        function() return db.recentDisplayLimit end,
        function(v) Data:SetRecentDisplayLimit(v) end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "成为小号时自动移除",
        function() return db.autoRemoveIfAlt end,
        function(v) Data:SetAutoRemoveIfAlt(v) end
    )
end
