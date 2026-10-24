local ADDON_NAME, ns = ...

-- Rank-1 description of each family-only ability, shown as the family's
-- specialty on Pet Index pages, and per-rank tooltip text for every rank.
-- Source: Petopia Classic's ability guide (wow-petopia.com/classic/
-- abilities.php). Keys match Data\PetAbilitiesData.lua.

ns.PET_ABILITY_DESCRIPTIONS = {
    charge = "Charges an enemy, immobilizes it for 1 sec, and adds 50 melee attack power to the boar's next attack.",
    furioushowl = "Party members within 15 yards receive an extra 9 to 11 damage to their next physical attack. Lasts 10 seconds.",
    lightningbreath = "Breathes lightning, instantly dealing 11 to 13 Nature damage to a single target.",
    prowl = "Puts your pet in stealth mode, but slows its movement speed by 50%. The first attack from stealth receives a 20% bonus to damage. Lasts until cancelled.",
    scorpidpoison = "Inflicts 10 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.",
    shellshield = "Reduces all damage your pet takes by 50%, but increases the time between your pet's attacks by 43%. Lasts 12 sec.",
    thunderstomp = "Shakes the ground with thundering force, doing 67 to 77 Nature damage to all enemies within 8 yards.",
}

ns.PET_ABILITY_RANK_TOOLTIPS = {
    -- Arcane Resistance
    [24493] = "Increases Arcane Resistance by 30.",
    [24497] = "Increases Arcane Resistance by 60.",
    [24500] = "Increases Arcane Resistance by 90.",
    [24501] = "Increases Arcane Resistance by 120.",
    -- Fire Resistance
    [23992] = "Increases Fire Resistance by 30.",
    [24439] = "Increases Fire Resistance by 60.",
    [24444] = "Increases Fire Resistance by 90.",
    [24445] = "Increases Fire Resistance by 120.",
    -- Frost Resistance
    [24446] = "Increases Frost Resistance by 30.",
    [24447] = "Increases Frost Resistance by 60.",
    [24448] = "Increases Frost Resistance by 90.",
    [24449] = "Increases Frost Resistance by 120.",
    -- Nature Resistance
    [24492] = "Increases Nature Resistance by 30.",
    [24502] = "Increases Nature Resistance by 60.",
    [24503] = "Increases Nature Resistance by 90.",
    [24504] = "Increases Nature Resistance by 120.",
    -- Shadow Resistance
    [24488] = "Increases Shadow Resistance by 30.",
    [24505] = "Increases Shadow Resistance by 60.",
    [24506] = "Increases Shadow Resistance by 90.",
    [24507] = "Increases Shadow Resistance by 120.",
    -- Great Stamina
    [4187] = "Increases Stamina by 3.",
    [4188] = "Increases Stamina by 5.",
    [4189] = "Increases Stamina by 7.",
    [4190] = "Increases Stamina by 10.",
    [4191] = "Increases Stamina by 13.",
    [4192] = "Increases Stamina by 17.",
    [4193] = "Increases Stamina by 21.",
    [4194] = "Increases Stamina by 26.",
    [5041] = "Increases Stamina by 32.",
    [5042] = "Increases Stamina by 40.",
    -- Natural Armor
    [24545] = "Increases Armor by 50.",
    [24549] = "Increases Armor by 100.",
    [24550] = "Increases Armor by 160.",
    [24551] = "Increases Armor by 240.",
    [24552] = "Increases Armor by 330.",
    [24553] = "Increases Armor by 430.",
    [24554] = "Increases Armor by 550.",
    [24555] = "Increases Armor by 675.",
    [24629] = "Increases Armor by 810.",
    [24630] = "Increases Armor by 1000.",
    -- Growl
    [2649] = "Taunt the target, generating 50 threat and increasing the likelyhood the creature will focus attacks on your pet.",
    [14916] = "Taunt the target, generating 65 threat and increasing the likelyhood the creature will focus attacks on your pet.",
    [14917] = "Taunt the target, generating 110 threat and increasing the likelyhood the creature will focus attacks on your pet.",
    [14918] = "Taunt the target, generating 170 threat and increasing the likelyhood the creature will focus attacks on your pet.",
    [14919] = "Taunt the target, generating 240 threat and increasing the likelyhood the creature will focus attacks on your pet.",
    [14920] = "Taunt the target, generating 320 threat and increasing the likelyhood the creature will focus attacks on your pet.",
    [14921] = "Taunt the target, generating 415 threat and increasing the likelyhood the creature will focus attacks on your pet.",
    -- Cower
    [1742] = "Cower, causing no damage but lowering your pet's threat by 30, making the enemy less likely to attack your pet.",
    [1753] = "Cower, causing no damage but lowering your pet's threat by 55, making the enemy less likely to attack your pet.",
    [1754] = "Cower, causing no damage but lowering your pet's threat by 85, making the enemy less likely to attack your pet.",
    [1755] = "Cower, causing no damage but lowering your pet's threat by 125, making the enemy less likely to attack your pet.",
    [1756] = "Cower, causing no damage but lowering your pet's threat by 175, making the enemy less likely to attack your pet.",
    [16697] = "Cower, causing no damage but lowering your pet's threat by 225, making the enemy less likely to attack your pet.",
    -- Bite
    [17253] = "Bite the enemy, causing 7 to 9 damage.",
    [17255] = "Bite the enemy, causing 16 to 18 damage.",
    [17256] = "Bite the enemy, causing 24 to 28 damage.",
    [17257] = "Bite the enemy, causing 31 to 37 damage.",
    [17258] = "Bite the enemy, causing 40 to 48 damage.",
    [17259] = "Bite the enemy, causing 49 to 59 damage.",
    [17260] = "Bite the enemy, causing 66 to 80 damage.",
    [17261] = "Bite the enemy, causing 81 to 99 damage.",
    -- Claw
    [16827] = "Claw the enemy, causing 4 to 6 damage.",
    [16828] = "Claw the enemy, causing 8 to 12 damage.",
    [16829] = "Claw the enemy, causing 12 to 16 damage.",
    [16830] = "Claw the enemy, causing 16 to 22 damage.",
    [16831] = "Claw the enemy, causing 21 to 29 damage.",
    [16832] = "Claw the enemy, causing 26 to 36 damage.",
    [3010] = "Claw the enemy, causing 35 to 49 damage.",
    [3009] = "Claw the enemy, causing 43 to 59 damage.",
    -- Dash
    [23099] = "Increases movement speed by 40% for 15 seconds.",
    [23109] = "Increases movement speed by 60% for 15 seconds.",
    [23110] = "Increases movement speed by 80% for 15 seconds.",
    -- Dive
    [23145] = "Increases movement speed by 40% for 15 seconds.",
    [23147] = "Increases movement speed by 60% for 15 seconds.",
    [23148] = "Increases movement speed by 80% for 15 seconds.",
    -- Screech
    [24423] = "Blasts a single enemy for 7 to 9 damage and lowers the melee attack power of all enemies in melee range by 25. Effect lasts 4 sec.",
    [24577] = "Blasts a single enemy for 12 to 16 damage and lowers the melee attack power of all enemies in melee range by 50. Effect lasts 4 sec.",
    [24578] = "Blasts a single enemy for 19 to 25 damage and lowers the melee attack power of all enemies in melee range by 75. Effect lasts 4 sec.",
    [24579] = "Blasts a single enemy for 26 to 46 damage and lowers the melee attack power of all enemies in melee range by 100. Effect lasts 4 sec.",
    -- Charge
    [7371] = "Charges an enemy, immobilizes it for 1 sec, and adds 50 melee attack power to the boar's next attack.",
    [26177] = "Charges an enemy, immobilizes it for 1 sec, and adds 100 melee attack power to the boar's next attack.",
    [26178] = "Charges an enemy, immobilizes it for 1 sec, and adds 180 melee attack power to the boar's next attack.",
    [26179] = "Charges an enemy, immobilizes it for 1 sec, and adds 250 melee attack power to the boar's next attack.",
    [26201] = "Charges an enemy, immobilizes it for 1 sec, and adds 390 melee attack power to the boar's next attack.",
    [27685] = "Charges an enemy, immobilizes it for 1 sec, and adds 550 melee attack power to the boar's next attack.",
    -- Furious Howl
    [24604] = "Party members within 15 yards receive an extra 9 to 11 damage to their next physical attack. Lasts 10 seconds.",
    [24605] = "Party members within 15 yards receive an extra 18 to 22 damage to their next physical attack. Lasts 10 seconds.",
    [24603] = "Party members within 15 yards receive an extra 28 to 34 damage to their next physical attack. Lasts 10 seconds.",
    [24597] = "Party members within 15 yards receive an extra 45 to 57 damage to their next physical attack. Lasts 10 seconds.",
    -- Lightning Breath
    [24844] = "Breathes lightning, instantly dealing 11 to 13 Nature damage to a single target.",
    [25008] = "Breathes lightning, instantly dealing 21 to 23 Nature damage to a single target.",
    [25009] = "Breathes lightning, instantly dealing 36 to 40 Nature damage to a single target.",
    [25010] = "Breathes lightning, instantly dealing 51 to 59 Nature damage to a single target.",
    [25011] = "Breathes lightning, instantly dealing 78 to 90 Nature damage to a single target.",
    [25012] = "Breathes lightning, instantly dealing 99 to 113 Nature damage to a single target.",
    -- Prowl
    [24450] = "Puts your pet in stealth mode, but slows its movement speed by 50%. The first attack from stealth receives a 20% bonus to damage. Lasts until cancelled.",
    [24452] = "Puts your pet in stealth mode, but slows its movement speed by 45%. The first attack from stealth receives a 35% bonus to damage. Lasts until cancelled.",
    [24453] = "Puts your pet in stealth mode, but slows its movement speed by 40%. The first attack from stealth receives a 50% bonus to damage. Lasts until cancelled.",
    -- Scorpid Poison
    [24640] = "Inflicts 10 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.",
    [24583] = "Inflicts 15 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.",
    [24586] = "Inflicts 30 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.",
    [24587] = "Inflicts 40 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.",
    -- Shell Shield
    [26064] = "Reduces all damage your pet takes by 50%, but increases the time between your pet's attacks by 43%. Lasts 12 sec.",
    -- Thunderstomp
    [26090] = "Shakes the ground with thundering force, doing 67 to 77 Nature damage to all enemies within 8 yards.",
    [26187] = "Shakes the ground with thundering force, doing 87 to 99 Nature damage to all enemies within 8 yards.",
    [26188] = "Shakes the ground with thundering force, doing 115 to 133 Nature damage to all enemies within 8 yards.",
}
