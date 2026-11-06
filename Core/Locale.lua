--------------------------------------------------------------------------
-- PetSmart: Core/Locale.lua
-- Translations. Every piece of PetSmart's own text is looked up through
-- ns.L, keyed by its English wording:  L["Pet Index"]. A key with no
-- translation for the player's language simply shows the English, so a
-- missing line never breaks anything.
--
-- Locales\<code>.lua files fill ns.L for one language each and stop
-- straight away on any other (see ns.NewLocale below). esMX uses the
-- esES file and enGB the English text.
--
-- Translations are a first version, not written by native speakers -
-- corrections are welcome.
--------------------------------------------------------------------------
local addonName, ns = ...

local locale = (GetLocale and GetLocale()) or "enUS"
if locale == "enGB" then locale = "enUS" end
if locale == "esMX" then locale = "esES" end
ns.LOCALE = locale

local L = setmetatable({}, {
    __index = function(_, key) return key end,
})
ns.L = L

-- Returns the translation table when `code` is the player's language,
-- otherwise nil (the calling locale file then returns without loading).
function ns.NewLocale(code)
    if code == locale then return L end
    return nil
end

--------------------------------------------------------------------------
-- Names the game itself can supply in the player's language.
--------------------------------------------------------------------------

-- English zone name -> UiMapID (WoW Classic Era / TBC Anniversary map
-- IDs), so a zone can be shown under the game's own name for it and found
-- on the map whatever language the client is in.
ns.ZONE_UIMAP = {
    ["Durotar"] = 1411, ["Mulgore"] = 1412, ["The Barrens"] = 1413,
    ["Alterac Mountains"] = 1416, ["Arathi Highlands"] = 1417, ["Badlands"] = 1418,
    ["Blasted Lands"] = 1419, ["Tirisfal Glades"] = 1420, ["Silverpine Forest"] = 1421,
    ["Western Plaguelands"] = 1422, ["Eastern Plaguelands"] = 1423, ["Hillsbrad Foothills"] = 1424,
    ["The Hinterlands"] = 1425, ["Dun Morogh"] = 1426, ["Searing Gorge"] = 1427,
    ["Burning Steppes"] = 1428, ["Elwynn Forest"] = 1429, ["Deadwind Pass"] = 1430,
    ["Duskwood"] = 1431, ["Loch Modan"] = 1432, ["Redridge Mountains"] = 1433,
    ["Stranglethorn Vale"] = 1434, ["Swamp of Sorrows"] = 1435, ["Westfall"] = 1436,
    ["Wetlands"] = 1437, ["Teldrassil"] = 1438, ["Darkshore"] = 1439, ["Ashenvale"] = 1440,
    ["Thousand Needles"] = 1441, ["Stonetalon Mountains"] = 1442, ["Desolace"] = 1443,
    ["Feralas"] = 1444, ["Dustwallow Marsh"] = 1445, ["Tanaris"] = 1446, ["Azshara"] = 1447,
    ["Felwood"] = 1448, ["Un'Goro Crater"] = 1449, ["Moonglade"] = 1450, ["Silithus"] = 1451,
    ["Winterspring"] = 1452, ["Stormwind City"] = 1453, ["Orgrimmar"] = 1454,
    ["Ironforge"] = 1455, ["Thunder Bluff"] = 1456, ["Darnassus"] = 1457, ["Undercity"] = 1458,
    -- The Burning Crusade
    ["Eversong Woods"] = 1941, ["Ghostlands"] = 1942, ["Azuremyst Isle"] = 1943,
    ["Hellfire Peninsula"] = 1944, ["Zangarmarsh"] = 1946, ["Shadowmoon Valley"] = 1948,
    ["Blade's Edge Mountains"] = 1949, ["Bloodmyst Isle"] = 1950, ["Nagrand"] = 1951,
    ["Terokkar Forest"] = 1952, ["Netherstorm"] = 1953, ["Shattrath City"] = 1955,
}

local zoneNameCache = {}
local function OneZone(name)
    if locale == "enUS" then return name end
    local cached = zoneNameCache[name]
    if cached then return cached end
    local id = ns.ZONE_UIMAP[name]
    local info = id and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    local loc = (info and info.name and info.name ~= "") and info.name or L[name]
    zoneNameCache[name] = loc
    return loc
