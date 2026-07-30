--[[
    zUI/Core.lua — 库入口与 API 暴露
    零业务数据：所有配置通过 zUI.config 注入。纯工厂模式。
--]]

local addonName, addonTable = ...

_G.zUI = _G.zUI or {}
local zUI = _G.zUI

-- ============================================================
--  全局 SharedMedia 引用（可选依赖）
-- ============================================================
local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)

-- ============================================================
--  zUI.config 默认值
-- ============================================================
zUI.config = {
    -- 字体
    fontMedia = nil,             -- SharedMedia 字体名称
    fontMediaPath = nil,         -- 手动字体路径（优先级高于 fontMedia）
    fontSize = 13,               -- 基础字号（中文最小 13）
    fontFlags = "OUTLINE",       -- 字体描边标志

    -- 背景
    backgroundMedia = nil,       -- SharedMedia 背景纹理名
    backgroundMediaPath = nil,   -- 手动背景路径

    -- 窗口位置存储（回调模式——zSuite DB 注入）
    getWindowLayoutValue = nil,  -- function(key) → {point, relativePoint, x, y}
    setWindowLayoutValue = nil,  -- function(key, value)

    -- 动画开关
    isAnimatedMinimizeEnabled = nil,  -- function() → boolean
    getHeaderPosition = nil,          -- function() → "top"|"left"|"right"

    -- 颜色覆盖（为 nil 则使用 zUI.COLORS 默认值）
    colors = nil,

    -- 字符窗口布局模式（true → 角色级存储，false → profile 级）
    characterWindowLayout = false,
}

-- ============================================================
--  运行时状态
-- ============================================================
zUI._fontPaths = {}          -- { [fontKey] = path }
zUI._ensuredFonts = {}       -- 已确保加载的字体
zUI._backdropFrames = {}     -- 弱引用表（需要 backdrop 刷新的 frame 集合）

-- ============================================================
--  ApplyConfig — 运行时配置应用
-- ============================================================
function zUI.ApplyConfig(configTable)
    if not configTable then return end

    -- 合并配置
    for k, v in pairs(configTable) do
        zUI.config[k] = v
    end

    -- 应用颜色覆盖
    if zUI.config.colors then
        zUI.ApplyColors(zUI.config.colors)
    end

    -- 刷新 SharedMedia
    zUI.ApplySharedMedia()

    -- 刷新所有 backdrop
    zUI.RefreshAllFrameBackgrounds()

    -- 使 Security 警告缓存失效（本地化可能已变）
    zUI.Security.InvalidateCache()
end

-- ============================================================
--  模块注册（供 zSuite 使用）
-- ============================================================
zUI._modules = {}

--- 注册一个模块
--- @param name string 模块名称
--- @param module table 模块表，须包含 .enabled 属性和 .Init() 方法
function zUI.RegisterModule(name, module)
    zUI._modules[name] = module
end

--- 获取已注册的模块
function zUI.GetModule(name)
    return zUI._modules[name]
end

--- 获取所有已注册模块
function zUI.GetAllModules()
    return zUI._modules
end

-- ============================================================
--  字体管理
-- ============================================================

--- 获取当前字号
function zUI.GetFontSize()
    return zUI.config.fontSize or 13
end

--- 获取当前字体描边标志
function zUI.GetFontFlags()
    return zUI.config.fontFlags or "OUTLINE"
end

--- 规范化字体标志字符串
--- @param flags string|boolean|nil
--- @return string
function zUI.NormalizeFontFlags(flags)
    if not flags then return "" end
    if type(flags) == "boolean" then return "" end
    if type(flags) == "string" then
        -- "THICKOUTLINE,MONOCHROME" → "THICKOUTLINE, MONOCHROME"
        return (flags:gsub("%s*,%s*", ", "):gsub("^%s+", ""):gsub("%s+$", ""))
    end
    return ""
end

--- 根据文本 Unicode 范围自动选择脚本字体
--- @param text string
--- @return string|nil 字体路径或 nil（使用默认字体）
function zUI.DetectScriptFont(text)
    if not text or text == "" then return nil end
    local code = string.byte(text, 1)
    if not code then return nil end

    -- CJK 范围检测
    if code >= 0x4E00 and code <= 0x9FFF then
        -- CJK Unified Ideographs → zhCN 或 zhTW
        local locale = _G.GetLocale and _G.GetLocale() or "enUS"
        if locale == "zhTW" then
            return "Fonts\\blei00d.ttf"
        else
            return "Fonts\\ARKai_T.ttf"  -- zhCN / default CJK
        end
    elseif code >= 0xAC00 and code <= 0xD7AF then
        return "Fonts\\2002.TTF"         -- Korean
    elseif code >= 0x0400 and code <= 0x04FF then
        return "Fonts\\FRIZQT___CYR.TTF" -- Cyrillic
    end

    return nil  -- 使用默认字体
