--[[
    zUI/Theme.lua — 暗色主题控件工厂
    从 MidnightRoutine Theme.lua 剥离，已消除所有 ns.MR / MR 引用。
    全部配置通过 zUI.config 注入，不持有任何业务数据。

    包含：
    - 完整的控件工厂（StyledFrame, TitleBar, CloseButton, TopAccent, LeftAccent...）
    - 完整的 Options* 系列（Gap, Divider, SectionLabel, Checkbox, Btn, Slider, ColorSwatch）
    - HeaderIconButton / HeaderToggleButton / HeaderTextButton
    - 窗口位置管理（CaptureFrameAnchor / ApplyFrameAnchor / RestoreFramePos / SaveFramePos）
    - 动画（AnimateFrameHeight）
    - SharedMedia 集成
--]]

local addonName, addonTable = ...

_G.zUI = _G.zUI or {}
local zUI = _G.zUI

-- ============================================================
--  本地别名（减少全局表查找）
-- ============================================================
local COLORS = zUI.COLORS
local LSM = zUI.HasSharedMedia and zUI.HasSharedMedia() and
             _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true) or nil

local DEFAULT_FONT_FLAGS = "OUTLINE"

-- ============================================================
--  内部辅助 —— 媒体解析
-- ============================================================

--- 解析选定的 SharedMedia 字体路径
local function ResolveSelectedFontPath()
    -- 手动路径优先
    if zUI.config.fontMediaPath and zUI.config.fontMediaPath ~= "" then
        return zUI.config.fontMediaPath
    end
    -- SharedMedia
    if LSM and zUI.config.fontMedia then
        local path = LSM:Fetch("font", zUI.config.fontMedia, true)
        if path then return path end
    end
    return nil
end

--- 获取活动的 SharedMedia 字体路径（Header 用）
local function GetActiveFontHeaders()
    local resolved = ResolveSelectedFontPath()
    if resolved then return resolved end
    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

--- 获取活动的 SharedMedia 字体路径（Row 用）
local function GetActiveFontRows()
    return GetActiveFontHeaders()
end

--- 获取活动的背景纹理路径
local function ResolveDefaultBackground()
    local path = zUI.GetDefaultBackgroundTexture()
    return path and path ~= "" and path or "Interface\\Buttons\\WHITE8X8"
end

--- 检测用户是否使用了自定义背景纹理
local function HasCustomBackground()
    return (zUI.config.backgroundMedia ~= nil and zUI.config.backgroundMedia ~= "") or
           (zUI.config.backgroundMediaPath ~= nil and zUI.config.backgroundMediaPath ~= "")
end

-- ============================================================
--  Frame Backdrop Hook（背景纹理自动刷新系统）
-- ============================================================

local backdropFrames = {}

local function HookFrameBackdrop(frame)
    if not frame or backdropFrames[frame] then return end
    backdropFrames[frame] = true

    frame._mrBackgroundColor = {frame:GetBackdropColor()}
    frame._mrBorderColor = {frame:GetBackdropBorderColor()}

    local origSetBackdropColor = frame.SetBackdropColor
    frame.SetBackdropColor = function(self, r, g, b, a)
        self._mrBackgroundColor = {r, g, b, a}
        if HasCustomBackground() then
            origSetBackdropColor(self, 1, 1, 1, a)
        else
            origSetBackdropColor(self, r, g, b, a)
        end
    end

    local origSetBorderColor = frame.SetBackdropBorderColor
    frame.SetBackdropBorderColor = function(self, r, g, b, a)
        self._mrBorderColor = {r, g, b, a}
        origSetBorderColor(self, r, g, b, a)
    end
end

-- 注册公共 hook（与 CardLayout.ApplySurface 配合使用）
zUI.HookBackdropFrame = HookFrameBackdrop

-- ============================================================
--  字体与字号（委托给 zUI.Core 已经有的函数，这里提供本地便利）
-- ============================================================

local GetFontSize do
    GetFontSize = function()
        return zUI.config.fontSize or 13
    end
end

