--[[
    zUI/ScrollBar.lua — 统一自定义滚动条工厂
    从 MidnightRoutine UI.lua 的 ns.AttachScrollList 提取。
    合并了 MR 中三处重复的滚动条实现为一套干净版本。

    特性：
    - 鼠标滚轮滚动（delta×30 像素/刻度）
    - Track 点击跳转到对应位置
    - Thumb 拖拽（含 OnUpdate 持续拖拽）
    - 内容 <= 可视区时自动隐藏 thumb
    - OnScrollRangeChanged / OnVerticalScroll 自动同步
--]]

local addonName, addonTable = ...

_G.zUI = _G.zUI or {}
local zUI = _G.zUI

--- 为标准 ScrollFrame 附加自定义滚动条
--- @param scrollFrame table ScrollFrame（需是 WoW ScrollFrame 控件）
--- @param contentFrame table ScrollFrame 的内容子框架
--- @param trackFrame table 滚动条轨道 Frame
--- @return function updateFunc  手动触发滚动条刷新的函数
--- @return table   thumb         滑块按钮
--- @return table   trackBg       轨道背景纹理
--- @return table   thumbTex      滑块纹理
function zUI.AttachScrollBar(scrollFrame, contentFrame, trackFrame)
    if not scrollFrame or not trackFrame then
        return function() end
    end

    scrollFrame:EnableMouseWheel(true)
    if contentFrame then
        scrollFrame:SetScrollChild(contentFrame)
    end

    local trackBg = trackFrame:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.3)

    local thumb = CreateFrame("Button", nil, trackFrame)
    thumb:SetPoint("LEFT", trackFrame, "LEFT", 0, 0)
    thumb:SetPoint("RIGHT", trackFrame, "RIGHT", 0, 0)
    thumb:EnableMouse(true)
    thumb:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.20, 0.66, 0.63, 0.7)

    -- ============================================================
    --  内部辅助函数
    -- ============================================================

    local function GetContentHeight()
        local child = scrollFrame:GetScrollChild()
        return child and child:GetHeight() or 0
    end

    local function UpdateScrollBar()
        local viewH = scrollFrame:GetHeight()
        local contentH = GetContentHeight()
        if contentH <= viewH or viewH <= 0 then
            thumb:Hide()
            return
        end

        thumb:Show()
        local trackH = math.max(trackFrame:GetHeight(), 1)
        local thumbH = math.max(trackH * (viewH / contentH), 14)
        local maxScroll = math.max(contentH - viewH, 1)
        local pct = scrollFrame:GetVerticalScroll() / maxScroll
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPLEFT", trackFrame, "TOPLEFT", 0, -((trackH - thumbH) * pct))
        thumb:SetPoint("RIGHT", trackFrame, "RIGHT", 0, 0)
    end

    local function SetScrollFromCursor(cursorY, grabOffset)
        local viewH = scrollFrame:GetHeight()
        local contentH = GetContentHeight()
        local maxScroll = math.max(contentH - viewH, 0)
        if maxScroll <= 0 then
            scrollFrame:SetVerticalScroll(0)
            UpdateScrollBar()
            return
        end

        local trackTop = trackFrame:GetTop()
        local trackBottom = trackFrame:GetBottom()
        if not trackTop or not trackBottom then return end

        local trackH = math.max(trackTop - trackBottom, 1)
        local thumbH = thumb:GetHeight()
        local movable = math.max(trackH - thumbH, 1)
        local offset = grabOffset or (thumbH * 0.5)
        local y = math.max(0, math.min((trackTop - cursorY) - offset, movable))
        local pct = y / movable
        scrollFrame:SetVerticalScroll(maxScroll * pct)
        UpdateScrollBar()
    end

    -- ============================================================
    --  Track 点击跳转
    -- ============================================================
    trackFrame:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not thumb:IsShown() then return end
        local _, cursorY = _G.GetCursorPosition()
        cursorY = cursorY / (_G.UIParent and _G.UIParent:GetEffectiveScale() or 1)
        SetScrollFromCursor(cursorY, thumb:GetHeight() * 0.5)

        -- 持续拖拽
        thumb._grabOffset = thumb:GetHeight() * 0.5
        thumb:SetScript("OnUpdate", function(self)
            if not _G.IsMouseButtonDown("LeftButton") then
                self._grabOffset = nil
                self:SetScript("OnUpdate", nil)
                return
            end
            local _, dragY = _G.GetCursorPosition()
            dragY = dragY / (_G.UIParent and _G.UIParent:GetEffectiveScale() or 1)
            SetScrollFromCursor(dragY, self._grabOffset)
        end)
    end)

    -- ============================================================
    --  Thumb 拖拽
    -- ============================================================
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not self:IsShown() then return end
        local _, cursorY = _G.GetCursorPosition()
        cursorY = cursorY / (_G.UIParent and _G.UIParent:GetEffectiveScale() or 1)
        local thumbTop = self:GetTop()
        self._grabOffset = thumbTop and (thumbTop - cursorY) or (self:GetHeight() * 0.5)

        self:SetScript("OnUpdate", function(btn)
            if not _G.IsMouseButtonDown("LeftButton") then
                btn._grabOffset = nil
                btn:SetScript("OnUpdate", nil)
                return
            end
            local _, dragY = _G.GetCursorPosition()
            dragY = dragY / (_G.UIParent and _G.UIParent:GetEffectiveScale() or 1)
            SetScrollFromCursor(dragY, btn._grabOffset)
        end)
    end)

    thumb:SetScript("OnMouseUp", function(self)
        self._grabOffset = nil
        self:SetScript("OnUpdate", nil)
    end)

    -- ============================================================
    --  滚轮滚动
    -- ============================================================
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local contentH = GetContentHeight()
        local viewH = scrollFrame:GetHeight()
        local maxScroll = math.max(contentH - viewH, 0)
        scrollFrame:SetVerticalScroll(
            math.max(0, math.min(scrollFrame:GetVerticalScroll() - delta * 30, maxScroll))
        )
        UpdateScrollBar()
    end)

    -- ============================================================
    --  自动同步
    -- ============================================================
    scrollFrame:SetScript("OnScrollRangeChanged", UpdateScrollBar)
    scrollFrame:SetScript("OnVerticalScroll", UpdateScrollBar)

    -- 初始刷新
    UpdateScrollBar()

    return UpdateScrollBar, thumb, trackBg, thumbTex
end
