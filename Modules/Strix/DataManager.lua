--[[
    Strix/DataManager.lua — 数据持久化层
    从 Strix 1.1.1 迁移至 zSuite，DB 路径改为 zSuiteDB.modules.strix。
    Bug#1 修复：MoveRecentToAlts 填入当前角色完整信息。
    Security：RegisterCurrentCharacter 的 UnitXxx 调用由 zUI.Security.SafeGet 包裹。
--]]

local addonName, addonTable = ...

local zSuite = _G.zSuite
if not zSuite then return end

local zUI = _G.zUI
local L = _G.zSuiteStrix_L

local mod = zSuite.modules.strix
if not mod then return end

local Data = {}
mod.Data = Data

-- ============================================================
--  常量
-- ============================================================
local DB_VERSION = 5
local DEFAULT_DISPLAY_LIMIT = 99
local DEFAULT_RECENT_LIMIT = 10
local MAX_RECENT_RECIPIENTS = 50

-- ============================================================
--  内部辅助
-- ============================================================
local function GetDB()
    if not zSuite.db or not zSuite.db.modules or not zSuite.db.modules.strix then
        return nil
    end
    return zSuite.db.modules.strix
end

local function BuildKey(name, realm)
    if not name then return nil end
    return (name:gsub("%s+", ""):lower()) .. "-" .. (realm and realm:gsub("%s+", ""):lower() or "")
end

-- ============================================================
--  数据库验证与清理
-- ============================================================
local function ValidateDatabase(db)
    if not db then return end
    if type(db.version) ~= "number" then db.version = 0 end
    if type(db.displayLimit) ~= "number" then db.displayLimit = DEFAULT_DISPLAY_LIMIT end
    if type(db.recentDisplayLimit) ~= "number" then db.recentDisplayLimit = DEFAULT_RECENT_LIMIT end
    if type(db.autoRemoveIfAlt) ~= "boolean" then db.autoRemoveIfAlt = true end
    if type(db.alts) ~= "table" then db.alts = {} end
    if type(db.recentRecipients) ~= "table" then db.recentRecipients = {} end
end

