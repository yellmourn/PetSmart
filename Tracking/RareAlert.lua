--------------------------------------------------------------------------
-- PetSmart: Tracking/RareAlert.lua
-- Tameable rare alerts: when one of the rare pets in this client's data
-- turns up nearby, PetSmart plays a sound, flashes the edge of the screen
-- and shows a small popup with the rare's details, a Target button and a
-- Track button.
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

local flash = CreateFrame("Frame", nil, UIParent)
flash:SetAllPoints(UIParent)
flash:SetFrameStrata("FULLSCREEN_DIALOG")
flash:EnableMouse(false)
flash:Hide()
flash.tex = flash:CreateTexture(nil, "BACKGROUND")
flash.tex:SetAllPoints()
flash.tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
flash.tex:SetBlendMode("ADD")
flash.tex:SetVertexColor(0.35, 1, 0.45) -- PetSmart green
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
    flash.t = 0
    flash:SetAlpha(0)
    flash:Show()
end

----------------------------------------------------------------------
-- Popup
----------------------------------------------------------------------
local popup = CreateFrame("Frame", "PetSmartRareAlert", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
popup:SetSize(290, 112)
popup:SetFrameStrata("DIALOG")
popup:SetClampedToScreen(true)
popup:SetMovable(true)
popup:EnableMouse(true)
popup:RegisterForDrag("LeftButton")
popup:Hide()
if popup.SetBackdrop then
    popup:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    popup:SetBackdropBorderColor(0.34, 0.6, 0.4, 1)
end

local function PlacePopup()
    popup:ClearAllPoints()
    local pos = ns.profile and ns.profile.rareAlertPos
    if pos then
        popup:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        popup:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

-- Dragging is out of combat only: the Target button below is a secure
-- frame anchored to the popup, and it can't be moved during combat.
popup:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then self:StartMoving() end
end)
popup:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if ns.profile then ns.profile.rareAlertPos = { point, relPoint, x, y } end
end)

popup.model = CreateFrame("PlayerModel", nil, popup)
popup.model:SetSize(76, 92)
popup.model:SetPoint("LEFT", popup, "LEFT", 10, 0)

popup.heading = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popup.heading:SetPoint("TOPLEFT", popup.model, "TOPRIGHT", 8, 2)
popup.heading:SetText(L["Tameable rare nearby!"])

popup.name = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
popup.name:SetPoint("TOPLEFT", popup.heading, "BOTTOMLEFT", 0, -3)
popup.name:SetPoint("RIGHT", popup, "RIGHT", -26, 0)
popup.name:SetJustifyH("LEFT")
popup.name:SetWordWrap(false)

popup.info = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
popup.info:SetPoint("TOPLEFT", popup.name, "BOTTOMLEFT", 0, -3)
popup.info:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
popup.info:SetJustifyH("LEFT")

popup.zone = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
popup.zone:SetPoint("TOPLEFT", popup.info, "BOTTOMLEFT", 0, -2)
popup.zone:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
popup.zone:SetJustifyH("LEFT")

popup.note = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
popup.note:SetPoint("BOTTOMLEFT", popup.model, "BOTTOMRIGHT", 8, 4)
popup.note:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
popup.note:SetJustifyH("LEFT")

popup.close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
popup.close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, 0)

popup.track = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
popup.track:SetSize(80, 22)
popup.track:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -10, 10)