end

--- 确保字体已可用（针对 SharedMedia 或手动路径）
function zUI.EnsureFonts()
    local fontKey = zUI.config.fontMedia or zUI.config.fontMediaPath or "__default__"
    if zUI._ensuredFonts[fontKey] then return end
    zUI._ensuredFonts[fontKey] = true

    -- SharedMedia 字体
    if LSM and zUI.config.fontMedia then
        local path = LSM:Fetch("font", zUI.config.fontMedia, true)
        if path then
            zUI._fontPaths["FONT_HEADERS"] = path
            zUI._fontPaths["FONT_ROWS"] = path
        end
    end

    -- 手动路径
    if zUI.config.fontMediaPath then
        zUI._fontPaths["FONT_HEADERS"] = zUI.config.fontMediaPath
        zUI._fontPaths["FONT_ROWS"] = zUI.config.fontMediaPath
    end
end

--- 获取默认字体路径（用于标题/header）
function zUI.GetDefaultFontTexture()
    return zUI._fontPaths["FONT_HEADERS"] or _G.STANDARD_TEXT_FONT or
           "Fonts\\FRIZQT__.TTF"
end

--- 获取默认字体路径（用于正文/rows）
function zUI.GetDefaultRowFontTexture()
    return zUI._fontPaths["FONT_ROWS"] or _G.STANDARD_TEXT_FONT or
           "Fonts\\FRIZQT__.TTF"
end

-- ============================================================
--  背景纹理管理
-- ============================================================

--- 检测是否使用自定义背景
function zUI.HasCustomBackground()
    return (zUI.config.backgroundMedia ~= nil and zUI.config.backgroundMedia ~= "") or
           (zUI.config.backgroundMediaPath ~= nil and zUI.config.backgroundMediaPath ~= "")
end

--- 获取当前有效背景纹理路径
function zUI.GetDefaultBackgroundTexture()
    if zUI.config.backgroundMediaPath then
        return zUI.config.backgroundMediaPath
    end
    if LSM and zUI.config.backgroundMedia then
        local path = LSM:Fetch("background", zUI.config.backgroundMedia, true)
        if path then return path end
    end
    return "Interface\\Buttons\\WHITE8X8"
end

--- 为纹理应用背景色
--- @param tex Texture
--- @param r number
--- @param g number
--- @param b number
--- @param a number
function zUI.ApplyBackgroundTexture(tex, r, g, b, a)
    if not tex then return end
    if zUI.HasCustomBackground() then
        tex:SetColorTexture(1, 1, 1, a or 1)
    else
        tex:SetColorTexture(r, g, b, a)
    end
end

--- Hook 一个 Frame 的 Backdrop 设置，注册到自动刷新系统
--- @param frame Frame（须有 SetBackdropColor/SetBackdropBorderColor 方法）
function zUI.HookBackdropFrame(frame)
    if not frame or zUI._backdropFrames[frame] then return end
    zUI._backdropFrames[frame] = true

    -- 存储被拦截的颜色
    frame._zUIBackgroundColor = {frame:GetBackdropColor()}
    frame._zUIBorderColor = {frame:GetBackdropBorderColor()}

    -- Hook SetBackdropColor
    local origSetBackdropColor = frame.SetBackdropColor
    frame.SetBackdropColor = function(self, r, g, b, a)
        self._zUIBackgroundColor = {r, g, b, a}
        origSetBackdropColor(self, r, g, b, a)
    end

    -- Hook SetBackdropBorderColor
    local origSetBorderColor = frame.SetBackdropBorderColor
    frame.SetBackdropBorderColor = function(self, r, g, b, a)
        self._zUIBorderColor = {r, g, b, a}
        origSetBorderColor(self, r, g, b, a)
    end
end

--- 刷新单个 Frame 的背景纹理
--- @param frame Frame
function zUI.RefreshFrameBackground(frame)
    if not frame then return end
    local bgPath = zUI.GetDefaultBackgroundTexture()
    frame:SetBackdrop({bgFile = bgPath})
    local bg = frame._zUIBackgroundColor or {0.02, 0.03, 0.07, 0.96}
    local bd = frame._zUIBorderColor or {0.15, 0.15, 0.20, 1}
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
end

--- 批量刷新所有已注册的背景
function zUI.RefreshAllFrameBackgrounds()
    for frame, _ in pairs(zUI._backdropFrames) do
        zUI.RefreshFrameBackground(frame)
    end
end

--- 应用 SharedMedia 设置
function zUI.ApplySharedMedia()
    zUI._ensuredFonts = {}  -- 强制刷新
    zUI.EnsureFonts()
    zUI.RefreshAllFrameBackgrounds()
end

-- ============================================================
--  窗口位置管理
-- ============================================================

