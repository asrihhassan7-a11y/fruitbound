--> Fishing (V1.1 overhaul) - shared data. The SERVER uses every number here to decide
-- casts, bites, fish, weights, values, rewards; the client only reads it to draw menus.
-- ids are saved in player data (data.fishing) - never rename an id.
-- ============================================================

local Fishing = {}

-- ------------------------------------------------------------ rarity
Fishing.RARITIES = {
	-- weight: base chance weight of every fish of that rarity; xp per catch; difficulty of the reel
	-- window: seconds to react to the BITE (server adds REACTION_EXTRA for lag)
	Common = {order = 1, weight = 100, xp = 10, difficulty = 1, window = 1.25, color = Color3.fromRGB(190, 190, 190)},
	Uncommon = {order = 2, weight = 38, xp = 20, difficulty = 2, window = 1.1, color = Color3.fromRGB(110, 210, 110)},
	Rare = {order = 3, weight = 11, xp = 45, difficulty = 3, window = 0.95, color = Color3.fromRGB(80, 160, 255)},
	Epic = {order = 4, weight = 3.2, xp = 90, difficulty = 4, window = 0.85, color = Color3.fromRGB(180, 100, 255)},
	Legendary = {order = 5, weight = 0.7, xp = 200, difficulty = 5, window = 0.8, color = Color3.fromRGB(255, 190, 50)},
	Mythic = {order = 6, weight = 0.08, xp = 500, difficulty = 6, window = 0.75, color = Color3.fromRGB(255, 80, 150)},
}

Fishing.BITE_DELAY = {4, 9} -- seconds after a valid cast (x rod bite speed, x0.85 with a liked bait)
Fishing.REACTION_EXTRA = 0.35 -- lag allowance on the bite window (server)
Fishing.RECAST_COOLDOWN = 1.5
Fishing.BAG_SIZE = 20
Fishing.BAG_SIZE_BIG = 30 -- from Fishing Level 12
Fishing.MAX_LEVEL = 20
Fishing.NPC_DISTANCE = 22 -- shop / sell / claim actions only at the Fishing NPC
Fishing.STARTER_WORMS = 5 -- given once with the free Starter Rod

-- XP needed to go from level L to L+1
function Fishing.xpForLevel(level)
	return math.floor(35 * level ^ 1.35) -- Lv 5 ~500 XP, Lv 10 ~2,950, Lv 20 ~16,000 in total
end

-- ------------------------------------------------------------ baits
-- like = multiplier a fish gets when it LIKES this bait (preferred 3, neutral 1, disliked 0.3)
Fishing.BAITS = {
	{id = "none", name = "No Bait", icon = "🎣", desc = "Free. Only basic fish bite."},
	{id = "worm", name = "Worm", icon = "🪱", desc = "Starter bait. River fish love it."},
	{id = "berry", name = "Berry Bait", icon = "🫐", desc = "Sweet bait for Koi and better freshwater fish."},
	{id = "glow", name = "Glow Bait", icon = "✨", desc = "Glows in the dark. Night and deep-water fish."},
	{id = "golden", name = "Golden Bait", icon = "🌟", desc = "Shiny bait for high-value catches."},
	{id = "mystic", name = "Mystic Bait", icon = "🔮", desc = "Needed for the rarest Mystic Pool species."},
}
Fishing.LIKE = {preferred = 3, neutral = 1, disliked = 0.3}

-- bait shop (Coins), unlocked by Fishing Level. Golden / Mystic are never sold.
Fishing.BAIT_SHOP = {
	{bait = "worm", count = 10, price = 100, level = 1},
	{bait = "berry", count = 5, price = 150, level = 3},
	{bait = "glow", count = 3, price = 180, level = 8},
}

