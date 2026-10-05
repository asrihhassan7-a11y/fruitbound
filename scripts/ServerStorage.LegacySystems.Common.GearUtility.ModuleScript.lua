-- ============================================================
-- GEAR UTILITY
-- ============================================================
-- Manages gear ownership, equipping, and effect calculations.
-- Gears are farming tools bought from the Gardener NPC.
-- Each gear has effects that scale with Gear Mastery level.
-- ============================================================

local _L = _G._L

local Gears
local MasteryUtility
local MasteryDB
local TableUtility

local GearUtility

GearUtility = {
	-- ============================================================
	-- INFO LOOKUP
	-- ============================================================

	getInfo = function(gearId)
		return Gears.getInfo(gearId)
	end,

	getAll = function()
		return Gears
	end,

	-- ============================================================
	-- OWNERSHIP
	-- ============================================================

	owns = function(data, gearId)
		local owned = data:Get({"gears", "owned"})
		return typeof(owned) == "table" and owned[gearId] == true
	end,

	getOwned = function(data)
		local owned = data:Get({"gears", "owned"})
		owned = if typeof(owned) == "table" then owned else {}
		local result = {}
		for gearId in pairs(owned) do
			local info = GearUtility.getInfo(gearId)
			if info then
				table.insert(result, info)
			end
		end
		table.sort(result, function(a, b) return a.cost < b.cost end)
		return result
	end,

	-- ============================================================
	-- EQUIPPING
	-- ============================================================

	getEquipped = function(data)
		return data:Get({"gears", "equipped"}) or nil
	end,

	isEquipped = function(data, gearId)
		return GearUtility.getEquipped(data) == gearId
	end,

	equip = function(data, gearId)
		if not GearUtility.owns(data, gearId) then
			return false, "not_owned"
		end
		local saved = data:Get("gears")
		local gears = if typeof(saved) == "table" then TableUtility.deep.clone(saved) else {}
		gears.owned = if typeof(gears.owned) == "table" then gears.owned else {}
		gears.equipped = gearId
		data:Set("gears", gears)
		return true
	end,

	unequip = function(data)
		local saved = data:Get("gears")
		local gears = if typeof(saved) == "table" then TableUtility.deep.clone(saved) else {}
		gears.owned = if typeof(gears.owned) == "table" then gears.owned else {}
		gears.equipped = nil
		data:Set("gears", gears)
		return true
	end,

	-- ============================================================
	-- PURCHASE
	-- ============================================================

	buy = function(data, gearId)
		local info = GearUtility.getInfo(gearId)
		if not info then
			return false, "invalid"
		end
		if GearUtility.owns(data, gearId) then
			return false, "already_owned"
		end
		local currency = data:Get({"stats", info.currency}) or 0
		if currency < info.cost then
			return false, "afford"
		end
		-- save ownership FIRST (whole table, so it also works for older saves without a "gears" entry),
		-- and only take the currency once the gear is really owned
		local saved = data:Get("gears")
		local gears = if typeof(saved) == "table" then TableUtility.deep.clone(saved) else {}
		gears.owned = if typeof(gears.owned) == "table" then gears.owned else {}
		gears.owned[gearId] = true
		data:Set("gears", gears)
		if not GearUtility.owns(data, gearId) then
			return false, "error"
		end
		data:Set({"stats", info.currency}, currency - info.cost)
		return true
	end,

	-- ============================================================
	-- EFFECT CALCULATION
	-- ============================================================
	-- Returns the effective effect of the currently equipped gear,
	-- scaled by the player's Gear Mastery level for that gear.

	getEffects = function(data)
		local equippedId = GearUtility.getEquipped(data)
		if not equippedId then
			return nil
		end
		local info = GearUtility.getInfo(equippedId)
		if not info then
			return nil
		end

		-- Get mastery level for this gear
		local xp = MasteryUtility.getXp(data, "gear", equippedId)
		local progress = MasteryUtility.getProgress(MasteryDB.gear, xp)
		local level = progress.level

		-- Calculate mastery multiplier from milestones
		local speedMult = 1
		local effectMult = 1
		for _, m in pairs(MasteryUtility.getActiveMilestones("gear", level)) do
			if m.type == "speed_mult" then
				speedMult += m.value
			elseif m.type == "effect_mult" then
				effectMult += m.value
			end
		end

		-- Scale the gear's effects by mastery
		local result = {}
		for key, value in pairs(info.effect or {}) do
			result[key] = value * effectMult
		end
		result.speed_mult = speedMult
		result.gear_id = equippedId
		result.gear_name = info.name
		result.gear_level = level

		return result
	end,

	-- Convenience: get regrow speed bonus from equipped gear
	getRegrowBonus = function(data)
		local effects = GearUtility.getEffects(data)
		if not effects then return 0 end
		return effects.regrow_speed or 0
	end,

	-- Convenience: get yield bonus from equipped gear
	getYieldBonus = function(data)
		local effects = GearUtility.getEffects(data)
		if not effects then return 0 end
		return effects.yield_mult or 0
	end,

	-- Convenience: get value bonus from equipped gear
	getValueBonus = function(data)
		local effects = GearUtility.getEffects(data)
		if not effects then return 0 end
		return effects.value_mult or 0
	end,

	-- ============================================================
	-- MASTERY XP
	-- ============================================================

	grantXp = function(data, gearId, amount)
		amount = amount or MasteryDB.gear.xp_per_use
		local _, leveledUp, newLevel = MasteryUtility.addXp(data, "gear", gearId, amount)
		return leveledUp, newLevel
	end,

	-- ============================================================
	-- SUMMARY (for UI)
	-- ============================================================

	getSummary = function(data)
		local equippedId = GearUtility.getEquipped(data)
		local owned = GearUtility.getOwned(data)
		local summaries = {}

		for _, info in ipairs(owned) do
			local xp = MasteryUtility.getXp(data, "gear", info.id)
			local progress = MasteryUtility.getProgress(MasteryDB.gear, xp)
			-- getNextMilestone returns (level, info)
			local nextLevel, nextInfo = MasteryUtility.getNextMilestone("gear", progress.level)

			table.insert(summaries, {
				id = info.id,
				name = info.name,
				description = info.description,
				icon = info.icon,
				color = info.color,
				type = info.type,
				equipped = equippedId == info.id,
				level = progress.level,
				xp = progress.xp,
				xp_needed = progress.xp_needed,
				is_max = progress.is_max,
				progress = progress.progress,
				next_milestone_level = nextLevel,
				next_milestone_desc = if typeof(nextInfo) == "table" then (nextInfo.description or nextInfo.desc) else nil,
			})
		end

		return {
			equipped = equippedId,
			gears = summaries,
			}
	end,

	_init = function()
		Gears = _L.Get {"Common", "Modules", "Databases", "Gears"}
		MasteryUtility = _L.Get {"Common", "Modules", "Utilities", "MasteryUtility"}
		MasteryDB = _L.Get {"Common", "Modules", "Databases", "Mastery"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	end,
}

return GearUtility