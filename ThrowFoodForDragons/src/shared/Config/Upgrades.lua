-- Upgrade tracks. cost(level) = base * growth^level for the NEXT level.
local Upgrades = {
	Order = { "range", "speed", "bonus", "crit", "multi" },
	Defs = {
		range = { name = "Throw Power", icon = "💪", desc = "Throw further", base = 60, growth = 1.62, max = 30 },
		speed = { name = "Throw Speed", icon = "⚡", desc = "Throw more often", base = 90, growth = 1.7, max = 20 },
		bonus = { name = "Feeding Bonus", icon = "💰", desc = "+12% coins per level", base = 150, growth = 1.72, max = 40 },
		crit = { name = "Lucky Toss", icon = "🍀", desc = "Chance for 3x rewards", base = 250, growth = 1.8, max = 20 },
		multi = { name = "Multi-Throw", icon = "🎯", desc = "Throw extra food at once", costs = { 25000, 2500000, 250000000, 25000000000 }, max = 4 },
	},
}

function Upgrades.cost(key: string, level: number): number?
	local d = Upgrades.Defs[key]
	if not d or level >= d.max then
		return nil
	end
	if d.costs then
		return d.costs[level + 1]
	end
	return math.floor(d.base * d.growth ^ level)
end

-- Effect values ------------------------------------------------------------
function Upgrades.rangeSpeed(level: number): number -- launch speed cap (studs/s)
	return 72 + level * 2.4
end
function Upgrades.cooldown(level: number): number -- seconds between throws
	return math.max(0.28, 0.85 - level * 0.0285)
end
function Upgrades.bonusMult(level: number): number
	return 1 + level * 0.12
end
function Upgrades.critChance(level: number): number
	return 0.03 + level * 0.012
end
function Upgrades.multiCount(level: number): number
	return 1 + level
end

-- Text shown in the shop for current -> next level.
function Upgrades.describe(key: string, level: number): string
	if key == "range" then
		return string.format("%d → %d power", Upgrades.rangeSpeed(level), Upgrades.rangeSpeed(level + 1))
	elseif key == "speed" then
		return string.format("%.2fs → %.2fs", Upgrades.cooldown(level), Upgrades.cooldown(level + 1))
	elseif key == "bonus" then
		return string.format("x%.2f → x%.2f", Upgrades.bonusMult(level), Upgrades.bonusMult(level + 1))
	elseif key == "crit" then
		return string.format("%d%% → %d%%", math.floor(Upgrades.critChance(level) * 100 + 0.5), math.floor(Upgrades.critChance(level + 1) * 100 + 0.5))
	elseif key == "multi" then
		return string.format("%d → %d food", Upgrades.multiCount(level), Upgrades.multiCount(level + 1))
	end
	return ""
end

return Upgrades
