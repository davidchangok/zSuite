--[[
    LorisID/Core.lua — 工具提示 ID 注入引擎
    从 LorisID 2.3.0 迁移至 zSuite。

    Bug 修复：
    #3 — PerfCheck 仅在模块 enabled 时运行
    #4 — 斜杠命令 nil guard
    #5 — ProcessTooltipData 使用 zUI.Security.IsSafe 代替全局 issecretvalue
    #6 — QUEST_DATA_LOAD_RESULT 移除（无实际逻辑）
    #7 — 移除无意义的 Security 沙盒自检

    Security：所有 TooltipDataProcessor 数据、UnitGUID 调用均通过 zUI.Security。
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

-- ============================================================
--  模块注册
-- ============================================================
local mod = {
    name = "lorisid",
    enabled = true,
}
zSuite.RegisterModule("lorisid", mod)

local L = mod.L or _G.zSuiteLorisID_L
local Security = zUI.Security

-- ============================================================
--  ID 类型映射
-- ============================================================
local IDTypes = {
    ITEM = "item", SPELL = "spell", PETSPELL = "petspell", UNIT = "unit",
    QUEST = "quest", ACHIEVEMENT = "achievement", CURRENCY = "currency",
    MOUNT = "mount", TOY = "toy", ICON = "icon", TALENT = "talent",
    EQUIP_SET = "set", VISUAL = "visual", COMPANION = "companion",
    OBJECT = "object", BATTLEPET = "battlepet", INSTANCE = "instance",
    RECIPE = "recipe", MACRO = "macro", PVP = "pvp", MINIMAP = "minimap",
}

-- TooltipDataType → 内部 ID 类型
local TooltipDataTypeMap = {}
if _G.Enum and _G.Enum.TooltipDataType then
    local ET = _G.Enum.TooltipDataType
    local function S(key, value) if key then TooltipDataTypeMap[key] = value end end
    S(ET.Item, "item")
    S(ET.Spell, "spell")
    S(ET.Unit, "unit")
    S(ET.Quest, "quest")
    S(ET.Achievement, "achievement")
    S(ET.Currency, "currency")
    S(ET.Toy, "toy")
    S(ET.Mount, "mount")
    S(ET.Talent, "talent")
    S(ET.Companion, "companion")
    S(ET.BattlePet, "battlepet")
    S(ET.Instance, "instance")
    S(ET.Recipe, "recipe")
    S(ET.Macro, "macro")
    S(ET.PvPBrawl, "pvp")
end

-- ============================================================
--  内部辅助
-- ============================================================
local function GetDB()
    if not zSuite.db or not zSuite.db.modules then return nil end
    return zSuite.db.modules.lorisid
end

local function IsModuleEnabled()
    local db = GetDB()
    return db and db.enabled
end

-- ============================================================
--  ID 标签本地化
-- ============================================================
local ID_LABELS = {
    item = "Item ID", spell = "Spell ID", petspell = "Pet Spell ID",
    unit = "Unit ID", quest = "Quest ID", achievement = "Achievement ID",
    currency = "Currency ID", mount = "Mount ID", toy = "Toy ID",
    talent = "Talent ID", set = "Equipment Set ID", visual = "Visual ID",
    companion = "Companion ID", object = "Object ID", battlepet = "Battle Pet ID",
    instance = "Instance ID", recipe = "Recipe ID", macro = "Macro ID",
    pvp = "PvP Brawl ID", minimap = "Minimap ID", icon = "Icon ID",
}

local function GetIDLabel(idType)
    local key = ID_LABELS[idType] or idType
    return (L and L[key]) or key
end

-- ============================================================
--  Tooltip 去重
-- ============================================================
local function HasLine(tooltip, text)
    if not tooltip or not text then return false end
    local regions = { tooltip:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetText then
            local lineText = region:GetText()
            -- Bug#2 修复：不对 tooltip 文本调用 IsSafe，仅检查子串匹配
            if lineText and lineText:find(text, 1, true) then
                return true
            end
        end
    end
    return false
end

-- ============================================================
--  Tooltip ID 注入
-- ============================================================
local function AddLine(tooltip, id, idType)
    if not tooltip or not id then return end
    local db = GetDB()
    if not db or not db.ids or not db.ids[idType] then return end

    local label = GetIDLabel(idType)
    local formattedID = Security.Format(id)
    local expectedText = label .. ":" .. formattedID

    if HasLine(tooltip, label .. ":") then return end

    -- pcall 保护（MBB 等第三方 UI 冲突）
    pcall(function()
        tooltip:AddDoubleLine(label, formattedID, 0.5, 0.8, 1, 1, 1, 1)
    end)
end

-- ============================================================
--  关联 ID 添加（图标/法术）
-- ============================================================
local function AddRelatedIDs(tooltip, mainID, mainType)
    if mainType == "item" then
        local info = { _G.C_Item and _G.C_Item.GetItemInfo(mainID) }
        if info[10] and GetDB().showIcons then
            AddLine(tooltip, info[10], "icon")
        end
    elseif mainType == "spell" then
        local spellInfo = _G.C_Spell and _G.C_Spell.GetSpellInfo(mainID)
        if spellInfo and spellInfo.iconID and GetDB().showIcons then
            AddLine(tooltip, spellInfo.iconID, "icon")
        end
    end
end

-- ============================================================
--  Unit GUID 提取 NPC ID
-- ============================================================
local function GetUnitID(guid)
    if not guid then return nil end
    local unitType = select(1, string.split("-", guid))
    if unitType == "Player" or unitType == "Pet" then return nil end
    local spawnID = select(5, string.split("-", guid))
    if spawnID and spawnID ~= "" and spawnID ~= "0000000000000000" then
        return tonumber(spawnID)
    end
    return nil
end

-- ============================================================
--  ProcessTooltipData（主要注入路径）
-- ============================================================
local function ProcessTooltipData(tooltip, data)
    if not IsModuleEnabled() then return end

    -- Bug#5 修复：使用 Security.IsSafe 代替全局 issecretvalue
    if not Security.IsSafe(data) then return end
    if not Security.IsSafe(data.id) then return end

    local idType = TooltipDataTypeMap[data.type]
    if not idType then return end

    -- Unit 特殊处理：从 GUID 提取 NPC ID
    if idType == "unit" and data.guid then
        -- Security: UnitGUID 可能返回 secret value (userdata)
        local guid = Security.SafeGet(function() return data.guid end)
        if guid and type(guid) == "string" then
            local unitID = GetUnitID(guid)
            if unitID then
                AddLine(tooltip, unitID, idType)
            end
        end
        return
    end

    AddLine(tooltip, data.id, idType)
    AddRelatedIDs(tooltip, data.id, idType)
end

-- ============================================================
--  SetUnit hook — Unit tooltip GUID 提取
--  TooltipDataProcessor 对 Unit 类型的回调不一定包含 data.guid 字段，
--  所以必须保留 SetUnit hook 来直接从 UnitGUID(unit) 获取 GUID。
--  AddLine() 内置 HasLine 去重，不会与 TDP 路径产生重复 ID。
--  SetHyperlink hook 不恢复：TDP 已完整覆盖物品/法术/等类型。
-- ============================================================
local function RegisterUnitHook()
    _G.hooksecurefunc(_G.GameTooltip, "SetUnit", function(self, unit)
        if not IsModuleEnabled() then return end
        _G.C_Timer.After(0, function()
            local guid = Security.SafeGet(_G.UnitGUID, unit or "mouseover")
            if guid and type(guid) == "string" then
                local unitID = GetUnitID(guid)
                if unitID then
                    AddLine(self, unitID, "unit")
                end
            end
        end)
    end)
end

-- ============================================================
--  初始化
-- ============================================================
function mod:Init()
    if not IsModuleEnabled() then return end

    -- 主路径：TooltipDataProcessor（12.0+ 标准 API，覆盖物品/法术/任务等类型）
    if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall then
        for _, enumValue in pairs(_G.Enum.TooltipDataType) do
            if type(enumValue) == "number" then
                pcall(function()
                    _G.TooltipDataProcessor.AddTooltipPostCall(enumValue, ProcessTooltipData)
                end)
            end
        end
    end

    -- Unit 补充路径：hooksecurefunc(SetUnit) — 直接从 UnitGUID 获取 NPC ID
    RegisterUnitHook()

    -- 斜杠命令（Bug#4 修复：nil guard）
    _G.SLASH_LORISID1 = "/lid"
    _G.SLASH_LORISID2 = "/lorisid"
    _G.SLASH_LORISID3 = "/et"
    _G.SlashCmdList["LORISID"] = function(msg)
        msg = msg or ""
        local cmd = string.match(msg, "^(%S+)%s*(.*)$")
        cmd = cmd or msg:lower()

        if cmd == "" or cmd == "config" then
            if zSuite.OpenOptions then zSuite.OpenOptions() end
        elseif cmd == "cache" then
            mod.Cache:Clear()
            zUI.Print("LorisID 缓存已清除")
        elseif cmd == "debug" then
            local db = GetDB()
            if db then db.debugMode = not db.debugMode end
            zUI.Print("调试模式: " .. tostring(db and db.debugMode))
        elseif cmd == "version" then
            zUI.Print("zSuite LorisID v2.3.0-remastered")
        else
            zUI.Print("/lid [config|cache|debug|version]")
        end
    end

    -- PerfCheck（Bug#3 修复：仅在模块 enabled 时启动）
    local function PerfCheck()
        if not IsModuleEnabled() then return end
        local db = GetDB()
        if db and db.debugMode and _G.C_AddOns then
            local cpu = _G.C_AddOns.GetAddOnCPUUsage("zSuite")
            if cpu and db.perfThreshold and cpu > db.perfThreshold then
                zUI.Print(string.format("LorisID 性能告警: %.2fms", cpu))
            end
        end
        _G.C_Timer.After(5, PerfCheck)
    end
    _G.C_Timer.After(5, PerfCheck)
end

-- ============================================================
--  设置面板构建（给 zSuite Config/Options.lua 调用）
-- ============================================================
function mod:BuildOptions(content)
    local db = GetDB()
    if not db or not content then return end

    local yOff = -4

    -- 启用 + 调试
    yOff = zUI.OptionsCheckbox(content, yOff, "启用 LorisID",
        function() return db.enabled end,
        function(v) db.enabled = v end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "调试模式",
        function() return db.debugMode end,
        function(v) db.debugMode = v end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "显示图标 ID",
        function() return db.showIcons end,
        function(v) db.showIcons = v end,
        "物品提示中显示关联图标 ID"
    )

    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8

    -- ID 类型（3 列）
    zUI.OptionsSectionLabel(content, yOff, "显示的 ID 类型")
    yOff = yOff - 12

    local idEntries = {
        {"item", "物品"},      {"spell", "法术"},      {"unit", "单位"},
        {"quest", "任务"},     {"achievement", "成就"}, {"currency", "货币"},
        {"mount", "坐骑"},     {"toy", "玩具"},         {"talent", "天赋"},
        {"set", "套装"},       {"visual", "幻象"},      {"companion", "伙伴"},
        {"object", "物件"},    {"battlepet", "战宠"},   {"instance", "副本"},
        {"recipe", "配方"},    {"macro", "宏"},         {"pvp", "PvP"},
        {"minimap", "小地图"}, {"icon", "图标"},        {"petspell", "宠物技能"},
    }

    local colW, rowH, startY = 195, 19, yOff
    local ci, cy = 0, startY

    for i, entry in ipairs(idEntries) do
        local id, label = entry[1], entry[2]
        if db.ids[id] ~= nil then
            local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            cb:SetSize(18, 18)
            cb:SetPoint("TOPLEFT", content, "TOPLEFT", 8 + ci * colW, cy)
            cb:SetChecked(db.ids[id])
            local lbl = cb:CreateFontString(nil, "OVERLAY")
            lbl:SetFont(zUI.GetDefaultRowFontTexture(), 11, zUI.GetFontFlags())
            lbl:SetPoint("LEFT", cb, "RIGHT", 4, -1)
            lbl:SetText(label); lbl:SetTextColor(0.85, 0.85, 0.85)
            cb:SetScript("OnClick", function(self) db.ids[id] = self:GetChecked() end)
            cy = cy - rowH
            if i % 7 == 0 then ci = ci + 1; cy = startY end
        end
    end

    yOff = startY - 7 * rowH - 8
    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8

    -- 缓存与性能
    zUI.OptionsSectionLabel(content, yOff, "缓存与性能")
    yOff = yOff - 12
    yOff = zUI.OptionsCheckbox(content, yOff, "启用缓存",
        function() return db.cache.enabled end,
        function(v) db.cache.enabled = v end
    )
    yOff = zUI.OptionsSlider(content, yOff, "缓存大小", 100, 5000, 100,
        function() return db.cache.maxSize end,
        function(v) db.cache.maxSize = v end
    )
    yOff = zUI.OptionsSlider(content, yOff, "性能阈值 (ms)", 1, 100, 1,
        function() return db.perfThreshold end,
        function(v) db.perfThreshold = v end
    )
end

-- ============================================================
--  斜杠命令路由
-- ============================================================
function mod:HandleSlash(msg)
    -- 预留 - 通过 /lid 已经注册，这里提供编程式路由
end
