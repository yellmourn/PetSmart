local ADDON_NAME, ns = ...
-- Classic data: only loads on the WoW Classic Era client (see Core/Client.lua).
if not ns.IS_CLASSIC then return end

-- Pet ability ranks for WoW Classic Era. Family IDs match FamilyData.lua.
-- Spell IDs are Classic's own pet-ability spell IDs (wowhead.com/classic,
-- "Pet Abilities" category). Pet level, training point cost and how each
-- rank is learned come from Petopia Classic's ability guide
-- (wow-petopia.com/classic/abilities.php); which families can learn each
-- ability from Petopia Classic's family pages. Trainer money costs are
-- Classic's pet trainer prices. Classic has four ranks of each resistance
-- (no rank 5 exists on wowhead.com/classic).
--
-- ability(key, families, displayName): families = CreatureFamily IDs
-- (nil = all); displayName is the ability's English name.
-- rank(spellId, rank, petLevel, tpCost, source, moneyCost): source "t" =
-- pet trainer, "w" = taming wild beasts, "n" = no known source.
-- moneyCost in copper.

local ability, rank = ns.NewPetAbilityDB()

ability("arcaneresistance", nil, "Arcane Resistance") -- Arcane Resistance: all families
rank(24493, 1, 20, 5, "t", 4400) -- Arcane Resistance 1
rank(24497, 2, 30, 15, "t", 16000) -- Arcane Resistance 2
rank(24500, 3, 40, 45, "t", 36000) -- Arcane Resistance 3
rank(24501, 4, 50, 90, "t", 72000) -- Arcane Resistance 4

ability("fireresistance", nil, "Fire Resistance") -- Fire Resistance: all families
rank(23992, 1, 20, 5, "t", 4400) -- Fire Resistance 1
rank(24439, 2, 30, 15, "t", 16000) -- Fire Resistance 2
rank(24444, 3, 40, 45, "t", 36000) -- Fire Resistance 3
rank(24445, 4, 50, 90, "t", 72000) -- Fire Resistance 4

ability("frostresistance", nil, "Frost Resistance") -- Frost Resistance: all families
rank(24446, 1, 20, 5, "t", 4400) -- Frost Resistance 1
rank(24447, 2, 30, 15, "t", 16000) -- Frost Resistance 2
rank(24448, 3, 40, 45, "t", 36000) -- Frost Resistance 3
rank(24449, 4, 50, 90, "t", 72000) -- Frost Resistance 4

ability("natureresistance", nil, "Nature Resistance") -- Nature Resistance: all families
rank(24492, 1, 20, 5, "t", 4400) -- Nature Resistance 1
rank(24502, 2, 30, 15, "t", 16000) -- Nature Resistance 2
rank(24503, 3, 40, 45, "t", 36000) -- Nature Resistance 3
rank(24504, 4, 50, 90, "t", 72000) -- Nature Resistance 4

ability("shadowresistance", nil, "Shadow Resistance") -- Shadow Resistance: all families
rank(24488, 1, 20, 5, "t", 4400) -- Shadow Resistance 1
rank(24505, 2, 30, 15, "t", 16000) -- Shadow Resistance 2
rank(24506, 3, 40, 45, "t", 36000) -- Shadow Resistance 3
rank(24507, 4, 50, 90, "t", 72000) -- Shadow Resistance 4

ability("greatstamina", nil, "Great Stamina") -- Great Stamina: all families
rank(4187, 1, 10, 5, "t", 100) -- Great Stamina 1
rank(4188, 2, 12, 10, "t", 1200) -- Great Stamina 2
rank(4189, 3, 18, 15, "t", 4000) -- Great Stamina 3
rank(4190, 4, 24, 25, "t", 14000) -- Great Stamina 4
rank(4191, 5, 30, 50, "t", 16000) -- Great Stamina 5
rank(4192, 6, 36, 75, "t", 28000) -- Great Stamina 6
rank(4193, 7, 42, 100, "t", 48000) -- Great Stamina 7
rank(4194, 8, 48, 125, "t", 64000) -- Great Stamina 8
rank(5041, 9, 54, 150, "t", 84000) -- Great Stamina 9
rank(5042, 10, 60, 185, "t", 100000) -- Great Stamina 10