-- ------------------------------------------------------------ materials + crafting
Fishing.MATERIALS = {
	{id = "river_scale", name = "River Scale", icon = "🐟"},
	{id = "pearl", name = "Pearl", icon = "⚪"},
	{id = "ancient_scale", name = "Ancient Scale", icon = "🦴"},
	{id = "mystic_scale", name = "Mystic Scale", icon = "💠"},
}
Fishing.RECIPES = {
	{id = "glow", name = "2 Glow Bait", gives = {bait = "glow", count = 2}, cost = {river_scale = 3}},
	{id = "golden", name = "1 Golden Bait", gives = {bait = "golden", count = 1}, cost = {pearl = 1}, coins = 1500},
	{id = "mystic", name = "1 Mystic Bait", gives = {bait = "mystic", count = 1}, cost = {mystic_scale = 2, pearl = 1}},
}

-- ------------------------------------------------------------ rods
-- zone = catch zone size in the reel bar, lift = how hard holding pulls up, stability = slower
-- escape when the fish is outside, bite = bite delay multiplier, max = hardest fish it can hook,
-- cast = cast distance (studs). Better rods = control and access, never more Legendaries.
Fishing.RODS = {
	{id = "starter", name = "Starter Rod", rank = 1, price = 0, level = 1, zone = 0.24, lift = 3.2, stability = 1, bite = 1, max = 3, cast = 16,
		color = Color3.fromRGB(150, 100, 60), accent = Color3.fromRGB(220, 220, 220), material = Enum.Material.Wood},
	{id = "river", name = "River Rod", rank = 2, price = 5000, level = 5, zone = 0.27, lift = 3.4, stability = 1.15, bite = 0.9, max = 4, cast = 19,
		color = Color3.fromRGB(70, 120, 190), accent = Color3.fromRGB(120, 220, 255), material = Enum.Material.SmoothPlastic},
	{id = "expert", name = "Expert Rod", rank = 3, price = 40000, level = 10, materials = {river_scale = 5}, zone = 0.3, lift = 3.6, stability = 1.3, bite = 0.82, max = 5, cast = 22,
		color = Color3.fromRGB(60, 60, 70), accent = Color3.fromRGB(255, 200, 60), material = Enum.Material.Metal},
	{id = "mystic", name = "Mystic Rod", rank = 4, price = 200000, level = 15, materials = {ancient_scale = 3, pearl = 1}, zone = 0.33, lift = 3.8, stability = 1.45, bite = 0.75, max = 6, cast = 25,
		color = Color3.fromRGB(90, 50, 140), accent = Color3.fromRGB(200, 150, 255), material = Enum.Material.SmoothPlastic, neon = true},
}

-- ------------------------------------------------------------ zones
-- Zone parts in Workspace.__MAP.V11World.FishingZones carry ZoneId = one of these.
Fishing.ZONES = {
	{id = "river", name = "Starter River", rod = 1, desc = "South river by Fisher Finn. Easy fish."},
	{id = "deep", name = "Deep River", rod = 2, desc = "North river by the island dock. Needs a River Rod."},
	{id = "mystic", name = "Mystic Pool", rod = 3, desc = "Inside the Mystic Glade stones. Needs an Expert Rod."},
}

