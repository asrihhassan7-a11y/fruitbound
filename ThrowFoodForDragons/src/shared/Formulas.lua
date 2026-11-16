-- Single source of truth for derived player stats. Used by the server (authoritative)
-- and by the client (display + throw prediction only).
local Config = script.Parent.Config
local Upgrades = require(Config.Upgrades)
local Foods = require(Config.Foods)
local Zones = require(Config.Zones)
local Companions = require(Config.Companions)
local Dragons = require(Config.Dragons)
local Rarities = require(Config.Rarities)

local Formulas = {}

function Formulas.xpForLevel(level: number): number
	return math.floor(40 * level ^ 1.6)
end

-- Approximate coins/second of an active player in `zone` with that zone's best food.
function Formulas.income(zone: number): number
	zone = math.clamp(zone, 1, #Zones.List)
	local best = Foods.List[1]
	for _, f in Foods.List do
		if f.zone <= zone and f.value > best.value then
			best = f
		end
	end
	return best.value * Zones.List[zone].mult * 1.4
end

-- Base coins/second one farm dragon earns (before player multipliers).
function Formulas.dragonIncome(defId: string): number
	local def = Dragons.ById[defId]
	if not def then
		return 0
	end
	local zone = def.zone == 0 and #Zones.List or def.zone
	return Formulas.income(zone) * 0.1 * Rarities.Info[def.rarity].mult
end

function Formulas.farmIncome(profile, coinMult: number): number
	local total = 0
	for _, e in profile.Farm do
		total += Formulas.dragonIncome(e.d)
	end
	return total * coinMult
end

function Formulas.boostActive(profile, name: string, now: number): boolean
	local t = profile.Boosts and profile.Boosts[name]
	return t ~= nil and t > now
end

-- passes: { [passName]: true }
function Formulas.compute(profile, passes, now: number)
	local up = profile.Upgrades
	local bonus = { coins = 0, xp = 0, power = 0, crit = 0 }
	for _, uid in profile.Equipped do
		local petId = profile.Pets[uid]
		local pet = petId and Companions.Pets[petId]
		if pet then
			for k, v in pet.bonus do
				bonus[k] += v
			end
		end
	end
	local vip = passes.VIP == true
	local coinMult = Upgrades.bonusMult(up.bonus or 0) * (1 + 0.02 * (profile.Level - 1)) * (1 + bonus.coins)
	if vip then
		coinMult *= 1.5
	end
	if passes.DoubleCoins then
		coinMult *= 2
	end
	if Formulas.boostActive(profile, "Coins2x", now) then
		coinMult *= 2
	end
	local lucky = Formulas.boostActive(profile, "Lucky", now)
	local crit = math.min(0.6, Upgrades.critChance(up.crit or 0) + bonus.crit)
	if lucky then
		crit = math.min(0.75, crit * 1.5)
	end
	return {
		range = Upgrades.rangeSpeed(up.range or 0) * (1 + bonus.power),
		cooldown = Upgrades.cooldown(up.speed or 0),
		multi = Upgrades.multiCount(up.multi or 0),
		coinMult = coinMult,
		xpMult = (1 + bonus.xp) * (passes.DoubleRewards and 2 or 1),
		rewardMult = passes.DoubleRewards and 2 or 1,
		crit = crit,
		lucky = lucky,
		equipSlots = Companions.BaseEquip + (vip and 1 or 0) + (passes.ExtraInventory and 1 or 0),
		storage = Companions.BaseStorage + (passes.ExtraInventory and 50 or 0),
		farmCap = Upgrades.farmCap(up.farm or 0),
		backpack = 60 + (passes.ExtraInventory and 120 or 0),
		income = Formulas.farmIncome(profile, coinMult),
	}
end

return Formulas
