--> BackpackUtility
-- Picked plants go into the BACKPACK (data "plants" = {[name] = count}), they are not coins yet.
-- Sell them to the Gardener NPC for Coins, or keep them to feed your fruits (pets).
-- data "plant_values" = {[name] = {c = count, v = coins}} remembers what the picked items are worth
-- (worth is decided when picked: garden, farm bonuses, boosts...). Plants from rewards have no stored
-- worth and sell for a base price by rarity instead.

local _L = _G._L

local Plants

local BackpackUtility = {}

BackpackUtility.BASE_CAPACITY = 150 -- items
BackpackUtility.PER_REBIRTH = 15 -- +items per rebirth
BackpackUtility.MAX_CAPACITY = 2000

-- Base sell price (x your coin multiplier) for plants that have no stored worth
BackpackUtility.RARITY_PRICE = {
	Common = 1, Rare = 3, Epic = 10, Legendary = 40, Mythical = 150, Huge = 600, Secret = 2500, Divine = 10000,
}

function BackpackUtility.getCapacity(data)
	local rebirths = data:Get({"stats", "Rebirths"}) or 0
	return math.min(BackpackUtility.BASE_CAPACITY + rebirths * BackpackUtility.PER_REBIRTH, BackpackUtility.MAX_CAPACITY)
end

function BackpackUtility.getCount(data)
	local n = 0
	for _, count in pairs(data:Get("plants") or {}) do
		n += count
	end
	return n
end

function BackpackUtility.isFull(data)
	return BackpackUtility.getCount(data) >= BackpackUtility.getCapacity(data)
end

function BackpackUtility.getRarity(name)
	name = _L.Get({"Common", "Modules", "Utilities", "MutationUtility"}).split(name)
	for _, p in ipairs(Plants) do
		if p.name == name then
			return p.rarity
		end
	end
	return "Common"
end

-- Worth of `amount` items of `name`. unitFallback = coins for one item with no stored worth
-- (server passes base price x coin multiplier; the client can pass nil to only count stored worth).
function BackpackUtility.getWorth(data, name, amount, unitFallback)
	local count = (data:Get("plants") or {})[name] or 0
	amount = math.min(amount or count, count)
	if amount <= 0 then
		return 0
	end
	local entry = (data:Get("plant_values") or {})[name]
	local valued = if entry then math.min(entry.c or 0, count) else 0
	local perValued = if entry and valued > 0 then (entry.v or 0) / math.max(entry.c or 1, 1) else 0
	local perFallback = unitFallback or 0
	-- items are sold/fed in proportion: valued share first by ratio
	local valuedShare = amount * (valued / count)
	return math.floor(valuedShare * perValued + (amount - valuedShare) * perFallback + 0.5)
end

-- Keep plant_values in sync after `amount` items of `name` left the backpack (sold or fed)
function BackpackUtility.removeWorth(data, name, amount, countBefore)
	local values = table.clone(data:Get("plant_values") or {})
	local entry = values[name]
	if not entry then
		return
	end
	countBefore = math.max(countBefore or 0, 1)
	local keep = math.max(0, 1 - amount / countBefore)
	local newC = math.floor((entry.c or 0) * keep + 0.5)
	if newC <= 0 then
		values[name] = nil
	else
		values[name] = {c = newC, v = (entry.v or 0) * keep}
	end
	data:Set("plant_values", values)
end

function BackpackUtility._init()
	Plants = _L.Get {"Common", "Modules", "Databases", "Plants"}
end

return BackpackUtility
