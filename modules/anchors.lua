--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  globals/
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
local addonName, S = ...

local INSET = 2
local BORDER_EASE_EXPONENT = 0.4  -- lower = border resists fading longer, higher = border tracks background more closely
local CONTENT = {
    "None",
    "Chat",
    "Damage Meter",
    "Details!",
}

local TEMPLATES = {
    "Flat",
    "DialogBox",
    "DialogBoxDark",
    "DialogBoxGold",
    "Tooltip",
    "Marble",
    "Rock",
    "Solid",
}

local BACKDROPS = {
    Flat          = { bg = "Interface\\Buttons\\WHITE8X8", color = { 0, 0, 0 } },
    DialogBox     = { bg = "Interface\\DialogFrame\\UI-DialogBox-Background",      edge = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    DialogBoxDark = { bg = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edge = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    DialogBoxGold = { bg = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background", edge = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", color = { 0, 0, 0 } },
    Tooltip       = { bg = "Interface\\Tooltips\\UI-Tooltip-Background",           edge = "Interface\\Tooltips\\UI-Tooltip-Border" },
    Marble        = { bg = "Interface\\FrameGeneral\\UI-Background-Marble",        edge = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    Rock          = { bg = "Interface\\FrameGeneral\\UI-Background-Rock",          edge = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    Solid         = { bg = "Interface\\Buttons\\WHITE8X8",                         edge = "Interface\\DialogFrame\\UI-DialogBox-Border" },
}


--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Settings and Controls
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local module = S.core.declareModule("anchors", {
    title = "Anchors",
    blurb = "Regions at the bottom corners that other frames attach to.",
})

local enabled = module:checkbox("enabled", {
    label   = "Enable Anchors",
    tooltip = "Show the anchor regions.",
    default = true,
})

module:section("Size")

local width = module:slider("width", {
    label   = "Width",
    tooltip = "How wide both regions are.",
    default = 430,
    min     = 100,
    max     = 1200,
    step    = 10,
})

local height = module:slider("height", {
    label   = "Height",
    tooltip = "How tall both regions are.",
    default = 210,
    min     = 50,
    max     = 600,
    step    = 10,
})


module:section("Content")

local leftContent = module:dropdown("leftContent", {
    label   = "Left Region",
    tooltip = "What fills the bottom left region.",
    default = 2,
    options = CONTENT,
})

local rightContent = module:dropdown("rightContent", {
    label   = "Right Region",
    tooltip = "What fills the bottom right region.",
    default = 3,
    options = CONTENT,
})

module:section("Visuals")
local anchorTemplate = module:dropdown("anchorTemplate", {
    label   = "Template",
    tooltip = "What template is used for the Anchor regions",
    default = 3,
    options = TEMPLATES,
})

local anchorAlpha = module:slider("anchorAlpha", {
    label   = "Opacity",
    tooltip = "How opaque the Anchors are.",
    default = 0.5,
    min     = 0,
    max     = 1,
    step    = 0.01,
})

--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Utilities
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local function createAnchor(globalName, corner)
    local frame = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")

    local x = INSET
    if corner == "BOTTOMRIGHT" then
        x = -INSET
    end

    frame:SetFrameStrata("BACKGROUND")
    frame:SetPoint(corner, UIParent, corner, x, INSET)

    return frame
end


local function getAnchor(label)
    if CONTENT[S.db.anchors.leftContent] == label then
        return module.state.left
    elseif CONTENT[S.db.anchors.rightContent] == label then
        return module.state.right
    end
end

-- we probably need to guard updateAnchors and updateAnchorAppearance someday.
-- im not toally sure how I want SnugUX to respond to being on default UI.
local function layoutIsCustom()
    local layoutInfo = C_EditMode.GetLayouts()

    local layouts = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    tAppendAll(layouts, layoutInfo.layouts)
    layoutInfo.layouts = layouts

    local currentLayout = layoutInfo.layouts[layoutInfo.activeLayout]
    return currentLayout.layoutType ~= Enum.EditModeLayoutType.Preset
end


module.state = {}

module.state.left = createAnchor("SnugUXLeftAnchor", "BOTTOMLEFT")
module.state.right = createAnchor("SnugUXRightAnchor", "BOTTOMRIGHT")

--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  actual work
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local function updateAnchors()
    local left  = module.state.left
    local right = module.state.right

    if not S.db.anchors.enabled or not layoutIsCustom() then
        left:Hide()
        right:Hide()
        return
    end

    left:SetSize(S.db.anchors.width, S.db.anchors.height)
    right:SetSize(S.db.anchors.width, S.db.anchors.height)
    left:Show()
    right:Show()

    S.blizzframes.placeChat(getAnchor("Chat"))
    S.blizzframes.placeDamageMeter(getAnchor("Damage Meter"))
end


local function updateAnchorAppearance()
    if not S.db.anchors.enabled or not layoutIsCustom() then return end

    local left  = module.state.left
    local right = module.state.right

    local templateValue = S.db.anchors.anchorTemplate
    local style = BACKDROPS[TEMPLATES[templateValue]]

    if module.state.lastTemplate ~= templateValue then
        module.state.lastTemplate = templateValue

        local backdrop = {
            bgFile   = style.bg,
            edgeFile = style.edge,
            tile     = true,
            tileSize = 16,
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        }

        left:SetBackdrop(backdrop)
        right:SetBackdrop(backdrop)
    end

    local r, g, b = unpack(style.color or { 1, 1, 1 })
    local alpha = S.db.anchors.anchorAlpha
    local borderAlpha = alpha ^ BORDER_EASE_EXPONENT

    left:SetBackdropColor(r, g, b, alpha)
    right:SetBackdropColor(r, g, b, alpha)

    if style.edge then
        left:SetBackdropBorderColor(1, 1, 1, borderAlpha)
        right:SetBackdropBorderColor(1, 1, 1, borderAlpha)
    end
end

local function validateLeftControl()
    if S.db.anchors.leftContent == S.db.anchors.rightContent then
        rightContent:SetValue(1)
    end
end

local function validateRightControl()
    if S.db.anchors.rightContent == S.db.anchors.leftContent then
        leftContent:SetValue(1)
    end
end

--==###====---- - - -  -  -  -   -   -    -     -   -  -  -  -  - - - ----====###
--==# Bindings/events
--==###====---- - - -  -  -  -   -   -    -     -   -  -  -  -  - - - ----====###

width:onChange(updateAnchors)
height:onChange(updateAnchors)
anchorAlpha:onChange(updateAnchorAppearance)
anchorTemplate:onChange(updateAnchorAppearance)

leftContent:onChange(
    updateAnchors,
    validateLeftControl
)
rightContent:onChange(
    updateAnchors,
    validateRightControl
)
enabled:onChange(
    updateAnchors,
    updateAnchorAppearance
)

S.register.playerLogin(function()
    updateAnchors()
    updateAnchorAppearance()

    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", updateAnchors)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", updateAnchorAppearance)
end)