local function CleanupDatabase(db)
    if not db or not db.alts then return end
    -- 移除损坏的小号记录（至少需要 name 和 realm）
    local cleaned = {}
    for i, alt in ipairs(db.alts) do
        if type(alt) == "table" and alt.name and alt.realm and alt.key then
            cleaned[#cleaned + 1] = alt
        end
    end
    db.alts = cleaned

    -- 清理最近收件人
    if not db.recentRecipients then db.recentRecipients = {} end
    local recentCleaned = {}
    for i, r in ipairs(db.recentRecipients) do
        if type(r) == "table" and r.name and r.key then
            recentCleaned[#recentCleaned + 1] = r
        end
    end
    db.recentRecipients = recentCleaned
end

-- ============================================================
--  公开 API
-- ============================================================

function Data:Init()
    local db = GetDB()
    if not db then return end
    ValidateDatabase(db)
    CleanupDatabase(db)
end

--- 注册当前角色为小号
function Data:RegisterCurrentCharacter()
    local db = GetDB()
    if not db then return end

    -- Security: SafeGet 包裹所有外部 API 调用
    local name, realm = zUI.Security.SafeGet(_G.UnitName, "player")
    if not name then return end
    realm = realm or zUI.Security.SafeGet(_G.GetRealmName) or ""

    local faction = zUI.Security.SafeGet(_G.UnitFactionGroup, "player")
    local _, classFile = zUI.Security.SafeGet(_G.UnitClass, "player")
    local race = zUI.Security.SafeGet(_G.UnitRace, "player")
    local sex = zUI.Security.SafeGet(_G.UnitSex, "player")
    local level = zUI.Security.SafeGet(_G.UnitLevel, "player")

    local key = BuildKey(name, realm)
    if not key then return end

    -- Upsert: 找到现有记录则更新，否则追加
    local found = false
    for i, alt in ipairs(db.alts) do
        if alt.key == key then
            alt.name = name
            alt.realm = realm
            alt.faction = faction
            alt.classFile = classFile
            alt.race = race
            alt.sex = sex
            alt.level = level
            found = true
            break
        end
    end

    if not found then
        table.insert(db.alts, {
            name = name,
            realm = realm,
            faction = faction,
            classFile = classFile,
            race = race,
            sex = sex,
            level = level,
            key = key,
        })
    end

    -- Auto-remove from recent if this is now an alt
    if db.autoRemoveIfAlt then
        Data:RemoveRecentRecipient(key)
    end
end

function Data:GetAlts()
    local db = GetDB()
    if not db then return {} end
    return db.alts or {}
end

function Data:GetAltByKey(key)
    local db = GetDB()
    if not db or not key then return nil end
    for _, alt in ipairs(db.alts or {}) do
        if alt.key == key then return alt end
    end
    return nil
end

function Data:IsMyAlt(key)
    return Data:GetAltByKey(key) ~= nil
end

function Data:GetDisplayLimit()
    local db = GetDB()
    return (db and db.displayLimit) or DEFAULT_DISPLAY_LIMIT
end

function Data:SetDisplayLimit(value)
    local db = GetDB()
    if not db then return end
    db.displayLimit = math.max(1, math.min(tonumber(value) or DEFAULT_DISPLAY_LIMIT, 99))
end

function Data:MoveAlt(from, to)
    local db = GetDB()
    if not db or not db.alts then return end
    if from < 1 or from > #db.alts or to < 1 or to > #db.alts or from == to then return end
    local entry = table.remove(db.alts, from)
    table.insert(db.alts, to, entry)
end

function Data:DeleteAltByIndex(index)
    local db = GetDB()
    if not db or not db.alts or index < 1 or index > #db.alts then return end
    table.remove(db.alts, index)
end

function Data:PromoteAltToFirst(key)
    local db = GetDB()
    if not db or not db.alts or not key then return end
    for i, alt in ipairs(db.alts) do
        if alt.key == key and i > 1 then
            local entry = table.remove(db.alts, i)
            table.insert(db.alts, 1, entry)
            return true
        end
    end
    return false
end

function Data:AddRecentRecipient(name, realm)
    local db = GetDB()
    if not db or not name then return end
    realm = realm or ""

    local key = BuildKey(name, realm)
    if not key then return end

    -- Skip if already a known alt
    if Data:IsMyAlt(key) then return end

    -- Upsert
    for i, r in ipairs(db.recentRecipients or {}) do
        if r.key == key then
            r.timestamp = _G.GetServerTime and _G.GetServerTime() or _G.time()
            -- Move to front
            local entry = table.remove(db.recentRecipients, i)
            table.insert(db.recentRecipients, 1, entry)
            return
        end
    end

    -- Insert new
    table.insert(db.recentRecipients, 1, {
        name = name,
        realm = realm,
        key = key,
        timestamp = _G.GetServerTime and _G.GetServerTime() or _G.time(),
    })

    -- Trim to max
    while #db.recentRecipients > MAX_RECENT_RECIPIENTS do
        table.remove(db.recentRecipients)
    end
end

function Data:GetRecentRecipients()
    local db = GetDB()
    if not db then return {} end
    return db.recentRecipients or {}
end

function Data:GetRecentDisplayLimit()
    local db = GetDB()
    return (db and db.recentDisplayLimit) or DEFAULT_RECENT_LIMIT
end

function Data:SetRecentDisplayLimit(value)
    local db = GetDB()
    if not db then return end
    db.recentDisplayLimit = math.max(1, math.min(tonumber(value) or DEFAULT_RECENT_LIMIT, 50))
end

function Data:RemoveRecentRecipient(key)
    local db = GetDB()
    if not db or not key then return end
    for i, r in ipairs(db.recentRecipients or {}) do
        if r.key == key then
            table.remove(db.recentRecipients, i)
            return true
        end
    end
    return false
end

function Data:RemoveRecentByIndex(index)
    local db = GetDB()
    if not db or not db.recentRecipients or index < 1 or index > #db.recentRecipients then return end
    table.remove(db.recentRecipients, index)
end

--- 提升最近收件人为小号
--- Bug#1 修复：如果当前角色 name-realm 匹配，填入完整信息（faction/class/race/sex/level）
function Data:MoveRecentToAlts(index)
    local db = GetDB()
    if not db or not db.recentRecipients or index < 1 or index > #db.recentRecipients then return end

    local entry = table.remove(db.recentRecipients, index)
    if not entry then return end

    -- Bug#1 修复：检查当前角色是否匹配此收件人
    local currentName = zUI.Security.SafeGet(_G.UnitName, "player")
    local currentRealm = zUI.Security.SafeGet(_G.GetRealmName) or ""
    local currentKey = BuildKey(currentName, currentRealm)

    local faction, classFile, race, sex, level = nil, nil, nil, nil, nil
    if currentKey == entry.key then
        -- 当前角色就是此收件人 → 填入完整信息
        faction = zUI.Security.SafeGet(_G.UnitFactionGroup, "player")
        _, classFile = zUI.Security.SafeGet(_G.UnitClass, "player")
        race = zUI.Security.SafeGet(_G.UnitRace, "player")
        sex = zUI.Security.SafeGet(_G.UnitSex, "player")
        level = zUI.Security.SafeGet(_G.UnitLevel, "player")
    end

    -- 检查是否已有同名小号
    local found = false
    for i, alt in ipairs(db.alts or {}) do
        if alt.key == entry.key then
            -- 更新已有记录
            if faction then alt.faction = faction end
            if classFile then alt.classFile = classFile end
            if race then alt.race = race end
            if sex then alt.sex = sex end
            if level then alt.level = level end
            found = true
            break
        end
    end

    if not found then
        table.insert(db.alts, {
            name = entry.name,
            realm = entry.realm,
            key = entry.key,
            faction = faction,
            classFile = classFile,
            race = race,
            sex = sex,
            level = level,
        })
    end
end

function Data:GetAutoRemoveIfAlt()
    local db = GetDB()
    return (db and db.autoRemoveIfAlt) ~= false
end

function Data:SetAutoRemoveIfAlt(value)
    local db = GetDB()
    if not db then return end
    db.autoRemoveIfAlt = value and true or false
end
