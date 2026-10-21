--------------------------------------------------------------------------
-- PetSmart: Compendium/DressingRoom.lua
-- The "dressing room": a small 3D model viewer along the bottom of the
-- rare and tame-creature detail pages. Left-drag turns the creature,
-- right-drag moves it, the mouse wheel zooms, and double-click resets.
--------------------------------------------------------------------------
local addonName, ns = ...

local LAYOUT = ns.LAYOUT
local contentPanel = ns.contentPanel
local scrollFrame = ns.scrollFrame

local MAX_HEIGHT = 290      -- the viewer's height on a normal-sized window
local MAX_WIDTH = 290       -- and its width (centred)
local ASPECT = 1.0          -- width is at most this share of the height (square)
local MIN_HEIGHT = 90       -- never squeezed smaller than this
local SHARE = 0.62          -- at most this share of the content panel's height
local GAP = 8               -- space between the page text and the viewer
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = -2.0, 3.0, 0.25
local TURN_SPEED = 0.012    -- radians per pixel dragged
local PAN_SPEED = 0.01      -- model units per pixel dragged
local RETRIES = 6           -- creature-cache retries (0.5 sec apart)

local panelTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

local room = CreateFrame("Frame", "PetSmartDressingRoom", contentPanel, panelTemplate)
room:SetPoint("BOTTOM", contentPanel, "BOTTOM", 0, 12)
room:SetSize(MAX_WIDTH, MAX_HEIGHT)
room:Hide()
if room.SetBackdrop then
    room:SetBackdrop(LAYOUT.SUBPANEL_BACKDROP)
    room:SetBackdropColor(0, 0, 0, 0.55)
    room:SetBackdropBorderColor(0.55, 0.45, 0.3, 1)
end

local model = CreateFrame("PlayerModel", "PetSmartDressingRoomModel", room)
model:SetPoint("TOPLEFT", 4, -4)
model:SetPoint("BOTTOMRIGHT", -4, 4)
model:EnableMouse(true)
model:EnableMouseWheel(true)

-- Text drawn over the model (the model frame would otherwise cover it).
local overlay = CreateFrame("Frame", nil, room)
overlay:SetAllPoints()
overlay:SetFrameLevel(model:GetFrameLevel() + 2)

-- Shown instead of the model when there's nothing to show.
room.empty = overlay:CreateFontString(nil, "OVERLAY", "GameFontDisable")
room.empty:SetPoint("CENTER")
room.empty:SetWidth(260)

room.hint = overlay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
room.hint:SetPoint("BOTTOMRIGHT", -8, 6)
room.hint:SetText("Drag: turn   Right-drag: move   Wheel: zoom")
room.hint:SetAlpha(0.8)

local state = { facing = 0, zoom = 0, x = 0, y = 0, dragging = nil, lastX = 0, lastY = 0 }

local function Apply()
    model:SetFacing(state.facing)
    model:SetPosition(state.zoom, state.x, state.y)
end

-- Turn the creature around the middle of its body, not the point its
-- model file was built around (for some creatures, e.g. Dishu, that point
-- sits off to one side, so they swing round instead of spinning in place).
-- Only on clients that have this option.
local function CenterPivot()
    if model.UseModelCenterToTransform then
        pcall(model.UseModelCenterToTransform, model, true)
    end
end

-- Point the camera at the middle of the creature (top to bottom as well as
-- side to side) while keeping the game's own framing distance, so models
-- built around a low or high point don't sit too high or too low in the
-- box. Needs a loaded model; skipped on clients without these options.
local function CenterCamera()
    if not (model.MakeCurrentCameraCustom and model.GetCameraPosition and model.GetCameraTarget
            and model.SetCameraPosition and model.SetCameraTarget) then return end
    pcall(function()
        model:MakeCurrentCameraCustom()
        local px, py, pz = model:GetCameraPosition()
        local tx, ty, tz = model:GetCameraTarget()
        if not (px and tx) then return end
        model:SetCameraTarget(0, 0, 0)
        model:SetCameraPosition(px - tx, py - ty, pz - tz)
    end)
end

local function ResetView()
    CenterPivot()
    state.facing, state.zoom, state.x, state.y = 0.6, 0, 0, 0
    if model.SetPortraitZoom then model:SetPortraitZoom(0) end
    if model.SetCamDistanceScale then model:SetCamDistanceScale(1) end
    Apply()
end

local function Cursor()
    local x, y = GetCursorPosition()
    local s = model:GetEffectiveScale()
    return x / s, y / s
end

