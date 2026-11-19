--------------------------------------------------------------------------
-- PetSmart: Sections/PetTypes.lua
-- Section: Pet Types and each family's detail page.
--------------------------------------------------------------------------
local addonName, ns = ...
local L = ns.L

-- Shared from earlier files (see the ns.<name> exports at the end of each).
local BuildFamilyAbilityNames = ns.BuildFamilyAbilityNames
local GetAbilitySpellDescription = ns.GetAbilitySpellDescription
local GetFamilySpecialty = ns.GetFamilySpecialty
local SPEC_LABEL = ns.SPEC_LABEL
local IsTrackedRare = ns.IsTrackedRare
local SetAbilitiesMode = ns.SetAbilitiesMode
local SetTrackedRare = ns.SetTrackedRare
local Tame = ns.Tame
local abilitiesPanel = ns.abilitiesPanel
local rareTrackBtn = ns.rareTrackBtn

-- Icons in front of a creature's name: silver paw = one of the Rare Pet
-- Spawns, bronze paw = a teacher pet (taming it teaches an ability).
local ICON_RARE = "|TInterface\\AddOns\\PetSmart\\Media\\UI-Elements\\RareCreatureIcon:14:14|t"
local ICON_TEACHER = "|TInterface\\AddOns\\PetSmart\\Media\\UI-Elements\\TeacherCreatureIcon:14:14|t"

