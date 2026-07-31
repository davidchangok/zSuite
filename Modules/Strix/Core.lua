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

-- ============================================================
--  图标辅助函数
-- ============================================================
local raceCorrections = { scourge = "undead" }

-- 使用 11.0+ 官方 API C_ClassColor.GetClassColor(classFile)
local function ClassColorWrap(name, classFile)
    if not name or not classFile then return name or "?" end
    local c = _G.C_ClassColor and _G.C_ClassColor.GetClassColor(classFile)
    if c and c.GenerateHexColor then
        return "|c" .. c:GenerateHexColor() .. name .. "|r"
    end
    return name
end

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
    return GetFactionIconString(alt.faction) .. ClassColorWrap(alt.name, alt.classFile)
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
    local alts = mod.Data:GetAlts()
    local recent = mod.Data:GetRecentRecipients()
    local altLimit = mod.Data:GetDisplayLimit()
    local recentLimit = mod.Data:GetRecentDisplayLimit()

    -- My Alts
    rootDescription:CreateTitle(L.HEADER_MY_ALTS)
    local altCount = 0
    for i, alt in ipairs(alts) do
        if altCount >= altLimit then break end
        local text = GetFormattedName(alt) .. "  |cFF888888" .. GetLevelString(alt.level) .. "|r"
        rootDescription:CreateButton(text, function()
            if _G.SendMailNameEditBox then
                _G.SendMailNameEditBox:SetText(alt.name .. "-" .. (alt.realm or ""))
                if _G.SendMailFrame and _G.SendMailFrame.SendMailButton then
                    _G.SendMailFrame.SendMailButton:Click()
                end
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
                if _G.SendMailFrame and _G.SendMailFrame.SendMailButton then
                    _G.SendMailFrame.SendMailButton:Click()
                end
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
    _G.MenuUtil.CreateContextMenu(_G.UIParent, function(owner, rootDescription) BuildMenu(rootDescription) end)
end

-- ============================================================
--  邮箱钩子
-- ============================================================
local isHooked = false

local function HookMailBox()
    if isHooked then return end
    if not _G.SendMailNameEditBox then return end

    isHooked = true
    -- 下拉按钮（按原 Strix 锚定到 SendMailFrame + SendMailNameEditBoxMiddle）
    if not mod._dropdownBtn then
        local btn = CreateFrame("Button", nil, _G.SendMailFrame)
        btn:SetSize(20, 20)
        btn:SetFrameLevel(_G.SendMailNameEditBox:GetFrameLevel() + 1)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrow:SetPoint("CENTER")
        arrow:SetText("\226\150\188")
        arrow:SetTextColor(1, 0.82, 0)
        btn:SetScript("OnClick", function() ShowContextMenu() end)
        btn:SetScript("OnEnter", function()
            local tip = GetOrCreateTooltip()
            tip:SetOwner(btn, "ANCHOR_RIGHT")
            tip:SetText(L.TOOLTIP_TITLE)
            tip:Show()
        end)
        btn:SetScript("OnLeave", function()
            local tip = GetOrCreateTooltip()
            tip:Hide()
        end)
        mod._dropdownBtn = btn
        local middle = _G.SendMailNameEditBoxMiddle or (_G.SendMailNameEditBox and _G.SendMailNameEditBox.Middle)
        if middle then
            btn:SetPoint("RIGHT", middle, "RIGHT", 24, 0)
        else
            local editW = _G.SendMailNameEditBox:GetWidth()
            local _, rightInset = _G.SendMailNameEditBox:GetTextInsets()
            btn:SetPoint("RIGHT", _G.SendMailNameEditBox, "LEFT", editW - (rightInset or 4), 0)
        end
    end

    -- 右键输入框弹出菜单
    _G.SendMailNameEditBox:HookScript("OnMouseDown", function(_, button)
        if button == "RightButton" then ShowContextMenu() end
    end)

    -- 悬停提示（使用私有 tooltip，避免污染 GameTooltip）
    _G.SendMailNameEditBox:HookScript("OnEnter", function(self)
        local tip = GetOrCreateTooltip()
        tip:SetOwner(self, "ANCHOR_TOPRIGHT")
        tip:AddLine(L.TOOLTIP_TITLE, 0, 1, 0)
        tip:AddLine(L.TOOLTIP_HINT, 1, 1, 1)
        tip:Show()
    end)
    _G.SendMailNameEditBox:HookScript("OnLeave", function()
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
        mod.Data:AddRecentRecipient(name, realm ~= "" and realm or _G.GetRealmName())
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
            if mod.Data:IsMyAlt(key) then
                mod.Data:PromoteAltToFirst(key)
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
        mod.Data:RegisterCurrentCharacter()
    elseif event == "MAIL_SHOW" then
        HookMailBox()
        mod.Data:RegisterCurrentCharacter()
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
--  设置面板（重建自原 Strix Core.lua SetupAltsTab / SetupRecentTab）
--  提供完整的双标签页管理：小号列表、最近收件人列表
-- ============================================================
function mod:BuildOptions(content)
    local db = zSuite.db and zSuite.db.modules and zSuite.db.modules.strix
    if not db then return end

    -- 主开关
    local yOff = -4
    yOff = zUI.OptionsCheckbox(content, yOff, "启用 Strix",
        function() return db.enabled end,
        function(v) db.enabled = v end
    )

    -- === 子标签按钮 ===
    local subTabAlts = CreateFrame("Button", nil, content, "BackdropTemplate")
    subTabAlts:SetSize(90, 22)
    subTabAlts:SetPoint("TOPLEFT", content, "TOPLEFT", 8, yOff - 6)
    subTabAlts:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})

    local subTabRecent = CreateFrame("Button", nil, content, "BackdropTemplate")
    subTabRecent:SetSize(90, 22)
    subTabRecent:SetPoint("LEFT", subTabAlts, "RIGHT", 2, 0)

    -- 子标签文字
    local function MkTabLabel(btn, text)
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(zUI.GetDefaultFontTexture(), 11, zUI.GetFontFlags())
        lbl:SetPoint("CENTER", btn, "CENTER", 0, 1)
        lbl:SetText(text)
        return lbl
    end
    local altTabLabel = MkTabLabel(subTabAlts, L.TAB_MY_ALTS or "My Alts")
    local recTabLabel = MkTabLabel(subTabRecent, L.TAB_RECENT or "Recent")

    -- 子标签内容区域
    local listArea = CreateFrame("Frame", nil, content)
    listArea:SetPoint("TOPLEFT", subTabAlts, "BOTTOMLEFT", 0, -6)
    listArea:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -4, 4)

    -- 内容区分为两个容器
    local altsContainer = CreateFrame("Frame", nil, listArea)
    altsContainer:SetAllPoints(listArea)
    local recContainer = CreateFrame("Frame", nil, listArea)
    recContainer:SetAllPoints(listArea)
    recContainer:Hide()

    -- === 小号列表容器 ===
    -- 滑块
    local altSlider = CreateFrame("Slider", nil, altsContainer, "OptionsSliderTemplate")
    altSlider:SetPoint("BOTTOMLEFT", altsContainer, "BOTTOMLEFT", 0, 0)
    altSlider:SetPoint("BOTTOMRIGHT", altsContainer, "BOTTOMRIGHT", 0, 0)
    altSlider:SetMinMaxValues(1, 20)
    altSlider:SetValueStep(1)
    altSlider:SetObeyStepOnDrag(true)
    altSlider:SetValue(mod.Data:GetDisplayLimit())
    altSlider.Low:SetText("1"); altSlider.High:SetText("20")
    local function UpdateAltsSliderText(val)
        local label = L.OPTIONS_SLIDER_ALTS and string.format(L.OPTIONS_SLIDER_ALTS, val) or ("Alts displayed: %d"):format(val)
        if altSlider.Text then altSlider.Text:SetText(label) end
    end
    UpdateAltsSliderText(altSlider:GetValue())
    altSlider:SetScript("OnValueChanged", function(self, v)
        local val = math.floor(v)
        mod.Data:SetDisplayLimit(val)
        UpdateAltsSliderText(val)
    end)

    -- 小号滚动列表
    local altScroll = CreateFrame("ScrollFrame", nil, altsContainer, "UIPanelScrollFrameTemplate")
    altScroll:SetPoint("TOPLEFT", altsContainer, "TOPLEFT", 0, -4)
    altScroll:SetPoint("BOTTOMRIGHT", altSlider, "TOPRIGHT", -20, 6)

    local altScrollChild = CreateFrame("Frame", nil, altScroll)
    altScrollChild:SetSize(540, 20)
    altScroll:SetScrollChild(altScrollChild)

    local altRows = {}

    local function RefreshAltList()
        for _, row in ipairs(altRows) do row:Hide() end
        local alts = mod.Data:GetAlts()
        local limit = mod.Data:GetDisplayLimit()
        local rowH = 24
        for i = 1, #alts do
            if i > limit then break end
            local alt = alts[i]
            local row = altRows[i]
            if not row then
                row = CreateFrame("Button", nil, altScrollChild)
                row:SetSize(520, rowH)
                row:SetHighlightAtlas("search-highlight")
                -- 职业颜色名
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetPoint("RIGHT", -28, 0)
                -- 删除按钮
                row.delBtn = CreateFrame("Button", nil, row)
                row.delBtn:SetNormalAtlas("transmog-icon-remove")
                row.delBtn:SetSize(14, 14)
                row.delBtn:SetPoint("RIGHT", -4, 0)
                row.delBtn:SetScript("OnClick", function()
                    if row.altIndex then
                        mod.Data:DeleteAltByIndex(row.altIndex)
                        RefreshAltList()
                    end
                end)
                altRows[i] = row
            end
            row.altIndex = i
            local nameStr = ClassColorWrap(alt.name, alt.classFile)
            local realmStr = alt.realm and (" |cFF888888(" .. alt.realm .. ")|r") or ""
            local levelStr = L.LEVEL_FORMAT and string.format(L.LEVEL_FORMAT, alt.level or 0) or ("Lv." .. (alt.level or "?"))
            row.text:SetText(nameStr .. realmStr .. "  " .. levelStr)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", altScrollChild, "TOPLEFT", 0, -(i - 1) * rowH)
            row:Show()
        end
        altScrollChild:SetHeight(math.max(20, (#mod.Data:GetAlts()) * rowH + 4))
    end

    -- === 最近收件人列表容器 ===
    local recSlider = CreateFrame("Slider", nil, recContainer, "OptionsSliderTemplate")
    recSlider:SetPoint("BOTTOMLEFT", recContainer, "BOTTOMLEFT", 0, 0)
    recSlider:SetPoint("BOTTOMRIGHT", recContainer, "BOTTOMRIGHT", 0, 0)
    recSlider:SetMinMaxValues(1, 50)
    recSlider:SetValueStep(1)
    recSlider:SetObeyStepOnDrag(true)
    recSlider:SetValue(mod.Data:GetRecentDisplayLimit())
    recSlider.Low:SetText("1"); recSlider.High:SetText("50")
    local function UpdateRecSliderText(val)
        local label = L.OPTIONS_SLIDER_RECENT and string.format(L.OPTIONS_SLIDER_RECENT, val) or ("Recents displayed: %d"):format(val)
        if recSlider.Text then recSlider.Text:SetText(label) end
    end
    UpdateRecSliderText(recSlider:GetValue())
    recSlider:SetScript("OnValueChanged", function(self, v)
        local val = math.floor(v)
        mod.Data:SetRecentDisplayLimit(val)
        UpdateRecSliderText(val)
    end)

    -- Auto-remove checkbox
    local autoRemoveCB = CreateFrame("CheckButton", nil, recContainer, "UICheckButtonTemplate")
    autoRemoveCB:SetPoint("BOTTOMLEFT", recSlider, "TOPLEFT", 0, 6)
    autoRemoveCB:SetSize(20, 20)
    autoRemoveCB:SetChecked(mod.Data:GetAutoRemoveIfAlt())
    autoRemoveCB:SetScript("OnClick", function(self)
        mod.Data:SetAutoRemoveIfAlt(self:GetChecked())
    end)
    local cbLabel = autoRemoveCB:CreateFontString(nil, "OVERLAY")
    cbLabel:SetFont(zUI.GetDefaultFontTexture(), 11, zUI.GetFontFlags())
    cbLabel:SetPoint("LEFT", autoRemoveCB, "RIGHT", 4, -1)
    cbLabel:SetText(L.AUTO_REMOVE_IF_ALT or "Auto-remove when registered as alt")
    cbLabel:SetTextColor(0.85, 0.85, 0.85)

    -- 最近收件人滚动列表
    local recScroll = CreateFrame("ScrollFrame", nil, recContainer, "UIPanelScrollFrameTemplate")
    recScroll:SetPoint("TOPLEFT", recContainer, "TOPLEFT", 0, -4)
    recScroll:SetPoint("BOTTOMRIGHT", autoRemoveCB, "TOPRIGHT", -20, 6)

    local recScrollChild = CreateFrame("Frame", nil, recScroll)
    recScrollChild:SetSize(540, 20)
    recScroll:SetScrollChild(recScrollChild)

    local recRows = {}

    local function RefreshRecList()
        for _, row in ipairs(recRows) do row:Hide() end
        local recs = mod.Data:GetRecentRecipients()
        local limit = mod.Data:GetRecentDisplayLimit()
        local rowH = 24
        for i = 1, #recs do
            if i > limit then break end
            local r = recs[i]
            local row = recRows[i]
            if not row then
                row = CreateFrame("Button", nil, recScrollChild)
                row:SetSize(520, rowH)
                row:SetHighlightAtlas("search-highlight")
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetPoint("RIGHT", -52, 0)
                -- Move to alts
                row.moveBtn = CreateFrame("Button", nil, row)
                row.moveBtn:SetNormalAtlas("communities-icon-addgroupplus")
                row.moveBtn:SetSize(14, 14)
                row.moveBtn:SetPoint("RIGHT", -20, 0)
                row.moveBtn:SetScript("OnClick", function()
                    if row.recIndex then
                        mod.Data:MoveRecentToAlts(row.recIndex)
                        RefreshRecList()
                        RefreshAltList()
                    end
                end)
                -- Delete
                row.delBtn = CreateFrame("Button", nil, row)
                row.delBtn:SetNormalAtlas("transmog-icon-remove")
                row.delBtn:SetSize(14, 14)
                row.delBtn:SetPoint("RIGHT", -4, 0)
                row.delBtn:SetScript("OnClick", function()
                    if row.recIndex then
                        mod.Data:RemoveRecentByIndex(row.recIndex)
                        RefreshRecList()
                    end
                end)
                recRows[i] = row
            end
            row.recIndex = i
            local display = r.name or "?"
            if r.realm and r.realm ~= "" then
                display = display .. " |cFF888888(" .. r.realm .. ")|r"
            end
            row.text:SetText(display)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", recScrollChild, "TOPLEFT", 0, -(i - 1) * rowH)
            row:Show()
        end
        recScrollChild:SetHeight(math.max(20, (#mod.Data:GetRecentRecipients()) * rowH + 4))
    end

    -- 刷新定时器（延迟刷新以等待 DB 就绪）
    local function DelayedRefresh()
        _G.C_Timer.After(0.1, function()
            RefreshAltList()
            RefreshRecList()
        end)
    end

    -- === 子标签切换 ===
    local function SelectSubTab(tab)
        if tab == 1 then
            subTabAlts:SetBackdropColor(0.08, 0.18, 0.28, 0.95)
            subTabAlts:SetBackdropBorderColor(0.20, 0.66, 0.63, 0.9)
            altTabLabel:SetTextColor(0.20, 0.66, 0.63)
            subTabRecent:SetBackdropColor(0.03, 0.05, 0.10, 0.8)
            subTabRecent:SetBackdropBorderColor(0.10, 0.10, 0.15, 0.6)
            recTabLabel:SetTextColor(0.50, 0.50, 0.50)
            altsContainer:Show()
            recContainer:Hide()
        else
            subTabRecent:SetBackdropColor(0.08, 0.18, 0.28, 0.95)
            subTabRecent:SetBackdropBorderColor(0.20, 0.66, 0.63, 0.9)
            recTabLabel:SetTextColor(0.20, 0.66, 0.63)
            subTabAlts:SetBackdropColor(0.03, 0.05, 0.10, 0.8)
            subTabAlts:SetBackdropBorderColor(0.10, 0.10, 0.15, 0.6)
            altTabLabel:SetTextColor(0.50, 0.50, 0.50)
            altsContainer:Hide()
            recContainer:Show()
            RefreshRecList()
        end
    end

    subTabAlts:SetScript("OnClick", function() SelectSubTab(1) end)
    subTabRecent:SetScript("OnClick", function() SelectSubTab(2) end)

    -- 初始状态
    SelectSubTab(1)
    DelayedRefresh()
end