local GetFontFlags do
    GetFontFlags = function()
        local flags = zUI.config.fontFlags
        if flags == nil or flags == false then return "" end
        if type(flags) == "string" then return zUI.NormalizeFontFlags(flags) end
        return DEFAULT_FONT_FLAGS
    end
end

-- 本地 DetectScriptFont —— 与 zUI.Core 版本保持一致
local function DetectScriptFont(text)
    if not text or text == "" then return nil end
    local code = string.byte(text, 1)
    if not code then return nil end

    if code >= 0x4E00 and code <= 0x9FFF then
        local locale = _G.GetLocale and _G.GetLocale() or "enUS"
        if locale == "zhTW" then
            return "Fonts\\blei00d.ttf"
        else
            return "Fonts\\ARKai_T.ttf"
        end
    elseif code >= 0xAC00 and code <= 0xD7AF then
        return "Fonts\\2002.TTF"
    elseif code >= 0x0400 and code <= 0x04FF then
        return "Fonts\\FRIZQT___CYR.TTF"
    end
    return nil
end

-- ============================================================
--  文件级字体解析（Theme 加载时立刻执行）
-- ============================================================

local FAT_FONT_HEADERS = GetActiveFontHeaders()
local FAT_FONT_ROWS = GetActiveFontRows()

-- 脚本字体回退
local function ResolveDefaultFont()
    if FAT_FONT_ROWS and FAT_FONT_ROWS ~= "" then
        return FAT_FONT_ROWS
    end
    if _G.STANDARD_TEXT_FONT and _G.STANDARD_TEXT_FONT ~= "" then
        return _G.STANDARD_TEXT_FONT
    end
    local obj = _G.GameFontNormal
    if obj then
        local font = obj:GetFont()
        if font and font ~= "" and font ~= "Interface\\AddOns\\" then
            return font
        end
    end
    -- 按 locale 回退
    local locale = _G.GetLocale and _G.GetLocale() or "enUS"
    if locale == "zhCN" then return "Fonts\\ARKai_T.ttf"
    elseif locale == "zhTW" then return "Fonts\\blei00d.ttf"
    elseif locale == "koKR" then return "Fonts\\2002.TTF"
    end
    return "Fonts\\FRIZQT__.TTF"
end

local RESOLVED_DEFAULT_FONT = ResolveDefaultFont()

--- 选择最佳字体——如果当前文本包含 CJK 则回退到脚本字体
--- @param text string
--- @return string fontPath
local function BestFont(text)
    local scriptFont = DetectScriptFont(text)
    if scriptFont then return scriptFont end
    if FAT_FONT_ROWS and FAT_FONT_ROWS ~= "" then
        return FAT_FONT_ROWS
    end
    return RESOLVED_DEFAULT_FONT
end

-- ============================================================
--  MakeBackdrop / StyledFrame / TitleBar / CloseButton
-- ============================================================

--- 创建标准 backdrop 表
--- @param edge boolean|nil false=仅背景无边框，nil/true=含 1px 边框
--- @return table backdrop 表
function zUI.MakeBackdrop(edge)
    local backdrop = {}

    -- 背景纹理
    local bgPath = zUI.GetDefaultBackgroundTexture()
    if bgPath and bgPath ~= "" then
        backdrop.bgFile = bgPath
    end

    if edge == false then
        return backdrop
    end

    backdrop.edgeFile = ResolveDefaultBackground()
    backdrop.edgeSize = 1
    return backdrop
end

--- 创建暗色风格的 StyledFrame
--- @param parent table|nil
--- @param name string|nil 全局名称
--- @param strata string|nil 默认 "MEDIUM"
--- @param level number|nil 默认 10
--- @return table frame
function zUI.StyledFrame(parent, name, strata, level)
    local frame = CreateFrame("Frame", name, parent or _G.UIParent, "BackdropTemplate")
    frame:SetFrameStrata(strata or "MEDIUM")
    frame:SetFrameLevel(level or 10)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetBackdrop(zUI.MakeBackdrop())
    HookFrameBackdrop(frame)
    frame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4])
    frame:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
    return frame
end

