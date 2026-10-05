--> FruitFarmUtility (V1.1)
-- Fruits as farming companions + Daycare Gem rates. Shared by the server (the real effects)
-- and the client (Fruits menu / Daycare menu), so the numbers shown are the numbers used.
--   EQUIPPED Fruit (not in Daycare): growth speed (FruitUtility boost), harvest luck, Auto Collect assist
--   DAYCARE Fruit: Gems over time only, no farming bonus at all
--   any other Fruit: nothing

local _L = _G._L

local FruitUtility
local FruitStageUtility

-- per rarity:
--   luck   = chance per MANUAL harvest for +1 extra crop unit
--   assist = seconds taken off the Auto Collect cooldown
--   gems   = Daycare Gems per hour
local RARITY = {
	Common = {luck = 0.02, assist = 0.1, gems = 5},
	Rare = {luck = 0.05, assist = 0.25, gems = 12},
	Epic = {luck = 0.08, assist = 0.4, gems = 18},
	Legendary = {luck = 0.10, assist = 0.5, gems = 28},
	Mythical = {luck = 0.12, assist = 0.6, gems = 40},
}
-- Huge / Secret / Divine (not obtainable in V1.1) use the top row
local TOP = RARITY.Mythical
-- Golden (or a higher stage) and Rainbow Fruits are a little stronger
local SPECIAL_BONUS = 1.25

local MAX_LUCK = 0.15 -- combined harvest luck of all equipped Fruits
local AUTO_BASE = 3.5 -- seconds per Auto Collect pick with no Fruit
local AUTO_FLOOR = 2 -- never faster than this
local MAX_GEMS_PER_HOUR = 40 -- per Daycare Fruit

local DAYCARE_CAPACITY = 3
local DAYCARE_MAX_PENDING = 12 * 60 * 60 -- Gems stop piling up after 12h without collecting

---------->
local FruitFarmUtility

local function rowOf(fruitData)
	local info = fruitData and FruitUtility.getInfo(fruitData.name)
	if not info then
		return nil
	end
	local row = RARITY[info.rarity] or TOP
	local mult = 1
	if FruitStageUtility.getStage(fruitData) >= 1 or fruitData.tier == "Rainbow" then
		mult = SPECIAL_BONUS
	end
	return row, mult
end

local function finite(n)
	return typeof(n) == "number" and n == n and math.abs(n) ~= math.huge
end

FruitFarmUtility = {
	DAYCARE_CAPACITY = DAYCARE_CAPACITY,
	DAYCARE_MAX_PENDING = DAYCARE_MAX_PENDING,
	AUTO_BASE = AUTO_BASE,
	AUTO_FLOOR = AUTO_FLOOR,

	-- Fruits that give farming bonuses right now
	getActive = function(data)
		return FruitUtility.getEquipped(data)
	end,

	-- one Fruit's own bonuses (Fruit details)
	getFruitBonuses = function(fruitData, data)
		local row, mult = rowOf(fruitData)
		if not row then
			return {growth = 0, luck = 0, assist = 0, gems = 0}
		end
		local info = FruitUtility.getInfo(fruitData.name)
		return {
			growth = FruitUtility.getEffectiveBoost(info, fruitData, data),
			luck = row.luck * mult,
			assist = row.assist * mult,
			gems = math.min(row.gems * mult, MAX_GEMS_PER_HOUR),
		}
	end,

	-- extra growth speed from equipped Fruits (0.25 = +25%), same number FarmingV2 uses
	getGrowthBonus = function(data)
		local total = FruitUtility.getTotalBoost(data)
		return if finite(total) then math.max(total - 1, 0) else 0
	end,

	-- chance (0..MAX_LUCK) that a manual harvest gives +1 extra crop unit
	getHarvestLuck = function(data)
		local miss = 1
		for _, fruitData in pairs(FruitUtility.getEquipped(data)) do
			local row, mult = rowOf(fruitData)
			if row then
				miss *= 1 - row.luck * mult
			end
		end
		return math.clamp(1 - miss, 0, MAX_LUCK)
	end,

	-- seconds between two Auto Collect picks
	getAutoCollectCooldown = function(data)
		local cut = 0
		for _, fruitData in pairs(FruitUtility.getEquipped(data)) do
			local row, mult = rowOf(fruitData)
			if row then
				cut += row.assist * mult
			end
		end
		return math.max(AUTO_BASE - cut, AUTO_FLOOR)
	end,

	-- Daycare Gems per hour for one Fruit
	getGemRate = function(fruitData)
		local row, mult = rowOf(fruitData)
		if not row then
			return 0
		end
		return math.min(row.gems * mult, MAX_GEMS_PER_HOUR)
	end,

	-- Gems a Daycare entry has made since it was last collected.
	-- Returns gems (whole number) and how many seconds of its timer those Gems used up
	-- (the unpaid fraction carries over, so nothing is lost between collects).
	getPending = function(entry, fruitData, now)
		local last = entry and entry.last_collected_at
		if not finite(last) or not finite(now) then
			return 0, 0
		end
		local rate = FruitFarmUtility.getGemRate(fruitData)
		local elapsed = math.max(now - last, 0)
		if rate <= 0 or elapsed <= 0 then
			return 0, 0
		end
		local paid = math.min(elapsed, DAYCARE_MAX_PENDING)
		local gems = math.floor(paid * rate / 3600)
		if elapsed > DAYCARE_MAX_PENDING then
			-- capped: the time past the cap is dropped, not banked
			return gems, elapsed
		end
		return gems, gems * 3600 / rate
	end,

	_init = function()
		FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
		FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
	end,
}

return FruitFarmUtility
