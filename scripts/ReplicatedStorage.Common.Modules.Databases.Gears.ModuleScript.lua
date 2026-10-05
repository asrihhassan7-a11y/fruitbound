--> Gears (V1.1 Gear Shop)
-- Gears are bought with Coins at the Village Gear Shop and are PERMANENT unlocks (data gears.owned[gear_id]).
-- Each owned Gear gives exactly one Roblox Tool. The shop stock rotates every RESTOCK_SECONDS; the stock
-- of a restock cycle is the same in every server (seeded by the cycle number), the remaining amount is
-- per server.
local _L = _G._L

local Gears = {}

Gears.RESTOCK_SECONDS = 15 * 60

-- gear_id      stable id (save key, never rename)
-- name         shown name
-- rarity       Common / Uncommon / Rare / Epic / Legendary (shop colour)
-- price        Coins (stats.Strength)
-- stock_weight chance (0-100) that this Gear is in stock in a restock cycle
-- stock_min / stock_max   how many a server can buy in that cycle
-- tool_name    name of the Roblox Tool given to owners
Gears.list = {
	{
		gear_id = "watering_can",
		name = "Watering Can",
		rarity = "Common",
		price = 2000,
		stock_weight = 80,
		stock_min = 3,
		stock_max = 6,
		tool_name = "Watering Can",
		icon = "🪣",
		description = "Tap your growing crop to water it: it grows 12% of its remaining time faster.",
	},
}

Gears.RARITY_COLORS = {
	Common = Color3.fromRGB(120, 200, 110),
	Uncommon = Color3.fromRGB(90, 180, 230),
	Rare = Color3.fromRGB(80, 120, 235),
	Epic = Color3.fromRGB(170, 90, 230),
	Legendary = Color3.fromRGB(245, 180, 50),
}

function Gears.get(gearId)
	for _, info in ipairs(Gears.list) do
		if info.gear_id == gearId then
			return info
		end
	end
	return nil
end

-- restock cycle number of a server os.time()
function Gears.cycle(now)
	return math.floor(now / Gears.RESTOCK_SECONDS)
end

-- os.time() of the next restock
function Gears.nextRestock(now)
	return (Gears.cycle(now) + 1) * Gears.RESTOCK_SECONDS
end

-- stock of one cycle: {[gear_id] = amount} (0 = not in stock this cycle)
function Gears.rollStock(cycle)
	local rng = Random.new(cycle * 7919 + 1213)
	local stock = {}
	for _, info in ipairs(Gears.list) do
		if rng:NextInteger(1, 100) <= info.stock_weight then
			stock[info.gear_id] = rng:NextInteger(info.stock_min, info.stock_max)
		else
			stock[info.gear_id] = 0
		end
	end
	return stock
end

function Gears.owns(data, gearId)
	local owned = data and data:Get({"gears", "owned"})
	return typeof(owned) == "table" and owned[gearId] == true
end

return Gears