-- ------------------------------------------------------------ fish
-- zones: where it lives; w = {min, max} kg; value = base Coins (x0.7..1.3 by weight);
-- likes = {bait = "preferred"|"neutral"|"disliked"} (missing = neutral; "none" = no bait);
-- needs = required bait; time = "day"/"night"; rain = chance multiplier while it rains;
-- nobait = can bite without bait; drop = {material, chance}; secret = hidden in the Journal
Fishing.FISH = {
	-- Starter River
	{id = "bass", name = "Bass", rarity = "Common", zones = {"river"}, w = {1.2, 4.5}, value = 22, nobait = true,
		likes = {worm = "preferred", glow = "disliked"}, drop = {"river_scale", 0.08}, desc = "A sturdy river fish. Loves worms."},
	{id = "carp", name = "Carp", rarity = "Common", zones = {"river", "deep"}, w = {1.5, 6}, value = 24, nobait = true,
		likes = {berry = "preferred", worm = "neutral"}, drop = {"river_scale", 0.08}, desc = "Lazy and round. Nibbles on berries."},
	{id = "bluegill", name = "Bluegill", rarity = "Common", zones = {"river"}, w = {0.3, 1.2}, value = 18, nobait = true, time = "day",
		likes = {worm = "preferred", berry = "neutral"}, desc = "A small sunny-day fish."},
	{id = "small_catfish", name = "Small Catfish", rarity = "Common", zones = {"river", "deep"}, w = {0.8, 3}, value = 20, nobait = true,
		likes = {worm = "preferred", glow = "neutral"}, drop = {"river_scale", 0.08}, desc = "Whiskers! Bites more at night.", nightBoost = 2},
	{id = "trout", name = "Trout", rarity = "Uncommon", zones = {"river", "deep"}, w = {1, 4}, value = 85,
		likes = {worm = "preferred", berry = "preferred", glow = "disliked"}, drop = {"river_scale", 0.12}, desc = "Quick and shiny."},
	{id = "perch", name = "Perch", rarity = "Uncommon", zones = {"river"}, w = {0.6, 2.4}, value = 80,
		likes = {worm = "preferred"}, drop = {"river_scale", 0.12}, desc = "Striped and hungry."},
	{id = "melon_puffer", name = "Melon Puffer", rarity = "Uncommon", zones = {"river"}, w = {0.8, 3.5}, value = 80,
		likes = {berry = "preferred", worm = "disliked"}, desc = "Puffs up like a little watermelon."},
	{id = "golden_koi", name = "Golden Koi", rarity = "Rare", zones = {"river"}, w = {3, 9}, value = 230, time = "day",
		likes = {berry = "preferred", golden = "preferred", worm = "disliked"}, drop = {"pearl", 0.1}, desc = "Gleams in the afternoon sun."},
	-- Deep River
	{id = "river_eel", name = "River Eel", rarity = "Uncommon", zones = {"deep"}, w = {1, 5}, value = 85, nightBoost = 2,
		likes = {glow = "preferred", worm = "neutral", berry = "disliked"}, drop = {"river_scale", 0.15}, desc = "Slippery. Most active at night."},
	{id = "rainbow_trout", name = "Rainbow Trout", rarity = "Rare", zones = {"deep"}, w = {2, 7}, value = 230, rain = 3,
		likes = {berry = "preferred", golden = "neutral", glow = "disliked"}, drop = {"river_scale", 0.2}, desc = "Shows up when it rains."},
	{id = "crystal_catfish", name = "Crystal Catfish", rarity = "Rare", zones = {"deep", "mystic"}, w = {3, 10}, value = 230,
		likes = {glow = "preferred", worm = "disliked"}, drop = {"river_scale", 0.2}, desc = "Its whiskers sparkle like ice."},
	{id = "pineapple_pike", name = "Pineapple Pike", rarity = "Rare", zones = {"deep"}, w = {2.5, 8}, value = 235,
		likes = {golden = "preferred", berry = "neutral", worm = "disliked"}, drop = {"pearl", 0.08}, desc = "Spiky scales, sweet temper."},
	{id = "moonfish", name = "Moonfish", rarity = "Epic", zones = {"deep", "mystic"}, w = {4, 12}, value = 620, time = "night",
		likes = {glow = "preferred", golden = "neutral"}, drop = {"pearl", 0.2}, desc = "Only rises under the moon."},
	{id = "emerald_koi", name = "Emerald Koi", rarity = "Epic", zones = {"deep", "mystic"}, w = {5, 14}, value = 620,
		likes = {golden = "preferred", berry = "preferred", glow = "disliked"}, drop = {"pearl", 0.2}, desc = "A jewel of the deep river."},
	{id = "ancient_eel", name = "Ancient Eel", rarity = "Epic", zones = {"deep"}, w = {6, 18}, value = 620, time = "night",
		likes = {glow = "preferred", golden = "neutral"}, drop = {"ancient_scale", 0.35}, desc = "Older than the village itself."},
	{id = "river_dragonfish", name = "River Dragonfish", rarity = "Legendary", zones = {"deep"}, w = {10, 30}, value = 2000,
		likes = {golden = "preferred", glow = "neutral"}, drop = {"ancient_scale", 0.6}, desc = "Breathes bubbles shaped like flames."},
	-- Mystic Pool (two small fish keep the pool from paying more than farming)
	{id = "glimmer_minnow", name = "Glimmer Minnow", rarity = "Common", zones = {"mystic"}, w = {0.2, 0.8}, value = 30, nobait = true,
		likes = {mystic = "disliked", glow = "neutral"}, desc = "Tiny sparkles that dart around the stones."},
	{id = "starlit_tadpole", name = "Starlit Tadpole", rarity = "Uncommon", zones = {"mystic"}, w = {0.3, 1.2}, value = 85,
		likes = {glow = "preferred", mystic = "disliked"}, desc = "Its tail leaves a trail of tiny stars."},
	{id = "celestial_koi", name = "Celestial Koi", rarity = "Legendary", zones = {"mystic"}, w = {8, 20}, value = 2000, needs = "mystic", boost = 4,
		likes = {mystic = "preferred"}, drop = {"mystic_scale", 0.6}, desc = "Its scales hold tiny stars."},
	{id = "starfruit_sovereign", name = "Starfruit Sovereign", rarity = "Mythic", zones = {"mystic"}, w = {15, 40}, value = 7500, needs = "mystic", time = "night", secret = true,
		likes = {mystic = "preferred"}, drop = {"mystic_scale", 1}, desc = "The legend of the Mystic Pool. Few have seen it."},
}
-- Mystic Pool also yields Mystic Scales from its fish
Fishing.ZONE_DROPS = {mystic = {"mystic_scale", 0.25}}

