--> Variables
local _L = _G._L

local Services
local Constants

--> Constants

---------->
local Titles

-- ============================================================
-- TITLES
-- ============================================================
--   id          unique id (never change it once players own the title)
--   text        what shows above the player's name and in chat
--   color       text colour
--   boosts      what the title gives while equipped (0.05 = +5%):
--                 luck           rarer food from plants + rarer fruits from eggs
--                 walk_speed     faster walking
--                 harvest_speed  faster harvesting
--                 coins          more coins per harvest
--                 all            adds to every boost above
--   unlock      text shown in the Titles menu for how to get it
--   achievement the achievement that gives this title (optional, for the menu)
--   starter     everyone gets it for free
--   hidden      only shown in the menu once owned (special / staff titles)
--
-- To add a title: add an entry here, then give it from an achievement reward
-- ({name = "Title", props = {id = "..."}}) or from a code / event.
-- ============================================================

Titles = {
	{
		id = "seedling", text = "🌱 Seedling", color = Color3.fromRGB(150, 230, 120),
		boosts = {coins = 0.02},
		unlock = "Everyone starts with this title.", starter = true,
	},
	{
		id = "fruit_collector", text = "🍎 Fruit Collector", color = Color3.fromRGB(255, 110, 110),
		boosts = {luck = 0.05, walk_speed = 0.05},
		unlock = "Collect 100 fruits.", achievement = "fruit_collector",
	},
	{
		id = "green_thumb", text = "🌿 Green Thumb", color = Color3.fromRGB(110, 220, 110),
		boosts = {harvest_speed = 0.08},
		unlock = "Harvest 850 crops.", achievement = "busy_bee",
	},
	{
		id = "nature_master", text = "🍃 Nature Master", color = Color3.fromRGB(90, 200, 140),
		boosts = {luck = 0.10, harvest_speed = 0.10},
		unlock = "Collect 500 fruits.", achievement = "nature_lover",
	},
	{
		id = "golden_gardener", text = "✨ Golden Gardener", color = Color3.fromRGB(255, 205, 60),
		boosts = {coins = 0.15},
		unlock = "Evolve a fruit into its Golden form.", achievement = "golden_touch",
	},
	{
		id = "legendary_explorer", text = "🧭 Legendary Explorer", color = Color3.fromRGB(255, 150, 60),
		boosts = {all = 0.15},
		unlock = "Discover 12 gardens.", achievement = "legendary_explorer",
	},
	{
		id = "fruit_master", text = "🏆 Fruit Master", color = Color3.fromRGB(255, 120, 200),
		boosts = {luck = 0.20, coins = 0.10},
		unlock = "Collect 10,000 fruits.", achievement = "fruit_master",
	},
	{
		id = "divine_keeper", text = "👑 Divine Keeper", color = Color3.fromRGB(255, 240, 170),
		boosts = {all = 0.25},
		unlock = "Evolve a fruit into its Divine form.", achievement = "divine_blessing",
	},

	{
		id = "paradise_farmer", text = "🏡 Paradise Farmer", color = Color3.fromRGB(140, 235, 120),
		boosts = {all = 0.10, coins = 0.10},
		unlock = "Complete your farm with the Paradise Gate.",
	},

	-- Special titles (given by the team, not shown until owned)
	{id = 1, text = "⚡ PRO", color = Color3.fromRGB(255, 255, 255), boosts = {}, unlock = "Special title.", hidden = true},
	{id = 2, text = "🔴 YTBER", color = Color3.fromRGB(255, 255, 255), boosts = {}, unlock = "Special title.", hidden = true},
	{id = 3, text = "♥️ FAN", color = Color3.fromRGB(255, 255, 255), boosts = {}, unlock = "Special title.", hidden = true},
}

return Titles