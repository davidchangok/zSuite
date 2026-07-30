--[[
    zUI/OptionsBuilder.lua — 共享分页选项窗体构造器
    为 zSuite 提供带标签页的选项面板基础设施。

    用法：
    local frame = zUI.CreateTabbedOptionsFrame("设置", 600, 500)
    zUI.AddOptionsTab(frame, "general", "常规", function(content)
        -- 使用 zUI.OptionsCheckbox/Slider 等构建
    end)
--]]

local addonName, addonTable = ...

_G.zUI = _G.zUI or {}
local zUI = _G.zUI

-- ============================================================
--  CreateTabbedOptionsFrame
-- ============================================================

--- 创建带标签页的选项窗体外壳
--- @param title string 窗口标题
--- @param width number 窗口宽度（默认 600）
--- @param height number 窗口高度（默认 500）
--- @return table frame     主容器 Frame
--- @return table tabRow    标签按钮行 Frame
--- @return table contentArea 内容区域 Frame
function zUI.CreateTabbedOptionsFrame(title, width, height)
    width = width or 600
    height = height or 500

    -- 主窗口
    local frame = zUI.StyledFrame(nil, nil, "DIALOG", 26)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER", _G.UIParent, "CENTER")
    frame:Hide()

    -- 标题栏
    local titleBar = zUI.TitleBar(frame, 32)
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(zUI.GetDefaultFontTexture(), 13, zUI.GetFontFlags())
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, -1)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -30, -1)
    titleText:SetText(title or "zSuite")
    titleText:SetTextColor(0.85, 0.85, 0.85)
    titleText:SetJustifyH("LEFT")
    frame._titleText = titleText

    -- 关闭按钮
    local closeBtn = zUI.CloseButton(titleBar, function() frame:Hide() end)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    frame._closeBtn = closeBtn

    -- 顶部强调线
    zUI.TopAccent(frame)

    -- 标签按钮行
    local tabRow = CreateFrame("Frame", nil, frame)
    tabRow:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    tabRow:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    tabRow:SetHeight(30)
    frame._tabRow = tabRow

    -- 标签行底部分割线
    local tabDivider = tabRow:CreateTexture(nil, "BORDER")
    tabDivider:SetPoint("BOTTOMLEFT", tabRow, "BOTTOMLEFT", 0, 0)
    tabDivider:SetPoint("BOTTOMRIGHT", tabRow, "BOTTOMRIGHT", 0, 0)
    tabDivider:SetHeight(1)
    tabDivider:SetColorTexture(0.15, 0.15, 0.20, 0.8)

    -- 内容区域
    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", tabRow, "BOTTOMLEFT", 8, -8)
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame._contentArea = contentArea

    -- 内部状态
    frame._tabs = {}
    frame._activeTabId = nil
    frame._tabContents = {}     -- { [tabId] = contentFrame }
    frame._tabBuilders = {}     -- { [tabId] = buildFunc }

    return frame, tabRow, contentArea
end

-- ============================================================
--  AddOptionsTab
-- ============================================================

