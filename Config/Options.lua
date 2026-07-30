--[[
    zSuite/Config/Options.lua — 共享分页选项窗体
    使用 zUI.OptionsBuilder 构建，整合 LorisID/Strix/PhaseWatcher 的设置
    通过标签页分开各模块的选项。
--]]

local addonName, addonTable = ...

_G.zSuite = _G.zSuite or {}
local zSuite = _G.zSuite

local optionsFrame = nil

-- ============================================================
--  通用标签页：全局 UI 设置 + 模块开关
-- ============================================================
local function BuildGeneralTab(content)
    local db = zSuite.db
    if not db then return end

    local yOff = -4

    -- 字体大小由 zUI.config.fontSize 控制（默认 13），仅在创建新 FontString 时生效。
    -- 由于 WoW 的 FontString 创建后无法动态批量刷新，全局字号滑块已移除。
    -- 需要字体大小设置的模块（如 PhaseWatcher）自行提供独立设置。
    -- "界面设置" 下暂无控件，保留标签以便未来添加真正有效的设置项。

    zUI.OptionsSectionLabel(content, yOff, "窗口")
    yOff = yOff - 12

    -- 角色级窗口布局
    yOff = zUI.OptionsCheckbox(content, yOff, "角色独立的窗口位置",
        function() return db.ui.characterWindowLayout end,
        function(v)
            db.ui.characterWindowLayout = v
            zUI.config.characterWindowLayout = v
        end, "启用后每个角色的窗口位置独立保存"
    )

    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8

    -- 模块开关
    zUI.OptionsSectionLabel(content, yOff, "模块")
    yOff = yOff - 12

    local modNames = {
        lorisid = "LorisID — 工具提示 ID 显示",
        strix = "Strix — 邮件收件人助手",
        phasewatcher = "PhaseWatcher — 位面监测",
    }

    for name, label in pairs(modNames) do
        local modCfg = db.modules and db.modules[name]
        if modCfg then
            yOff = zUI.OptionsCheckbox(content, yOff, label,
                function() return modCfg.enabled end,
                function(v)
                    zSuite.SetModuleEnabled(name, v)
                end
            )
        end
    end
end

-- ============================================================
--  LorisID 标签页
-- ============================================================
local function BuildLorisIDTab(content)
    local mod = zSuite.modules.lorisid
    if mod and mod.BuildOptions then
        mod:BuildOptions(content)
        return
    end

    -- 回退：直接从 DB 构建
    local db = zSuite.db
    if not db or not db.modules.lorisid then return end
    local cfg = db.modules.lorisid

    local yOff = -4

    -- 主开关 + 调试
    yOff = zUI.OptionsCheckbox(content, yOff, "启用 LorisID",
        function() return cfg.enabled end,
        function(v) cfg.enabled = v end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "调试模式",
        function() return cfg.debugMode end,
        function(v) cfg.debugMode = v end
    )

    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8

    -- ID 类型复选框（3 列布局）
    zUI.OptionsSectionLabel(content, yOff, "显示的 ID 类型")
    yOff = yOff - 12

    local idTypes = {
        {"item", "物品"},      {"spell", "法术"},      {"unit", "单位"},
        {"quest", "任务"},     {"achievement", "成就"}, {"currency", "货币"},
        {"mount", "坐骑"},     {"toy", "玩具"},         {"talent", "天赋"},
        {"set", "套装"},       {"visual", "幻象"},      {"companion", "伙伴"},
        {"object", "物品"},    {"battlepet", "战宠"},   {"instance", "副本"},
        {"recipe", "配方"},    {"macro", "宏"},         {"pvp", "PvP"},
        {"minimap", "小地图"}, {"icon", "图标"},        {"petspell", "宠物技能"},
    }

    local colW = 180
    local rowHeight = 19
    local startY = yOff
    local colIndex = 0
    local colY = startY

    for i, entry in ipairs(idTypes) do
        local id = entry[1]
        local label = entry[2]

        if cfg.ids[id] ~= nil then
            local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            cb:SetSize(18, 18)
            cb:SetPoint("TOPLEFT", content, "TOPLEFT", 8 + colIndex * colW, colY)
            cb:SetChecked(cfg.ids[id])

            local lbl = cb:CreateFontString(nil, "OVERLAY")
            lbl:SetFont(zUI.GetDefaultRowFontTexture(), 11, zUI.GetFontFlags())
            lbl:SetPoint("LEFT", cb, "RIGHT", 4, -1)
            lbl:SetText(label)
            lbl:SetTextColor(0.85, 0.85, 0.85)

            cb:SetScript("OnClick", function(self)
                cfg.ids[id] = self:GetChecked()
            end)

            colY = colY - rowHeight
            if i % 7 == 0 then
                colIndex = colIndex + 1
                colY = startY
            end
        end
    end

    yOff = startY - 7 * rowHeight
    yOff = yOff - 8

    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8

    -- 缓存与性能
    zUI.OptionsSectionLabel(content, yOff, "缓存与性能")
    yOff = yOff - 12

    yOff = zUI.OptionsCheckbox(content, yOff, "启用缓存",
        function() return cfg.cache.enabled end,
        function(v) cfg.cache.enabled = v end
    )
    yOff = zUI.OptionsSlider(content, yOff, "缓存大小", 100, 5000, 100,
        function() return cfg.cache.maxSize end,
        function(v) cfg.cache.maxSize = v end, "每种类型的最大缓存条目数"
    )
    yOff = zUI.OptionsSlider(content, yOff, "性能阈值 (ms)", 1, 100, 1,
        function() return cfg.perfThreshold end,
        function(v) cfg.perfThreshold = v end, "CPU 使用超过此值将在调试模式下告警"
    )
end

