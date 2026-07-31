--[[
    zUI/Util.lua — 纯工具函数
    无状态，无依赖，所有函数为纯计算或格式化。
    基于 MidnightRoutine Theme.lua 中提取的工具函数。
--]]

local addonName, addonTable = ...

-- ============================================================
--  全局命名空间
-- ============================================================
_G.zUI = _G.zUI or {}

local zUI = _G.zUI

-- ============================================================
--  默认颜色表（可被 zUI.config.colors 覆盖）
-- ============================================================
zUI.COLORS = {
    complete   = { 0,    1,    0.59 },  -- 完成：翠绿
    half       = { 1,    0.47, 0    },  -- 进行中：暖橙
    incomplete = { 0.6,  0.6,  0.6  },  -- 未完成：灰色
    bg         = { 0.02, 0.03, 0.07, 0.96 },  -- 主背景：极暗蓝黑
    accent     = { 0.85, 0.65, 0.10 },  -- 强调色：暗金
    border     = { 0.15, 0.15, 0.20 },  -- 边框色
    titlebar   = { 0.05, 0.12, 0.22 },  -- 标题栏：暗蓝
    text       = { 0.85, 0.85, 0.85 },  -- 主文字：浅灰
    dimText    = { 0.50, 0.50, 0.50 },  -- 次文字：中灰
    divider    = { 0.12, 0.12, 0.16 },  -- 分割线
}

-- ============================================================
--  颜色工具函数
-- ============================================================

--- 将 6 位 hex 颜色字符串转为 r, g, b (0-1 范围)
--- @param rrggbb string 如 "#FF8800" 或 "FF8800"
--- @return number, number, number r, g, b
function zUI.Hex(rrggbb)
    if not rrggbb then return 1, 1, 1 end
    local hex = rrggbb:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255,
           tonumber("0x" .. hex:sub(3, 4)) / 255,
           tonumber("0x" .. hex:sub(5, 6)) / 255
end

--- 生成 WoW 颜色字符串 |cffrrggbb文本|r
--- @param rrggbb string hex 颜色码
--- @param text string 文本内容
--- @return string WoW 格式颜色字符串
function zUI.WrapColor(rrggbb, text)
    if not rrggbb or not text then return text or "" end
    local hex = rrggbb:gsub("#", "")
    -- hex 已包含 alpha 通道（如 RAID_CLASS_COLORS.colorStr = "ffC79C6E"），
    -- 只需拼接 |c 前缀即可组成 |cAARRGGBB
    return "|c" .. hex .. text .. "|r"
end

--- 根据完成/总数比例返回 RGB 颜色
--- 完成 → 翠绿；部分完成 → 暖橙；零 → 灰色
--- @param done number 已完成数
--- @param max number 总数
--- @return number, number, number
function zUI.CountColor(done, max)
    if not max or max == 0 then return 0.6, 0.6, 0.6 end
    if done >= max then
        return 0, 1, 0.59
    elseif done > 0 then
        return 1, 0.47, 0
    else
        return 0.6, 0.6, 0.6
    end
end

--- 为纹理设置颜色——基于完成度
--- @param tex Texture 纹理对象
--- @param done number 已完成数
--- @param max number 总数
function zUI.SetDotColor(tex, done, max)
    if not tex then return end
    local r, g, b = zUI.CountColor(done, max)
    tex:SetVertexColor(r, g, b)
end

--- 应用 colors 表覆盖（从 zUI.config.colors 注入）
--- @param override table 用户自定义颜色表
function zUI.ApplyColors(override)
    if not override then return end
    for k, v in pairs(override) do
        if zUI.COLORS[k] then
            zUI.COLORS[k] = v
        end
    end
end

-- ============================================================
--  通用工具函数
-- ============================================================

--- 从数组末尾 nil 清空（避免创建新 table）
--- @param t table 要清空的数组
function zUI.ClearArrayContents(t)
    if not t then return end
    for i = #t, 1, -1 do
        t[i] = nil
    end
end

--- 安全地将值转为字符串（处理 nil）
--- @param value any
--- @return string
function zUI.SafeToString(value)
    if value == nil then return "" end
    return tostring(value)
end

--- 在 WoW 聊天框中打印带前缀的消息
--- @param msg string 消息内容
--- @param prefix string 可选前缀，默认 "[zUI]"
function zUI.Print(msg, prefix)
    local p = prefix or "|cFFD4A017[zUI]|r"
    print(p .. " " .. (msg or ""))
end

-- ============================================================
--  配置合并工具
-- ============================================================

--- 递归浅合并默认值到目标表（仅填充不存在的键）
--- 子表采用同策略递归合并
--- @param target table 目标表（用户数据）
--- @param defaults table 默认值表
function zUI.MergeDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then return end
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = v
        elseif type(target[k]) == "table" and type(v) == "table" then
            zUI.MergeDefaults(target[k], v)
        end
    end
end

-- ============================================================
--  表安全复制（浅层）
-- ============================================================

--- 创建表的浅拷贝
--- @param t table
--- @return table
function zUI.ShallowCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end
