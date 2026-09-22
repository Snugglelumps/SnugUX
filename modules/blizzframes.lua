--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Globals, locals, you name it
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
local addonName, S = ...

S.blizzframes = {}

local widthInset  = 11
local heightInset = 11

local extraWidthInset = 8

--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Settings and Controls
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local module = S.core.declareModule("blizzframes", {
    title = "Blizzard Frames",
    blurb = "Regions at the bottom corners that other frames attach to.",
})

module:section("Chat")
local socialButton = module:checkbox("socialButton", {
    label   = "Disable Social Button",
    default = true,
})

local chatButtonFrame = module:checkbox("chatButtonFrame", {
    label   = "Disable Chat Button Frame",
    default = true,
})

local chatTabHighlight = module:checkbox("chatTabHighlight", {
    label   = "Disable Chat Tab Highlights",
    default = true,
})

module:section("Damage Meter")
local damageMeterHeader = module:checkbox("damageMeterHeader", {
    label   = "Disable Damage Meter Header",
    default = true,
})

module:section("Miscellaneous")
local bagsBar = module:checkbox("bagsBar", {
    label = "Disable Bags Bar",
    default = true,
})

local micromenu = module:checkbox("microMenu", {
    label = "Disable Micro Menu",
    default = true,
})

--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  Respect my utillitaaahhh
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local function findSystem(layoutInfo, frame)
    local systems =
        layoutInfo.layouts[layoutInfo.activeLayout].systems

    for _, system in pairs(systems) do
        if system.system == frame.system
           and system.systemIndex == frame.systemIndex then
            return system
        end
    end
end

local function checkReadiness(anchor)
    if not anchor then return end
    if InCombatLockdown() then return end
    if not EditModeManagerFrame.accountSettings then return end
    return true
end

local function saveLayout(frame, anchor, offsetX, offsetY)
    if not checkReadiness(anchor) then return end

    local layoutInfo = C_EditMode.GetLayouts()

    -- GetLayouts excludes presets, but activeLayout includes them.
    local layouts = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    tAppendAll(layouts, layoutInfo.layouts)
    layoutInfo.layouts = layouts

    local system = findSystem(layoutInfo, frame)
    if not system then return end

    system.isInDefaultPosition = false

    local anchorInfo = system.anchorInfo
    anchorInfo.point, anchorInfo.relativeTo, anchorInfo.relativePoint =
        "BOTTOMLEFT", anchor:GetName(), "BOTTOMLEFT"
    anchorInfo.offsetX, anchorInfo.offsetY = offsetX, offsetY

    C_EditMode.SaveLayouts(layoutInfo)
end

-- an attempt at a debounce. I cant see it not working, then again, I JUST looked it up lol
local function inject(frame, anchor, offsetX, offsetY)
    if frame.snugTimer then
        frame.snugTimer:Cancel()
    end

    frame.snugTimer = C_Timer.NewTimer(0.5, function()
        saveLayout(frame, anchor, offsetX, offsetY)
    end)
end

--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  WORK: Chat Frames
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

function S.blizzframes.placeChat(anchor)
    if not checkReadiness(anchor) then return end

    local frame = ChatFrame1

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 7, 6.5)
    frame:SetSize(
        S.db.anchors.width - widthInset - extraWidthInset - 4,
        S.db.anchors.height - heightInset - 2
    )
    frame:SetClampedToScreen(false)
    inject(frame, anchor, 3.5, 6.5)
end


local function formatChat()
    -- moves the edit box to clear the tabs
    ChatFrame1EditBox:ClearAllPoints()
    ChatFrame1EditBox:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 25)
    ChatFrame1EditBox:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 10, 25)

    local partFrames = {
        "TopTexture",
        "BottomTexture",
        "RightTexture",
        "LeftTexture",
        "Background",
        "TopRightTexture",
        "TopLeftTexture",
        "BottomLeftTexture",
        "BottomRightTexture"
    }

    -- sets alpha to 0 and hooks aphla changes to 0 for errything in chatTextures
    for i = 1, NUM_CHAT_WINDOWS do
        for _, part in ipairs(partFrames) do
            local frame = _G["ChatFrame" .. i .. part]

            frame:SetAlpha(0)

            hooksecurefunc(frame, "SetAlpha", function(self)
                if self:GetAlpha() ~= 0 then
                    self:SetAlpha(0)
                end
            end)
        end
    end

    local frames = {
        ChatFrame1EditBoxFocusLeft,
        ChatFrame1EditBoxFocusRight,
        ChatFrame1EditBoxFocusMid,
    }

    for _, frame in ipairs(frames) do
        frame:SetAlpha(0)

        hooksecurefunc(frame, "SetAlpha", function(self)
            if self:GetAlpha() ~= 0 then
                self:SetAlpha(0)
            end
        end)
    end

    local chatPieces = {
        ChatFrame1EditBoxLeft,
        ChatFrame1EditBoxMid,
        ChatFrame1EditBoxRight,
    }

    ChatFrame1EditBox:HookScript("OnEditFocusGained", function()
        for _, frame in ipairs(chatPieces) do
            frame:SetAlpha(0.8)
        end
    end)
    ChatFrame1EditBox:HookScript("OnEditFocusLost", function()
        for _, frame in ipairs(chatPieces) do
            frame:SetAlpha(0)
        end
    end)
end


