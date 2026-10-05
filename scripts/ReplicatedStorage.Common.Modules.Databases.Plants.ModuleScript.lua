--> Variables
local _L = _G._L

--> Constants

---------->
local Plants

-- ============================================================
-- PLANT DATABASE
-- ============================================================
-- Schema:
--   name        (string)  - Unique identifier
--   rarity      (string)  - One of the rarity tiers from Fruits.Rarities
--   image       (string)  - Roblox asset ID for the plant icon
--   exp_value   (number)  - EXP granted when fed to a Fruit
--   description(string)  - Flavor text / description
--
-- To add a new plant, simply add a new entry to this table.
-- The system will automatically pick it up.
-- ============================================================

Plants = {
	-- ======================== COMMON ========================
	{
		name = "Clover",
		rarity = "Common",
		image = "",
		exp_value = 10,
		description = "A lucky clover that gives basic EXP.",
	},
	{
		name = "Mint Leaf",
		rarity = "Common",
		image = "",
		exp_value = 15,
		description = "A fresh mint leaf packed with energy.",
	},
	{
		name = "Carrot",
		rarity = "Common",
		image = "",
		exp_value = 20,
		description = "A crunchy carrot that fruits love.",
	},
	-- Apple: harvested from the (future, regrowable) Apple Tree crop only.
	-- fixed_only = never rolled as random garden food (Harvest.plantsOfRarity skips it)
	{
		name = "Apple",
		rarity = "Common",
		image = "",
		exp_value = 20,
		fixed_only = true,
		description = "A crisp apple from your own Apple Tree.",
	},
	{
		name = "Sunflower Seed",
		rarity = "Common",
		image = "",
		exp_value = 25,
		description = "A tasty seed full of sunshine.",
	},

	-- ======================== RARE ========================
	{
		name = "Glow Mushroom",
		rarity = "Rare",
		image = "",
		exp_value = 50,
		description = "A glowing mushroom that gives decent EXP.",
	},
	{
		name = "Honey Blossom",
		rarity = "Rare",
		image = "",
		exp_value = 75,
		description = "A sweet blossom rich in energy.",
	},
	{
		name = "Aloe Leaf",
		rarity = "Rare",
		image = "",
		exp_value = 100,
		description = "A thick aloe leaf with concentrated EXP.",
	},

	-- ======================== EPIC ========================
	{
		name = "Dragon Lily",
		rarity = "Epic",
		image = "",
		exp_value = 250,
		description = "A rare fiery lily bursting with power.",
	},
	{
		name = "Star Petal",
		rarity = "Epic",
		image = "",
		exp_value = 400,
		description = "A star-shaped petal that glows with energy.",
	},
	{
		name = "Moon Flower",
		rarity = "Epic",
		image = "",
		exp_value = 600,
		description = "A mystical flower that blooms under moonlight.",
	},

	-- ======================== LEGENDARY ========================
	{
		name = "Golden Sprout",
		rarity = "Legendary",
		image = "",
		exp_value = 1000,
		description = "A legendary golden sprout with immense power.",
	},
	{
		name = "Crystal Bloom",
		rarity = "Legendary",
		image = "",
		exp_value = 1500,
		description = "A crystallized flower of legendary quality.",
	},
	{
		name = "Spirit Blossom",
		rarity = "Legendary",
		image = "",
		exp_value = 2500,
		description = "A spiritual blossom that resonates with fruits.",
	},

	-- ======================== MYTHICAL ========================
	{
		name = "Celestial Lotus",
		rarity = "Mythical",
		image = "",
		exp_value = 5000,
		description = "A heavenly lotus that grants massive EXP.",
	},
	{
		name = "Phoenix Feather Plant",
		rarity = "Mythical",
		image = "",
		exp_value = 7500,
		description = "A plant infused with phoenix energy.",
	},
	{
		name = "World Tree Leaf",
		rarity = "Mythical",
		image = "",
		exp_value = 10000,
		description = "A leaf from the mythical World Tree.",
	},

	-- ======================== HUGE ========================
	{
		name = "Cosmic Fern",
		rarity = "Huge",
		image = "",
		exp_value = 25000,
		description = "A fern born from the cosmos itself.",
	},
	{
		name = "Eternal Seed",
		rarity = "Huge",
		image = "",
		exp_value = 50000,
		description = "A seed containing eternal energy.",
	},

	-- ======================== SECRET ========================
	{
		name = "Genesis Seed",
		rarity = "Secret",
		image = "",
		exp_value = 100000,
		description = "A seed from the beginning of creation.",
	},
	{
		name = "Chaos Bloom",
		rarity = "Secret",
		image = "",
		exp_value = 250000,
		description = "A bloom of pure chaos energy.",
	},

	-- ======================== DIVINE ========================
	{
		name = "Divine Lotus",
		rarity = "Divine",
		image = "",
		exp_value = 500000,
		description = "A lotus blessed by the gods themselves.",
	},
}

return Plants