--- 捕获 Frame 的当前锚点信息
--- @param frame Frame
--- @return table {point, relativeTo, relativePoint, x, y}
function zUI.CaptureFrameAnchor(frame)
    if not frame then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return nil end
    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

--- 将锚点信息应用到 Frame
--- @param frame Frame
--- @param anchor table {point, relativeTo, relativePoint, x, y}
function zUI.ApplyFrameAnchor(frame, anchor)
    if not frame or not anchor or not anchor.point then return end
    frame:ClearAllPoints()
    frame:SetPoint(anchor.point, anchor.relativeTo or _G.UIParent,
                   anchor.relativePoint or anchor.point, anchor.x or 0, anchor.y or 0)
end

--- 从存储中恢复窗口位置（通过 config.getWindowLayoutValue 回调）
--- @param frame Frame
--- @param key string 存储键
--- @param defaultX number 默认 X 偏移
--- @param defaultY number 默认 Y 偏移
function zUI.RestoreFramePos(frame, key, defaultX, defaultY)
    if not frame or not key then return end
    if zUI.config.getWindowLayoutValue then
        local saved = zUI.config.getWindowLayoutValue(key)
        if saved then
            zUI.ApplyFrameAnchor(frame, saved)
            return
        end
    end
    -- 没有保存的位置，使用默认值
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", defaultX or 0, defaultY or 0)
end

--- 保存窗口当前位置到存储
--- @param frame Frame
--- @param key string 存储键
function zUI.SaveFramePos(frame, key)
    if not frame or not key then return end
    local anchor = zUI.CaptureFrameAnchor(frame)
    if anchor and zUI.config.setWindowLayoutValue then
        zUI.config.setWindowLayoutValue(key, anchor)
    end
end

--- 窗口布局值读取（兼容 characterWindowLayout）
--- @param key string
--- @return table|nil
function zUI.GetWindowLayoutValue(key)
    if zUI.config.getWindowLayoutValue then
        return zUI.config.getWindowLayoutValue(key)
    end
    return nil
end

--- 窗口布局值写入（兼容 characterWindowLayout）
--- @param key string
--- @param value table
function zUI.SetWindowLayoutValue(key, value)
    if zUI.config.setWindowLayoutValue then
        zUI.config.setWindowLayoutValue(key, value)
    end
end

-- ============================================================
--  动画
-- ============================================================

--- 带动画的 Frame 高度变化（ease-out 三次方缓动）
--- @param frame Frame
--- @param targetHeight number
--- @param onFinished function|nil 完成回调
--- @param onUpdate function|nil 每帧更新回调(frame, currentHeight)
function zUI.AnimateFrameHeight(frame, targetHeight, onFinished, onUpdate)
    if not frame then return end
    local startH = frame:GetHeight()
    if not startH or startH == targetHeight then
        if onFinished then onFinished() end
        return
    end

    local delta = math.abs(targetHeight - startH)
    local duration = math.max(0.06, math.min(delta / 1600, 0.18))
    local elapsed = 0

    -- 停止之前的动画
    if frame._zUIAnim then
        frame:SetScript("OnUpdate", nil)
        frame._zUIAnim = nil
    end

    frame._zUIAnim = {
        startH = startH,
        targetH = targetHeight,
        duration = duration,
        elapsed = 0,
        onFinished = onFinished,
        onUpdate = onUpdate,
    }

    frame:SetScript("OnUpdate", function(self, dt)
        local anim = self._zUIAnim
        if not anim then self:SetScript("OnUpdate", nil); return end
        anim.elapsed = anim.elapsed + dt
        local t = math.min(anim.elapsed / anim.duration, 1)
        -- ease-out cubic: 1 - (1-t)^3
        local eased = 1 - (1 - t) * (1 - t) * (1 - t)
        local currentH = anim.startH + (anim.targetH - anim.startH) * eased
        self:SetHeight(currentH)

        if anim.onUpdate then anim.onUpdate(self, currentH) end

        if t >= 1 then
            self:SetHeight(anim.targetH)
            self:SetScript("OnUpdate", nil)
            self._zUIAnim = nil
            if anim.onFinished then anim.onFinished() end
        end
    end)
end

-- ============================================================
--  SharedMedia 查询（供调用方使用）
-- ============================================================

--- 获取 SharedMedia 中可用的字体列表
--- @return table|nil { {name, path}, ... }
function zUI.GetSharedMediaFonts()
    if not LSM then return nil end
    return LSM:List("font")
end

--- 获取 SharedMedia 中可用的背景列表
--- @return table|nil { name, ... }
function zUI.GetSharedMediaBackgrounds()
    if not LSM then return nil end
    return LSM:List("background")
end

--- 检查 LibSharedMedia-3.0 是否可用
function zUI.HasSharedMedia()
    return LSM ~= nil
end
