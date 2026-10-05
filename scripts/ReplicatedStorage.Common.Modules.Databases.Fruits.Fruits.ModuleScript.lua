--> Variables
local _L = _G._L

--> Constants

---------->
local Fruits

-- ============================================================
-- FRUIT DATABASE
-- ============================================================
-- Schema:
--   name        (string)  - Unique identifier
--   rarity      (string)  - One of the rarity tiers from Fruits.Rarities
--   image       (string)  - Roblox asset ID for the fruit icon (optional, used if no model)
--   model       (string)  - Name of the 3D model in ReplicatedStorage.Assets.Models.Fruits (optional)
--   boost       (number)  - Base strength boost at level 1
--   max_level   (number)  - Maximum level this fruit can reach
--   base_exp    (number)  - Base EXP needed for level 2 (scales with exp_curve)
--   exp_curve   (number)  - EXP multiplier per level (exp = base_exp * exp_curve^(level-1))
--   evolution   (string?) - Name of the fruit this evolves into (nil = no evolution)
--   can_awaken  (boolean) - Whether this fruit can be awakened at max level
--   description (string)  - Flavor text / description
--
-- To add a new fruit, simply add a new entry to this table.
-- The system will automatically pick it up.
-- ============================================================

Fruits = {
	-- ======================== COMMON ========================
	{
		name = "Flame Fruit",
		rarity = "Common",
		image = "",
		boost = 1.5,
		max_level = 50,
		base_exp = 100,
		exp_curve = 1.15,
		evolution = "Inferno Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A basic flame fruit that provides a small strength boost.",
	},
	{
		name = "Ice Fruit",
		rarity = "Common",
		image = "",
		boost = 2,
		max_level = 50,
		base_exp = 100,
		exp_curve = 1.15,
		evolution = "Glacier Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A cool ice fruit that chills the battlefield.",
	},
	{
		name = "Spark Fruit",
		rarity = "Common",
		image = "",
		boost = 2.5,
		max_level = 50,
		base_exp = 120,
		exp_curve = 1.15,
		evolution = "Lightning Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A crackling spark fruit full of electric energy.",
	},
	{
		name = "Stone Fruit",
		rarity = "Common",
		image = "",
		boost = 3,
		max_level = 50,
		base_exp = 150,
		exp_curve = 1.15,
		evolution = "Boulder Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A solid stone fruit with sturdy power.",
	},
	{
		name = "Apple",
		rarity = "Common",
		image = "",
		model = "Apple",
		boost = 0.25,
		max_level = 50,
		base_exp = 100,
		exp_curve = 1.15,
		evolution = nil,
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A fresh apple fruit with crisp, energizing power.",
	},
	{
		-- STARTER FRUIT (chosen in the starter menu, same stats as the Apple)
		name = "Strawberry",
		rarity = "Common",
		image = "",
		model = "Strawberry",
		boost = 0.25,
		max_level = 50,
		base_exp = 100,
		exp_curve = 1.15,
		evolution = nil,
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A sweet little strawberry, small but always reliable.",
	},

	-- ======================== RARE ========================
	{
		name = "Inferno Fruit",
		rarity = "Rare",
		image = "",
		boost = 5,
		max_level = 60,
		base_exp = 500,
		exp_curve = 1.18,
		evolution = "Magma Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "An evolved flame fruit burning with intense heat.",
	},
	{
		name = "Glacier Fruit",
		rarity = "Rare",
		image = "",
		boost = 7,
		max_level = 60,
		base_exp = 500,
		exp_curve = 1.18,
		evolution = "Tundra Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "An evolved ice fruit that freezes everything around it.",
	},
	{
		name = "Lightning Fruit",
		rarity = "Rare",
		image = "",
		boost = 10,
		max_level = 60,
		base_exp = 600,
		exp_curve = 1.18,
		evolution = "Thunder Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "An evolved spark fruit crackling with raw power.",
	},
	{
		name = "Boulder Fruit",
		rarity = "Rare",
		image = "",
		boost = 12,
		max_level = 60,
		base_exp = 600,
		exp_curve = 1.18,
		evolution = nil,
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "An evolved stone fruit with mountain-shaking force.",
	},
	{
		name = "Wind Fruit",
		rarity = "Rare",
		image = "",
		boost = 15,
		max_level = 60,
		base_exp = 700,
		exp_curve = 1.18,
		evolution = "Cyclone Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A swirling wind fruit that grants swift power.",
	},

	-- ======================== EPIC ========================
	{
		name = "Magma Fruit",
		rarity = "Epic",
		image = "",
		boost = 25,
		max_level = 75,
		base_exp = 2000,
		exp_curve = 1.2,
		evolution = "Volcano Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A molten magma fruit radiating immense heat.",
	},
	{
		name = "Tundra Fruit",
		rarity = "Epic",
		image = "",
		boost = 35,
		max_level = 75,
		base_exp = 2000,
		exp_curve = 1.2,
		evolution = "Absolute Zero Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A frozen tundra fruit that chills to the bone.",
	},
	{
		name = "Thunder Fruit",
		rarity = "Epic",
		image = "",
		boost = 40,
		max_level = 75,
		base_exp = 2500,
		exp_curve = 1.2,
		evolution = "Storm Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A thunderous fruit that crackles with electric fury.",
	},
	{
		name = "Dragon Fruit",
		model = "Meshy_AI_Dragon_Fruit",
		display_name = "Dragon Fruit",
		rarity = "Epic",
		image = "",
		boost = 3,
		max_level = 75,
		base_exp = 450,
		exp_curve = 1.18,
		evolution = nil,
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A dragon-infused fruit with scaly power.",
	},
	{
		name = "Phoenix Fruit",
		rarity = "Epic",
		image = "",
		boost = 80,
		max_level = 75,
		base_exp = 3500,
		exp_curve = 1.2,
		evolution = "Eternal Phoenix Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A phoenix fruit blazing with rebirth energy.",
	},
	{
		name = "Cyclone Fruit",
		rarity = "Epic",
		image = "",
		boost = 70,
		max_level = 75,
		base_exp = 3000,
		exp_curve = 1.2,
		evolution = "Tempest Fruit",
		can_awaken = false,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A cyclone fruit swirling with devastating wind power.",
	},

	-- ======================== LEGENDARY ========================
	{
		name = "Volcano Fruit",
		rarity = "Legendary",
		image = "",
		boost = 150,
		max_level = 100,
		base_exp = 10000,
		exp_curve = 1.22,
		evolution = "Eruption Fruit",
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A volcanic fruit that erupts with raw power.",
	},
	{
		name = "Absolute Zero Fruit",
		rarity = "Legendary",
		image = "",
		boost = 200,
		max_level = 100,
		base_exp = 10000,
		exp_curve = 1.22,
		evolution = "Eternal Winter Fruit",
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A fruit that brings absolute zero to everything.",
	},
	{
		name = "Storm Fruit",
		rarity = "Legendary",
		image = "",
		boost = 250,
		max_level = 100,
		base_exp = 12000,
		exp_curve = 1.22,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A storm fruit that commands the weather itself.",
	},
	{
		name = "Dragon Lord Fruit",
		rarity = "Legendary",
		image = "",
		boost = 300,
		max_level = 100,
		base_exp = 15000,
		exp_curve = 1.22,
		evolution = "Ancient Dragon Fruit",
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A dragon lord fruit of legendary might.",
	},
	{
		name = "Eternal Phoenix Fruit",
		rarity = "Legendary",
		image = "",
		boost = 400,
		max_level = 100,
		base_exp = 18000,
		exp_curve = 1.22,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "An eternal phoenix fruit of endless rebirth.",
	},
	{
		name = "Soul Fruit",
		rarity = "Legendary",
		image = "",
		boost = 500,
		max_level = 100,
		base_exp = 20000,
		exp_curve = 1.22,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A soul fruit that commands spiritual energy.",
	},

	-- ======================== MYTHICAL ========================
	{
		name = "Eruption Fruit",
		rarity = "Mythical",
		image = "",
		boost = 700,
		max_level = 120,
		base_exp = 50000,
		exp_curve = 1.25,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A mythical eruption fruit of world-ending power.",
	},
	{
		name = "Eternal Winter Fruit",
		rarity = "Mythical",
		image = "",
		boost = 900,
		max_level = 120,
		base_exp = 50000,
		exp_curve = 1.25,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A mythical fruit of eternal, unending winter.",
	},
	{
		name = "Ancient Dragon Fruit",
		rarity = "Mythical",
		image = "",
		boost = 1000,
		max_level = 120,
		base_exp = 60000,
		exp_curve = 1.25,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "An ancient dragon fruit of mythic proportions.",
	},
	{
		name = "Void Fruit",
		rarity = "Mythical",
		image = "",
		boost = 1200,
		max_level = 120,
		base_exp = 70000,
		exp_curve = 1.25,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A void fruit that consumes all light and matter.",
	},
	{
		name = "Tempest Fruit",
		rarity = "Mythical",
		image = "",
		boost = 800,
		max_level = 120,
		base_exp = 55000,
		exp_curve = 1.25,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A mythical tempest fruit of cataclysmic storms.",
	},

	-- ======================== HUGE ========================
	{
		name = "Celestial Fruit",
		rarity = "Huge",
		image = "",
		boost = 3000,
		max_level = 150,
		base_exp = 200000,
		exp_curve = 1.28,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A celestial fruit born from the stars themselves.",
	},
	{
		name = "Ancient Fruit",
		rarity = "Huge",
		image = "",
		boost = 5000,
		max_level = 150,
		base_exp = 250000,
		exp_curve = 1.28,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "An ancient fruit from a forgotten era.",
	},
	{
		name = "Primordial Fruit",
		rarity = "Huge",
		image = "",
		boost = 8000,
		max_level = 150,
		base_exp = 300000,
		exp_curve = 1.28,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A primordial fruit from the dawn of creation.",
	},

	-- ======================== SECRET ========================
	{
		name = "Reality Fruit",
		rarity = "Secret",
		image = "",
		boost = 15000,
		max_level = 200,
		base_exp = 500000,
		exp_curve = 1.3,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A secret fruit that bends reality to its will.",
	},
	{
		name = "Chaos Fruit",
		rarity = "Secret",
		image = "",
		boost = 25000,
		max_level = 200,
		base_exp = 600000,
		exp_curve = 1.3,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A secret fruit of pure, unbridled chaos.",
	},
	{
		name = "Eternal Fruit",
		rarity = "Secret",
		image = "",
		boost = 50000,
		max_level = 200,
		base_exp = 800000,
		exp_curve = 1.3,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A secret fruit of eternal, unending power.",
	},

	-- ======================== DIVINE ========================
	{
		name = "Genesis Fruit",
		rarity = "Divine",
		image = "",
		boost = 100000,
		max_level = 250,
		base_exp = 1000000,
		exp_curve = 1.35,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A divine fruit from the genesis of all creation.",
	},
	{
		name = "Apocalypse Fruit",
		rarity = "Divine",
		image = "",
		boost = 200000,
		max_level = 250,
		base_exp = 1500000,
		exp_curve = 1.35,
		evolution = nil,
		can_awaken = true,
		CanMount = false, -- true = can be used as a mount (Fruits menu > Mount)
		description = "A divine fruit heralding the end of all things.",
	},
	-- ======================== ADMIN ONLY (testing) ========================
	-- Never drops, cannot be given to or used by normal players (see AdminUtility).
	-- Admins type  !givemount  in chat to get it, then Fruits menu > Mount.
	{
		name = "Admin Test Mount",
		rarity = "Divine",
		image = "",
		model = "Apple",
		boost = 0, -- no coin boost: does not touch the economy
		max_level = 1,
		base_exp = 1,
		exp_curve = 1,
		evolution = nil,
		can_awaken = false,
		CanMount = true,
		admin_only = true,
		mount_scale = 5, -- mount height in studs
		mount_yaw = -90, -- turn the model so the fruit's face looks forward
		mount_speed = 16, -- extra walk speed while riding
		description = "ADMIN ONLY test mount.",
	},
}

-- New fruit pets staged in FruitCatalog join the game here once they're enabled + have stats
-- (duplicates of an existing name are ignored, so existing fruits/data are never touched).
do
	local ok, catalog = pcall(require, script.Parent:WaitForChild("FruitCatalog", 5))
	if ok and catalog and catalog.ready then
		local existing = {}
		for _, f in ipairs(Fruits) do
			existing[f.name] = true
		end
		for _, e in ipairs(catalog.ready()) do
			if not existing[e.name] then
				existing[e.name] = true
				table.insert(Fruits, {
					name = e.name,
					display_name = e.display_name,
					rarity = e.rarity,
					image = e.icon or "",
					icon = e.icon,
					model = e.model,
					boost = e.boost,
					max_level = e.max_level,
					base_exp = e.base_exp,
					exp_curve = e.exp_curve,
					evolution = e.evolution,
					can_awaken = e.can_awaken == true,
					CanMount = e.CanMount == true,
					base_value = e.base_value,
					description = e.description or "",
				})
			end
		end
	end
end

return Fruits