-- ============================================================
-- MASTERY UTILITY
-- ============================================================
-- Core progression logic for the Mastery system.
-- Provides functions for calculating levels, XP, adding XP,
-- and querying active bonuses from milestones.
-- ============================================================

local _L = _G._L

local Mastery
local TableUtility

local MasteryUtility = {}

function MasteryUtility._init()
	Mastery = _L.Get {"Common", "Modules", "Databases", "Mastery"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
end

-- ======================== XP / LEVEL MATH ========================

-- Returns the total XP required to reach `level` from level 1.
-- xp_for_level(n) = base_xp * xp_curve^(n-1)
-- Total XP for level L = sum of xp_for_level(2..L)
function MasteryUtility.getXpForLevel(config, level)
	local total = 0
	for i = 2, level do
		total += math.floor(config.base_xp * config.xp_curve ^ (i - 2))
	end
	return total
end

-- Returns the XP needed to go from `level` to `level + 1`.
function MasteryUtility.getXpForNextLevel(config, level)
	return math.floor(config.base_xp * config.xp_curve ^ (level - 1))
end

-- Converts raw cumulative XP into a level + remaining XP.
function MasteryUtility.getLevelFromXp(config, xp)
	local level = 1
	local remaining = xp
	while level < config.max_level do
		local needed = MasteryUtility.getXpForNextLevel(config, level)
		if remaining < needed then
			break
		end
		remaining -= needed
		level += 1
	end
	return level, remaining
end

-- Returns the progress info for a mastery entry.
function MasteryUtility.getProgress(config, xp)
	local level, currentXp = MasteryUtility.getLevelFromXp(config, xp)
	local isMax = level >= config.max_level
	local xpForNext = if isMax then 0 else MasteryUtility.getXpForNextLevel(config, level)
	return {
		level = level,
		xp = currentXp,
		xp_needed = xpForNext,
		is_max = isMax,
		progress = if isMax then 1 else currentXp / xpForNext,
	}
end

-- ======================== DATA HELPERS ========================

-- Ensures the mastery sub-table exists in the player's data.
function MasteryUtility.ensureEntry(data, masteryType, key)
	local mastery = data:Get("mastery") or {}
	if not mastery[masteryType] then
		mastery[masteryType] = {}
	end
	if key and not mastery[masteryType][key] then
		mastery[masteryType][key] = 0
	end
	data:Set("mastery", mastery)
	return mastery
end

-- Gets the raw XP for a specific mastery entry.
function MasteryUtility.getXp(data, masteryType, key)
	local mastery = data:Get("mastery") or {}
	if masteryType == "player" then
		return mastery.player or 0
	end
	-- Handle both singular ("power", "gear", "fruit") and plural ("powers", "gears", "fruits") forms
	local group = mastery[masteryType] or mastery[masteryType .. "s"] or {}
	return group[key] or 0
end

-- Adds XP to a mastery entry and returns the new total and whether a level-up occurred.
function MasteryUtility.addXp(data, masteryType, key, amount)
	local mastery = TableUtility.deep.clone(data:Get("mastery") or {
		powers = {},
		fruits = {},
		player = 0,
	})

	if not mastery.powers then mastery.powers = {} end
	if not mastery.fruits then mastery.fruits = {} end
	if not mastery.gears then mastery.gears = {} end
	if mastery.player == nil then mastery.player = 0 end

	local config = Mastery[masteryType]
	local oldXp, newXp

	if masteryType == "player" then
		oldXp = mastery.player
		newXp = oldXp + amount
		mastery.player = newXp
	else
		local group = mastery[masteryType .. "s"] -- "powers" or "fruits"
		if not group[key] then group[key] = 0 end
		oldXp = group[key]
		newXp = oldXp + amount
		group[key] = newXp
	end

	data:Set("mastery", mastery)

	-- Check for level-up
	local oldLevel = MasteryUtility.getLevelFromXp(config, oldXp)
	local newLevel = MasteryUtility.getLevelFromXp(config, newXp)
	local leveledUp = newLevel > oldLevel

	return newXp, leveledUp, newLevel, oldLevel
end

-- ======================== MILESTONES / BONUSES ========================

-- Returns all milestones at or below the given level for a mastery type.
function MasteryUtility.getActiveMilestones(masteryType, level)
	local milestones = Mastery[masteryType .. "_milestones"] or {}
	local active = {}
	for milestoneLevel, info in pairs(milestones) do
		if level >= milestoneLevel then
			active[milestoneLevel] = info
		end
	end
	return active
end

-- Returns the next milestone above the current level, or nil if maxed.
function MasteryUtility.getNextMilestone(masteryType, level)
	local milestones = Mastery[masteryType .. "_milestones"] or {}
	local nextLevel = nil
	local nextInfo = nil
	for milestoneLevel, info in pairs(milestones) do
		if milestoneLevel > level then
			if not nextLevel or milestoneLevel < nextLevel then
			nextLevel = milestoneLevel
			nextInfo = info
			end
		end
	end
	return nextLevel, nextInfo
end

-- Returns the total bonus multiplier for a given bonus type.
-- e.g. getBonus("power", level, "strength_mult") returns 1 + sum of all strength_mult values.
function MasteryUtility.getBonus(masteryType, level, bonusType)
	local active = MasteryUtility.getActiveMilestones(masteryType, level)
	local total = 0
	for _, info in pairs(active) do
		if info.type == bonusType then
			total += info.value
		end
	end
	return total
end

-- Convenience: get the combined strength multiplier from player mastery.
function MasteryUtility.getPlayerStrengthMultiplier(data)
	local xp = MasteryUtility.getXp(data, "player")
	local level = MasteryUtility.getLevelFromXp(Mastery.player, xp)
	return 1 + MasteryUtility.getBonus("player", level, "strength_mult")
end

-- Convenience: get the strength multiplier for a specific power component.
function MasteryUtility.getPowerStrengthMultiplier(data, component)
	local xp = MasteryUtility.getXp(data, "powers", component)
	local level = MasteryUtility.getLevelFromXp(Mastery.power, xp)
	return 1 + MasteryUtility.getBonus("power", level, "strength_mult")
end

-- Convenience: get the value multiplier for a specific fruit.
function MasteryUtility.getFruitValueMultiplier(data, fruitName)
	local xp = MasteryUtility.getXp(data, "fruits", fruitName)
	local level = MasteryUtility.getLevelFromXp(Mastery.fruit, xp)
	return 1 + MasteryUtility.getBonus("fruit", level, "value_mult")
end

-- Convenience: get the mutation chance bonus for a specific fruit.
function MasteryUtility.getFruitMutationBonus(data, fruitName)
	local xp = MasteryUtility.getXp(data, "fruits", fruitName)
	local level = MasteryUtility.getLevelFromXp(Mastery.fruit, xp)
	return MasteryUtility.getBonus("fruit", level, "mutation_chance")
end

-- ======================== SUMMARY ========================

-- Returns a full summary of all mastery data for UI display.
function MasteryUtility.getSummary(data)
	local mastery = data:Get("mastery") or {powers = {}, fruits = {}, player = 0}
	local summary = {
		powers = {},
		fruits = {},
		player = {},
	}

	-- Player mastery
	do
		local xp = mastery.player or 0
		local progress = MasteryUtility.getProgress(Mastery.player, xp)
		local nextLevel, nextInfo = MasteryUtility.getNextMilestone("player", progress.level)
		summary.player = {
			level = progress.level,
			xp = progress.xp,
			xp_needed = progress.xp_needed,
			is_max = progress.is_max,
			progress = progress.progress,
			next_milestone_level = nextLevel,
			next_milestone_desc = nextInfo and nextInfo.description or nil,
			active_milestones = MasteryUtility.getActiveMilestones("player", progress.level),
		}
	end

	-- Power mastery (per component)
	for component, xp in pairs(mastery.powers or {}) do
		local progress = MasteryUtility.getProgress(Mastery.power, xp)
		local nextLevel, nextInfo = MasteryUtility.getNextMilestone("power", progress.level)
		summary.powers[component] = {
			name = component,
			level = progress.level,
			xp = progress.xp,
			xp_needed = progress.xp_needed,
			is_max = progress.is_max,
			progress = progress.progress,
			next_milestone_level = nextLevel,
			next_milestone_desc = nextInfo and nextInfo.description or nil,
		}
	end

	-- Fruit mastery (per fruit name)
	for fruitName, xp in pairs(mastery.fruits or {}) do
		local progress = MasteryUtility.getProgress(Mastery.fruit, xp)
		local nextLevel, nextInfo = MasteryUtility.getNextMilestone("fruit", progress.level)
		summary.fruits[fruitName] = {
			name = fruitName,
			level = progress.level,
			xp = progress.xp,
			xp_needed = progress.xp_needed,
			is_max = progress.is_max,
			progress = progress.progress,
			next_milestone_level = nextLevel,
			next_milestone_desc = nextInfo and nextInfo.description or nil,
		}
	end

	-- Gear mastery (per gear id)
	summary.gears = {}
	for gearId, xp in pairs(mastery.gears or {}) do
		local progress = MasteryUtility.getProgress(Mastery.gear, xp)
		local nextLevel, nextInfo = MasteryUtility.getNextMilestone("gear", progress.level)
		summary.gears[gearId] = {
			id = gearId,
			level = progress.level,
			xp = progress.xp,
			xp_needed = progress.xp_needed,
			is_max = progress.is_max,
			progress = progress.progress,
			next_milestone_level = nextLevel,
			next_milestone_desc = nextInfo and nextInfo.description or nil,
			active_milestones = MasteryUtility.getActiveMilestones("gear", progress.level),
		}
	end

	return summary
end

return MasteryUtility