--- 创建深色标题栏（可拖拽）
--- @param parent table
--- @param height number|nil 默认 36
--- @return table bar
function zUI.TitleBar(parent, height)
    height = height or 36
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(height)
    bar:SetBackdrop(zUI.MakeBackdrop(false))
    HookFrameBackdrop(bar)
    bar:SetBackdropColor(COLORS.titlebar[1], COLORS.titlebar[2], COLORS.titlebar[3], 1)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    return bar
end

--- 创建红色关闭按钮 16×16
--- @param parent table
--- @param onClose function|nil
--- @return table btn
function zUI.CloseButton(parent, onClose)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(16, 16)
    btn:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    btn:SetBackdrop(zUI.MakeBackdrop())
    btn:SetBackdropColor(0.12, 0.04, 0.04, 1)
    btn:SetBackdropBorderColor(0.45, 0.12, 0.12, 1)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(GetActiveFontHeaders(), 11, GetFontFlags())
    lbl:SetPoint("CENTER", btn, "CENTER", 0, 1)
    lbl:SetText("x")
    lbl:SetTextColor(0.75, 0.28, 0.28)

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.35, 0.06, 0.06, 1)
        btn:SetBackdropBorderColor(0.90, 0.25, 0.25, 1)
        lbl:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.12, 0.04, 0.04, 1)
        btn:SetBackdropBorderColor(0.45, 0.12, 0.12, 1)
        lbl:SetTextColor(0.75, 0.28, 0.28)
    end)

    if onClose then
        btn:SetScript("OnClick", onClose)
    end

    return btn
end

-- ============================================================
--  TopAccent / LeftAccent
-- ============================================================

--- 顶部强调色装饰线（2px 高跨越全宽）
--- @param parent table
--- @param r number|nil
--- @param g number|nil
--- @param b number|nil
--- @return table tex
function zUI.TopAccent(parent, r, g, b)
    r, g, b = r or COLORS.accent[1], g or COLORS.accent[2], b or COLORS.accent[3]
    local tex = parent:CreateTexture(nil, "BORDER")
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    tex:SetHeight(2)
    tex:SetColorTexture(r, g, b, 1)
    return tex
end

--- 左侧品牌装饰组：12px 起始线 + 44px 横线 + 4px 间隙 + 10px 缺口 + 下方渐变辉光
--- @param parent table
--- @param r number|nil
--- @param g number|nil
--- @param b number|nil
--- @return table group 包含 topRule/notch/glow 的容器 Frame
function zUI.LeftAccent(parent, r, g, b)
    r, g, b = r or COLORS.accent[1], g or COLORS.accent[2], b or COLORS.accent[3]

    local group = CreateFrame("Frame", nil, parent)
    group:SetAllPoints(parent)

    local topRule = group:CreateTexture(nil, "BORDER")
    topRule:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, 0)
    topRule:SetWidth(44)
    topRule:SetHeight(2)
    topRule:SetColorTexture(r, g, b, 0.95)
    group.topRule = topRule

    local notch = group:CreateTexture(nil, "BORDER")
    notch:SetPoint("TOPLEFT", topRule, "BOTTOMRIGHT", 4, 0)
    notch:SetWidth(10)
    notch:SetHeight(2)
    notch:SetColorTexture(r, g, b, 0.65)
    group.notch = notch

    local glow = group:CreateTexture(nil, "ARTWORK")
    glow:SetPoint("TOPLEFT", topRule, "BOTTOMLEFT", 0, -2)
    glow:SetWidth(58)
    glow:SetHeight(8)
    glow:SetColorTexture(r, g, b, 0.14)
    group.glow = glow

    return group
end

-- ============================================================
--  HeaderIconButton / HeaderToggleButton / HeaderTextButton
-- ============================================================

