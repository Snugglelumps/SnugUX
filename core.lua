--[[--------------------------------------------------------------------------
    SnugUX :: core.lua

    Core's whole job:

      1. Let modules register themselves.
      2. Hold the saved variables.
      3. Turn declared settings into Blizzard Settings controls.
      4. Run each control's callbacks when it changes.
      5. Call module:enable() at PLAYER_LOGIN.
      6. Open the settings window.

    Four things to know:

        S.modules      what modules exist
        S.db           their persistent values
        S.controls     the Settings controls
        module         the code that owns a feature

    Startup order:

        files load           modules declare themselves and their settings
        ADDON_LOADED         saved variables exist, controls get built
        PLAYER_LOGIN         module:enable() runs
----------------------------------------------------------------------------]]

local addonName, S = ...
local registerFrame = CreateFrame("Frame")

_G.SnugUX = S

S.core     = {}
S.modules  = {}      -- name -> module
S.controls = {}      -- name -> key -> control
S.db       = nil     -- set at ADDON_LOADED

S.register = {}


S.core.moduleOrder = {}
S.core.root        = nil
S.core.needsReload = false

function S.core.print(...)
    print("|cff66ccffSnugUX|r:", ...)
end


local playerLoginHandlers = {}
local addonLoadedHandlers = {}
local xpEventHandlers = {}


function S.register.playerLogin(...)
    for _, fn in ipairs({...}) do
        table.insert(playerLoginHandlers, fn)
    end
end

function S.register.addonLoaded(...)
    for _, fn in ipairs({...}) do
        table.insert(addonLoadedHandlers, fn)
    end
end

function S.register.event(event, ...)
    if not xpEventHandlers[event] then
        xpEventHandlers[event] = {}
        registerFrame:RegisterEvent(event)
    end

    for _, fn in ipairs({...}) do
        table.insert(xpEventHandlers[event], fn)
    end
end
--[[--------------------------------------------------------------------------
    Controls

    A control is created the moment a module declares it, so you can attach
    callbacks at file load:

        local width = module:slider("width", { default = 420 })
        width:onChange(update_anchor)

    The Blizzard widget behind it isn't built until ADDON_LOADED, when the
    saved variables and the settings page exist. Until then control.setting
    is nil -- read S.db instead.
----------------------------------------------------------------------------]]


local function addControl(module, key, wtype, def)
    def = def or {}

    if S.controls[module.name][key] then
        error("duplicate setting: " .. module.name .. "." .. key)
    end

    local control = {
        module   = module,
        key      = key,
        wtype    = wtype,
        def      = def,

        setting  = nil,    -- the Blizzard object, set at build time
        handlers = {},
    }

        -- Run fn whenever this setting changes. Returns self so you can chain.
    function control:onChange(...)
        for i = 1, select("#", ...) do
            table.insert(self.handlers, (select(i, ...)))
        end
        return self
    end

    function control:GetValue()
        return self.setting:GetValue()
    end

    function control:SetValue(value)
        self.setting:SetValue(value)
    end

    S.controls[module.name][key] = control
    table.insert(module.items, control)

    return control
end

--  name   lowercase, unique. Keys the page, S.modules, S.controls and S.db.
--  opts   title    page name in the settings list
--         custom   true for a hand built page -- core makes a canvas
--                  subcategory, puts the frame on module.panel, and stops
function S.core.declareModule(name, opts)
    opts = opts or {}

    if S.modules[name] then
        error("duplicate module: " .. name)
    end

    local module = {
        name   = name,
        title  = opts.title or name,
        custom = opts.custom == true,

        items  = {},     -- controls and section headers, in declaration order

        category = nil,
        layout   = nil,
        panel    = nil,  -- custom modules only
    }

    --  def   label, tooltip, default, commit ("live" or "reload")
    --        min / max / step    sliders
    --        options             dropdowns: array of strings, or a function
    --                            returning one
    function module:slider(key, def)
        return addControl(self, key, "slider", def)
    end

    function module:checkbox(key, def)
        return addControl(self, key, "checkbox", def)
    end

    function module:dropdown(key, def)
        return addControl(self, key, "dropdown", def)
    end

    -- A header above the next declared control.
    function module:section(text)
        table.insert(self.items, { section = text })
    end

    S.modules[name]  = module
    S.controls[name] = {}

    table.insert(S.core.moduleOrder, module)

    return module
