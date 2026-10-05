--> MutationUtility
-- Mutated crops are stored in the backpack with the mutation as a prefix: "Wet Carrot", "Rainbow Clover".
-- split("Wet Carrot") -> "Carrot", mutationInfo

local _L = _G._L

local WorldEvents

local MutationUtility = {}

local function db()
	if not WorldEvents then
		WorldEvents = _L.Get {"Common", "Modules", "Databases", "WorldEvents"}
	end
	return WorldEvents
end

function MutationUtility.getInfo(mutationId)
	return mutationId and db().Mutations[mutationId] or nil
end

-- returns baseName, mutationInfo (nil when not mutated)
function MutationUtility.split(itemName)
	if typeof(itemName) ~= "string" then
		return itemName, nil
	end
	local prefix, rest = string.match(itemName, "^(%S+) (.+)$")
	if prefix and db().Mutations[prefix] then
		return rest, db().Mutations[prefix]
	end
	return itemName, nil
end

function MutationUtility.makeName(baseName, mutationId)
	if mutationId and db().Mutations[mutationId] then
		return mutationId .. " " .. baseName
	end
	return baseName
end

function MutationUtility.getMultiplier(itemName)
	local _, info = MutationUtility.split(itemName)
	return info and info.value or 1
end

-- can `newId` replace `currentId`? (only higher tiers)
function MutationUtility.isUpgrade(currentId, newId)
	local new = db().Mutations[newId]
	if not new then
		return false
	end
	local cur = currentId and db().Mutations[currentId]
	return not cur or new.tier > cur.tier
end

function MutationUtility._init()
	WorldEvents = _L.Get {"Common", "Modules", "Databases", "WorldEvents"}
end

return MutationUtility