--- 16×16 图标小按钮（Header 区域）
--- @param parent table
--- @param texturePath string
--- @param tintColor table|nil {r,g,b}
--- @param hoverTintColor table|nil {r,g,b}
--- @param tooltipText string|nil
--- @param onClick function|nil
--- @return table btn
function zUI.HeaderIconButton(parent, texturePath, tintColor, hoverTintColor, tooltipText, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(16, 16)
    btn:SetBackdrop(zUI.MakeBackdrop())
    btn:SetBackdropColor(0.06, 0.12, 0.22, 0.85)
    btn:SetBackdropBorderColor(0.15, 0.35, 0.40, 0.9)

    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetSize(14, 14)
    tex:SetPoint("CENTER")
    tex:SetTexture(texturePath)
    if tintColor then
        tex:SetVertexColor(tintColor[1], tintColor[2], tintColor[3])
    else
        tex:SetVertexColor(1, 1, 1)
    end

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.08, 0.20, 0.32, 0.95)
        btn:SetBackdropBorderColor(0.20, 0.66, 0.63, 1)
        if hoverTintColor then
            tex:SetVertexColor(hoverTintColor[1], hoverTintColor[2], hoverTintColor[3])
        end
        if tooltipText then
            _G.GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltipText, 1, 1, 1)
            _G.GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.06, 0.12, 0.22, 0.85)
        btn:SetBackdropBorderColor(0.15, 0.35, 0.40, 0.9)
        if tintColor then
            tex:SetVertexColor(tintColor[1], tintColor[2], tintColor[3])
        else
            tex:SetVertexColor(1, 1, 1)
        end
        if tooltipText then
            _G.GameTooltip:Hide()
        end
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    btn._iconTex = tex
    return btn
end

--- 16×16 可切换按钮（动态文本标签）
--- @param parent table
--- @param getLabel function|string 返回当前标签文本
--- @param tooltipText string|nil
--- @param onClick function|nil
--- @return table btn
function zUI.HeaderToggleButton(parent, getLabel, tooltipText, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(16, 16)
    btn:SetBackdrop(zUI.MakeBackdrop())
    btn:SetBackdropColor(0.06, 0.12, 0.22, 0.85)
    btn:SetBackdropBorderColor(0.15, 0.35, 0.40, 0.9)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(GetActiveFontHeaders(), 12, GetFontFlags())
    lbl:SetPoint("CENTER", btn, "CENTER", 0, 1)
    lbl:SetTextColor(0.25, 0.80, 0.68)

    local function RefreshLabel()
        lbl:SetText(type(getLabel) == "function" and getLabel() or tostring(getLabel or "-"))
    end

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.08, 0.20, 0.32, 0.95)
        btn:SetBackdropBorderColor(0.20, 0.66, 0.63, 1)
        if tooltipText then
            _G.GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltipText, 1, 1, 1)
            _G.GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.06, 0.12, 0.22, 0.85)
        btn:SetBackdropBorderColor(0.15, 0.35, 0.40, 0.9)
        _G.GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(...)
        if onClick then onClick(...) end
        RefreshLabel()
    end)

    RefreshLabel()
    btn._label = lbl
    btn.RefreshLabel = RefreshLabel
    return btn
end

--- 可点击文字按钮（Header 区域）
--- @param parent table
--- @param label string 按钮文本
--- @param tooltip string|nil
--- @param onClick function|nil
--- @param width number|nil
--- @param fontSize number|nil
--- @return table btn
function zUI.HeaderTextButton(parent, label, tooltip, onClick, width, fontSize)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 100, 16)
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont(GetActiveFontHeaders(), fontSize or 11, GetFontFlags())
    fs:SetAllPoints()
    fs:SetText(label or "")
    fs:SetTextColor(0.50, 0.80, 0.90)
    fs:SetJustifyH("CENTER")

    btn:SetScript("OnEnter", function()
        fs:SetTextColor(0.20, 0.66, 0.63)
        if tooltip then
            _G.GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltip, 1, 1, 1)
            _G.GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        fs:SetTextColor(0.50, 0.80, 0.90)
        _G.GameTooltip:Hide()
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

-- ============================================================
--  窗口位置管理
-- ============================================================

--- 捕获当前锚点位置（兼容双状态最小化/展开分离存储）
--- @param frame table
--- @return table|nil {point, relPoint, x, y}
function zUI.CaptureFrameAnchor(frame)
    if not frame then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return nil end

    return {
        point = point,
        relPoint = relativePoint or point,
        x = math.floor(x or 0),
        y = math.floor(y or 0),
    }
