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
    end
end

-- ============================================================
--  Strix 标签页
-- ============================================================
local function BuildStrixTab(content)
    local mod = zSuite.modules.strix
    if mod and mod.BuildOptions then
        mod:BuildOptions(content)
    end
end

-- ============================================================
--  PhaseWatcher 标签页
-- ============================================================
local function BuildPhaseWatcherTab(content)
    local mod = zSuite.modules.phasewatcher
    if mod and mod.BuildOptions then
        mod:BuildOptions(content)
    end
end

-- ============================================================
--  OpenOptions — 创建并显示选项窗体（仅在首次调用时构建）
-- ============================================================
function zSuite.OpenOptions(tabId)
    if optionsFrame then
        optionsFrame:Show()
        if tabId then zUI.SwitchTab(optionsFrame, tabId) end
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

    -- 如果指定了标签页，切换到它（创建后首次显示为 general）
    if tabId then zUI.SwitchTab(optionsFrame, tabId) end
end

-- ============================================================
--  注册到 Blizzard Settings —— 已移除
--  原因: RegisterCanvasLayoutCategory("zSuite", "zSuite") 的第二个参数
--  被 Blizzard 当作全局 frame 名称，查找 _G["zSuite"] 失败导致
--  Blizzard_SettingsPanel.lua:898 attempt to call a nil value。
--  zSuite 使用 /zsuite 命令打开自定义选项面板，无需 Blizzard 集成。
-- ============================================================