-- ------------------------------------------------------------ treasure
-- caught like a fish (bite + reel); rewards are rolled by the server when caught
Fishing.TREASURES = {
	-- share = part of all bites (the same everywhere, whatever fish live there)
	{id = "treasure_bag", name = "Sunken Bag", rarity = "Uncommon", share = 0.01, difficulty = 2}, -- 1 in 100 bites with bait (x0.3 without)
	{id = "treasure_chest", name = "Treasure Chest", rarity = "Epic", share = 0.001, difficulty = 4, chest = true}, -- 1 in 1000 (x2 Golden Bait), River Rod+
}
-- Sunken Bag: one of these (weights)
Fishing.BAG_LOOT = {
	{weight = 40, coins = {150, 400}},
	{weight = 25, bait = "worm", count = 5},
	{weight = 15, bait = "berry", count = 3},
	{weight = 12, material = "river_scale", count = 2},
	{weight = 6, seedpack = "flower"},
	{weight = 2, material = "pearl", count = 1},
}
-- Treasure Chest: everything below (rolled); golden bait doubles chest weight
Fishing.CHEST = {coins = {1500, 3000}, gems = {10, 25}, extra = {
	{weight = 45, material = "pearl", count = 1},
	{weight = 35, bait = "golden", count = 1},
	{weight = 15, bait = "glow", count = 3},
	{weight = 5, cosmetic = "treasure_bobber"},
}}

-- ------------------------------------------------------------ daily quests (3 per day)
Fishing.QUESTS = {
	{id = "catch5", text = "Catch 5 fish", stat = "catch", goal = 5, reward = {coins = 300, bait = "worm", count = 5}},
	{id = "catch12", text = "Catch 12 fish", stat = "catch", goal = 12, reward = {coins = 800, bait = "berry", count = 3}},
	{id = "rare2", text = "Catch 2 Rare or better fish", stat = "rare", goal = 2, reward = {gems = 5, bait = "glow", count = 2}},
	{id = "heavy5", text = "Catch a fish over 5 kg", stat = "heavy", goal = 1, reward = {coins = 500, bait = "berry", count = 3}},
	{id = "bait3", text = "Use 3 Baits", stat = "bait", goal = 3, reward = {bait = "worm", count = 5, xp = 40}},
	{id = "night1", text = "Catch a fish at night", stat = "night", goal = 1, reward = {bait = "glow", count = 2}},
	{id = "perfect1", text = "Get a Perfect Catch", stat = "perfect", goal = 1, reward = {gems = 3, bait = "berry", count = 3}},
	{id = "sell10", text = "Sell 10 fish", stat = "sell", goal = 10, reward = {coins = 600}},
}

