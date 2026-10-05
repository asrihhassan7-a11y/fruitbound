-- ============================================================
-- MASTERY DATABASE
-- ============================================================
-- Defines XP curves, max levels, milestones, and XP rewards
-- for the three mastery types: Power, Fruit, and Player.
--
-- To add a new milestone, simply add an entry to the milestones
-- table for that mastery type with the level as the key.
-- The system will automatically pick it up.
-- ============================================================

local Mastery = {
	-- ======================== POWER MASTERY ========================
	-- Tracked per power component (e.g. "Punch", "Fireball").
	-- XP is granted every time the player harvests with that power.
	power = {
		max_level = 100,
		base_xp = 100,
		xp_curve = 1.10, -- xp_for_level(n) = base_xp * xp_curve^(n-1)
		xp_per_use = 1,
	},

	-- ======================== GEAR MASTERY ========================
	-- Tracked per gear name (e.g. "Watering Can", "Garden Shears").
	-- XP is granted every time the player uses that gear.
	gear = {
		max_level = 100,
		base_xp = 80,
		xp_curve = 1.12,
		xp_per_use = 1,
	},

	-- ======================== FRUIT MASTERY ========================
	-- Tracked per fruit name (e.g. "Apple", "Flame Fruit").
	-- XP is granted when the player feeds plants to that fruit.
	fruit = {
		max_level = 100,
		base_xp = 50,
		xp_curve = 1.10,
		xp_per_feed = 2,
	},

	-- ======================== PLAYER MASTERY ========================
	-- A single overall track that aggregates all mastery activity.
	-- XP is granted alongside power and fruit mastery gains.
	player = {
		max_level = 50,
		base_xp = 500,
		xp_curve = 1.15,
	},

	-- ======================== MILESTONES ========================
	-- Each milestone defines what the player unlocks at that level.
	-- Fields:
	--   description (string)  - Text shown in the UI
	--   type (string)         - Identifier used by the bonus system
	--   value (number)         - The magnitude of the bonus

	power_milestones = {
		[10]  = { description = "+10% Harvest Power",   type = "strength_mult", value = 0.10 },
		[25]  = { description = "+25% Harvest Power",   type = "strength_mult", value = 0.25 },
		[50]  = { description = "+50% Harvest Power",   type = "strength_mult", value = 0.50 },
		[100] = { description = "Master Harvestor (+100%)", type = "strength_mult", value = 1.00 },
	},

	gear_milestones = {
		[10]  = { description = "Faster Use Speed",         type = "speed_mult",   value = 0.15 },
		[25]  = { description = "New Ability Unlocked",    type = "ability_unlock", value = 1 },
		[50]  = { description = "+50% Effect Power",       type = "effect_mult",  value = 0.50 },
		[100] = { description = "Master Gear (+100% Power)", type = "effect_mult",  value = 1.00 },
	},

	fruit_milestones = {
		[10]  = { description = "+10% Fruit Value",      type = "value_mult", value = 0.10 },
		[25]  = { description = "+5% Mutation Chance",   type = "mutation_chance", value = 0.05 },
		[50]  = { description = "+25% Fruit Value",      type = "value_mult", value = 0.25 },
		[100] = { description = "Fruit Master (+50% Value)", type = "value_mult", value = 0.50 },
	},

	player_milestones = {
		[5]  = { description = "+5% All Strength",        type = "strength_mult", value = 0.05 },
		[10] = { description = "+10% All Strength",       type = "strength_mult", value = 0.10 },
		[20] = { description = "+20% All Strength",        type = "strength_mult", value = 0.20 },
		[30] = { description = "+30% All Strength",        type = "strength_mult", value = 0.30 },
		[40] = { description = "+40% All Strength",        type = "strength_mult", value = 0.40 },
		[50] = { description = "Mastery Legend (+50%)",      type = "strength_mult", value = 0.50 },
	},
}

return Mastery