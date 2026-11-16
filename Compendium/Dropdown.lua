--------------------------------------------------------------------------
-- PetSmart: Compendium/Dropdown.lua
-- A small dropdown list for the Options page (rare alert sound and flash
-- colour). PetSmart's own widget rather than Blizzard's UIDropDownMenu,
-- which differs between clients and is easily tainted.
--
--   local dd = ns.Dropdown.Create(parent, "PetSmartSomethingDropdown")
--   dd:SetLabel("Sound")
--   dd:SetItems(items, selectedValue, onSelect, keepOpen)
--
-- items: { { text = "...", value = v, color = {r, g, b}, header = true }, ... }
-- A header row is a heading inside the list, not something to pick.
-- keepOpen leaves the list open after a pick (handy for trying sounds).
--------------------------------------------------------------------------
local addonName, ns = ...
local L = ns.L

local Dropdown = {}
ns.Dropdown = Dropdown

local ROW_HEIGHT = 18
local VISIBLE_ROWS = 14
local all = {}

----------------------------------------------------------------------
-- The one list frame, shared by every dropdown (only one is open at once).
----------------------------------------------------------------------
local list = CreateFrame("Frame", "PetSmartDropdownList", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
list:SetFrameStrata("FULLSCREEN_DIALOG")
list:SetClampedToScreen(true)
list:EnableMouse(true)
list:EnableMouseWheel(true)
list:Hide()
if list.SetBackdrop then
    list:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    list:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    list:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
end
-- Escape closes it.
tinsert(UISpecialFrames, "PetSmartDropdownList")

list.rows = {}
for i = 1, VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", list, "RIGHT", -22, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(14, 14)
    row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.swatch = row:CreateTexture(nil, "ARTWORK")
    row.swatch:SetSize(10, 10)
    row.swatch:SetPoint("LEFT", row, "LEFT", 18, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.text:SetWordWrap(false)
    list.rows[i] = row
end

-- Scroll bar thumb (only shown when the list is longer than the frame).
list.track = list:CreateTexture(nil, "ARTWORK")
list.track:SetWidth(6)
list.track:SetPoint("TOPRIGHT", list, "TOPRIGHT", -9, -8)
list.track:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -9, 8)
list.track:SetColorTexture(1, 1, 1, 0.08)
list.thumb = list:CreateTexture(nil, "OVERLAY")
list.thumb:SetWidth(6)
list.thumb:SetColorTexture(0.8, 0.8, 0.8, 0.6)

local function DrawList()
    local dd = list.owner
    if not dd then return end
    local items = dd.items
    local maxOffset = math.max(0, #items - VISIBLE_ROWS)
    list.offset = math.max(0, math.min(list.offset or 0, maxOffset))
    for i, row in ipairs(list.rows) do
        local item = items[i + list.offset]
        if item then
            row.text:SetText(item.text)
            if item.header then
                row.text:SetTextColor(1, 0.82, 0)
                row.check:Hide()
                row.swatch:Hide()
                row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
                row:EnableMouse(false)
                row:SetScript("OnClick", nil)
            else
                row.text:SetTextColor(1, 1, 1)
                row.check:SetShown(item.value == dd.selected)
                if item.color then
                    row.swatch:SetColorTexture(item.color[1], item.color[2], item.color[3], 1)
                    row.swatch:Show()
                    row.text:SetPoint("LEFT", row.swatch, "RIGHT", 5, 0)
                else
                    row.swatch:Hide()
                    row.text:SetPoint("LEFT", row, "LEFT", 18, 0)
                end
                row:EnableMouse(true)
                row:SetScript("OnClick", function()
                    dd.selected = item.value
                    if dd.onSelect then dd.onSelect(item.value, item) end
                    if dd.keepOpen then DrawList() else list:Hide() end
                end)
            end
            row:Show()
        else
            row:Hide()
        end
    end
    local shown = math.min(#items, VISIBLE_ROWS)
    list:SetHeight(shown * ROW_HEIGHT + 12)
    if maxOffset > 0 then
        local trackH = shown * ROW_HEIGHT - 4
        local thumbH = math.max(16, trackH * VISIBLE_ROWS / #items)
        list.thumb:SetHeight(thumbH)
        list.thumb:ClearAllPoints()
        list.thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", -9, -8 - (trackH - thumbH) * list.offset / maxOffset)
        list.track:Show()
        list.thumb:Show()
    else
        list.track:Hide()
        list.thumb:Hide()
    end
end

list:SetScript("OnMouseWheel", function(_, delta)
    list.offset = (list.offset or 0) - delta * 3
    DrawList()
end)
list:SetScript("OnHide", function()
    if list.owner then list.owner.arrowOpen(false) end
    list.owner = nil
end)

-- A click anywhere outside the list (or its dropdown) closes it, on
-- clients that report clicks anywhere on screen.
if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("GLOBAL_MOUSE_DOWN") then
    list:RegisterEvent("GLOBAL_MOUSE_DOWN")
    list:SetScript("OnEvent", function(self)
        if not self:IsShown() then return end
        if self:IsMouseOver() or (self.owner and self.owner.box:IsMouseOver()) then return end
        self:Hide()
    end)
end

local function Open(dd)
    if list:IsShown() and list.owner == dd then
        list:Hide()
        return
    end
    list:Hide()
    list.owner = dd
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", dd.box, "BOTTOMLEFT", 0, -2)
    list:SetWidth(math.max(dd.box:GetWidth() or 0, 180))
    -- Start scrolled so the current choice is in view.
    list.offset = 0
    for i, item in ipairs(dd.items) do
        if item.value == dd.selected and not item.header then
            list.offset = i - math.floor(VISIBLE_ROWS / 2)
            break
        end
    end
    dd.arrowOpen(true)
    list:Show()
    DrawList()
end

----------------------------------------------------------------------
-- A dropdown: a label, then a box showing the current choice and an arrow.
----------------------------------------------------------------------
function Dropdown.Create(parent, name)
    local dd = CreateFrame("Frame", name, parent)
    dd:SetHeight(24)
    dd.items = {}

    dd.label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dd.label:SetPoint("LEFT", dd, "LEFT", 4, 0)
    dd.label:SetJustifyH("LEFT")

    local box = CreateFrame("Button", nil, dd, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetHeight(22)
    box:SetPoint("LEFT", dd.label, "RIGHT", 8, 0)
    box:SetPoint("RIGHT", dd, "RIGHT", -6, 0)
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.8)
        box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    box:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")
    box.arrow = box:CreateTexture(nil, "OVERLAY")
    box.arrow:SetSize(18, 18)
    box.arrow:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    box.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    box.swatch = box:CreateTexture(nil, "ARTWORK")
    box.swatch:SetSize(10, 10)
    box.swatch:SetPoint("LEFT", box, "LEFT", 8, 0)
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.text:SetJustifyH("LEFT")
    box.text:SetPoint("RIGHT", box.arrow, "LEFT", -2, 0)
    box.text:SetWordWrap(false)
    box:SetScript("OnClick", function() Open(dd) end)
    dd.box = box

    function dd.arrowOpen(open)
        box.arrow:SetTexture(open and "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up"
            or "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    end

    function dd:SetLabel(text)
        self.label:SetText(text)
    end

    function dd:SetItems(items, selected, onSelect, keepOpen)
        self.items, self.selected, self.onSelect, self.keepOpen = items, selected, onSelect, keepOpen
        local shownText, color = "", nil
        for _, item in ipairs(items) do
            if not item.header and item.value == selected then
                shownText, color = item.text, item.color
                break
            end
        end
        box.text:SetText(shownText)
        if color then
            box.swatch:SetColorTexture(color[1], color[2], color[3], 1)
            box.swatch:Show()
            box.text:SetPoint("LEFT", box.swatch, "RIGHT", 5, 0)
        else
            box.swatch:Hide()
            box.text:SetPoint("LEFT", box, "LEFT", 8, 0)
        end
        if list:IsShown() and list.owner == self then DrawList() end
    end

    dd:SetScript("OnHide", function(self)
        if list.owner == self then list:Hide() end
    end)
    dd:Hide()
    all[#all + 1] = dd
    return dd
end

-- Hides every dropdown (the Compendium does this before drawing a page).
function Dropdown.HideAll()
    for _, dd in ipairs(all) do dd:Hide() end
    list:Hide()
end