-- The Target button runs "/targetexact <name>", which only a secure button
-- may do. It's its own top-level frame laid over the popup rather than a
-- child of it, so the popup itself can still be shown and hidden in
-- combat; the button only appears, changes or hides out of combat.
local target = CreateFrame("Button", "PetSmartRareAlertTarget", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
target:SetSize(80, 22)
target:SetFrameStrata("DIALOG")
target:SetFrameLevel(popup:GetFrameLevel() + 10)
target:SetText(_G.TARGET or L["Target"])
target:RegisterForClicks("AnyUp", "AnyDown")
target:SetAttribute("type", "macro")
target:Hide()

local pendingTarget -- name to set up on the Target button once combat ends
local function ShowTargetButton(name)
    if InCombatLockdown() then
        pendingTarget = name
        popup.note:SetText(L["Targeting is available after combat."])
        return
    end
    pendingTarget = nil
    popup.note:SetText("")
    target:SetAttribute("macrotext", "/cleartarget\n/targetexact " .. name)
    target:ClearAllPoints()
    target:SetPoint("RIGHT", popup.track, "LEFT", -6, 0)
    target:Show()
end

local function HideTargetButton()
    pendingTarget = nil
    if not InCombatLockdown() then target:Hide() end
end

popup:SetScript("OnHide", function(self)
    self.npc = nil
    HideTargetButton()
end)
popup:SetScript("OnUpdate", function(self, dt)
    self.left = (self.left or POPUP_SECONDS) - dt
    if self.left <= 0 then self:Hide() end
end)

local function UpdateTrackButton(info)
    local rare = info.rare
    if rare and rare.mapID and not rare.isDungeon and ns.SetTrackedRare then
        local tracked = ns.IsTrackedRare and ns.IsTrackedRare(rare)
        popup.track:SetText(tracked and L["Untrack"] or L["Track"])
        popup.track:SetScript("OnClick", function()
            ns.SetTrackedRare(rare)
            UpdateTrackButton(info)
            if ns.RefreshAbilitiesPanel then ns.RefreshAbilitiesPanel() end
        end)
        popup.track:Show()
    else
        popup.track:Hide()
    end
end

local function ShowPopup(npc, info, unit, unitName)
    popup.npc = npc
    popup.left = POPUP_SECONDS
    local name = unitName or ns.LocCreature(info.name)
    popup.name:SetText(name)
    local level = info.level and ns.LocLevel(tostring(info.level)) or "?"
    local family = info.family and ns.LocFamily(info.family) or ""
    local text = L["Level %s %s"]:format(level, family)
    -- A rare above the hunter's level can't be tamed yet.
    local low = tonumber(tostring(info.level or ""):match("%d+"))
    if low and low > UnitLevel("player") then
        text = text .. "  |cffff5050" .. L["Tameable at level %d"]:format(low) .. "|r"
    end
    popup.info:SetText(text)
    popup.zone:SetText(info.zone and L["Zone: %s"]:format(ns.LocZone(tostring(info.zone))) or "")
    popup.note:SetText("")

    popup.model:ClearModel()
    if unit and UnitExists(unit) then
        pcall(popup.model.SetUnit, popup.model, unit)
    elseif popup.model.SetCreature then
        pcall(popup.model.SetCreature, popup.model, npc)
    end
    pcall(popup.model.SetPortraitZoom, popup.model, 0.6)

    UpdateTrackButton(info)
    PlacePopup()
    popup:Show()
    ShowTargetButton(name)
end

----------------------------------------------------------------------
-- Spotting
----------------------------------------------------------------------
local lastAlert = {}

local function Notify(npc, info, unit, unitName)
    local now = GetTime()
    if popup:IsShown() and popup.npc == npc then
        popup.left = POPUP_SECONDS -- still around: keep the popup up
        return
    end
    if lastAlert[npc] and now - lastAlert[npc] < RE_ALERT_SECONDS then return end
    lastAlert[npc] = now

    local p = ns.profile
    if p.rareAlertSoundEnabled ~= false then Alert.PlaySound() end
    if p.rareAlertFlash ~= false then Flash() end
    if p.rareAlertPopup ~= false then ShowPopup(npc, info, unit, unitName) end
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
local function HideBlockedMessage()
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local dialog = _G["StaticPopup" .. i]
        if dialog and dialog:IsShown() and dialog.which == "ADDON_ACTION_FORBIDDEN" then
            local text = dialog.text and dialog.text.GetText and dialog.text:GetText()
            if not text or text:find(addonName, 1, true) then dialog:Hide() end
        end
    end
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
        if popup:IsShown() and pendingTarget then
            ShowTargetButton(pendingTarget)
        elseif not popup:IsShown() then
            target:Hide()
        end
    end
end)

-- Options "Test" line: shows the alert for a rare from this client's list.
function Alert.Test()
    if not watch then BuildWatchList() end
    -- Prefer a rare from the Rare Index (it has a map spot for Track).
    local npc, info
    for id, i in pairs(watch) do
        if not npc or (i.rare and not info.rare) then npc, info = id, i end
    end
    if not npc then return end
    lastAlert[npc] = nil
    if popup:IsShown() then popup:Hide() end
    local p = ns.profile
    if p.rareAlertSoundEnabled ~= false then Alert.PlaySound() end
    if p.rareAlertFlash ~= false then Flash() end
    if p.rareAlertPopup ~= false then ShowPopup(npc, info, nil, nil) end
end
