--[[
    LorisID/AuraScanner.lua — 光环扫描与 CSV 导出
    从 LorisID 2.3.0 迁移。Bug#8 修复：清理已移除 table pool 的残留注释。
    Security：所有 auraData 字段通过 zUI.Security 审计。
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

local mod = zSuite.modules.lorisid
if not mod then return end

local L = mod.L or _G.zSuiteLorisID_L

local AuraUtil = _G.AuraUtil

local AuraScanner = { name = "AuraScanner", enabled = true }
mod.AuraScanner = AuraScanner

-- ============================================================
--  全量光环扫描
-- ============================================================
function AuraScanner:ScanUnit(unit, filter)
    if not unit or not _G.UnitExists(unit) then return nil end

    local results = {}

    AuraUtil.ForEachAura(unit, filter or "HELPFUL", nil, function(auraData)
        if auraData then
            -- Security：提取 points 数组并逐值审计
            local safePoints = {}
            if auraData.points and zUI.Security.IsSafe(auraData.points) then
                for i, val in ipairs(auraData.points) do
                    safePoints[i] = zUI.Security.IsSafe(val) and val or 0
                end
            end

            table.insert(results, {
                name           = zUI.Security.IsSafe(auraData.name) and auraData.name or L.SecretValueBlocked,
                icon           = zUI.Security.IsSafe(auraData.icon) and auraData.icon or 0,
                count          = zUI.Security.IsSafe(auraData.applications) and auraData.applications or 0,
                dispelType     = zUI.Security.IsSafe(auraData.dispelName) and auraData.dispelName or "Unknown",
                duration       = zUI.Security.IsSafe(auraData.duration) and auraData.duration or 0,
                expirationTime = zUI.Security.IsSafe(auraData.expirationTime) and auraData.expirationTime or 0,
                caster         = zUI.Security.IsSafe(auraData.sourceUnit) and auraData.sourceUnit or "Unknown",
                spellID        = auraData.spellId,
                instanceID     = auraData.auraInstanceID,
                isStealable    = zUI.Security.IsSafe(auraData.isStealable) and auraData.isStealable or false,
                points         = safePoints,
                isFromPlayer   = zUI.Security.IsSafe(auraData.isFromPlayerOrPlayerPet) and auraData.isFromPlayerOrPlayerPet or false,
            })
        end
        return false
    end, true)

    return results
end

-- ============================================================
--  快速检索特定 SpellID
-- ============================================================
function AuraScanner:HasAura(unit, spellID, filter)
    local found = false
    AuraUtil.ForEachAura(unit, filter or "HELPFUL", nil, function(auraData)
        if auraData and auraData.spellId == spellID then
            found = true
            return true
        end
        return false
    end, true)
    return found
end

-- ============================================================
--  提取特定 points 值
-- ============================================================
function AuraScanner:GetAuraValue(unit, spellID, pointIndex, filter)
    local value = 0
    AuraUtil.ForEachAura(unit, filter or "HELPFUL", nil, function(auraData)
        if auraData and auraData.spellId == spellID and auraData.points
           and zUI.Security.IsSafe(auraData.points) then
            local rawVal = auraData.points[pointIndex or 1]
            if zUI.Security.IsSafe(rawVal) then
                value = rawVal
            end
            return true
        end
        return false
    end, true)
    return value
end

-- ============================================================
--  CSV 导出
-- ============================================================
function AuraScanner:ExportToCSV(unit, filter)
    local auras = self:ScanUnit(unit, filter)
    if not auras or #auras == 0 then return nil end

    local lines = { "SpellID,Name,Count,InstanceID,Caster,Duration,Expiration,DispelType,IsStealable,Points" }
    for _, aura in ipairs(auras) do
        local pointsStr = aura.points and table.concat(aura.points, "|") or ""
        local line = string.format("%d,%s,%d,%s,%s,%.1f,%.1f,%s,%s,%s",
            aura.spellID or 0,
            (aura.name or ""):gsub(",", " "),
            aura.count or 0,
            tostring(aura.instanceID or ""),
            aura.caster or "none",
            aura.duration or 0,
            aura.expirationTime or 0,
            aura.dispelType or "None",
            tostring(aura.isStealable == true),
            pointsStr
        )
        table.insert(lines, line)
    end
    return table.concat(lines, "\n")
end

-- ============================================================
--  调试输出
-- ============================================================
function AuraScanner:PrintDebug(unit)
    local db = zSuite.db and zSuite.db.modules and zSuite.db.modules.lorisid
    if not db or not db.debugMode then return end

    local buffs = self:ScanUnit(unit, "HELPFUL")
    if buffs then
        print(("|cff4cff4c[LorisID]|r Scanning auras for: %s"):format(unit))
        for _, b in ipairs(buffs) do
            print(string.format("- [%d] %s (Count: %d)", b.spellID, b.name, b.count))
        end
    end
end
