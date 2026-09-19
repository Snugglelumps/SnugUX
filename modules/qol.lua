local addonName, S = ...

local BINDING_UI_ADDONS = { "Blizzard_QuickKeybind", "Blizzard_BindingUI", "Blizzard_Settings" }
local hooked = false

local function loadBindingUI()
    if QuickKeybindFrame then
        return true
    end

    for _, addon in ipairs(BINDING_UI_ADDONS) do
        C_AddOns.LoadAddOn(addon)
        if QuickKeybindFrame then
            return true
        end
    end

    return QuickKeybindFrame ~= nil
end

local function hookQuickKeybindFrame()
    if hooked then return end
    hooked = true

    -- QuickKeybindFrame only writes bindings to disk from its own Okay
    -- button; closing it any other way (Escape, click-off) silently loses
    -- them at logout unless we also save on hide.
    QuickKeybindFrame:HookScript("OnHide", function()
        SaveBindings(GetCurrentBindingSet())
    end)
end

local function enterQuickKeybindMode()
    if InCombatLockdown() then
        S.core.print("Can't change keybindings during combat.")
        return
    end

    if not loadBindingUI() then
        S.core.print("Quick Keybind Mode isn't available.")
        return
    end

    hookQuickKeybindFrame()
    ShowUIPanel(QuickKeybindFrame)
end

SLASH_SNUGUXKEYBIND1 = "/kb"
SlashCmdList.SNUGUXKEYBIND = enterQuickKeybindMode