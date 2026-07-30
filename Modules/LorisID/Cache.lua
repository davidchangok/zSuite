--[[
    LorisID/Cache.lua — LRU 缓存系统
    从 LorisID 2.3.0 迁移。Bug#1 修复：O(1) 桶大小计数（维护 self.counts 计数器）。
    Security：写入前通过 zUI.Security.IsSafe 拒绝涉密数据。
--]]

local addonName, addonTable = ...

local zSuite, zUI = _G.zSuite, _G.zUI
if not zSuite then return end

local mod = zSuite.modules.lorisid
if not mod then return end

-- ============================================================
--  缓存配置
-- ============================================================
local CACHE_CONFIG = {
    maxSize = 1000,
    defaultTTL = 600,
    cleanupInterval = 300,
    types = {
        ["item"] = 600,
        ["spell"] = 600,
        ["unit"] = 300,
        ["quest"] = 600,
        ["achievement"] = 3600,
    }
}

-- ============================================================
--  Cache 对象
-- ============================================================
local Cache = {
    store = {},
    counts = {},   -- Bug#1 修复：O(1) 桶大小计数器
    stats = { hits = 0, misses = 0, sets = 0, evictions = 0 },
    lastCleanup = _G.GetTime(),
}
mod.Cache = Cache

-- ============================================================
--  初始化
-- ============================================================
function Cache:Initialize()
    local idTypesMap = {
        item = true, spell = true, petspell = true, unit = true,
        quest = true, achievement = true, currency = true, mount = true,
        toy = true, talent = true, set = true, visual = true,
        companion = true, object = true, battlepet = true, instance = true,
        recipe = true, macro = true, pvp = true, minimap = true, icon = true,
    }
    for idType in pairs(idTypesMap) do
        self.store[idType] = {}
        self.counts[idType] = 0
    end

    -- 定期自动清理
    local function ScheduleCleanup()
        self:Cleanup()
        _G.C_Timer.After(CACHE_CONFIG.cleanupInterval, ScheduleCleanup)
    end
    _G.C_Timer.After(CACHE_CONFIG.cleanupInterval, ScheduleCleanup)
end

-- ============================================================
--  读取
-- ============================================================
function Cache:Get(cacheType, key)
    local db = zSuite.db and zSuite.db.modules and zSuite.db.modules.lorisid
    if not db or not db.cache or not db.cache.enabled then return nil end

    local bucket = self.store[cacheType]
    if not bucket then return nil end

    local entry = bucket[key]
    if entry then
        local now = _G.GetTime()
        local ttl = (CACHE_CONFIG.types and CACHE_CONFIG.types[cacheType]) or CACHE_CONFIG.defaultTTL
        if (now - entry.timestamp) > ttl then
            bucket[key] = nil
            self.counts[cacheType] = math.max((self.counts[cacheType] or 0) - 1, 0)
            self.stats.misses = (self.stats.misses or 0) + 1
            return nil
        end
        entry.lastAccess = now
        self.stats.hits = (self.stats.hits or 0) + 1
        return entry.data
    end

    self.stats.misses = (self.stats.misses or 0) + 1
    return nil
end

-- ============================================================
--  写入（Bug#1 修复：O(1) 计数器）
-- ============================================================
function Cache:Set(cacheType, key, data)
    local db = zSuite.db and zSuite.db.modules and zSuite.db.modules.lorisid
    if not db or not db.cache or not db.cache.enabled then return end

    -- Security：拒绝涉密数据
    if not zUI.Security.IsSafe(data) then return end

    local bucket = self.store[cacheType]
    if not bucket then return end

    local maxSize = (db.cache.maxSize) or CACHE_CONFIG.maxSize
    local currentCount = self.counts[cacheType] or 0

    -- LRU 淘汰
    if currentCount >= maxSize then
        self:EvictLRU(cacheType)
    end

    -- 仅在新插入时增加计数（覆盖旧 key 不计数）
    if not bucket[key] then
        self.counts[cacheType] = currentCount + 1
    end

    local now = _G.GetTime()
    bucket[key] = {
        data = data,
        timestamp = now,
        lastAccess = now,
    }
    self.stats.sets = (self.stats.sets or 0) + 1
end

-- ============================================================
--  LRU 淘汰
-- ============================================================
function Cache:EvictLRU(cacheType)
    local bucket = self.store[cacheType]
    if not bucket then return end

    local oldestKey = nil
    local oldestTime = math.huge
    for k, entry in pairs(bucket) do
        if entry.lastAccess < oldestTime then
            oldestTime = entry.lastAccess
            oldestKey = k
        end
    end

    if oldestKey then
        bucket[oldestKey] = nil
        self.counts[cacheType] = math.max((self.counts[cacheType] or 0) - 1, 0)
        self.stats.evictions = (self.stats.evictions or 0) + 1
    end
end

-- ============================================================
--  清理过期项
-- ============================================================
function Cache:Cleanup()
    local now = _G.GetTime()
    for cacheType, bucket in pairs(self.store) do
        local ttl = (CACHE_CONFIG.types and CACHE_CONFIG.types[cacheType]) or CACHE_CONFIG.defaultTTL
        for k, entry in pairs(bucket) do
            if (now - entry.timestamp) > ttl then
                bucket[k] = nil
                self.counts[cacheType] = math.max((self.counts[cacheType] or 0) - 1, 0)
            end
        end
    end
    self.lastCleanup = now
end

-- ============================================================
--  清空
-- ============================================================
function Cache:Clear(cacheType)
    if cacheType and self.store[cacheType] then
        self.store[cacheType] = {}
        self.counts[cacheType] = 0
    elseif not cacheType then
        for k in pairs(self.store) do
            self.store[k] = {}
            self.counts[k] = 0
        end
    end
end

-- 初始化
Cache:Initialize()