end

--- 应用锚点位置
--- @param frame table
--- @param pos table {point, relPoint, x, y}
--- @param anchorMode string|nil "bottom" 使用底部锚点
function zUI.ApplyFrameAnchor(frame, pos, anchorMode)
    if not frame or not pos or not pos.point then return end
    frame:ClearAllPoints()

    if anchorMode == "bottom" then
        frame:SetPoint("BOTTOM", _G.UIParent, "BOTTOM", pos.x, pos.y)
    elseif pos.relPoint then
        frame:SetPoint(pos.point, _G.UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint(pos.point, _G.UIParent, pos.point, pos.x, pos.y)
    end
end

--- 从存储恢复位置
--- @param frame table
--- @param key string 存储键
--- @param defaultX number
--- @param defaultY number
function zUI.RestoreFramePos(frame, key, defaultX, defaultY)
    if not frame or not key then return end

    -- 通过 zUI.config.getWindowLayoutValue 读取
    if zUI.config.getWindowLayoutValue then
        local saved = zUI.config.getWindowLayoutValue(key)
        if saved then
            zUI.ApplyFrameAnchor(frame, saved)
            return
        end
    end

    -- 无保存 → 默认居中
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", defaultX or 0, defaultY or 0)
end

--- 保存当前位置到存储
--- @param frame table
--- @param key string
function zUI.SaveFramePos(frame, key)
    if not frame or not key then return end
    if not zUI.config.setWindowLayoutValue then return end

    local pos = zUI.CaptureFrameAnchor(frame)
    if pos then
        zUI.config.setWindowLayoutValue(key, pos)
    end
end

-- ============================================================
--  窗口布局值（兼容 characterWindowLayout）
-- ============================================================

function zUI.GetWindowLayoutValue(key)
    if zUI.config.getWindowLayoutValue then
        return zUI.config.getWindowLayoutValue(key)
    end
    return nil
end

function zUI.SetWindowLayoutValue(key, value)
    if zUI.config.setWindowLayoutValue then
        zUI.config.setWindowLayoutValue(key, value)
    end
end

-- ============================================================
--  动画
-- ============================================================

--- 带动画的 Frame 高度变化（ease-out 三次方缓动）
--- 由 zUI.config.isAnimatedMinimizeEnabled 控制是否启用（false 时直接设置高度）
--- @param frame table
--- @param targetHeight number
--- @param onFinished function|nil
--- @param onUpdate function|nil
--- @param driverFrame table|nil 驱动动画的 OnUpdate 宿主（默认 frame 自身）
function zUI.AnimateFrameHeight(frame, targetHeight, onFinished, onUpdate, driverFrame)
    if not frame then return end

    -- 如果动画被禁用，直接设置高度
    if zUI.config.isAnimatedMinimizeEnabled and not zUI.config.isAnimatedMinimizeEnabled() then
        frame:SetHeight(targetHeight)
        if onFinished then onFinished(frame) end
        return
    end

    local driver = driverFrame or frame
    local startHeight = frame:GetHeight() or targetHeight
    local delta = targetHeight - startHeight

    if math.abs(delta) < 1 then
        frame:SetHeight(targetHeight)
        if onFinished then onFinished(frame) end
        return
    end

    -- 停止之前的动画
    if driver._zUIAnim then
        driver:SetScript("OnUpdate", nil)
        driver._zUIAnim = nil
    end

    local duration = math.max(0.06, math.min(math.abs(delta) / 1600, 0.18))

    driver._zUIAnim = {
        startH = startHeight,
        targetH = targetHeight,
        duration = duration,
        elapsed = 0,
        onFinished = onFinished,
        onUpdate = onUpdate,
    }

    driver:SetScript("OnUpdate", function(self, dt)
        local anim = self._zUIAnim
        if not anim then self:SetScript("OnUpdate", nil); return end
        anim.elapsed = anim.elapsed + dt
        local t = math.min(anim.elapsed / anim.duration, 1)
        -- ease-out cubic: 1 - (1-t)³
        local eased = 1 - (1 - t) * (1 - t) * (1 - t)
        local currentH = anim.startH + (anim.targetH - anim.startH) * eased
        frame:SetHeight(currentH)

        if anim.onUpdate then anim.onUpdate(frame, currentH) end

        if t >= 1 then
            frame:SetHeight(anim.targetH)
            self:SetScript("OnUpdate", nil)
            self._zUIAnim = nil
            if anim.onFinished then anim.onFinished(frame) end
        end
    end)
end

-- ============================================================
--  窗口拖动支持
-- ============================================================

--- 为 Frame 设置标准拖拽行为（StartMoving / StopMovingOrSizing）
--- @param frame table
--- @param titleBar table 拖拽敏感的标题栏
--- @param saveKey string|nil 拖动结束时自动保存位置的 key
function zUI.SetupDrag(frame, titleBar, saveKey)
    if not frame or not titleBar then return end
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if saveKey then
            zUI.SaveFramePos(frame, saveKey)
        end
    end)