-- ============================================================
--  Strix 标签页
-- ============================================================
local function BuildStrixTab(content)
    local mod = zSuite.modules.strix
    if mod and mod.BuildOptions then
        mod:BuildOptions(content)
        return
    end

    local db = zSuite.db
    if not db or not db.modules.strix then return end
    local cfg = db.modules.strix

    local yOff = -4

    yOff = zUI.OptionsCheckbox(content, yOff, "启用 Strix",
        function() return cfg.enabled end,
        function(v) cfg.enabled = v end
    )

    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8

    yOff = zUI.OptionsSlider(content, yOff, "下拉菜单小号数量", 1, 99, 1,
        function() return cfg.displayLimit end,
        function(v) cfg.displayLimit = v end, "邮件下拉菜单中显示的小号最大数量"
    )
    yOff = zUI.OptionsSlider(content, yOff, "最近收件人数量", 1, 50, 1,
        function() return cfg.recentDisplayLimit end,
        function(v) cfg.recentDisplayLimit = v end, "邮件下拉菜单中显示的最近收件人最大数量"
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "自动移除已成为小号的收件人",
        function() return cfg.autoRemoveIfAlt end,
        function(v) cfg.autoRemoveIfAlt = v end, "登录小号角色时自动从最近收件人中移除"
    )
end

-- ============================================================
--  PhaseWatcher 标签页
-- ============================================================
local function BuildPhaseWatcherTab(content)
    local mod = zSuite.modules.phasewatcher
    if mod and mod.BuildOptions then
        mod:BuildOptions(content)
        return
    end

    local db = zSuite.db
    if not db or not db.modules.phasewatcher then return end
    local cfg = db.modules.phasewatcher

    local yOff = -4

    yOff = zUI.OptionsCheckbox(content, yOff, "启用 PhaseWatcher",
        function() return cfg.enabled end,
        function(v) cfg.enabled = v end
    )

    zUI.OptionsDivider(content, yOff, 0)
    yOff = yOff - 8

    yOff = zUI.OptionsCheckbox(content, yOff, "十六进制显示",
        function() return cfg.useHexadecimal end,
        function(v) cfg.useHexadecimal = v end, "以十六进制格式显示位面 ID"
    )
    yOff = zUI.OptionsSlider(content, yOff, "更新间隔 (秒)", 0.1, 5.0, 0.1,
        function() return cfg.updateInterval end,
        function(v) cfg.updateInterval = v end, "检测位面 ID 的时间间隔"
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "锁定窗口",
        function() return cfg.isLocked end,
        function(v) cfg.isLocked = v end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "战斗中自动隐藏",
        function() return cfg.autoHideInCombat end,
        function(v) cfg.autoHideInCombat = v end
    )
    yOff = zUI.OptionsCheckbox(content, yOff, "无窗体",
        function() return cfg.frameless end,
        function(v)
            cfg.frameless = v
            if mod and mod.UpdateFrameless then mod:UpdateFrameless() end
        end,
        "隐藏标题栏和关闭按钮，仅保留位面 ID 文字"
    )
    yOff = zUI.OptionsSlider(content, yOff, "窗口透明度", 0, 1.0, 0.1,
        function() return cfg.windowAlpha end,
        function(v)
            cfg.windowAlpha = v
            if mod and mod.UpdateAppearance then mod:UpdateAppearance() end
        end,
        "窗口背景透明度（仅背景，文字不受影响）"
    )
    yOff = zUI.OptionsSlider(content, yOff, "信息透明度", 0, 1.0, 0.1,
        function() return cfg.textAlpha or 1.0 end,
        function(v)
            cfg.textAlpha = v
            if mod and mod.UpdateUI then mod:UpdateUI() end
        end,
        "仅文字透明度（背景保持不透明）"
    )
end

-- ============================================================
--  OpenOptions — 创建并显示选项窗体（仅在首次调用时构建）
-- ============================================================
function zSuite.OpenOptions()
    if optionsFrame then
        optionsFrame:Show()
        return
    end

    -- 确保 DB 已经存在
    if not zSuite.db then
        zSuite.InitializeDB()
        zSuite.ApplyUIConfig()
    end

    optionsFrame, _, _ = zUI.CreateTabbedOptionsFrame("zSuite 设置", 620, 530)

    -- 设置拖拽
    local titleBar = optionsFrame._closeBtn:GetParent()
    if titleBar then
        zUI.SetupDrag(optionsFrame, titleBar, "optionsFrame")
    end

    -- 注册标签页
    zUI.AddOptionsTab(optionsFrame, "general", "常规", BuildGeneralTab)
    zUI.AddOptionsTab(optionsFrame, "lorisid", "LorisID", BuildLorisIDTab)
    zUI.AddOptionsTab(optionsFrame, "strix", "Strix", BuildStrixTab)
    zUI.AddOptionsTab(optionsFrame, "phasewatcher", "PhaseWatcher", BuildPhaseWatcherTab)

    -- 恢复上次关闭时的位置
    if zSuite.db then
        zUI.RestoreFramePos(optionsFrame, "optionsFrame", 0, 0)
    end

    -- 关闭时保存位置
    local origHide = optionsFrame.Hide
    optionsFrame.Hide = function(self)
        zUI.SaveFramePos(self, "optionsFrame")
        origHide(self)
    end

    optionsFrame:Show()
end

-- ============================================================
--  注册到 Blizzard Settings —— 已移除
--  原因: RegisterCanvasLayoutCategory("zSuite", "zSuite") 的第二个参数
--  被 Blizzard 当作全局 frame 名称，查找 _G["zSuite"] 失败导致
--  Blizzard_SettingsPanel.lua:898 attempt to call a nil value。
--  zSuite 使用 /zsuite 命令打开自定义选项面板，无需 Blizzard 集成。
-- ============================================================
