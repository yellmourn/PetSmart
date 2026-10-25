local ADDON_NAME, ns = ...
-- Classic data: only loads on the WoW Classic Era client (see Core/Client.lua).
if not ns.IS_CLASSIC then return end

-- Per-family combat role, stat modifiers and diet for WoW Classic Era.
-- Source: Petopia Classic's family pages (wow-petopia.com/classic,
-- "Family Role", "Stat modifiers" and "Diet"). Classic families have no
-- fixed basic attack, so basicSkill is nil throughout. TIER IS NIL
-- THROUGHOUT: no verified tier list source yet.
-- Keys are the CreatureFamily IDs from FamilyData.lua.
--
-- info(familyId, spec, tier, health, armor, damage, diet, basicSkill,
--      healthQualifier, armorQualifier, dpsQualifier)

ns.FAMILY_INFO = {}
local function info(familyId, spec, tier, health, armor, damage, diet, basicSkill, healthQualifier, armorQualifier, dpsQualifier)
    ns.FAMILY_INFO[familyId] = {
        spec = spec, tier = tier,
        health = health, armor = armor, damage = damage,
        diet = diet, basicSkill = basicSkill,
        healthQualifier = healthQualifier, armorQualifier = armorQualifier, dpsQualifier = dpsQualifier,
    }
end

--        id   spec         tier  health armor damage  diet                                                       skill healthQ   armorQ    dpsQ
info(1,  "general", nil, 1.00, 1.05, 1.00, { "Meat" }, nil, "Medium", "Medium", "Medium") -- Wolf
info(2,  "offense", nil, 0.98, 1.00, 1.10, { "Fish", "Meat" }, nil, "Medium", "Low", "High") -- Cat
info(3,  "offense", nil, 1.00, 1.00, 1.07, { "Meat" }, nil, "Medium", "Low", "High") -- Spider
info(4,  "defense", nil, 1.08, 1.05, 0.91, { "Bread", "Cheese", "Fish", "Fruit", "Fungus", "Meat" }, nil, "High", "Medium", "Low") -- Bear
info(5,  "defense", nil, 1.04, 1.09, 0.90, { "Bread", "Cheese", "Fish", "Fruit", "Fungus", "Meat" }, nil, "High", "Medium", "Low") -- Boar
info(6,  "defense", nil, 0.95, 1.10, 1.00, { "Fish", "Meat" }, nil, "Low", "High", "Medium") -- Crocolisk
info(7,  "general", nil, 1.00, 1.05, 1.00, { "Fish", "Meat" }, nil, "Medium", "Medium", "Medium") -- Carrion Bird
info(8,  "defense", nil, 0.96, 1.13, 0.95, { "Bread", "Fish", "Fruit", "Fungus" }, nil, "Low", "High", "Low") -- Crab
info(9,  "defense", nil, 1.04, 1.00, 1.02, { "Fruit", "Fungus" }, nil, "High", "Low", "Medium") -- Gorilla
info(11, "offense", nil, 0.95, 1.03, 1.10, { "Meat" }, nil, "Low", "Low", "High") -- Raptor
info(12, "defense", nil, 1.05, 1.00, 1.00, { "Cheese", "Fruit", "Fungus" }, nil, "High", "Low", "Medium") -- Tallstrider
info(20, "defense", nil, 1.00, 1.10, 0.94, { "Meat" }, nil, "Medium", "High", "Low") -- Scorpid
info(21, "defense", nil, 1.00, 1.13, 0.90, { "Fish", "Fruit", "Fungus" }, nil, "Medium", "High", "Low") -- Turtle
info(24, "offense", nil, 1.00, 1.00, 1.07, { "Fruit", "Fungus" }, nil, "Medium", "Low", "High") -- Bat
info(25, "general", nil, 1.00, 1.05, 1.00, { "Fruit", "Meat" }, nil, "Medium", "Medium", "Medium") -- Hyena
info(26, "offense", nil, 1.00, 1.00, 1.07, { "Meat" }, nil, "Medium", "Low", "High") -- Owl
info(27, "offense", nil, 1.00, 1.00, 1.07, { "Bread", "Cheese", "Fish" }, nil, "Medium", "Low", "High") -- Wind Serpent