end

-- A zone as written in the data ("Elwynn Forest", "Longshore, Westfall",
-- "Uldaman (Dungeon)", "Redridge Mountains; Westfall") in the player's
-- language: each zone and sub-zone translated, the (Dungeon)/(Raid) tag too.
function ns.LocZone(zone)
    if locale == "enUS" or type(zone) ~= "string" then return zone end
    local parts = {}
    for piece in (zone .. ";"):gmatch("%s*(.-)%s*;") do
        local base, tag = piece:match("^(.-)%s*(%(%a+%))$")
        base = base or piece
        local names = {}
        for n in (base .. ","):gmatch("%s*(.-)%s*,") do names[#names + 1] = OneZone(n) end
        local text = table.concat(names, ", ")
        if tag then text = text .. " " .. L[tag] end
        parts[#parts + 1] = text
    end
    return table.concat(parts, "; ")
end

-- A pet family's name ("Wind Serpent") in the player's language.
function ns.LocFamily(name)
    if locale == "enUS" or type(name) ~= "string" then return name end
    return L[name]
end

-- A food type ("Meat", "Fish"...) in the player's language.
function ns.LocFood(name)
    if locale == "enUS" or type(name) ~= "string" then return name end
    return L[name]
end

-- A level as written in the data ("32", "60 Elite").
function ns.LocLevel(level)
    if locale == "enUS" or type(level) ~= "string" then return level end
    return (level:gsub("Elite", L["Elite"]))
end

-- A creature's name in the player's language. The Locales\<code>.lua files
-- fill ns.CREATURE_NAMES (English name -> local name, from Wowhead's NPC
-- data for that language); any name not in it stays in English.
function ns.LocCreature(name)
    if locale == "enUS" or type(name) ~= "string" then return name end
    local names = ns.CREATURE_NAMES
    return (names and names[name]) or name
end

-- Reference text (descriptions, training info) in the player's language.
-- Translations can carry tokens that are filled in with the game's own
-- name for something, so they always match what the player sees in game:
--   {z:Elwynn Forest}      a zone            {n:Princess}   a creature
--   {s:1515:Tame Beast}    a spell by ID      {a:Tendon Rip} a pet ability
--   {f:Dragonhawk}         a pet family
function ns.LocText(text)
    if type(text) ~= "string" then return text end
    local s = L[text]
    if locale == "enUS" or not s:find("{", 1, true) then return s end
    s = s:gsub("{z:(.-)}", function(z) return ns.LocZone(z) end)
    s = s:gsub("{n:(.-)}", function(n) return ns.LocCreature(n) end)
    s = s:gsub("{f:(.-)}", function(f) return ns.LocFamily(f) end)
    s = s:gsub("{a:(.-)}", function(a) return ns.LocAbilityList(a) end)
    s = s:gsub("{s:(%d+):(.-)}", function(id, english)
        local name = GetSpellInfo and GetSpellInfo(tonumber(id))
        return (name and name ~= "") and name or english
    end)
    return s
end

-- An ability list as written in the data ("Claw 3, Pinch 1") with each
-- ability under the game's own name for it.
local abilityByEnglish
function ns.LocAbilityList(text)
    if locale == "enUS" or type(text) ~= "string" or not ns.PET_ABILITIES then return text end
    if not abilityByEnglish then
        abilityByEnglish = { ["Demoralizing Screech"] = "screech", ["Screech"] = "screech",
            ["Mine!"] = "mine", ["Trickster's Dance"] = "tricklersdance" }
        for key, entry in pairs(ns.PET_ABILITIES) do
            if entry.displayName then abilityByEnglish[entry.displayName] = key end
        end
    end
    local out = {}
    for piece in (text .. ","):gmatch("%s*(.-)%s*,") do
        local name, rank = piece:match("^(.-)%s+(%d+)$")
        local key = abilityByEnglish[name or piece]
        local entry = key and ns.PET_ABILITIES[key]
        if entry and ns.GetAbilityDisplayName then
            local loc = ns.GetAbilityDisplayName(key, entry)
            out[#out + 1] = rank and (loc .. " " .. rank) or loc
        else
            out[#out + 1] = piece
        end
    end
    return table.concat(out, ", ")
end
