--> Upgrade Tree database
-- Each node is bought with Coins and levels up to max_level.
-- requires = {node = "id", level = n} : the parent node must reach that level first.
-- effect / per_level : what one level gives (see UpgradeTreeUtility.getBonus).
-- col / row : position of the node in the tree UI (col 1..5, row 1..4).

local UpgradeTree = {
	-- ROOT
	{
		id = "sprout", name = "Sprout", icon = "🌱", branch = "Root",
		description = "+10% Coins per level",
		effect = "coins", per_level = 0.10, max_level = 5,
		base_cost = 100, growth = 2.2,
		col = 3, row = 1,
	},

	-- COINS BRANCH
	{
		id = "golden_harvest", name = "Golden Harvest", icon = "💰", branch = "Coins",
		description = "+25% Coins per level",
		effect = "coins", per_level = 0.25, max_level = 5,
		base_cost = 5000, growth = 2.5,
		requires = {node = "sprout", level = 5},
		col = 1, row = 2,
	},
	{
		id = "midas_touch", name = "Midas Touch", icon = "👑", branch = "Coins",
		description = "+50% Coins per level",
		effect = "coins", per_level = 0.50, max_level = 5,
		base_cost = 2500000, growth = 3,
		requires = {node = "golden_harvest", level = 5},
		col = 1, row = 3,
	},

	-- LUCK BRANCH
	{
		id = "lucky_leaf", name = "Lucky Leaf", icon = "🍀", branch = "Luck",
		description = "+5% Luck on rare fruits per level",
		effect = "luck", per_level = 0.05, max_level = 5,
		base_cost = 1000, growth = 2.5,
		requires = {node = "sprout", level = 1},
		col = 2, row = 2,
	},
	{
		id = "four_leaf", name = "Four-Leaf Clover", icon = "✨", branch = "Luck",
		description = "+10% Luck on rare fruits per level",
		effect = "luck", per_level = 0.10, max_level = 5,
		base_cost = 250000, growth = 3,
		requires = {node = "lucky_leaf", level = 5},
		col = 2, row = 3,
	},
	{
		id = "rainbow_luck", name = "Rainbow Luck", icon = "🌈", branch = "Luck",
		description = "+25% Luck on rare fruits per level",
		effect = "luck", per_level = 0.25, max_level = 3,
		base_cost = 50000000, growth = 4,
		requires = {node = "four_leaf", level = 5},
		col = 2, row = 4,
	},

	-- STATS BRANCH
	{
		id = "swift_steps", name = "Swift Steps", icon = "👟", branch = "Stats",
		description = "+2 Walk Speed per level",
		effect = "speed", per_level = 2, max_level = 5,
		base_cost = 500, growth = 2.5,
		requires = {node = "sprout", level = 1},
		col = 4, row = 2,
	},
	{
		id = "bigger_basket", name = "Bigger Basket", icon = "🧺", branch = "Stats",
		description = "+10 Fruit Storage per level",
		effect = "fruit_storage", per_level = 10, max_level = 5,
		base_cost = 20000, growth = 2.5,
		requires = {node = "swift_steps", level = 3},
		col = 4, row = 3,
	},
	{
		id = "extra_hands", name = "Extra Hands", icon = "🤲", branch = "Stats",
		description = "+1 Fruit Equipped per level",
		effect = "fruit_equip", per_level = 1, max_level = 3,
		base_cost = 500000, growth = 5,
		requires = {node = "bigger_basket", level = 5},
		col = 4, row = 4,
	},

	-- REBIRTH BRANCH
	{
		id = "deep_roots", name = "Deep Roots", icon = "🌳", branch = "Rebirth",
		description = "+25% Rebirth coin bonus per level",
		effect = "rebirth_power", per_level = 0.25, max_level = 5,
		base_cost = 10000, growth = 2.5,
		requires = {node = "sprout", level = 3},
		col = 5, row = 2,
	},
	{
		id = "seed_bank", name = "Seed Bank", icon = "🌰", branch = "Rebirth",
		description = "-5% Rebirth cost per level",
		effect = "rebirth_discount", per_level = 0.05, max_level = 6,
		base_cost = 100000, growth = 2.5,
		requires = {node = "deep_roots", level = 3},
		col = 5, row = 3,
	},
	{
		id = "diamond_bloom", name = "Diamond Bloom", icon = "💎", branch = "Rebirth",
		description = "+20% Gems from Rebirth per level",
		effect = "rebirth_gems", per_level = 0.20, max_level = 5,
		base_cost = 1000000, growth = 3,
		requires = {node = "seed_bank", level = 3},
		col = 5, row = 4,
	},
}

return UpgradeTree
