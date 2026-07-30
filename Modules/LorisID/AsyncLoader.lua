--[[
    LorisID/AsyncLoader.lua — 异步数据加载器
    从 LorisID 2.3.0 迁移。使用 12.0 Item/Spell Mixin 模式 + Quest 轮询。
    Security：所有外部 API 调用使用 zUI.Security 审计。
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

local mod = zSuite.modules.lorisid
if not mod then return end

local C_Item = _G.C_Item
local C_Spell = _G.C_Spell
local C_QuestLog = _G.C_QuestLog
local Item = _G.Item
local Spell = _G.Spell

local AsyncLoader = {}
mod.AsyncLoader = AsyncLoader

-- ============================================================
--  物品异步加载
-- ============================================================
function AsyncLoader:LoadItem(itemID, callback)
    if not itemID or itemID == 0 then return end

    -- 优先查缓存
    local cached = mod.Cache:Get("item", itemID)
    if cached then
        callback(cached)
        return
    end

    local itemObj = Item:CreateFromItemID(tonumber(itemID) or 0)
    if itemObj:IsItemEmpty() then return end

    itemObj:ContinueOnItemLoad(function()
        local info = { C_Item.GetItemInfo(itemID) }
        if info[1] then
            local data = {
                id          = itemID,
                name        = info[1],
                link        = info[2],
                quality     = info[3],
                level       = info[4],
                icon        = info[10],
                bindType    = info[14],
                description = nil,
                expansionID = info[15],
            }
            mod.Cache:Set("item", itemID, data)
            callback(data)
        end
    end)
end

-- ============================================================
--  法术异步加载
-- ============================================================
function AsyncLoader:LoadSpell(spellID, callback)
    if not spellID or spellID == 0 then return end

    local cached = mod.Cache:Get("spell", spellID)
    if cached then
        callback(cached)
        return
    end

    local spellObj = Spell:CreateFromSpellID(tonumber(spellID) or 0)
    spellObj:ContinueOnSpellLoad(function()
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo then
            local data = {
                name        = spellInfo.name,
                icon        = spellInfo.iconID,
                castTime    = spellInfo.castTime,
                minRange    = spellInfo.minRange,
                maxRange    = spellInfo.maxRange,
                description = C_Spell.GetSpellDescription(spellID) or "",
            }
            mod.Cache:Set("spell", spellID, data)
            callback(data)
        end
    end)
end

-- ============================================================
--  任务异步加载（轮询重试，最多 10 次 ≈ 2 秒）
-- ============================================================
function AsyncLoader:LoadQuest(questID, callback, retryCount)
    if not questID or questID == 0 then return end

    local cached = mod.Cache:Get("quest", questID)
    if cached then
        callback(cached)
        return
    end

    retryCount = retryCount or 0
    if retryCount > 10 then return end

    if not C_QuestLog.IsQuestDataCached(questID) then
        C_QuestLog.RequestLoadQuestByID(questID)
        _G.C_Timer.After(0.2, function()
            self:LoadQuest(questID, callback, retryCount + 1)
        end)
        return
    end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    if title and title ~= "" then
        local data = { name = title }
        mod.Cache:Set("quest", questID, data)
        callback(data)
    end
end

-- ============================================================
--  批量预加载
-- ============================================================
function AsyncLoader:BulkPreload(idList, idType)
    if type(idList) ~= "table" then return end
    for _, id in ipairs(idList) do
        if idType == "item" then
            C_Item.RequestLoadItemDataByID(id)
        elseif idType == "spell" then
            Spell:CreateFromSpellID(id)
        end
    end
end
