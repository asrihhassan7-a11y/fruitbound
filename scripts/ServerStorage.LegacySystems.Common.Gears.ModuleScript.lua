-- ============================================================
-- GEARS DATABASE
-- ============================================================
-- Defines all farming gears that can be purchased from the
-- Gardener NPC. Each gear has gameplay effects that improve
-- as the player's Gear Mastery for that item increases.
--
-- Gear types:
--   watering_can  - Speeds up plant regrow time
--   shears        - Increases harvest yield
--   basket        - Increases coin/str value from harvesting
--   spray         - Boosts all plant growth speed
--   premium_can   - Stronger watering can variant
-- ============================================================

local Gears = {
	{
		id = "watering_can",
		name = "Watering Can",
		description = "Speeds up plant regrow time by 20%",
		type = "watering_can",
		cost = 500,
		currency = "Strength",
		effect = { regrow_speed = 0.20 },
		icon = "🪣",
		color = Color3.fromRGB(100, 180, 255),
	},
	{
		id = "garden_shears",
		name = "Garden Shears",
		description = "Increases harvest yield by 15%",
		type = "shears",
		cost = 2500,
		currency = "Strength",
		effect = { yield_mult = 0.15 },
		icon = "✂️",
		color = Color3.fromRGB(120, 200, 120),
	},
	{
		id = "harvest_basket",
		name = "Harvest Basket",
		description = "Increases coin value from harvesting by 25%",
		type = "basket",
		cost = 10000,
		currency = "Strength",
		effect = { value_mult = 0.25 },
		icon = "🧺",
		color = Color3.fromRGB(200, 160, 100),
	},
	{
		id = "growth_spray",
		name = "Growth Spray",
		description = "Boosts all plant growth speed by 30%",
		type = "spray",
		cost = 50000,
		currency = "Strength",
		effect = { regrow_speed = 0.30, yield_mult = 0.05 },
		icon = "🍶",
		color = Color3.fromRGB(180, 255, 180),
	},
	{
		id = "golden_watering_can",
		name = "Golden Watering Can",
		description = "Speeds up regrow by 40% and +10% harvest value",
		type = "watering_can",
		cost = 500000,
		currency = "Strength",
		effect = { regrow_speed = 0.40, value_mult = 0.10 },
		icon = "🏆",
		color = Color3.fromRGB(255, 200, 70),
		premium = true,
	},
}

-- Helper: get gear info by id
local function getInfo(gearId)
	for _, gear in ipairs(Gears) do
		if gear.id == gearId then
		return gear
		end
	end
	return nil
end

Gears.getInfo = getInfo

return Gears