end

-- ============================================================
--  MakeBackdrop / 背景纹理刷新
-- ============================================================

function zUI.RefreshFrameBackground(frame)
    if not frame then return end
    local bgPath = zUI.GetDefaultBackgroundTexture()
    frame:SetBackdrop({bgFile = bgPath and bgPath ~= "" and bgPath or nil})
    local bg = frame._mrBackgroundColor or {0.02, 0.03, 0.07, 0.96}
    local bd = frame._mrBorderColor or {0.15, 0.15, 0.20, 1}
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
end

function zUI.RefreshAllFrameBackgrounds()
    for frame, _ in pairs(backdropFrames) do
        if frame and frame.GetBackdropColor then
            zUI.RefreshFrameBackground(frame)
        else
            backdropFrames[frame] = nil
        end
    end
end

-- ============================================================
--  应用 SharedMedia
-- ============================================================

function zUI.ApplySharedMedia()
    -- 强制下次从 zUI.config 重新读取
    FAT_FONT_HEADERS = GetActiveFontHeaders()
    FAT_FONT_ROWS = GetActiveFontRows()
    zUI.RefreshAllFrameBackgrounds()
end

-- ============================================================
--  Options* 系列控件
-- ============================================================

--- 间距占位
--- @param body table 内容 Frame
--- @param yOff number 当前 Y 偏移
--- @param height number|nil 间距高度（默认 4）
--- @return number 新的 yOff
function zUI.OptionsGap(body, yOff, height)
    return yOff - (height or 4)
end

--- 细分割线
--- @param body table
--- @param yOff number
--- @param pad number|nil 左右内边距（默认 8）
--- @return number 新的 yOff
function zUI.OptionsDivider(body, yOff, pad)
    pad = pad or 8
    local frame = CreateFrame("Frame", nil, body, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", body, "TOPLEFT", pad, yOff)
    frame:SetPoint("TOPRIGHT", body, "TOPRIGHT", -pad, yOff)
    frame:SetHeight(1)
    frame:SetBackdrop(zUI.MakeBackdrop(false))
    frame:SetBackdropColor(1, 1, 1, 0.07)
    return yOff - 4
end

--- 灰字小标题
--- @param body table
--- @param yOff number
--- @param text string
--- @param pad number|nil（默认 8）
--- @param fontSize number|nil（默认 9）
--- @return number 新的 yOff
function zUI.OptionsSectionLabel(body, yOff, text, pad, fontSize)
    pad = pad or 8
    local fs = body:CreateFontString(nil, "OVERLAY")
    fs:SetFont(GetActiveFontRows(), fontSize or 9, GetFontFlags())
    fs:SetText("|cff888888" .. (text or "") .. "|r")
    fs:SetPoint("TOPLEFT", body, "TOPLEFT", pad, yOff)
    fs:SetPoint("TOPRIGHT", body, "TOPRIGHT", -pad, yOff)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return yOff - 12
end

--- 复选框
--- @param body table
--- @param yOff number
--- @param label string
--- @param getVal function → boolean
--- @param setVal function(checked)
--- @param tooltip string|nil
--- @param r number|nil 标签颜色 r
--- @param g number|nil
--- @param b number|nil
--- @param pad number|nil
--- @param onRefresh function|nil
--- @param fontSize number|nil
--- @return number 新的 yOff
function zUI.OptionsCheckbox(body, yOff, label, getVal, setVal, tooltip, r, g, b, pad, onRefresh, fontSize)
    pad = pad or 8
    local frame = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
    frame:SetSize(20, 20)
    frame:SetPoint("TOPLEFT", body, "TOPLEFT", pad - 2, yOff)
    frame:SetChecked(getVal())

    local lbl = frame:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(GetActiveFontRows(), fontSize or 12, GetFontFlags())
    lbl:SetPoint("LEFT", frame, "RIGHT", 4, -1)
    lbl:SetText(label)
    lbl:SetTextColor(r or 0.85, g or 0.85, b or 0.85)

    frame:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        setVal(checked)
        if onRefresh then onRefresh(checked) end
    end)

    if tooltip then
        frame:SetScript("OnEnter", function(self)
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltip, 1, 1, 1)
            _G.GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function()
            _G.GameTooltip:Hide()
        end)
    end

    return yOff - 19
