--------------------------------------------------------------------------
-- PetSmart: Tracking/RareAlert.lua
-- Tameable rare alerts: when one of the rare pets in this client's data
-- turns up nearby, PetSmart plays a sound, flashes the edge of the screen
-- and shows a popup for it (one per rare, stacked) with the rare's
-- details, a Target button and a Track button.
--
-- How a rare is spotted: enemy nameplates as they appear, the unit under
-- the mouse, your target, minimap vignettes on clients that have them,
-- and a background scan (see "Background scan" below) that finds rares
-- in the current zone before they're on screen.
--
-- Only hunters get alerts, only for rares in the addon's own lists (so
-- only tameable ones), never for another player's pet, a dead rare, or a
-- Horde-only tame on an Alliance character, and at most once every few
-- minutes per rare.
--------------------------------------------------------------------------
local addonName, ns = ...
local L = ns.L

local RE_ALERT_SECONDS = 300 -- same rare again: wait this long before another alert
local POPUP_SECONDS = 60     -- the popup closes itself after this long
local FLASH_SECONDS = 3

-- Built-in sounds the player can pick from (Options): game sounds from the
-- original game, so they're on every client PetSmart runs on. The first
-- four keep their places so older saved choices (stored as a list number)
-- still point at the same sound.
local SOUNDS = {
    { name = "Raid Warning", kit = 8959 },
    { name = "Ready Check", kit = 8960 },
    { name = "War Drums", file = 567275 },
    { name = "Scourge Horn", file = 567386 },
    { name = "Level Up", file = 567431 },
    { name = "Flag Taken", file = 569200 },
    { name = "Flag Captured", file = 567434 },
    { name = "PvP Warning (Alliance)", file = 568320 },
    { name = "PvP Warning (Horde)", file = 569112 },
    { name = "Alliance Bell", file = 566564 },
    { name = "Horde Bell", file = 565853 },
    { name = "Night Elf Bell", file = 566558 },
    { name = "Tribal Bell", file = 566027 },
    { name = "Dwarf Horn", file = 566064 },
    { name = "Thunder Crack", file = 566202 },
}
local DEFAULT_SOUND = "Raid Warning"
local LSM_PREFIX = "lsm:" -- saved choices from other addons' sounds start with this

local Alert = {}
ns.RareAlert = Alert
Alert.SOUNDS = SOUNDS

----------------------------------------------------------------------
-- Which creatures to watch for: every tameable creature tagged Rare and
-- every rare in the Rare Index, by creature (NPC) ID.
----------------------------------------------------------------------
local watch
local function BuildWatchList()
    watch = {}
    for familyName, list in pairs(ns.TAMEABLE_CREATURES or {}) do
        for _, c in ipairs(list) do
            if c.npc and c.tag and c.tag:find("Rare", 1, true) then
                watch[c.npc] = watch[c.npc] or {
                    name = c.name, family = familyName, level = c.level, zone = c.zone, horde = c.horde,
                }
            end
        end
    end
    for _, r in ipairs(ns.RARE_SPAWNS or {}) do
        local npc = ns.CREATURE_IDS and ns.CREATURE_IDS[r.name]
        if npc then
            local info = watch[npc] or {
                name = r.name, level = r.level, zone = r.zone,
                family = r.familyId and ns.PET_FAMILIES and ns.PET_FAMILIES[r.familyId],
            }
            info.rare = r
            watch[npc] = info
        end
    end
end

local function IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

local function Enabled()
    return ns.profile and ns.profile.rareAlertEnabled ~= false and IsHunter()
end

