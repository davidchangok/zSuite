--[[
    LorisID/ItemQuery.lua — 物品异步查询与审计
    从 LorisID 2.3.0 迁移。使用 zUI.Security 保护 C_Item API 调用。
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

local mod = zSuite.modules.lorisid
if not mod then return end

local L = mod.L or _G.zSuiteLorisID_L
local Security = zUI.Security

local C_Item = _G.C_Item
local C_CurrencyInfo = _G.C_CurrencyInfo

local ItemQuery = { name = "ItemQuery", enabled = true }
mod.ItemQuery = ItemQuery

-- ============================================================
--  处理异步返回数据
-- ============================================================
function ItemQuery:ProcessData(data, chatOutput)
    if not data or not data.link then return end

    if chatOutput then
        local _, _, _, qualityHex = C_Item.GetItemQualityColor(data.quality or 1)
        print(("|cFF%s[LorisID]|r %s"):format(qualityHex and qualityHex:sub(3) or "ffffff", data.link))
    end

    -- 记录最后一次成功查询
    local db = zSuite.db and zSuite.db.modules and zSuite.db.modules.lorisid
    if db then
        db.lastItem = {
            id = data.id, name = data.name, link = data.link,
            time = _G.GetServerTime and _G.GetServerTime() or _G.time(),
        }
    end
end

-- ============================================================
--  战团绑定状态
-- ============================================================
function ItemQuery:GetWarbandStatus(itemLocation)
    if not itemLocation then return nil end
    return Security:SafeGet(C_Item.IsBound, itemLocation)
end

-- ============================================================
--  物品元数据
-- ============================================================
function ItemQuery:GetMetadata(itemID)
    local info = { C_Item.GetItemInfo(itemID) }
    if not info[1] then return nil end

    return {
        name        = info[1],
        link        = info[2],
        quality     = info[3],
        iLevel      = info[4],
        stackSize   = info[8] or 1,
        sellPrice   = info[11] or 0,
        bindType    = info[14],
        expansionID = info[15],
        description = nil,
    }
end

-- ============================================================
--  统一异步查询入口
-- ============================================================
function ItemQuery:Query(itemIdentifier, chatOutput)
    if not itemIdentifier then return end
    mod.AsyncLoader:LoadItem(itemIdentifier, function(data)
        self:ProcessData(data, chatOutput)
    end)
end

-- ============================================================
--  调试审计
-- ============================================================
function ItemQuery:Audit(itemID)
    local db = zSuite.db and zSuite.db.modules and zSuite.db.modules.lorisid
    if not db or not db.debugMode then return end

    local meta = self:GetMetadata(itemID)
    if meta then
        print(("|cff4cff4c[LorisID]|r Item Audit:"))
        print("- iLevel: " .. tostring(meta.iLevel))
        print("- Sell Price: " .. C_CurrencyInfo.GetCoinTextureString(meta.sellPrice))
        print("- Stack: " .. tostring(meta.stackSize))
        print("- Expansion: " .. tostring(meta.expansionID))
    end
end