local function _chatButtonFrame()
    local record = S.db.blizzframes
    local frame = ChatFrame1ButtonFrame
    if record.chatButtonFrame then
        frame:Hide()
    else
        frame:Show()
    end
end


local function _socialButton()
    local record = S.db.blizzframes
    local frame = QuickJoinToastButton
    if record.socialButton then
        frame:Hide()
    else
        frame:Show()
    end
end


local function _chatTabHighlight()
    for i = 1, 3 do
        if S.db.blizzframes.chatTabHighlight then
            _G["ChatFrame" .. i .. "Tab"].Middle:Hide()
            _G["ChatFrame" .. i .. "Tab"].Right:Hide()
            _G["ChatFrame" .. i .. "Tab"].Left:Hide()
        else
            _G["ChatFrame" .. i .. "Tab"].Middle:Show()
            _G["ChatFrame" .. i .. "Tab"].Right:Show()
            _G["ChatFrame" .. i .. "Tab"].Left:Show()
        end
    end
end
S.register.playerLogin(_chatTabHighlight)


--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  WORK: Damage Meter
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###


function S.blizzframes.placeDamageMeter(anchor)
    if not checkReadiness(anchor) then return end

    if C_CVar.GetCVar("damageMeterEnabled") == "0" then
        C_CVar.SetCVar("damageMeterEnabled", "1")
    end

    local frame = DamageMeterSessionWindow1

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 3, 8)
    frame:SetSize(
        S.db.anchors.width - widthInset - extraWidthInset + 13,
        S.db.anchors.height - heightInset
    )
    frame:SetClampedToScreen(false)
    frame.Header:Hide()
    inject(frame, anchor, -3.5, 11.5)
end


local function formatDamageMeter()
    local frames = {
        DamageMeterSessionWindow1.MinimizeContainer.Background,
        DamageMeterSessionWindow1.MinimizeContainer.NotActive,
    }

    -- sets alpha to 0 and hooks aphla changes to 0 for errything in chatTextures
    for _, frame in ipairs(frames) do
        frame:SetAlpha(0)

        hooksecurefunc(frame, "SetAlpha", function(self)
            if self:GetAlpha() ~= 0 then
                self:SetAlpha(0)
            end
        end)
    end
end


local function _damageMeterHeader()
    local record = S.db.blizzframes
    local frame = DamageMeterSessionWindow1
    if record.damageMeterHeader then
        frame.Header:Hide()
    else
        frame.Header:Show()
    end
end


local function _bagsBar()
    local record = S.db.blizzframes
    local frame = BagsBar
    if record.bagsBar then
        frame:Hide()
    else
        frame:Show()
    end
end


local function _microMenu()
    local record = S.db.blizzframes
    local frame = MicroMenu
    if record.microMenu then
        frame:Hide()
    else
        frame:Show()
    end
end


local function hookHides()
    do -- Hook to hide MicroMenu
        hooksecurefunc(MicroMenu, "Show", function(self)
            if S.db.blizzframes.microMenu then
                self:Hide()
            end
        end)
    end

    do -- Hook to hide BagsBar
        hooksecurefunc(BagsBar, "Show", function(self)
            if S.db.blizzframes.bagsBar then
                self:Hide()
            end
        end)
    end
end

--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###
--==#  WORK: Combat Menu Bars
--==###====---- - - -  -  -  -   -    -     -    -   -  -  -  - - - ----====###

local combatMenuBars = { MultiBar5, MultiBar6, MultiBar7 }

local function showCombatMenuBars()
    if InCombatLockdown() then return end

    for i, bar in ipairs(combatMenuBars) do
        UnregisterStateDriver(bar, "visibility")
        bar:Show()

        if i == 1 then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 0, -50)
        end
        if i == 2 then
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", PlayerSpellsFrame, "RIGHT", 0, 0)
        end
        if i == 3 then
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", PlayerSpellsFrame, "BOTTOMRIGHT", 0, 50)
        end

    end
end

local function hideCombatMenuBars()
    for _, bar in ipairs(combatMenuBars) do
        RegisterStateDriver(bar, "visibility", "hide")
    end
end

local ticker
ticker = C_Timer.NewTicker(.1, function()
    local frame = PlayerSpellsFrame

    if frame then
        showCombatMenuBars()
        ticker:Cancel()

        frame:HookScript("OnShow", showCombatMenuBars)
        frame:HookScript("OnHide", hideCombatMenuBars)
    end
end)


--==###====---- - - -  -  -  -   -   -    -     -   -  -  -  -  - - - ----====###
--==# Bindings/events
--==###====---- - - -  -  -  -   -   -    -     -   -  -  -  -  - - - ----====###

S.register.playerLogin(formatChat)

S.register.playerLogin(_chatButtonFrame)
chatButtonFrame:onChange(_chatButtonFrame)

socialButton:onChange(_socialButton)
S.register.playerLogin(_socialButton)

S.register.playerLogin(formatDamageMeter)

S.register.playerLogin(_damageMeterHeader)
damageMeterHeader:onChange(_damageMeterHeader)

S.register.playerLogin(_bagsBar)
bagsBar:onChange(_bagsBar)

S.register.playerLogin(_microMenu)
micromenu:onChange(_microMenu)

S.register.playerLogin(hookHides)

S.register.playerLogin(function()
    hideCombatMenuBars()
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", showCombatMenuBars)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", hideCombatMenuBars)
end)


chatTabHighlight:onChange(_chatTabHighlight)