-- Creature ID from a unit GUID ("Creature-0-...-<id>-<spawn>"), or nil.
local function NpcFromGUID(guid)
    if not guid or ns.AnySecret(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

----------------------------------------------------------------------
-- Sound and screen flash
----------------------------------------------------------------------
-- Sounds other addons share through LibSharedMedia (SilverDragon, DBM,
-- WeakAuras, SharedMedia packs...). PetSmart doesn't ship the library; it
-- uses it only when another addon has loaded it.
local function SharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local builtinByName, builtinFiles = {}, {}
for _, s in ipairs(SOUNDS) do
    builtinByName[s.name] = s
    if s.file then builtinFiles[s.file] = true end
end

-- Other addons' sounds, sorted by name, leaving out "None" and any that
-- are just one of PetSmart's own built-in sounds again.
function Alert.SharedSounds()
    local lsm = SharedMedia()
    local out = {}
    if not lsm then return out end
    local ok, list = pcall(lsm.List, lsm, "sound")
    if not ok or type(list) ~= "table" then return out end
    for _, name in ipairs(list) do
        local path = lsm:Fetch("sound", name, true)
        if path and name ~= "None" and not builtinByName[name] and not builtinFiles[path]
            and not (type(path) == "string" and path:lower():find("quiet%.ogg$")) then
            out[#out + 1] = name
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- The saved choice as a key: a built-in sound's name, or "lsm:<name>" for
-- another addon's sound. Older saves hold a list number instead.
function Alert.SoundKey()
    local v = ns.profile and ns.profile.rareAlertSound
    if type(v) == "number" then v = SOUNDS[v] and SOUNDS[v].name end
    if type(v) ~= "string" then v = DEFAULT_SOUND end
    return v
end

-- What to show for a key: the built-in name (translated) or the other
-- addon's own name for its sound.
function Alert.SoundLabel(key)
    key = key or Alert.SoundKey()
    if key:sub(1, #LSM_PREFIX) == LSM_PREFIX then return key:sub(#LSM_PREFIX + 1) end
    return L[key]
end
Alert.LSM_PREFIX = LSM_PREFIX

local function PlayBuiltin(s)
    if s.kit then
        local ok, willPlay = pcall(PlaySound, s.kit, "Master")
        return ok and willPlay ~= false
    end
    local ok, willPlay = pcall(PlaySoundFile, s.file, "Master")
    return ok and willPlay ~= false
end

-- Plays the chosen sound (or `key`). If it can't be played - another
-- addon's sound whose addon is gone, or a sound missing from this
-- client - Raid Warning plays instead, so an alert is never silent.
function Alert.PlaySound(key)
    key = key or Alert.SoundKey()
    local played
    if key:sub(1, #LSM_PREFIX) == LSM_PREFIX then
        local lsm = SharedMedia()
        local path = lsm and lsm:Fetch("sound", key:sub(#LSM_PREFIX + 1), true)
        if path then
            local ok, willPlay = pcall(PlaySoundFile, path, "Master")
            played = ok and willPlay ~= false
        end
    elseif builtinByName[key] then
        played = PlayBuiltin(builtinByName[key])
    end
    if not played then PlayBuiltin(builtinByName[DEFAULT_SOUND]) end
end

-- Flash colours to pick from (Options). "Custom" is any colour chosen in
-- the game's colour picker, saved as {r, g, b}.
local FLASH_COLORS = {
    { name = "Red", color = { 1, 0.1, 0.1 } },
    { name = "Orange", color = { 1, 0.5, 0 } },
    { name = "Yellow", color = { 1, 0.9, 0.1 } },
    { name = "Green", color = { 0.2, 1, 0.3 } },
    { name = "Hunter Green", color = { 0.67, 0.83, 0.45 } }, -- the hunter class colour
    { name = "Teal", color = { 0.1, 0.9, 0.8 } },
    { name = "Blue", color = { 0.2, 0.5, 1 } },
    { name = "Purple", color = { 0.7, 0.3, 1 } },
    { name = "Pink", color = { 1, 0.4, 0.8 } },
    { name = "White", color = { 1, 1, 1 } },
}
local DEFAULT_FLASH = "Red"
Alert.FLASH_COLORS = FLASH_COLORS

-- The chosen colour's name ("Custom" for a picked colour) and its r, g, b.
function Alert.FlashColor()
    local v = ns.profile and ns.profile.rareAlertFlashColor
    if type(v) == "table" then return "Custom", v[1], v[2], v[3] end
    for _, c in ipairs(FLASH_COLORS) do
        if c.name == v then return c.name, c.color[1], c.color[2], c.color[3] end
    end
    local c = FLASH_COLORS[1]
    return c.name, c.color[1], c.color[2], c.color[3]
end

-- The flash: a soft glow along each edge of the screen, strongest at the
-- edge and fading inward, so it can be any colour.
local flash = CreateFrame("Frame", nil, UIParent)
flash:SetAllPoints(UIParent)
flash:SetFrameStrata("FULLSCREEN_DIALOG")
flash:EnableMouse(false)
flash:Hide()
flash.edges = {}
for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = flash:CreateTexture(nil, "BACKGROUND")
    t.side = side
    if side == "TOP" or side == "BOTTOM" then
        t:SetPoint(side .. "LEFT", flash, side .. "LEFT")
        t:SetPoint(side .. "RIGHT", flash, side .. "RIGHT")
    else
        t:SetPoint("TOP" .. side, flash, "TOP" .. side)
        t:SetPoint("BOTTOM" .. side, flash, "BOTTOM" .. side)
    end
    flash.edges[#flash.edges + 1] = t
end

-- Fades a texture from `outer` alpha at the screen edge to 0 inside it.
-- Newer clients take colour objects, older ones separate numbers.
local function EdgeGradient(t, r, g, b, outer)
    t:SetColorTexture(1, 1, 1, 1)
    local orientation = (t.side == "TOP" or t.side == "BOTTOM") and "VERTICAL" or "HORIZONTAL"
    -- VERTICAL runs bottom -> top, HORIZONTAL left -> right.
    local a1, a2 = outer, 0
    if t.side == "TOP" or t.side == "RIGHT" then a1, a2 = 0, outer end
    if CreateColor and pcall(t.SetGradient, t, orientation, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2)) then
        return
    end
    if t.SetGradientAlpha then
        t:SetGradientAlpha(orientation, r, g, b, a1, r, g, b, a2)
    else
        t:SetColorTexture(r, g, b, outer * 0.5)
    end
end

local function PaintFlash()
    local _, r, g, b = Alert.FlashColor()
    local depth = math.floor((UIParent:GetHeight() or 768) * 0.12)
    for _, t in ipairs(flash.edges) do
        if t.side == "TOP" or t.side == "BOTTOM" then t:SetHeight(depth) else t:SetWidth(depth) end
        EdgeGradient(t, r, g, b, 0.85)
    end
end

flash:SetScript("OnUpdate", function(self, dt)
    self.t = self.t + dt
    if self.t >= FLASH_SECONDS then
        self:Hide()
        return
    end
    -- Three soft pulses.
    self:SetAlpha(math.abs(math.sin(self.t / FLASH_SECONDS * math.pi * 3)))
end)

local function Flash()
    PaintFlash()
    flash.t = 0
    flash:SetAlpha(0)
    flash:Show()
end
Alert.Flash = Flash

----------------------------------------------------------------------
-- Popups: one per rare, stacked downward from where the first one sits,
-- so two rares found together each get their own. Drawn on the game's
-- legendary-toast art turned silver (the look SilverDragon uses by
-- default); a client without that art gets a plain tooltip-style frame.
----------------------------------------------------------------------
local MAX_POPUPS = 4
local TOAST_ATLAS = "LegendaryToast-background"
local GLOW_ATLAS = "loottoast-glow"

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
local useToast = HasAtlas(TOAST_ATLAS)
local POPUP_W, POPUP_H = useToast and 302 or 290, useToast and 119 or 96
local GAP = useToast and -14 or 4 -- toast art has see-through edges, so they overlap a bit

-- Invisible frame the stack hangs from; dragging any popup moves it.
local stackAnchor = CreateFrame("Frame", "PetSmartRareAlertAnchor", UIParent)
stackAnchor:SetSize(POPUP_W, POPUP_H)
stackAnchor:SetMovable(true)
stackAnchor:SetClampedToScreen(true)

local function PlaceAnchor()
    stackAnchor:ClearAllPoints()
    local pos = ns.profile and ns.profile.rareAlertPos
    if pos then
        stackAnchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        stackAnchor:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

local popups = {}
local queue = {} -- rares waiting for a free popup: { npc, info, unitName }

-- The Target button runs "/targetexact <name>", which only a secure button
-- may do. Each popup's button is its own top-level frame placed over the
-- popup by screen position (not attached to it), so popups can still
-- appear and close during combat; the buttons only appear, change or hide
-- out of combat.
local function PlaceTargetButton(p)
    local left, bottom = p.track:GetLeft(), p.track:GetBottom()
    if not (left and bottom) then return false end
    local t = p.target
    t:ClearAllPoints()
    if p.track:IsShown() then
        t:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", left - 4, bottom)
    else
        t:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", p.track:GetRight() or left, bottom)
    end
    return true
end

local function ShowTargetButton(p)
    if InCombatLockdown() then
        p.pendingTarget = true
        p.note:SetText(L["Targeting is available after combat."])
        return
    end
    p.pendingTarget = nil
    p.note:SetText("")
    p.target:SetAttribute("macrotext", "/cleartarget\n/targetexact " .. p.unitName)
    if PlaceTargetButton(p) then
        p.target:Show()
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if p:IsShown() and not InCombatLockdown() and PlaceTargetButton(p) then p.target:Show() end
        end)
    end
end

local function UpdateTrackButton(p)
    local rare = p.info and p.info.rare
    if rare and rare.mapID and not rare.isDungeon and ns.SetTrackedRare then
        local tracked = ns.IsTrackedRare and ns.IsTrackedRare(rare)
        p.track:SetText(tracked and L["Untrack"] or L["Track"])
        p.track:Show()
    else
        p.track:Hide()
    end
end

local ShowNextQueued -- defined below

local function CreatePopup(i)
    local p = CreateFrame("Frame", "PetSmartRareAlert" .. i, UIParent, (not useToast and BackdropTemplateMixin) and "BackdropTemplate" or nil)
    p:SetSize(POPUP_W, POPUP_H)
    p:SetFrameStrata("DIALOG")
    p:SetFrameLevel(10 + i * 10)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:Hide()
    p.slot = i

    -- Background, and the area the contents sit in.
    local area
    if useToast then
        p.bg = p:CreateTexture(nil, "BORDER")
        p.bg:SetAtlas(TOAST_ATLAS, true)
        p.bg:SetPoint("CENTER")
        p.bg:SetDesaturated(true)
        area = p.bg
        if HasAtlas(GLOW_ATLAS) then
            p.glow = p:CreateTexture(nil, "OVERLAY")
            p.glow:SetAtlas(GLOW_ATLAS)
            p.glow:SetDesaturated(true)
            p.glow:SetPoint("TOPLEFT", p.bg, "TOPLEFT", -10, 8)
            p.glow:SetPoint("BOTTOMRIGHT", p.bg, "BOTTOMRIGHT", 10, -8)
            p.glow:SetBlendMode("ADD")
            p.glow:SetAlpha(0)
        end
    else
        p:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        p:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
        p:SetBackdropBorderColor(0.75, 0.75, 0.8, 1)
        area = p
    end

    -- Creature portrait on the left, in the art's round frame.
    p.modelBg = p:CreateTexture(nil, "BACKGROUND")
    p.modelBg:SetColorTexture(0, 0, 0, 0.6)
    p.modelBg:SetSize(54, 54)
    if useToast then
        p.modelBg:SetPoint("LEFT", area, "LEFT", 34, 0)
    else
        p.modelBg:SetPoint("LEFT", area, "LEFT", 12, 0)
    end
    p.model = CreateFrame("PlayerModel", nil, p)
    p.model:SetAllPoints(p.modelBg)

    p.heading = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.heading:SetPoint("TOPLEFT", p.modelBg, "TOPRIGHT", 12, 2)
    p.heading:SetText(L["Tameable rare nearby!"])

    p.name = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if _G.GameFontHighlightMedium then p.name:SetFontObject(_G.GameFontHighlightMedium) end
    p.name:SetPoint("TOPLEFT", p.heading, "BOTTOMLEFT", 0, -2)
    p.name:SetPoint("RIGHT", area, "RIGHT", -24, 0)
    p.name:SetJustifyH("LEFT")
    p.name:SetWordWrap(false)

    p.detail = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.detail:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -2)
    p.detail:SetPoint("RIGHT", area, "RIGHT", -16, 0)
    p.detail:SetJustifyH("LEFT")
    p.detail:SetWordWrap(false)

    p.note = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.note:SetPoint("BOTTOMLEFT", p.modelBg, "BOTTOMRIGHT", 12, -2)
    p.note:SetPoint("RIGHT", area, "RIGHT", -16, 0)
    p.note:SetJustifyH("LEFT")

    p.close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    p.close:SetScale(0.75)
    p.close:SetPoint("TOPRIGHT", area, "TOPRIGHT", useToast and -6 or 2, useToast and -6 or 2)
    p.close:SetScript("OnClick", function() p:Hide() end)

    p.track = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.track:SetSize(64, 20)
    p.track:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", useToast and -18 or -10, useToast and 12 or 8)
    p.track:SetScript("OnClick", function()
        local rare = p.info and p.info.rare
        if not rare then return end
        ns.SetTrackedRare(rare)
        for _, other in ipairs(popups) do
            if other:IsShown() then UpdateTrackButton(other) end
        end
        if ns.RefreshAbilitiesPanel then ns.RefreshAbilitiesPanel() end
    end)

    local t = CreateFrame("Button", "PetSmartRareAlertTarget" .. i, UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    t:SetSize(64, 20)
    t:SetFrameStrata("DIALOG")
    t:SetFrameLevel(p:GetFrameLevel() + 8)
    t:SetText(_G.TARGET or L["Target"])
    t:RegisterForClicks("AnyUp", "AnyDown")
    t:SetAttribute("type", "macro")
    t:Hide()
    p.target = t

    -- Dragging any popup moves the whole stack (out of combat only, since
    -- the Target buttons have to move with it).
    p:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        for _, other in ipairs(popups) do other.target:Hide() end
        p.dragging = true
        stackAnchor:StartMoving()
    end)
    p:SetScript("OnDragStop", function()
        if not p.dragging then return end
        p.dragging = false
        stackAnchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = stackAnchor:GetPoint()
        if ns.profile then ns.profile.rareAlertPos = { point, relPoint, x, y } end
        for _, other in ipairs(popups) do
            if other:IsShown() and not other.pendingTarget then ShowTargetButton(other) end
        end
    end)

    p:SetScript("OnUpdate", function(self, dt)
        -- The fade-in glow when it appears.
        if self.glow and self.glowT then
            self.glowT = self.glowT + dt
            local a = self.glowT < 0.3 and self.glowT / 0.3 or math.max(0, 1 - (self.glowT - 0.3) / 1.2)
            self.glow:SetAlpha(a)
            if self.glowT > 1.5 then self.glowT = nil end
        end
        -- Doesn't count down while the mouse is over it.
        if not self:IsMouseOver() then
            self.left = (self.left or POPUP_SECONDS) - dt
            if self.left <= 0 then self:Hide() end
        end
    end)

    p:SetScript("OnHide", function(self)
        self.npc, self.info, self.pendingTarget = nil, nil, nil
        if not InCombatLockdown() then self.target:Hide() end
        if ShowNextQueued then ShowNextQueued() end
    end)

    -- Each popup sits below the one before it.
    p:ClearAllPoints()
    p:SetPoint("TOP", stackAnchor, "TOP", 0, -(i - 1) * (POPUP_H + GAP))
    return p
end

for i = 1, MAX_POPUPS do popups[i] = CreatePopup(i) end

-- A popup that can take a new rare: closed, and (in combat) without a
-- Target button still showing for its last rare.
local function FreePopup()
    for _, p in ipairs(popups) do
        if not p:IsShown() and not (InCombatLockdown() and p.target:IsShown()) then return p end
    end
end

local function FillPopup(p, npc, info, unit, unitName)
    p.npc, p.info = npc, info
    p.left = POPUP_SECONDS
    p.unitName = unitName or ns.LocCreature(info.name)
    p.name:SetText(p.unitName)
    local level = info.level and ns.LocLevel(tostring(info.level)) or "?"
    local family = info.family and ns.LocFamily(info.family) or ""
    local text = L["Level %s %s"]:format(level, family)
    -- A rare above the hunter's level can't be tamed yet.
    local low = tonumber(tostring(info.level or ""):match("%d+"))
    if low and low > UnitLevel("player") then
        text = text .. "  |cffff5050" .. L["Tameable at level %d"]:format(low) .. "|r"
    end
    p.detail:SetText(text)
    p.note:SetText("")

    p.model:ClearModel()
    if unit and UnitExists(unit) then
        pcall(p.model.SetUnit, p.model, unit)
    elseif p.model.SetCreature then
        pcall(p.model.SetCreature, p.model, npc)
    end
    pcall(p.model.SetPortraitZoom, p.model, 0.7)

    UpdateTrackButton(p)
    PlaceAnchor()
    p.glowT = 0
    p:Show()
    ShowTargetButton(p)
end

local function ShowPopup(npc, info, unit, unitName)
    -- Already up for this rare: just keep it up longer.
    for _, p in ipairs(popups) do
        if p:IsShown() and p.npc == npc then
            p.left = POPUP_SECONDS
            return
        end
    end
    local p = FreePopup()
    if p then
        FillPopup(p, npc, info, unit, unitName)
        return
    end
    -- Every popup is in use: wait for one to close.
    for _, q in ipairs(queue) do
        if q.npc == npc then return end
    end
    queue[#queue + 1] = { npc = npc, info = info, unitName = unitName }
end

ShowNextQueued = function()
    while #queue > 0 do
        local p = FreePopup()
        if not p then return end
        local q = table.remove(queue, 1)
        FillPopup(p, q.npc, q.info, nil, q.unitName)
    end
end

-- After combat: finish the Target buttons combat held back, clear away
-- ones whose popup closed, and show anything that was waiting.
local function AfterCombat()
    for _, p in ipairs(popups) do
        if p:IsShown() then
            if p.pendingTarget then ShowTargetButton(p) end
        else
            p.target:Hide()
        end
    end
    ShowNextQueued()
end

----------------------------------------------------------------------
-- Spotting
----------------------------------------------------------------------
local lastAlert = {}

local function Notify(npc, info, unit, unitName)
    local now = GetTime()
    for _, p in ipairs(popups) do
        if p:IsShown() and p.npc == npc then
            p.left = POPUP_SECONDS -- still around: keep its popup up
            return
        end
    end
    if lastAlert[npc] and now - lastAlert[npc] < RE_ALERT_SECONDS then return end
    lastAlert[npc] = now

    local prof = ns.profile
    if prof.rareAlertSoundEnabled ~= false then Alert.PlaySound() end
    if prof.rareAlertFlash ~= false then Flash() end
    if prof.rareAlertPopup ~= false then ShowPopup(npc, info, unit, unitName) end
    print("|cff569965PetSmart:|r " .. L["Tameable rare nearby: %s"]:format(unitName or ns.LocCreature(info.name)))
end

local function CheckUnit(unit)
    if not Enabled() or not unit or not UnitExists(unit) then return end
    if not watch then BuildWatchList() end
    local npc = NpcFromGUID(UnitGUID(unit))
    local info = npc and watch[npc]
    if not info then return end
    -- Another hunter's pet, or already dead: nothing to tame.
    if UnitPlayerControlled(unit) or UnitIsDead(unit) then return end
    if info.horde and UnitFactionGroup("player") ~= "Horde" then return end
    local name = UnitName(unit)
    if name and ns.AnySecret(name) then name = nil end
    Notify(npc, info, unit, name)
end

-- Minimap vignettes (on clients that have them): the vignette names the
-- creature behind it.
local function CheckVignette(id)
    if not Enabled() or not (C_VignetteInfo and C_VignetteInfo.GetVignetteInfo) then return end
    if not watch then BuildWatchList() end
    local ok, v = pcall(C_VignetteInfo.GetVignetteInfo, id)
    if not ok or not v then return end
    local npc = NpcFromGUID(v.objectGUID)
    local info = npc and watch[npc]
    if not info then return end
    if info.horde and UnitFactionGroup("player") ~= "Horde" then return end
    Notify(npc, info, nil, (v.name and not ns.AnySecret(v.name)) and v.name or nil)
end

----------------------------------------------------------------------
-- Background scan: finding rares before they're on screen.
-- Every half second PetSmart asks the game to target one rare from the
-- current zone by name. Addons aren't allowed to change your target, so
-- the game always refuses - but it only bothers to refuse (with an
-- ADDON_ACTION_FORBIDDEN event) when a creature with that name is
-- actually close enough to target. That refusal is the "found it".
-- Your target never changes. The game's "PetSmart has been blocked from
-- an action" message is hidden straight away unless that's turned off in
-- Options. Skipped in combat, inside dungeons, and for rares that
-- alerted in the last few minutes (so a rare standing nearby doesn't
-- keep getting tried).
----------------------------------------------------------------------
local SCAN_INTERVAL = 0.5

-- English zone name for the zone the player is in (the data is in
-- English), from its map ID.
local zoneByMap
local function CurrentZone()
    if not zoneByMap then
        zoneByMap = {}
        for name, id in pairs(ns.ZONE_UIMAP or {}) do zoneByMap[id] = name end
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    while mapID do
        if zoneByMap[mapID] then return zoneByMap[mapID], mapID end
        local info = C_Map.GetMapInfo(mapID)
        if not info or info.mapType == zoneType or not info.parentMapID or info.parentMapID == 0 then
            return nil, mapID
        end
        mapID = info.parentMapID
    end
    if ns.LOCALE == "enUS" and GetRealZoneText then return GetRealZoneText(), nil end
end

local zoneList, zoneIndex = {}, 0
local function BuildZoneList()
    wipe(zoneList)
    zoneIndex = 0
    if not watch then BuildWatchList() end
    local zone, mapID = CurrentZone()
    for npc, info in pairs(watch) do
        local here = (info.rare and mapID and info.rare.mapID == mapID)
            or (zone and info.zone and ns.SameZone(info.zone, zone) and info.zone ~= "")
        if here and not (info.horde and UnitFactionGroup("player") ~= "Horde") then
            zoneList[#zoneList + 1] = npc
        end
    end
end
Alert.BuildZoneList = BuildZoneList

local scanning, forbidden = false, false
-- Error-catching addons (BugGrabber, shown by BugSack) also record the
-- game's refusal, as "[ADDON_ACTION_FORBIDDEN] AddOn 'PetSmart' tried to
-- call the protected function 'TargetUnit()'". That entry is just the scan
-- working, not a fault, so it's taken back out of their list.
local function RemoveBugGrabberEntry()
    local grabber = _G.BugGrabber
    if not (grabber and grabber.GetDB) then return end
    local ok, db = pcall(grabber.GetDB, grabber)
    if not ok or type(db) ~= "table" then return end
    local removed = false
    for i = #db, 1, -1 do
        local e = db[i]
        local msg = type(e) == "table" and e.message
        if type(msg) == "string" and msg:find("ADDON_ACTION_FORBIDDEN", 1, true)
            and msg:find("'" .. addonName .. "'", 1, true) and msg:find("TargetUnit()", 1, true) then
            table.remove(db, i)
            removed = true
        end
    end
    -- Let BugSack redraw its count/list without the entry.
    local sack = _G.BugSack
    if removed and sack then
        if sack.UpdateDisplay then pcall(sack.UpdateDisplay, sack) end
        if _G.BugSackFrame and _G.BugSackFrame:IsShown() and sack.CloseSack then
            pcall(sack.CloseSack, sack)
        end
    end
end

local function HideBlockedMessage()
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local dialog = _G["StaticPopup" .. i]
        if dialog and dialog:IsShown() and dialog.which == "ADDON_ACTION_FORBIDDEN" then
            local text = dialog.text and dialog.text.GetText and dialog.text:GetText()
            if not text or text:find(addonName, 1, true) then dialog:Hide() end
        end
    end
    RemoveBugGrabberEntry()
end

local function ScanStep()
    local p = ns.profile
    if not Enabled() or not p or p.rareAlertBackgroundScan == false then return end
    if InCombatLockdown() or (IsInInstance and IsInInstance()) then return end
    if #zoneList == 0 then return end
    zoneIndex = zoneIndex % #zoneList + 1
    local npc = zoneList[zoneIndex]
    local info = watch[npc]
    if lastAlert[npc] and GetTime() - lastAlert[npc] < RE_ALERT_SECONDS then return end
    local name = ns.LocCreature(info.name)
    if not name or name == "" then return end
    forbidden = false
    scanning = true
    TargetUnit(name)
    scanning = false
    if forbidden then
        forbidden = false
        if p.rareAlertHideBlocked ~= false then HideBlockedMessage() end
        Notify(npc, info, nil, name)
    end
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(SCAN_INTERVAL, ScanStep)
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
local hasVignettes = C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("VIGNETTE_MINIMAP_UPDATED")
if hasVignettes then events:RegisterEvent("VIGNETTE_MINIMAP_UPDATED") end
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "NAME_PLATE_UNIT_ADDED" then
        CheckUnit(arg1)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CheckUnit("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        CheckUnit("target")
    elseif event == "VIGNETTE_MINIMAP_UPDATED" then
        if arg2 then CheckVignette(arg1) end
    elseif event == "ADDON_ACTION_FORBIDDEN" then
        if scanning and arg1 == addonName then forbidden = true end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        BuildZoneList()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Finish what combat held back on the Target button.
        AfterCombat()
    end
end)

-- Options "Test" line: shows the alert for a rare from this client's list.
-- Options "Test Alert": shows the alert for up to three rares from this
-- client's list, so the stacked popups can be seen and placed.
function Alert.Test()
    if not watch then BuildWatchList() end
    -- Prefer rares from the Rare Index (they have a map spot for Track).
    local picks = {}
    for id, i in pairs(watch) do
        if i.rare then picks[#picks + 1] = id end
        if #picks >= 3 then break end
    end
    if #picks == 0 then
        local id = next(watch)
        if id then picks[1] = id end
    end
    if #picks == 0 then return end
    for _, p in ipairs(popups) do p:Hide() end
    wipe(queue)
    local prof = ns.profile
    if prof.rareAlertSoundEnabled ~= false then Alert.PlaySound() end
    if prof.rareAlertFlash ~= false then Flash() end
    if prof.rareAlertPopup ~= false then
        for _, id in ipairs(picks) do ShowPopup(id, watch[id], nil, nil) end
    end
end