-- ------------------------------------------------------------ cosmetics
Fishing.COSMETICS = {
	{id = "classic_bobber", slot = "bobber", name = "Classic Bobber", color = Color3.fromRGB(235, 70, 60), free = true},
	{id = "duck_bobber", slot = "bobber", name = "Duck Bobber", color = Color3.fromRGB(255, 220, 60), price = 2000, level = 4},
	{id = "lantern_bobber", slot = "bobber", name = "Lantern Bobber", color = Color3.fromRGB(255, 190, 90), neon = true, price = 8000, catches = 25},
	{id = "golden_bobber", slot = "bobber", name = "Golden Bobber", color = Color3.fromRGB(255, 200, 40), neon = true, source = "River Collection"},
	{id = "starlight_bobber", slot = "bobber", name = "Starlight Bobber", color = Color3.fromRGB(170, 140, 255), neon = true, source = "Mystic Collection"},
	{id = "treasure_bobber", slot = "bobber", name = "Treasure Bobber", color = Color3.fromRGB(230, 170, 60), neon = true, source = "Treasure Chest (rare)"},
	{id = "default_skin", slot = "skin", name = "Rod's own look", free = true},
	{id = "sakura_skin", slot = "skin", name = "Sakura Rod Skin", color = Color3.fromRGB(255, 170, 200), price = 15000, level = 8},
	{id = "coral_skin", slot = "skin", name = "Coral Rod Skin", color = Color3.fromRGB(255, 120, 90), source = "Deep River Collection"},
	{id = "rainbow_skin", slot = "skin", name = "Rainbow Rod Skin", color = Color3.fromRGB(255, 255, 255), rainbow = true, source = "Complete Journal"},
}

-- ------------------------------------------------------------ collections (Journal rewards, once each)
-- need = "species" (any N species) | "rarity" (all of a rarity) | "zone" (all of a zone) | "all"
Fishing.COLLECTIONS = {
	{id = "first5", name = "First Five", text = "Catch 5 different species", need = "species", count = 5, reward = {coins = 2000, bait = "worm", count = 10}},
	{id = "commons", name = "Common Collector", text = "Catch every Common fish", need = "rarity", rarity = "Common", reward = {bait = "berry", count = 10}},
	{id = "river", name = "River Collection", text = "Catch every Starter River fish", need = "zone", zone = "river", reward = {gems = 50, bait = "glow", count = 5, cosmetic = "golden_bobber"}},
	{id = "deep", name = "Deep River Collection", text = "Catch every Deep River fish", need = "zone", zone = "deep", reward = {gems = 100, bait = "golden", count = 3, cosmetic = "coral_skin"}},
	{id = "mystic", name = "Mystic Collection", text = "Catch every Mystic Pool fish", need = "zone", zone = "mystic", reward = {gems = 150, bait = "mystic", count = 3, cosmetic = "starlight_bobber"}},
	{id = "all", name = "Master Angler", text = "Complete the whole Journal", need = "all", reward = {gems = 100, cosmetic = "rainbow_skin"}},
}

-- ------------------------------------------------------------ lookups
local byId = {}
for _, list in ipairs({Fishing.FISH, Fishing.TREASURES, Fishing.BAITS, Fishing.RODS, Fishing.ZONES, Fishing.MATERIALS, Fishing.COSMETICS, Fishing.QUESTS, Fishing.COLLECTIONS, Fishing.RECIPES}) do
	byId[list] = {}
	for _, e in ipairs(list) do
		byId[list][e.id] = e
	end
end
function Fishing.get(list, id)
	return byId[list] and byId[list][id]
end
function Fishing.fish(id) return byId[Fishing.FISH][id] or byId[Fishing.TREASURES][id] end
function Fishing.bait(id) return byId[Fishing.BAITS][id] end
function Fishing.rod(id) return byId[Fishing.RODS][id] end
function Fishing.zone(id) return byId[Fishing.ZONES][id] end
function Fishing.material(id) return byId[Fishing.MATERIALS][id] end
function Fishing.cosmetic(id) return byId[Fishing.COSMETICS][id] end
function Fishing.quest(id) return byId[Fishing.QUESTS][id] end
function Fishing.collection(id) return byId[Fishing.COLLECTIONS][id] end
function Fishing.recipe(id) return byId[Fishing.RECIPES][id] end

return Fishing