end


--[[--------------------------------------------------------------------------
    Building the settings page
----------------------------------------------------------------------------]]

local function buildControl(module, control)
    local db  = S.db[module.name]
    local def = control.def
    local key = control.key

    if db[key] == nil then
        db[key] = def.default
    end

    control.setting = Settings.RegisterAddOnSetting(
        module.category,
        addonName .. "_" .. module.name .. "_" .. key,   -- globally unique id
        key,
        db,
        type(def.default),
        def.label or key,
        def.default
    )

    control.setting:SetValueChangedCallback(function(_, value)
        if def.commit == "reload" then
            S.core.needsReload = true
            S.core.print("that change needs a reload to take effect.")
        end

        for i = 1, #control.handlers do
            control.handlers[i](value)
        end
    end)

    if control.wtype == "checkbox" then
        Settings.CreateCheckbox(module.category, control.setting, def.tooltip)

    elseif control.wtype == "slider" then
        local options = Settings.CreateSliderOptions(def.min, def.max, def.step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(module.category, control.setting, options, def.tooltip)

    elseif control.wtype == "dropdown" then
        local function getOptions()
            local container = Settings.CreateControlTextContainer()
            local list = def.options

            if type(list) == "function" then
                list = list()
            end

            for i = 1, #list do
                container:Add(i, list[i])
            end

            return container:GetData()
        end

        Settings.CreateDropdown(module.category, control.setting, getOptions, def.tooltip)

    else
        error("unknown widget type: " .. tostring(control.wtype))
    end
end

local function buildModulePage(module)
    S.db[module.name] = S.db[module.name] or {}

    if module.custom then
        module.panel = CreateFrame("Frame")
        module.panel.name = module.title

        module.category = Settings.RegisterCanvasLayoutSubcategory(
                              S.core.root, module.panel, module.title)
        return
    end

    module.category, module.layout =
        Settings.RegisterVerticalLayoutSubcategory(S.core.root, module.title)

    for i = 1, #module.items do
        local item = module.items[i]

        if item.section then
            module.layout:AddInitializer(
                CreateSettingsListSectionHeaderInitializer(item.section))
        else
            buildControl(module, item)
        end
    end
end


--[[--------------------------------------------------------------------------
    Startup
----------------------------------------------------------------------------]]


registerFrame:RegisterEvent("ADDON_LOADED")
registerFrame:RegisterEvent("PLAYER_LOGIN")

registerFrame:SetScript("OnEvent", function(_, event, arg1)

    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end

        SnugUXDB = SnugUXDB or {}
        S.db = SnugUXDB

        S.core.root = Settings.RegisterVerticalLayoutCategory("SnugUX")
        Settings.RegisterAddOnCategory(S.core.root)



        for i = 1, #S.core.moduleOrder do
            buildModulePage(S.core.moduleOrder[i])
        end

        for i = 1, #addonLoadedHandlers do
            addonLoadedHandlers[i]()
        end

    elseif event == "PLAYER_LOGIN" then

        for i = 1, #S.core.moduleOrder do
            local module = S.core.moduleOrder[i]
            if module.enable then
                module:enable()
            end
        end

        for i = 1, #playerLoginHandlers do
            playerLoginHandlers[i]()
        end
    end

    local list = xpEventHandlers[event]

    if list then
        for i = 1, #list do
            list[i](event, arg1)
        end
    end
end)


--[[--------------------------------------------------------------------------
    Opening the window
----------------------------------------------------------------------------]]

function S.core.openSettings(moduleName)
    local module = moduleName and S.modules[moduleName]
    local target = S.core.root

    if module and module.category then
        target = module.category
    end

    Settings.OpenToCategory(target:GetID())
end

SLASH_SNUGUX1 = "/sux"
SLASH_SNUGUX2 = "/snug"

SlashCmdList.SNUGUX = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" then
        S.core.openSettings()
    else
        S.core.openSettings(msg)
    end
end