end

--- 标准按钮
--- @param body table
--- @param yOff number
--- @param label string
--- @param onClick function
--- @param width number|nil 默认 184
--- @param pad number|nil 默认 8
--- @param fontSize number|nil
--- @return number 新的 yOff
function zUI.OptionsBtn(body, yOff, label, onClick, width, pad, fontSize)
    pad = pad or 8
    width = width or 184
    local btn = CreateFrame("Button", nil, body, "BackdropTemplate")
    btn:SetSize(width, 20)
    btn:SetPoint("TOPLEFT", body, "TOPLEFT", pad, yOff)
    btn:SetBackdrop(zUI.MakeBackdrop())
    btn:SetBackdropColor(0.05, 0.10, 0.18, 1)
    btn:SetBackdropBorderColor(0.18, 0.40, 0.45, 1)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(GetActiveFontRows(), fontSize or 11, GetFontFlags())
    lbl:SetPoint("CENTER")
    lbl:SetText(label)
    lbl:SetTextColor(0.25, 0.80, 0.68)

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.08, 0.20, 0.32, 1)
        btn:SetBackdropBorderColor(0.20, 0.66, 0.63, 1)
        lbl:SetTextColor(0.20, 0.66, 0.63)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.05, 0.10, 0.18, 1)
        btn:SetBackdropBorderColor(0.18, 0.40, 0.45, 1)
        lbl:SetTextColor(0.25, 0.80, 0.68)
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    btn._label = lbl

    return yOff - 22, btn
end

