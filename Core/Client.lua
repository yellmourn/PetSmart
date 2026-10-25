--------------------------------------------------------------------------
-- PetSmart: Core/Client.lua
-- Works out which game client PetSmart is running on, before anything else
-- loads. PetSmart is one addon for three clients:
--   WoW: Forever                        (interface 16xxx) - Data\Forever\*.lua
--   WoW: Classic Era                    (interface 11xxx) - Data\Classic\*.lua
--   WoW: Burning Crusade Anniversary    (interface 2xxxx) - Data\TBC\*.lua
-- Every data file in those folders starts with a check on these flags and
-- stops straight away on the other clients, so only one set of data is
-- ever built. Shared code reads ns.IS_FOREVER / ns.IS_CLASSIC / ns.IS_TBC
-- where the clients behave differently.
--------------------------------------------------------------------------
local addonName, ns = ...

local function TocVersion()
    if not GetBuildInfo then return 0 end
    local _, _, _, toc = GetBuildInfo()
    return tonumber(toc) or 0
end

-- A spell that only exists on Forever (Savage Rend, rank 1): a second check
-- in case a Forever build ever reports an unexpected interface number.
local function HasForeverSpell()
    local id = 1265065
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and name then return true end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok and name then return true end
    end
    return false
end

local toc = TocVersion()
ns.TOC_VERSION = toc
ns.IS_FOREVER = (toc >= 16000 and toc < 20000) or HasForeverSpell()
ns.IS_TBC = not ns.IS_FOREVER and toc >= 20000 and toc < 30000
ns.IS_CLASSIC = not ns.IS_FOREVER and not ns.IS_TBC
ns.CLIENT = ns.IS_FOREVER and "forever" or ns.IS_TBC and "tbc" or "classic"
ns.CLIENT_NAME = ns.IS_FOREVER and "WoW: Forever"
    or ns.IS_TBC and "WoW: Burning Crusade Anniversary"
    or "WoW: Classic"

-- One version number for both clients, from PetSmart.toc.
local function Metadata(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not get then return nil end
    local ok, value = pcall(get, addonName, field)
    return ok and value or nil
end
ns.VERSION = Metadata("Version") or "?"