ability("naturalarmor", nil, "Natural Armor") -- Natural Armor: all families
rank(24545, 1, 10, 1, "t", 100) -- Natural Armor 1
rank(24549, 2, 12, 5, "t", 1200) -- Natural Armor 2
rank(24550, 3, 18, 10, "t", 4000) -- Natural Armor 3
rank(24551, 4, 24, 15, "t", 14000) -- Natural Armor 4
rank(24552, 5, 30, 25, "t", 16000) -- Natural Armor 5
rank(24553, 6, 36, 50, "t", 28000) -- Natural Armor 6
rank(24554, 7, 42, 75, "t", 48000) -- Natural Armor 7
rank(24555, 8, 48, 100, "t", 64000) -- Natural Armor 8
rank(24629, 9, 54, 125, "t", 84000) -- Natural Armor 9
rank(24630, 10, 60, 150, "t", 100000) -- Natural Armor 10

ability("growl", nil, "Growl") -- Growl: all families
rank(2649, 1, 1, 0, "t", 100) -- Growl 1
rank(14916, 2, 10, 0, "t", 100) -- Growl 2
rank(14917, 3, 20, 0, "t", 4000) -- Growl 3
rank(14918, 4, 30, 0, "t", 16000) -- Growl 4
rank(14919, 5, 40, 0, "t", 36000) -- Growl 5
rank(14920, 6, 50, 0, "t", 72000) -- Growl 6
rank(14921, 7, 60, 0, "t", 100000) -- Growl 7

ability("cower", nil, "Cower") -- Cower: all families
rank(1742, 1, 5, 8, "w", 0) -- Cower 1
rank(1753, 2, 15, 10, "w", 0) -- Cower 2
rank(1754, 3, 25, 12, "w", 0) -- Cower 3
rank(1755, 4, 35, 14, "w", 0) -- Cower 4
rank(1756, 5, 45, 16, "w", 0) -- Cower 5
rank(16697, 6, 55, 18, "w", 0) -- Cower 6

ability("bite", { 1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 21, 24, 25, 27 }, "Bite") -- Bite: Bat, Bear, Boar, Carrion Bird, Cat, Crocolisk, Gorilla, Hyena, Raptor, Spider, Tallstrider, Turtle, Wind Serpent, Wolf
rank(17253, 1, 1, 1, "w", 0) -- Bite 1
rank(17255, 2, 8, 4, "w", 0) -- Bite 2
rank(17256, 3, 16, 7, "w", 0) -- Bite 3
rank(17257, 4, 24, 10, "w", 0) -- Bite 4
rank(17258, 5, 32, 13, "w", 0) -- Bite 5
rank(17259, 6, 40, 17, "w", 0) -- Bite 6
rank(17260, 7, 48, 21, "w", 0) -- Bite 7
rank(17261, 8, 56, 25, "w", 0) -- Bite 8

ability("claw", { 2, 4, 7, 8, 11, 20, 26 }, "Claw") -- Claw: Bear, Carrion Bird, Cat, Crab, Owl, Raptor, Scorpid
rank(16827, 1, 1, 1, "w", 0) -- Claw 1
rank(16828, 2, 8, 4, "w", 0) -- Claw 2
rank(16829, 3, 16, 7, "w", 0) -- Claw 3
rank(16830, 4, 24, 10, "w", 0) -- Claw 4
rank(16831, 5, 32, 13, "w", 0) -- Claw 5
rank(16832, 6, 40, 17, "w", 0) -- Claw 6
rank(3010, 7, 48, 21, "w", 0) -- Claw 7
rank(3009, 8, 56, 25, "w", 0) -- Claw 8

