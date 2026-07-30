--[[
    zUI/CardLayout.lua — 卡片/面板布局辅助
    从 MidnightRoutine UI.lua + WarbandBoard.lua 提取的纯 UI 工具。

    包含：
    - zUI.CollapseIndicator(parent, isOpen) → 折叠/展开 V 形箭头
    - zUI.SurfaceVariant → 面板表面变体（BASE/PANEL/RAISED/SOFT）
    - zUI.ApplySurface(frame, variant, alpha) → 应用表面变体颜色
    - zUI.AddSoftSheen(parent, r, g, b, alpha) → 卡片顶部微光
--]]

local addonName, addonTable = ...

_G.zUI = _G.zUI or {}
local zUI = _G.zUI

-- ============================================================
--  Surface Variant 预定义色值
-- ============================================================
zUI.SurfaceVariant = {
    -- 最暗，用于底层容器
    BASE = {
        bg = { 0.014, 0.024, 0.042 },
        border = { 0.08, 0.13, 0.20 },
        alpha = 0.98,
        borderAlpha = 0.76,
    },
    -- 最亮，用于最高层卡片
    PANEL = {
        bg = { 0.018, 0.030, 0.050 },
        border = { 0.10, 0.16, 0.24 },
        alpha = 0.96,
        borderAlpha = 0.72,
    },
    -- 中等，用于悬浮面板
    RAISED = {
        bg = { 0.030, 0.055, 0.085 },
        border = { 0.16, 0.26, 0.34 },
        alpha = 0.96,
        borderAlpha = 0.78,
    },
    -- 柔和，用于内嵌卡片
    SOFT = {
        bg = { 0.022, 0.038, 0.060 },
        border = { 0.07, 0.12, 0.18 },
        alpha = 0.92,
        borderAlpha = 0.62,
    },
}

--- 将表面变体应用于 Frame 的 Backdrop
--- @param frame table Backdrop frame
--- @param variant string|nil "BASE"|"PANEL"|"RAISED"|"SOFT"|nil（默认 BASE）
--- @param alpha number|nil 覆盖 alpha 值
function zUI.ApplySurface(frame, variant, alpha)
    if not frame then return end

    -- 注册到 backdrop 刷新系统
    if zUI.HookBackdropFrame then
        zUI.HookBackdropFrame(frame)
    end

    local v = zUI.SurfaceVariant[variant] or zUI.SurfaceVariant.BASE
    local a = alpha or v.alpha

    frame:SetBackdropColor(v.bg[1], v.bg[2], v.bg[3], a)
    frame:SetBackdropBorderColor(v.border[1], v.border[2], v.border[3], v.borderAlpha)
end

-- ============================================================
--  折叠指示器（V 形箭头）
-- ============================================================

--- 为容器创建/更新折叠展开指示器
--- 第一次调用时创建指示器纹理，后续调用更新状态
--- @param indicator table Frame 或 Button（作为指示器容器）
--- @param isOpen boolean true = 展开状态（显示 >），false = 折叠状态（显示 V）
function zUI.CollapseIndicator(indicator, isOpen)
    if not indicator then return end
    indicator:ClearAllPoints()
    indicator:SetSize(14, 14)
    indicator:SetPoint("RIGHT", indicator:GetParent(), "RIGHT", -6, 0)

    -- 延迟创建纹理（Widget 复用模式）
    if not indicator._lineA then
        indicator._lineA = indicator:CreateTexture(nil, "OVERLAY")
        indicator._lineA:SetTexture("Interface\\Buttons\\WHITE8X8")
        indicator._lineB = indicator:CreateTexture(nil, "OVERLAY")
        indicator._lineB:SetTexture("Interface\\Buttons\\WHITE8X8")
    end

    local r, g, b, a = 0.50, 0.95, 0.80, 1
    indicator._lineA:SetColorTexture(r, g, b, a)
    indicator._lineB:SetColorTexture(r, g, b, a)
    indicator._lineA:ClearAllPoints()
    indicator._lineB:ClearAllPoints()

    if isOpen then
        -- 展开：显示 > 形状（两条线段向外旋转）
        indicator._lineA:SetSize(8, 2)
        indicator._lineB:SetSize(8, 2)
        indicator._lineA:SetPoint("CENTER", indicator, "CENTER", -2, 0)
        indicator._lineB:SetPoint("CENTER", indicator, "CENTER", 2, 0)
        if indicator._lineA.SetRotation then
            indicator._lineA:SetRotation(math.rad(35))
            indicator._lineB:SetRotation(math.rad(-35))
        end
        indicator._lineB:Show()
    else
        -- 折叠：显示 > 形状（两条线段向内旋转成 V）
        indicator._lineA:SetSize(10, 2)
        indicator._lineA:SetPoint("CENTER", indicator, "CENTER", 0, 0)
        if indicator._lineA.SetRotation then
            indicator._lineA:SetRotation(0)
            indicator._lineB:SetRotation(0)
        end
        indicator._lineB:Hide()
    end
    indicator._lineA:Show()
end

-- ============================================================
--  卡片顶部微光（Soft Sheen）
-- ============================================================

--- 在 Frame 顶部添加一条 24px 高的柔和光条
--- @param frame table 目标 Frame
--- @param r number 红色分量 (0-1)
--- @param g number 绿色分量 (0-1)
--- @param b number 蓝色分量 (0-1)
--- @param alpha number 透明度
--- @return table|nil 创建的纹理对象
function zUI.AddSoftSheen(frame, r, g, b, alpha)
    if not frame then return nil end

    local tex = frame:CreateTexture(nil, "BACKGROUND")
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    tex:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
    tex:SetHeight(24)
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetColorTexture(r or 0.10, g or 0.20, b or 0.30, alpha or 0.07)
    return tex
end
