--> HatchAnnounce (server)
-- Global (silent) chat line when someone hatches an extremely rare fruit:
--   🌟 [RARE HATCH] Hasven hatched a SECRET Reality Fruit!
-- Called ONLY by EggUtility.give on the server, right after the fruit was really given.
-- Clients can't trigger it (they only receive C_Rare_Hatch), so fake announcements are impossible.
-- Threshold uses the existing rarity order (Databases.Fruits.Rarities): ANNOUNCE_FROM and everything above.

local _L = _G._L

local Network
local FruitUtility
local Rarities

local ANNOUNCE_FROM = "Secret" -- Secret + Divine (the two highest rarities)

local HatchAnnounce = {}

local minIndex

local function rarityIndex(name)
	for i, r in ipairs(Rarities) do
		if r.name == name then
			return i
		end
	end
end

-- player: who hatched; fruits: list of hatched fruit names (one entry per fruit actually given)
function HatchAnnounce.announce(player, fruits)
	if not player or not player.Parent or typeof(fruits) ~= "table" then
		return
	end
	for _, fruitName in ipairs(fruits) do
		local info = FruitUtility.getInfo(fruitName)
		local idx = info and rarityIndex(info.rarity)
		if idx and minIndex and idx >= minIndex then
			Network.Remote.FireAll("C_Rare_Hatch", {
				player = player.DisplayName,
				fruit = info.display_name or info.name,
				rarity = info.rarity,
			})
		end
	end
end

function HatchAnnounce._init()
	Network = _L.Get {"Common", "Library", "Network"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	Rarities = _L.Get {"Common", "Modules", "Databases", "Fruits", "Rarities"}
	minIndex = rarityIndex(ANNOUNCE_FROM)
end

function HatchAnnounce._start() end

return HatchAnnounce