-- Double-click (two left clicks within 0.3 sec) puts the creature back
-- where it started. Models don't get OnDoubleClick, so it's timed here.
local lastClick = 0
model:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        local now = GetTime()
        if now - lastClick < 0.3 then
            lastClick = 0
            ResetView()
            return
        end
        lastClick = now
    end
    state.dragging = button
    state.lastX, state.lastY = Cursor()
end)
model:SetScript("OnMouseUp", function() state.dragging = nil end)
model:SetScript("OnHide", function() state.dragging = nil end)
model:SetScript("OnUpdate", function()
    if not state.dragging then return end
    local x, y = Cursor()
    local dx, dy = x - state.lastX, y - state.lastY
    state.lastX, state.lastY = x, y
    if dx == 0 and dy == 0 then return end
    if state.dragging == "LeftButton" then
        state.facing = state.facing + dx * TURN_SPEED
    elseif state.dragging == "RightButton" then
        state.x = state.x + dx * PAN_SPEED
        state.y = state.y + dy * PAN_SPEED
    end
    Apply()
end)
-- The pivot setting can be lost when a new model finishes loading.
if model.HasScript and model:HasScript("OnModelLoaded") then
    model:SetScript("OnModelLoaded", function()
        CenterPivot()
        CenterCamera()
        Apply()
    end)
end
model:SetScript("OnMouseWheel", function(_, delta)
    state.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, state.zoom + delta * ZOOM_STEP))
    Apply()
end)

-- True once the client has actually loaded a model into the frame. On a
-- client that can't report that, assume it worked rather than hide it.
local function HasModel()
    if not model.GetModelFileID and not model.GetModel then return true end
    if model.GetModelFileID then
        local ok, id = pcall(model.GetModelFileID, model)
        if ok and id and id ~= 0 then return true end
    end
    if model.GetModel then
        local ok, m = pcall(model.GetModel, model)
        if ok and type(m) == "string" and m ~= "" then return true end
    end
    return false
end

-- The client loads a creature's model from its creature ID. If it hasn't
-- got that creature's details yet it asks the server for them, so keep
-- retrying for a few seconds and fall back to a note if nothing arrives.
local npcID, tries, elapsed = nil, 0, 0
local function Load()
    model:ClearModel()
    if npcID and model.SetCreature then
        pcall(model.SetCreature, model, npcID)
    end
    ResetView()
    if HasModel() then
        CenterCamera()
        return true
    end
    return false
end

local watcher = CreateFrame("Frame")
watcher:Hide()
watcher:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0
    tries = tries + 1
    if HasModel() or Load() then
        CenterCamera()
        room.empty:Hide()
        model:Show()
        self:Hide()
    elseif tries >= RETRIES then
        model:Hide()
        room.empty:SetText("The model didn't load.\nReopen this page to try again.")
        room.empty:Show()
        self:Hide()
    end
end)

local DressingRoom = {}

-- Gives the scroll area its full height back. Called at the start of
-- every page refresh; Show() below takes the room again when needed.
function DressingRoom.Hide()
    watcher:Hide()
    room:Hide()
    scrollFrame:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -30, 12)
end

-- Sizes the viewer to the window and moves the scroll area's bottom edge
-- up above it.
local function Fit()
    local h = contentPanel:GetHeight()
    if not h or ns.AnySecret(h) then h = MAX_HEIGHT / SHARE end
    h = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, math.floor(h * SHARE)))
    local w = contentPanel:GetWidth()
    if not w or ns.AnySecret(w) then w = MAX_WIDTH + 24 end
    room:SetSize(math.max(80, math.min(MAX_WIDTH, math.floor(h * ASPECT), math.floor(w - 24))), h)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -30, 12 + h + GAP)
end
contentPanel:HookScript("OnSizeChanged", function()
    if room:IsShown() then Fit() end
end)

-- name: the creature's name as written in the addon's data. id (optional):
-- its creature ID, when the caller already has it (the Pet Types lists);
-- otherwise it's looked up by name.
function DressingRoom.Show(name, id)
    Fit()
    room:Show()

    local newID = id or (name and ns.CREATURE_IDS and ns.CREATURE_IDS[name])
    -- Same creature still loaded (the page was just redrawn): keep the
    -- view the player has turned/zoomed it to.
    if newID and newID == npcID and model:IsShown() and HasModel() then
        room.hint:Show()
        room.empty:Hide()
        return
    end
    npcID = newID
    watcher:Hide()
    if not npcID then
        model:ClearModel()
        model:Hide()
        room.empty:SetText("No model on record for this creature.")
        room.empty:Show()
        room.hint:Hide()
        return
    end
    room.hint:Show()
    room.empty:Hide()
    model:Show()
    tries, elapsed = 0, 0
    if not Load() then watcher:Show() end
end

ns.DressingRoom = DressingRoom