--- 滑块
--- @param body table
--- @param yOff number
--- @param label string 标签文本
--- @param min number 最小值
--- @param max number 最大值
--- @param step number 步长
--- @param getVal function → number
--- @param setVal function(value)
--- @param tooltip string|nil
--- @param fillR number|nil 填充色 r
--- @param fillG number|nil
--- @param fillB number|nil
--- @param pad number|nil
--- @param disabled boolean|nil
--- @param fontSize number|nil
--- @return number 新的 yOff
function zUI.OptionsSlider(body, yOff, label, min, max, step, getVal, setVal, tooltip, fillR, fillG, fillB, pad, disabled, fontSize)
    pad = pad or 8
    min = min or 1; max = max or 100; step = step or 1
    fillR, fillG, fillB = fillR or 0.20, fillG or 0.66, fillB or 0.63
    local labelW = 140

    -- 标签
    local lbl = body:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(GetActiveFontRows(), fontSize or 11, GetFontFlags())
    lbl:SetPoint("TOPLEFT", body, "TOPLEFT", pad, yOff)
    lbl:SetText(label)
    lbl:SetTextColor(0.85, 0.85, 0.85)
    lbl:SetWidth(labelW)
    lbl:SetJustifyH("LEFT")

    -- 滑块背景
    local bg = CreateFrame("Frame", nil, body, "BackdropTemplate")
    bg:SetSize(180, 12)
    bg:SetPoint("TOPLEFT", body, "TOPLEFT", pad + labelW + 4, yOff)
    bg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    bg:SetBackdropColor(0.05, 0.05, 0.08, 0.8)

    -- 填充条
    local fill = bg:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(fillR, fillG, fillB, 0.4)

    local function UpdateFill()
        local val = getVal()
        local pct = math.max(0, math.min((val - min) / math.max(max - min, 1), 1))
        fill:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMRIGHT", bg, "BOTTOMLEFT", bg:GetWidth() * pct, 0)
    end

    -- 数值显示
    local valBox = CreateFrame("Frame", nil, body, "BackdropTemplate")
    valBox:SetSize(44, 18)
    valBox:SetPoint("LEFT", bg, "RIGHT", 6, 0)
    valBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    valBox:SetBackdropColor(0.05, 0.05, 0.08, 0.8)

    local valTxt = valBox:CreateFontString(nil, "OVERLAY")
    valTxt:SetFont(GetActiveFontRows(), 10, GetFontFlags())
    valTxt:SetPoint("CENTER")
    valTxt:SetTextColor(0.20, 0.66, 0.63)

    local function UpdateValText()
        valTxt:SetText(tostring(getVal()))
    end

    -- 滑块（隐藏默认 thumb）
    local slider = CreateFrame("Slider", nil, bg)
    slider:SetAllPoints()
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getVal())
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local thumb = slider:GetThumbTexture()
    if thumb then thumb:Hide() end

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        val = math.max(min, math.min(val, max))
        self:SetValue(val)
        setVal(val)
        UpdateFill()
        UpdateValText()
    end)

    if disabled then
        slider:Disable()
        fill:SetColorTexture(0.15, 0.15, 0.15, 0.3)
    end

    UpdateFill()
    UpdateValText()

    if tooltip then
        slider:SetScript("OnEnter", function(self)
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltip, 1, 1, 1)
            _G.GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    end

    return yOff - 28
end

--- 颜色选择器方块 16×16
--- @param parent table
--- @param r number 初始红色
--- @param g number 初始绿色
--- @param b number 初始蓝色
--- @param onPick function(r, g, b) 选择后回调
--- @param onReset function → r, g, b 右键重置回调
--- @param tooltip string|nil
--- @return table swatch
function zUI.OptionsColorSwatch(parent, r, g, b, onPick, onReset, tooltip)
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(16, 16)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -1, 1)
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")

    local function UpdateFill()
        r, g, b = math.max(0, math.min(r or 0, 1)),
                   math.max(0, math.min(g or 0, 1)),
                   math.max(0, math.min(b or 0, 1))
        fill:SetColorTexture(r, g, b, 1)
        swatch:SetBackdropBorderColor(r * 0.7, g * 0.7, b * 0.7, 1)
    end
    UpdateFill()

    swatch:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if _G.ColorPickerFrame then
                _G.ColorPickerFrame:SetupColorPickerAndShow({
                    r = r, g = g, b = b,
                    opacity = false,
                    hasOpacity = false,
                    swatchFunc = function()
                        local newR, newG, newB = _G.ColorPickerFrame:GetColorRGB()
                        r, g, b = newR, newG, newB
                        UpdateFill()
                    end,
                    cancelFunc = function(previousValues)
                        r, g, b = previousValues.r, previousValues.g, previousValues.b
                        UpdateFill()
                        if onPick then onPick(r, g, b) end
                    end,
                })
            end
        elseif button == "RightButton" and onReset then
            r, g, b = onReset()
            UpdateFill()
            if onPick then onPick(r, g, b) end
        end
    end)

    -- 完成选择后的确认回调（ColorPickerFrame 关闭时触发）
    swatch:SetScript("OnMouseUp", function()
        if onPick then onPick(r, g, b) end
    end)

    if tooltip then
        swatch:SetScript("OnEnter", function(self)
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tooltip, 1, 1, 1)
            _G.GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    end

    swatch.GetColor = function() return r, g, b end
    swatch.SetColor = function(nr, ng, nb) r, g, b = nr, ng, nb; UpdateFill() end

    return swatch
end