--- 向选项窗体添加一个标签页
--- 构建函数仅在第一次切换到此标签页时调用（延迟构建）
--- @param frame table 由 CreateTabbedOptionsFrame 返回的主 Frame
--- @param tabId string 标签页唯一标识
--- @param label string 标签按钮文本
--- @param buildFunc function(contentFrame) 构建函数
--- @return table tabBtn 标签按钮
function zUI.AddOptionsTab(frame, tabId, label, buildFunc)
    if not frame or not tabId or not buildFunc then return nil end
    if frame._tabs[tabId] then return frame._tabs[tabId] end

    local tabs = frame._tabs
    local count = 0
    for _ in pairs(tabs) do count = count + 1 end

    -- 存储构建函数
    frame._tabBuilders[tabId] = buildFunc

    -- 创建标签按钮
    local tabBtn = CreateFrame("Button", nil, frame._tabRow, "BackdropTemplate")
    tabBtn:SetHeight(26)
    tabBtn:SetWidth(math.max(70, (#label * 14) + 20))
    tabBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    tabBtn:SetBackdropColor(0.03, 0.05, 0.10, 0.8)
    tabBtn:SetBackdropBorderColor(0.10, 0.10, 0.15, 0.6)

    -- 排列位置
    if count == 0 then
        tabBtn:SetPoint("BOTTOMLEFT", frame._tabRow, "BOTTOMLEFT", 6, 0)
    else
        -- 找到最后一个按钮
        local lastBtn = nil
        for _, t in pairs(tabs) do
            if not lastBtn or t._index > (lastBtn._index or 0) then
                lastBtn = t
            end
        end
        tabBtn:SetPoint("LEFT", lastBtn, "RIGHT", 2, 0)
    end
    tabBtn._index = count + 1

    -- 标签文本
    local tabLabel = tabBtn:CreateFontString(nil, "OVERLAY")
    tabLabel:SetFont(zUI.GetDefaultFontTexture(), 11, zUI.GetFontFlags())
    tabLabel:SetPoint("CENTER", tabBtn, "CENTER", 0, 1)
    tabLabel:SetText(label)
    tabLabel:SetTextColor(0.50, 0.50, 0.50)
    tabBtn._label = tabLabel

    -- 内容 Frame（延迟创建——首次切换到该 tab 时才构建）
    local contentFrame = CreateFrame("Frame", nil, frame._contentArea)
    contentFrame:SetAllPoints(frame._contentArea)
    contentFrame:Hide()
    frame._tabContents[tabId] = contentFrame

    -- Click 处理
    tabBtn:SetScript("OnClick", function()
        zUI.SwitchTab(frame, tabId)
    end)

    -- Hover 效果
    tabBtn:SetScript("OnEnter", function()
        if frame._activeTabId ~= tabId then
            tabBtn:SetBackdropColor(0.05, 0.10, 0.20, 0.9)
            tabBtn:SetBackdropBorderColor(0.20, 0.40, 0.45, 0.8)
        end
    end)
    tabBtn:SetScript("OnLeave", function()
        if frame._activeTabId ~= tabId then
            tabBtn:SetBackdropColor(0.03, 0.05, 0.10, 0.8)
            tabBtn:SetBackdropBorderColor(0.10, 0.10, 0.15, 0.6)
        end
    end)

    frame._tabs[tabId] = tabBtn

    -- 第一个标签页自动激活
    if not frame._activeTabId then
        zUI.SwitchTab(frame, tabId)
    end

    return tabBtn
end

-- ============================================================
--  SwitchTab
-- ============================================================

--- 切换到指定标签页
--- @param frame table 主 Frame
--- @param tabId string 目标标签页 ID
function zUI.SwitchTab(frame, tabId)
    if not frame or not frame._tabs[tabId] then return end
    if frame._activeTabId == tabId then return end

    -- 隐藏旧内容
    if frame._activeTabId then
        local oldBtn = frame._tabs[frame._activeTabId]
        if oldBtn then
            oldBtn:SetBackdropColor(0.03, 0.05, 0.10, 0.8)
            oldBtn:SetBackdropBorderColor(0.10, 0.10, 0.15, 0.6)
            if oldBtn._label then
                oldBtn._label:SetTextColor(0.50, 0.50, 0.50)
            end
        end
        local oldContent = frame._tabContents[frame._activeTabId]
        if oldContent then oldContent:Hide() end
    end

    -- 显示新内容
    frame._activeTabId = tabId
    local newBtn = frame._tabs[tabId]
    if newBtn then
        -- 选中态样式
        newBtn:SetBackdropColor(0.08, 0.18, 0.28, 0.95)
        newBtn:SetBackdropBorderColor(0.20, 0.66, 0.63, 0.9)
        if newBtn._label then
            newBtn._label:SetTextColor(0.20, 0.66, 0.63)
        end
    end

    local content = frame._tabContents[tabId]
    if content then
        -- 延迟构建（仅首次）
        if frame._tabBuilders[tabId] and not content._built then
            frame._tabBuilders[tabId](content)
            content._built = true
        end
        content:Show()
    end
end
