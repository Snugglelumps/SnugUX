--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Globals, locals, you name it
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
local addonName, S = ...

S.bars = {}

local xp, rep      -- the two bars

-- local bar          -- the whole thing
-- local fill         -- the gradient
-- local notches = {} -- the 20% marks
-- local levelText
-- local percentText

local GAP        = 4    -- pixels between the anchor and the bar
local NOTCH_STEP = 20   -- a mark every N percent

-- gradient, left to right
local gradientEnd = CreateColor(0.776, 0.380, 1.000, 1)   -- #C661FF
local xpStart     = CreateColor(0.337, 0.388, 1.000, 1)   -- #5663FF
local repStart    = CreateColor(1.000, 0.467, 0.443, 1)   -- #FF7771
 
local bgColor    = { 0.10, 0.10, 0.12, 1 }
local notchColor = { 1.000, 0.624, 0.000, 1 }             -- #FF9F00



--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Settings and Controls
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local module = S.core.declareModule("bars", {
    title = "Bars",
})

module:section("XP Bar Stuff")
local height = module:slider("height", {
    label   = "Height",
    tooltip = "...y'know... how tall something is..",
    default = 18,
    min     = 8,
    max     = 60,
    step    = 1,
})

local snugXPBar = module:checkbox("snugXPBar", {
    label   = "Enable SnugUX XP Bar",
    default = true,
})

local snugRepBar = module:checkbox("snugRepBar", {
    label   = "Enable SnugUX Rep Bar",
    default = true,
})

local blizzBars = module:checkbox("blizzBars", {
    label   = "Disable Blizzard's XP/Rep Bars",
    default = true,
})

module:section("Cast Bar Stuff")

--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Respect my utillitaaahhh
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

-- Notches sit at 20, 40, 60, 80 percent of whatever the bar is now.
local function layoutNotches(self)
    local width = self.frame:GetWidth()
 
    for i = 1, #self.notches do
        local pct = (i * NOTCH_STEP) / 100
        self.notches[i]:SetPoint("LEFT", self.frame, "LEFT", width * pct, 0)
    end
end

 
-- Draw a fill percentage and the two labels.
local function draw(self, pct, leftLabel, rightLabel)
    self.frame:Show()
 
    self.fill:SetWidth(self.frame:GetWidth() * pct)
    self.leftText:SetText(leftLabel)
    self.rightText:SetText(rightLabel)
end


local function isMaxLevel()
    return UnitLevel("player") >= GetMaxLevelForPlayerExpansion()
end


--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Work
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

-- Notches live at 20, 40, 60, 80 percent of whatever the bar is now.

local function newBar(globalName, colorStart)
    local self = { notches = {} }
 
    self.frame = CreateFrame("Frame", globalName, UIParent)
    self.frame:SetFrameStrata("LOW")
 
    local bg = self.frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(self.frame)
    bg:SetColorTexture(unpack(bgColor))
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0, 0, 0, .3)
 
    self.fill = self.frame:CreateTexture(nil, "ARTWORK")
    self.fill:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self.fill:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    self.fill:SetColorTexture(1, 1, 1, 1)
    self.fill:SetGradient("HORIZONTAL", colorStart, gradientEnd)
 
    for i = 1, math.floor(100 / NOTCH_STEP) - 1 do
        local notch = self.frame:CreateTexture(nil, "OVERLAY")
        notch:SetColorTexture(unpack(notchColor))
        notch:SetWidth(1)
        notch:SetPoint("TOP", self.frame, "TOP", 0, 0)
        notch:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
        self.notches[i] = notch
    end
 
    self.leftText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.leftText:SetPoint("LEFT", self.frame, "LEFT", 6, 0)
 
    self.rightText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.rightText:SetPoint("RIGHT", self.frame, "RIGHT", -6, 0)
 
    return self
end


local function updateXP()
    if not xp then return end

    if not S.db.bars.snugXPBar or isMaxLevel() or IsXPUserDisabled() then
        xp.frame:Hide()
        return
    end

    local current = UnitXP("player")
    local max     = UnitXPMax("player")
    local pct     = 0

    if max > 0 then
        pct = current / max
    end

    draw(xp, pct,
        "Level " .. UnitLevel("player"),
        string.format("%.1f%%", pct * 100))
end



local function updateRep()
    if not rep then return end

    if not S.db.bars.snugRepBar then
        rep.frame:Hide()
        return
    end

    local data = C_Reputation.GetWatchedFactionData()

    -- Nothing watched in the reputation tab.
    if not data then
        rep.frame:Hide()
        return
    end

    local span = data.nextReactionThreshold - data.currentReactionThreshold
    local into = data.currentStanding - data.currentReactionThreshold
    local pct  = 0

    -- Exalted with no paragon track leaves no span to fill.
    if span > 0 then
        pct = into / span
    else
        pct = 1
    end

    draw(rep, pct,
        data.name,
        string.format("%.1f%%", pct * 100))
end


local function updateAll()
    updateXP()
    updateRep()
end

local function applyHeight()
    xp.frame:SetHeight(S.db.bars.height)
    rep.frame:SetHeight(S.db.bars.height)
 
    layoutNotches(xp)
    layoutNotches(rep)
 
    updateAll()
end

local function resize()
    bar:SetHeight(S.db.xpbar.height)
    layoutNotches()
    updateXP()
end


--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Build
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local function createBars()
    local anchor = SnugUXRightAnchor

    xp  = newBar("SnugUXXPBar",  xpStart)
    rep = newBar("SnugUXRepBar", repStart)

    xp.frame:SetPoint("BOTTOMLEFT",  anchor, "TOPLEFT",  4, GAP)
    xp.frame:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -4, GAP)

    rep.frame:SetPoint("BOTTOMLEFT",  xp.frame, "TOPLEFT",  0, GAP)
    rep.frame:SetPoint("BOTTOMRIGHT", xp.frame, "TOPRIGHT", 0, GAP)

    xp.frame:SetScript("OnSizeChanged", function()
        layoutNotches(xp)
        updateXP()
    end)

    rep.frame:SetScript("OnSizeChanged", function()
        layoutNotches(rep)
        updateRep()
    end)

    applyHeight()
end

local function _blizzBars()
    local record = S.db.bars
    local frame = StatusTrackingBarManager

    if record.blizzBars then
        frame:Hide()
    else
        frame:Show()
    end
end


--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Settings Wiring
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

height:onChange(applyHeight)

snugXPBar:onChange(updateXP)
snugRepBar:onChange(updateRep)
blizzBars:onChange(_blizzBars)


--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Registrations
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

S.register.playerLogin(
    createBars,
    _blizzBars
)

S.register.event("PLAYER_XP_UPDATE",   updateXP)
S.register.event("PLAYER_LEVEL_UP",    updateAll)
S.register.event("UPDATE_EXHAUSTION",  updateXP)
S.register.event("UPDATE_FACTION",     updateRep)