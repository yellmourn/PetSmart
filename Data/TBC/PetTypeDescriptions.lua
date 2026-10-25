local ADDON_NAME, ns = ...
-- TBC data: only loads on the WoW: Burning Crusade Anniversary client
-- (see Core/Client.lua).
if not ns.IS_TBC then return end

-- General flavor descriptions for the Pet Index panel. HAND-WRITTEN
-- short summaries informed by Wowhead's Classic hunter pets guide
-- (wowhead.com/classic/guide/classic-wow-hunter-pets) and Petopia's
-- per-family pages, for the WoW: Burning Crusade Anniversary families.
--
-- Keys are the CreatureFamily IDs from FamilyData.lua.

ns.PET_TYPE_DESCRIPTIONS = {
    [1]  = "A loyal, versatile pack hunter at home in nearly any fight.",
    [2]  = "A swift, agile predator that relies on speed and stealth.",
    [3]  = "A venomous ambusher that lies in wait for its prey.",
    [4]  = "A thick-hided brawler that shrugs off punishment.",
    [5]  = "A tusked omnivore willing to eat almost anything.",
    [6]  = "An ambush predator that lurks at the water's edge.",
    [7]  = "A scavenging flier that picks apart weakened prey.",
    [8]  = "A heavily armored crustacean built like a walking fortress.",
    [9]  = "A powerful, territorial brawler known for its ground-shaking slam.",
    [11] = "A fast, vicious hunter that tears into prey with claw and fang.",
    [12] = "A flightless ground bird with a surprisingly sturdy frame.",
    [20] = "An armored arachnid whose sting wears down its prey.",
    [21] = "A heavily-shelled reptile built to absorb punishment.",
    [24] = "A nimble night flier that screeches and dives at its prey.",
    [25] = "A scrappy, fast-moving pack hunter.",
    [26] = "A silent, sharp-eyed hunter that swoops on prey from above.",
    [27] = "An elemental serpent that breathes crackling lightning.",
    [30] = "A fiery winged hunter that breathes flame over everything in front of it.",
    [31] = "A spiny Outland predator that gores and tears into its prey.",
    [32] = "A blinking Outland stalker that warps straight to its target.",
    [33] = "A drifting creature of the fungal forests of Zangarmarsh.",
    [34] = "A gliding ray from the skies of Outland, hardy but lightly armored.",
    [35] = "A coiled snake that spits poison at its prey.",
}
