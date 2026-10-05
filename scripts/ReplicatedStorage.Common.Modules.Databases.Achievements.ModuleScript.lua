--> Achievements database
-- ============================================================
--   id           unique id (never change it once players claimed it)
--   name / icon / description   shown in the Achievements menu
--   progress     which counter to watch (see Utilities.ProgressUtility):
--                  fruits, harvests, food, gardens, rebirths, stage, coins_earned
--   goal         the number to reach
--   reward_text  short text shown in the menu
--   rewards      what the player gets when they press Claim. Types:
--                  {name = "Stat",  props = {name = "Strength", value = 500}}   -- Coins ("Strength" = Coins)
--                  {name = "Stat",  props = {name = "Gems", value = 100}}
--                  {name = "Boost", props = {name = "Lucky_Potion", value = 1}}
--                  {name = "Plant", props = {name = "Golden Sprout", value = 3}} -- special food
--                  {name = "Title", props = {id = "fruit_collector"}}
--
-- To add an achievement: copy an entry and change it. It shows up in the menu automatically.
-- ============================================================

local Achievements = {
	{
		id = "first_fruit", name = "First Fruit", icon = "🍎",
		description = "Get a new fruit (your starter fruit doesn't count).",
		progress = "fruits", goal = 2,
		reward_text = "500 Coins",
		rewards = {{name = "Stat", props = {name = "Strength", value = 500}}},
	},
	{
		id = "first_harvest", name = "First Harvest", icon = "🌱",
		description = "Harvest 8 crops.",
		progress = "harvests", goal = 8, legacy_goal = 50, -- legacy_goal: old Kills goal (migration only)
		reward_text = "250 Coins",
		rewards = {{name = "Stat", props = {name = "Strength", value = 250}}},
	},
	{
		id = "fruit_collector", name = "Fruit Collector", icon = "🧺",
		description = "Collect 150 fruits.",
		progress = "fruits", goal = 150,
		reward_text = "🍎 Fruit Collector title + 50 Gems",
		rewards = {
			{name = "Title", props = {id = "fruit_collector"}},
			{name = "Stat", props = {name = "Gems", value = 50}},
		},
	},
	{
		id = "first_upgrade", name = "Little Farmer", icon = "🏡",
		description = "Buy your first farm upgrade.",
		progress = "farm_upgrades", goal = 1,
		reward_text = "1,000 Coins + Lucky Potion",
		rewards = {
			{name = "Stat", props = {name = "Strength", value = 1000}},
			{name = "Boost", props = {name = "Lucky_Potion", value = 1}},
		},
	},
	{
		id = "growing_farm", name = "Growing Farm", icon = "🌻",
		description = "Buy 10 farm upgrades.",
		progress = "farm_upgrades", goal = 10,
		reward_text = "500 Gems + 3 Golden Sprouts",
		rewards = {
			{name = "Stat", props = {name = "Gems", value = 500}},
			{name = "Plant", props = {name = "Golden Sprout", value = 3}},
		},
	},
	{
		id = "fruitbound_paradise", name = "Fruitbound Paradise", icon = "✨",
		description = "Buy every farm upgrade.",
		progress = "farm_upgrades", goal = 19,
		reward_text = "5,000 Gems + 5 Divine Lotus",
		rewards = {
			{name = "Stat", props = {name = "Gems", value = 5000}},
			{name = "Plant", props = {name = "Divine Lotus", value = 5}},
		},
	},
	{
		id = "explorer", name = "Explorer", icon = "🗺️",
		description = "Discover 5 areas.",
		progress = "gardens", goal = 5,
		reward_text = "Lucky Potion + 100 Gems",
		rewards = {
			{name = "Boost", props = {name = "Lucky_Potion", value = 1}},
			{name = "Stat", props = {name = "Gems", value = 100}},
		},
	},
	{
		id = "busy_bee", name = "Busy Bee", icon = "🐝",
		description = "Harvest 850 crops.",
		progress = "harvests", goal = 850, legacy_goal = 5000,
		reward_text = "🌿 Green Thumb title",
		rewards = {{name = "Title", props = {id = "green_thumb"}}},
	},
	{
		id = "food_hoarder", name = "Food Hoarder", icon = "🥕",
		description = "Fully harvest 500 plants.",
		progress = "food", goal = 500,
		reward_text = "3 Golden Sprouts (special food)",
		rewards = {{name = "Plant", props = {name = "Golden Sprout", value = 3}}},
	},
	{
		id = "nature_lover", name = "Nature Lover", icon = "💚",
		description = "Collect 750 fruits.",
		progress = "fruits", goal = 750,
		reward_text = "🍃 Nature Master title + 250 Gems",
		rewards = {
			{name = "Title", props = {id = "nature_master"}},
			{name = "Stat", props = {name = "Gems", value = 250}},
		},
	},
	{
		id = "golden_touch", name = "Golden Touch", icon = "✨",
		description = "Evolve a fruit into its Golden form.",
		progress = "stage", goal = 1,
		reward_text = "✨ Golden Gardener title",
		rewards = {{name = "Title", props = {id = "golden_gardener"}}},
	},
	{
		id = "fresh_start", name = "Fresh Start", icon = "🔁",
		description = "Rebirth 3 times.",
		progress = "rebirths", goal = 3,
		reward_text = "Lucky Potion",
		rewards = {{name = "Boost", props = {name = "Lucky_Potion", value = 1}}},
	},
	{
		id = "legendary_explorer", name = "Legendary Explorer", icon = "🧭",
		description = "Discover 12 areas.",
		progress = "gardens", goal = 12,
		reward_text = "🧭 Legendary Explorer title",
		rewards = {{name = "Title", props = {id = "legendary_explorer"}}},
	},
	{
		id = "harvest_legend", name = "Harvest Legend", icon = "🌾",
		description = "Harvest 17,000 crops.",
		progress = "harvests", goal = 17000, legacy_goal = 100000,
		reward_text = "1,000 Gems + 3 Divine Lotus",
		rewards = {
			{name = "Stat", props = {name = "Gems", value = 1000}},
			{name = "Plant", props = {name = "Divine Lotus", value = 3}},
		},
	},
	{
		id = "fruit_master", name = "Fruit Master", icon = "🏆",
		description = "Collect 10,000 fruits.",
		progress = "fruits", goal = 10000,
		reward_text = "🏆 Fruit Master title + 2,500 Gems",
		rewards = {
			{name = "Title", props = {id = "fruit_master"}},
			{name = "Stat", props = {name = "Gems", value = 2500}},
		},
	},
	{
		id = "divine_blessing", name = "Divine Blessing", icon = "👑",
		description = "Evolve a fruit into its Divine form.",
		progress = "stage", goal = 5,
		reward_text = "👑 Divine Keeper title",
		rewards = {{name = "Title", props = {id = "divine_keeper"}}},
	},
}

return Achievements
