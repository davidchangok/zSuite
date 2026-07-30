--[[
    zUI/Security.lua — Secret Value 保护层
    从 LorisID 提升至 zUI 级别，作为所有模块的全局安全基础设施。

    强制规则（在计划 §2.1 中定义）：
    1. UnitGUID() 必须由 zUI.Security.SafeGet() 包裹
    2. TooltipDataProcessor 回调数据必须经 IsSafe() 检查
    3. Cache:Set() 写入前必须经 IsSafe() 检查
    4. 禁止直接调用全局 issecretvalue / issecrettable
--]]

local addonName, addonTable = ...

_G.zUI = _G.zUI or {}
local zUI = _G.zUI

-- 缓存 Blizzard 12.0 secret value API
local issecretvalue = _G.issecretvalue
local issecrettable = _G.issecrettable
local canaccesssecrets = _G.canaccesssecrets

zUI.Security = {}

-- ============================================================
--  内部本地化（不依赖 Locale 文件，zUI.Security 加载极早）
--  可由 zSuite 初始化后通过 SetLocale() 覆盖
-- ============================================================
local WARNING_TEXT_EN = "Action Blocked"
local WARNING_COLOR_HEX = "FFFF6600"  -- 橙色

--- 注入本地化警告文本（由 zSuite Core 在初始化时调用）
--- @param text string 警告文本
--- @param colorHex string 可选颜色 hex
function zUI.Security.SetLocale(text, colorHex)
    if text then WARNING_TEXT_EN = text end
    if colorHex then WARNING_COLOR_HEX = colorHex end
end

-- ============================================================
--  核心安全函数
-- ============================================================

--- 检测一个值是否为安全的（非 Secret Value）
--- 对 table 使用 pcall + issecrettable；对普通值使用 issecretvalue
--- @param value any 要检测的值
--- @return boolean true = 安全可访问
function zUI.Security.IsSafe(value)
    if value == nil then
        return true
    end
    if type(value) == "table" then
        if issecrettable then
            local ok, isSecret = pcall(issecrettable, value)
            return ok and not isSecret
        end
        return true
    end
    if issecretvalue then
        return not issecretvalue(value)
    end
    -- issecretvalue 不可用（极早期加载）→ 安全侧放行
    return true
end

--- 检查当前运行时环境是否允许访问 Secret Value
--- @return boolean
function zUI.Security.CanAccess()
    if canaccesssecrets then
        return canaccesssecrets()
    end
    return true
end

--- pcall 包裹执行一个函数，并自动审计返回值中的秘密值
--- 若 func 执行失败或返回秘密值，则返回 nil
--- @param func function 要执行的函数
--- @param ... any 传递给 func 的参数
--- @return any|nil 安全的结果，或 nil
function zUI.Security.SafeGet(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result = pcall(func, ...)
    if not ok then
        return nil
    end
    if not zUI.Security.IsSafe(result) then
        return nil
    end
    return result
end

--- 格式化一个值为显示字符串
--- 安全值 → tostring(value)，秘密值 → 本地化警告文本（带颜色）
--- @param value any
--- @return string
function zUI.Security.Format(value)
    if zUI.Security.IsSafe(value) then
        return tostring(value)
    end
    -- 缓存格式化警告字符串
    if not zUI.Security._cachedWarning then
        zUI.Security._cachedWarning = "|cFF"
            .. WARNING_COLOR_HEX
            .. WARNING_TEXT_EN
            .. "|r"
    end
    return zUI.Security._cachedWarning
end

--- 使缓存的格式化警告失效（本地化文本变更后调用）
function zUI.Security.InvalidateCache()
    zUI.Security._cachedWarning = nil
end