-- Rares and teacher pets by name, built the first time a creature list is
-- drawn (the ability names need the game's spell data, so not at load).
local rareByName, teacherByName
local function BuildLookups()
    if rareByName then return end
    rareByName, teacherByName = {}, {}
    for _, r in ipairs(ns.RARE_SPAWNS or {}) do
        rareByName[r.name] = r
    end
    for _, key in ipairs(ns.PET_ABILITY_ORDER or {}) do
        local ranks = ns.PETOPIA_TAME_MOBS and ns.PETOPIA_TAME_MOBS[key]
        local entry = ns.PET_ABILITIES and ns.PET_ABILITIES[key]
        if ranks and entry then
            local abilityName = ns.GetAbilityDisplayName(key, entry)
            for rank = 1, 20 do
                for _, m in ipairs(ranks[rank] or {}) do
                    -- Same-named creatures in different places (e.g. the two
                    -- Shore Crawlers) are kept apart by family, zone and level.
                    local list = teacherByName[m[1]]
                    if not list then list = {}; teacherByName[m[1]] = list end
                    local t
                    for _, e in ipairs(list) do
                        if e.mob.family == m[2] and e.mob.zone == m[4] and e.mob.levels == m[3] then t = e end
                    end
                    if not t then
                        t = { mob = { name = m[1], family = m[2], levels = m[3], zone = m[4] }, teaches = {} }
                        list[#list + 1] = t
                    end
                    t.teaches[#t.teaches + 1] = abilityName .. " " .. rank
                end
            end
        end
    end
end

-- The rare / teacher records behind a creature list entry (nil if it's
-- neither). Matched by name and family, so a same-named creature of
-- another family isn't mistaken for one.
local function RareFor(c, familyName)
    local r = rareByName[c.name]
    if r and r.familyId and ns.PET_FAMILIES and ns.PET_FAMILIES[r.familyId] ~= familyName then return nil end
    return r
end
local function LowLevel(text)
    return tonumber(tostring(text or ""):match("%d+"))
end
local function TeacherFor(c, familyName)
    local best, bestGap
    for _, t in ipairs(teacherByName[c.name] or {}) do
        if t.mob.family == familyName then
            -- Same name, very different level = a different creature (e.g. the
            -- same-named creature at a very different level isn't the teacher).
            local a, b = LowLevel(c.level), LowLevel(t.mob.levels)
            local gap = (a and b) and math.abs(a - b) or 0
            if gap <= 5 and (not bestGap or gap < bestGap) then best, bestGap = t, gap end
        end
    end
    return best
end

-- The tameable-creature entry (TameableCreatureData.lua) for a name in a
-- zone, for pages that only have a teacher list row (name, family, zone).
function ns.FindTameableCreature(name, familyName, zone)
    local list = ns.TAMEABLE_CREATURES and ns.TAMEABLE_CREATURES[familyName]
    local fallback
    for _, c in ipairs(list or {}) do
        if c.name == name then
            if ns.SameZone(c.zone, zone) then return c end
            fallback = fallback or c
        end
    end
    return fallback
end

local function CreatureIcons(c, familyName)
    return (RareFor(c, familyName) and ICON_RARE or "") .. (TeacherFor(c, familyName) and ICON_TEACHER or "")
end

----------------------------------------------------------------------
-- Search box at the top of the Pet Index: type part of a pet's name or a
-- family's name to list every match. A persistent widget placed by hand,
-- like the Options sliders; Compendium/Refresh.lua hides it on every
-- other page.
----------------------------------------------------------------------
local MAX_RESULTS = 150
local search = CreateFrame("EditBox", "PetSmartPetSearch", ns.scrollChild, "InputBoxTemplate")
search:SetHeight(20)
search:SetAutoFocus(false)
search:SetMaxLetters(40)
search:Hide()
search.hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
search.hint:SetPoint("LEFT", search, "LEFT", 2, 0)
search.hint:SetText(L["Search by name or family"])
local function UpdateHint()
    search.hint:SetShown(search:GetText() == "" and not search:HasFocus())
end
search:SetScript("OnEditFocusGained", UpdateHint)
search:SetScript("OnEditFocusLost", UpdateHint)
search:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged", function(self, userInput)
    UpdateHint()
    if userInput or self:GetText() == "" then ns.RefreshAbilitiesPanel() end
end)
ns.PetSearch = search

-- Lower-case, for matching without caring about capitals.
local function Lower(text) return (tostring(text or "")):lower() end

local function DrawSearchResults(ctx, query)
    local q = Lower(query)
    BuildLookups()
    local familyIds = {}
    for familyId, familyName in pairs(ns.PET_FAMILIES or {}) do
        familyIds[#familyIds + 1] = familyId
    end
    table.sort(familyIds, function(a, b) return ns.LocFamily(ns.PET_FAMILIES[a]) < ns.LocFamily(ns.PET_FAMILIES[b]) end)

    -- Families whose name matches.
    local families = {}
    for _, familyId in ipairs(familyIds) do
        local name = ns.PET_FAMILIES[familyId]
        if Lower(name):find(q, 1, true) or Lower(ns.LocFamily(name)):find(q, 1, true) then
            families[#families + 1] = familyId
        end
    end
    if #families > 0 then
        ctx.AddLine(L["Families"], 1, 0.82, 0)
        for _, familyId in ipairs(families) do
            ctx.AddLine(ns.LocFamily(ns.PET_FAMILIES[familyId]), 1, 1, 1, function()
                SetAbilitiesMode("typedetail", familyId)
            end)
        end
        ctx.AddLine(" ", 1, 1, 1)
    end

    -- Creatures whose name (in English or the game's language) or family matches.
    local matches = {}
    for _, familyId in ipairs(familyIds) do
        local familyName = ns.PET_FAMILIES[familyId]
        local familyHit = Lower(familyName):find(q, 1, true) or Lower(ns.LocFamily(familyName)):find(q, 1, true)
        for _, c in ipairs(ns.TAMEABLE_CREATURES and ns.TAMEABLE_CREATURES[familyName] or {}) do
            if familyHit or Lower(c.name):find(q, 1, true) or Lower(ns.LocCreature(c.name)):find(q, 1, true) then
                matches[#matches + 1] = { c = c, familyId = familyId, familyName = familyName }
            end
        end
    end
    if #families == 0 and #matches == 0 then
        ctx.AddLine(L["No pets match \"%s\"."]:format(query), 0.8, 0.8, 0.8)
        return
    end
    ctx.AddLine(L["Tameable Creatures (%d):"]:format(#matches), 1, 0.82, 0)
    for i, m in ipairs(matches) do
        if i > MAX_RESULTS then
            ctx.AddLine(L["Showing the first %d. Type more of the name to narrow it down."]:format(MAX_RESULTS), 0.7, 0.7, 0.7)
            break
        end
        local c = m.c
        local icons = CreatureIcons(c, m.familyName)
        local text = (icons ~= "" and (icons .. " ") or "") .. ns.LocCreature(c.name)
            .. "  |cff9d9d9d" .. ns.LocFamily(m.familyName) .. " (" .. c.level .. ")  " .. ns.LocZone(c.zone) .. "|r"
        ctx.AddLine(text, 1, 1, 1, function()
            SetAbilitiesMode("creaturedetail", { creature = c, familyId = m.familyId })
        end)
    end
end

ns.Pages.types = function(ctx)
    abilitiesPanel.title:SetText(L["Pet Index"])
    abilitiesPanel.subtitle:SetText(L["Select a pet type to view family information and tamable pets."])
    abilitiesPanel.subtitle:SetTextColor(0.6, 0.6, 0.6)
    abilitiesPanel.subtitle:Show()

    search:ClearAllPoints()
    search:SetPoint("TOPLEFT", ns.scrollChild, "TOPLEFT", 8, -(ctx.y + 2))
    search:SetWidth(math.max(140, ctx.rowWidth - 16))
    search:Show()
    UpdateHint()
    ctx.y = ctx.y + 26 + (ns.ROW_PADDING or 0)
    local query = search:GetText():match("^%s*(.-)%s*$")
    if query ~= "" then
        DrawSearchResults(ctx, query)
        return
    end
    local familyIds = {}
    if ns.PET_FAMILIES then
        for familyId in pairs(ns.PET_FAMILIES) do
            familyIds[#familyIds + 1] = familyId
        end
        table.sort(familyIds, function(a, b) return ns.LocFamily(ns.PET_FAMILIES[a]) < ns.LocFamily(ns.PET_FAMILIES[b]) end)
    end
    local items = {}
    for _, familyId in ipairs(familyIds) do
        items[#items + 1] = {
            text = ns.LocFamily(ns.PET_FAMILIES[familyId]), color = { 1, 1, 1 },
            onClick = function() SetAbilitiesMode("typedetail", familyId) end,
        }
    end
    ctx.AddList(items, L["No pet family data loaded."])
end

ns.Pages.typedetail = function(ctx)
    local familyId = ns.selectedFamilyId
    local familyName = (familyId and ns.PET_FAMILIES and ns.PET_FAMILIES[familyId]) or L["Pet Type"]
    -- Keep the main header on "Pet Index" and put the family itself
    -- in the subheader instead of replacing it, same as how an
    -- ability's detail page behaves when reached from the Abilities
    -- Index.
    abilitiesPanel.title:SetText(L["Pet Index"])
    abilitiesPanel.subtitle:SetText(ns.LocFamily(familyName))
    abilitiesPanel.subtitle:Show()
    -- Key for the icons in this family's creature list, under the family name.
    abilitiesPanel.subtitle2:SetText(ICON_RARE .. " " .. L["Rare"] .. "    " .. ICON_TEACHER .. " " .. L["Ability Teaching"])
    abilitiesPanel.subtitle2:Show()
    if not familyId then
        ctx.AddLine(L["No pet type selected."], 0.8, 0.8, 0.8)
    else
        local info = ns.FAMILY_INFO and ns.FAMILY_INFO[familyId]
        ctx.AddLine(ns.FamilyDietText(familyId), 0.8, 0.8, 0.8)

        local roleText = (info and SPEC_LABEL[info.spec]) or L["Unknown"]
        ctx.AddLine(L["Combat Role: %s"]:format(roleText), 0.8, 0.8, 0.8)

        if info and info.basicSkill then
            ctx.AddLine(L["Basic Attack: %s"]:format(ns.LocAbilityList(info.basicSkill)), 0.8, 0.8, 0.8)
        end

        if info and info.healthQualifier and info.armorQualifier and info.dpsQualifier then
            ctx.AddLine(L["Health: %s   Armor: %s   DPS: %s"]:format(L[info.healthQualifier], L[info.armorQualifier], L[info.dpsQualifier]), 0.8, 0.8, 0.8)
        end

        ctx.AddLine(" ", 1, 1, 1)
        local desc = ns.PET_TYPE_DESCRIPTIONS and ns.PET_TYPE_DESCRIPTIONS[familyId]
        ctx.AddLine(desc and ns.LocText(desc) or L["No description available."], 0.9, 1, 0.9)

        ctx.AddLine(" ", 1, 1, 1)
        local specialty = GetFamilySpecialty(familyId)
        if specialty then
            ctx.AddLine(L["Family Specialty: %s"]:format(specialty.displayName), 1, 0.82, 0)
            local firstRank = specialty.entry.ranks[1]
            -- In another language the game's own (translated) description comes first.
            local specialtyDesc = (ns.LOCALE ~= "enUS" and firstRank and GetAbilitySpellDescription(firstRank.spellId))
                or (ns.PET_ABILITY_DESCRIPTIONS and ns.PET_ABILITY_DESCRIPTIONS[specialty.key])
                or (firstRank and GetAbilitySpellDescription(firstRank.spellId))
            ctx.AddLine(specialtyDesc and L[specialtyDesc] or L["No description available."], 0.9, 1, 0.9)
        else
            ctx.AddLine(L["Family Specialty:"], 1, 0.82, 0)
            ctx.AddLine(L["None on record."], 0.8, 0.8, 0.8)
        end

        ctx.AddLine(" ", 1, 1, 1)
        ctx.AddLine(L["Family Abilities:"], 1, 0.82, 0)
        local abilityNames = BuildFamilyAbilityNames(familyId)
        if #abilityNames > 0 then
            ctx.AddLine(table.concat(abilityNames, ", "), 1, 1, 1)
        else
            ctx.AddLine(L["None on record."], 0.8, 0.8, 0.8)
        end

        -- Every tameable creature of this family (TameableCreatureData.lua),
        -- lowest level first. Click one for its own page.
        local creatures = ns.TAMEABLE_CREATURES and ns.TAMEABLE_CREATURES[familyName] or {}
        BuildLookups()
        ctx.AddLine(" ", 1, 1, 1)
        ctx.AddLine(L["Tameable Creatures (%d):"]:format(#creatures), 1, 0.82, 0)
        if #creatures == 0 then
            ctx.AddLine(L["None on record."], 0.8, 0.8, 0.8)
        end
        for _, c in ipairs(creatures) do
            local icons = CreatureIcons(c, familyName)
            local text = (icons ~= "" and (icons .. " ") or "") .. ns.LocCreature(c.name)
                .. "  |cff9d9d9d(" .. c.level .. ")  " .. ns.LocZone(c.zone) .. "|r"
            ctx.AddLine(text, 1, 1, 1, function()
                SetAbilitiesMode("creaturedetail", { creature = c, familyId = familyId })
            end)
        end
    end
end

-- One creature from a family's list: the same details as the rare and
-- teacher-pet pages (family, level, zone, diet, what it teaches), its
-- Track button when it has one, and the 3D model.
ns.Pages.creaturedetail = function(ctx)
    local sel = ns.selectedCreature
    local c = sel and sel.creature
    local familyId = sel and sel.familyId
    local familyName = (familyId and ns.PET_FAMILIES and ns.PET_FAMILIES[familyId]) or "Unknown"
    abilitiesPanel.title:SetText(L["Pet Index"])
    abilitiesPanel.subtitle:SetText(c and ns.LocCreature(c.name) or L["Tameable Creature"])
    abilitiesPanel.subtitle:Show()
    if not c then
        ctx.AddLine(L["No creature selected."], 0.8, 0.8, 0.8)
        return
    end
    BuildLookups()
    local rare = RareFor(c, familyName)
    local teacher = TeacherFor(c, familyName)

    -- Track button: a rare tracks like it does on Rare Pet Spawns; a
    -- teacher pet with known spawn areas tracks like it does from the
    -- Abilities Index.
    local spawnInfo = (not rare) and teacher and ns.SpawnInfoFor(c.name, c.zone)
    if rare then
        rareTrackBtn:SetState(IsTrackedRare(rare) or false, nil, function()
            SetTrackedRare(rare)
            ns.RefreshAbilitiesPanel()
        end)
    elseif spawnInfo then
        rareTrackBtn:SetState(Tame.IsTracking(c.name), nil, function()
            Tame.Set(c.name, spawnInfo)
            ns.RefreshAbilitiesPanel()
        end)
    end

    local icons = CreatureIcons(c, familyName)
    if rare and teacher then
        ctx.AddLine(icons .. " " .. L["Rare spawn and teacher pet"], 0.8, 0.8, 0.8)
    elseif rare then
        ctx.AddLine(icons .. " " .. L["Rare spawn"], 0.8, 0.8, 0.8)
    elseif teacher then
        ctx.AddLine(icons .. " " .. L["Teacher pet"], 0.8, 0.8, 0.8)
    end
    ctx.AddLine(L["Family: %s"]:format(ns.LocFamily(familyName)), 0.8, 0.8, 0.8)
    local level = L["Level: %s"]:format(tostring(c.level))
    if c.tag and c.tag:find("Elite") then level = level .. " " .. L["(Elite)"] end
    ctx.AddLine(level, 0.8, 0.8, 0.8)
    if c.speed then
        -- Only set for pets that don't attack at the normal 2.0.
        ctx.AddLine(L["Attack Speed (seconds):"] .. " " .. c.speed, 0.8, 0.8, 0.8)
    end
    ctx.AddLine(ns.FamilyDietText(familyId), 0.8, 0.8, 0.8)
    local zoneLine = L["Zone: %s"]:format(ns.LocZone(tostring(c.zone)))
    local points = (rare and rare.points) or (spawnInfo and spawnInfo.points)
    if points and #points > 1 then
        zoneLine = zoneLine .. "  " .. L["(%d known locations)"]:format(#points)
    end
    ctx.AddLine(zoneLine, 0.8, 0.8, 0.8)
    if teacher then
        ctx.AddLine(L["Teaches when tamed: %s"]:format(table.concat(teacher.teaches, ", ")), 1, 0.82, 0.2)
    elseif c.knows then
        ctx.AddLine(L["Knows when tamed: %s"]:format(ns.LocAbilityList(c.knows)), 1, 0.82, 0.2)
    end
    if c.horde then
        ctx.AddLine(L["Only Horde hunters can tame this creature."], 1, 0.5, 0.5)
    end
    local desc = (rare and rare.description) or (spawnInfo and spawnInfo.description)
    if desc then
        ctx.AddLine(" ", 1, 1, 1)
        ctx.AddLine(ns.LocText(desc), 0.9, 1, 0.9)
    end
    ns.DressingRoom.Show(c.name, c.npc)
end