ability("dash", { 1, 2, 5, 12, 25 }, "Dash") -- Dash: Boar, Cat, Hyena, Tallstrider, Wolf
rank(23099, 1, 30, 15, "w", 0) -- Dash 1
rank(23109, 2, 40, 20, "w", 0) -- Dash 2
rank(23110, 3, 50, 25, "w", 0) -- Dash 3

ability("dive", { 7, 24, 26, 27 }, "Dive") -- Dive: Bat, Carrion Bird, Owl, Wind Serpent
rank(23145, 1, 30, 15, "w", 0) -- Dive 1
rank(23147, 2, 40, 20, "w", 0) -- Dive 2
rank(23148, 3, 50, 25, "w", 0) -- Dive 3

ability("screech", { 7, 24, 26 }, "Screech") -- Screech: Bat, Carrion Bird, Owl
rank(24423, 1, 8, 10, "w", 0) -- Screech 1
rank(24577, 2, 24, 15, "w", 0) -- Screech 2
rank(24578, 3, 48, 20, "w", 0) -- Screech 3
rank(24579, 4, 56, 25, "w", 0) -- Screech 4

ability("charge", { 5 }, "Charge") -- Charge: Boar
rank(7371, 1, 1, 5, "w", 0) -- Charge 1
rank(26177, 2, 12, 9, "w", 0) -- Charge 2
rank(26178, 3, 24, 13, "w", 0) -- Charge 3
rank(26179, 4, 36, 17, "n", 0) -- Charge 4
rank(26201, 5, 48, 21, "w", 0) -- Charge 5
rank(27685, 6, 60, 25, "w", 0) -- Charge 6

ability("furioushowl", { 1 }, "Furious Howl") -- Furious Howl: Wolf
rank(24604, 1, 10, 10, "w", 0) -- Furious Howl 1
rank(24605, 2, 24, 15, "w", 0) -- Furious Howl 2
rank(24603, 3, 40, 20, "w", 0) -- Furious Howl 3
rank(24597, 4, 56, 25, "w", 0) -- Furious Howl 4

ability("lightningbreath", { 27 }, "Lightning Breath") -- Lightning Breath: Wind Serpent
rank(24844, 1, 1, 1, "n", 0) -- Lightning Breath 1
rank(25008, 2, 12, 5, "w", 0) -- Lightning Breath 2
rank(25009, 3, 24, 10, "w", 0) -- Lightning Breath 3
rank(25010, 4, 36, 15, "w", 0) -- Lightning Breath 4
rank(25011, 5, 48, 20, "w", 0) -- Lightning Breath 5
rank(25012, 6, 60, 25, "w", 0) -- Lightning Breath 6

ability("prowl", { 2 }, "Prowl") -- Prowl: Cat
rank(24450, 1, 30, 15, "w", 0) -- Prowl 1
rank(24452, 2, 40, 20, "w", 0) -- Prowl 2
rank(24453, 3, 50, 25, "w", 0) -- Prowl 3

ability("scorpidpoison", { 20 }, "Scorpid Poison") -- Scorpid Poison: Scorpid
rank(24640, 1, 8, 10, "w", 0) -- Scorpid Poison 1
rank(24583, 2, 24, 15, "w", 0) -- Scorpid Poison 2
rank(24586, 3, 40, 20, "w", 0) -- Scorpid Poison 3
rank(24587, 4, 56, 25, "w", 0) -- Scorpid Poison 4

ability("shellshield", { 21 }, "Shell Shield") -- Shell Shield: Turtle
rank(26064, 1, 20, 15, "w", 0) -- Shell Shield 1

ability("thunderstomp", { 9 }, "Thunderstomp") -- Thunderstomp: Gorilla
rank(26090, 1, 30, 15, "w", 0) -- Thunderstomp 1
rank(26187, 2, 40, 20, "w", 0) -- Thunderstomp 2
rank(26188, 3, 50, 25, "w", 0) -- Thunderstomp 3
